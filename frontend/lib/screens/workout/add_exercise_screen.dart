import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/exercise_model.dart';
import '../../models/workout_models.dart';
import '../../services/exercise_service.dart';
import '../../services/workout_service.dart';
import '../../widgets/exercise_workout_widgets.dart';

/// Hevy: Add Exercise — előnézet + hozzáadás ugyanazon a képernyőn.
class AddExerciseScreen extends StatefulWidget {
  const AddExerciseScreen({super.key});

  @override
  State<AddExerciseScreen> createState() => _AddExerciseScreenState();
}

class _AddExerciseScreenState extends State<AddExerciseScreen> {
  final _exerciseService = ExerciseService.instance;
  final _workoutService = WorkoutService.instance;
  final _keresoController = TextEditingController();

  List<ExerciseModel> _talalatok = [];
  bool _betolt = false;
  String? _hiba;
  String? _hozzaadasAlatt;
  String? _kivalasztottId;
  ExerciseModel? _kivalasztottReszletek;
  bool _reszletekBetolt = false;
  final Map<String, String> _hozzaadottNevek = {};
  final Map<String, List<LoggedSetModel>> _sorozatSablonok = {};
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _kereses('');
    _hozzaadottakBetoltese();
  }

  Future<void> _hozzaadottakBetoltese() async {
    try {
      final edzes = await _workoutService.aktivEdzes();
      if (edzes == null || !mounted) return;
      setState(() {
        for (final g in edzes.exercises) {
          _hozzaadottNevek[g.exerciseId] = g.exerciseName;
        }
      });
    } catch (_) {}
  }

  void _onKeresesValtozott(String szoveg) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _kereses(szoveg));
  }

  Future<void> _kereses(String szoveg) async {
    setState(() {
      _betolt = true;
      _hiba = null;
    });

    try {
      final lista = await _exerciseService.kereses(szoveg);
      if (!mounted) return;
      setState(() {
        _talalatok = lista;
        _betolt = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hiba = e.toString();
        _betolt = false;
      });
    }
  }

  Future<void> _gyakorlatKivalasztasa(ExerciseModel gyakorlat) async {
    if (_kivalasztottId == gyakorlat.id) {
      setState(() {
        _kivalasztottId = null;
        _kivalasztottReszletek = null;
      });
      return;
    }

    setState(() {
      _kivalasztottId = gyakorlat.id;
      _kivalasztottReszletek = gyakorlat;
      _reszletekBetolt = true;
      _sorozatSablonok.putIfAbsent(gyakorlat.id, () => WorkoutSessionModel.alapSorozatok());
    });

    try {
      final reszletes = await _exerciseService.gyakorlatLekerdezese(gyakorlat.id);
      if (!mounted || _kivalasztottId != gyakorlat.id) return;
      setState(() {
        _kivalasztottReszletek = reszletes ?? gyakorlat;
        _reszletekBetolt = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _reszletekBetolt = false);
    }
  }

  Future<void> _gyakorlatHozzaadasa(ExerciseModel gyakorlat) async {
    if (_hozzaadottNevek.containsKey(gyakorlat.id)) return;

    setState(() => _hozzaadasAlatt = gyakorlat.id);
    try {
      final sorozatok = _sorozatSablonok[gyakorlat.id] ?? WorkoutSessionModel.alapSorozatok();
      await _workoutService.gyakorlatHozzaadasa(
        exerciseId: gyakorlat.id,
        exerciseName: gyakorlat.name,
        sets: sorozatok,
      );
      if (!mounted) return;
      setState(() {
        _hozzaadottNevek[gyakorlat.id] = gyakorlat.name;
        _hozzaadasAlatt = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${gyakorlat.name} hozzáadva'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red.shade700),
      );
      setState(() => _hozzaadasAlatt = null);
    }
  }

  Future<void> _gyakorlatTorlese(String exerciseId, String nev) async {
    final megerosites = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gyakorlat eltávolítása'),
        content: Text('Eltávolítod az edzésből: $nev?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Mégse')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Törlés'),
          ),
        ],
      ),
    );
    if (megerosites != true) return;

    try {
      await _workoutService.gyakorlatTorlese(exerciseId);
      if (!mounted) return;
      setState(() {
        _hozzaadottNevek.remove(exerciseId);
        if (_kivalasztottId == exerciseId) {
          _kivalasztottId = null;
          _kivalasztottReszletek = null;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$nev eltávolítva'), duration: const Duration(seconds: 2)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red.shade700),
      );
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _keresoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hozzaadottSzam = _hozzaadottNevek.length;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        title: const Text('Gyakorlat hozzáadása', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          if (hozzaadottSzam > 0)
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Kész ($hozzaadottSzam)', style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: Column(
        children: [
          if (hozzaadottSzam > 0) _buildHozzaadottLista(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _keresoController,
              autofocus: hozzaadottSzam == 0,
              onChanged: _onKeresesValtozott,
              decoration: InputDecoration(
                hintText: 'Keresés (név vagy ID)...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _keresoController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _keresoController.clear();
                          _onKeresesValtozott('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  _betolt ? 'Betöltés...' : '${_talalatok.length} gyakorlat',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const Spacer(),
                Text(
                  'Koppints az előnézethez',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Expanded(child: _buildLista()),
        ],
      ),
    );
  }

  Widget _buildHozzaadottLista() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hozzáadva (${_hozzaadottNevek.length})',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.green.shade800),
          ),
          const SizedBox(height: 8),
          ..._hozzaadottNevek.entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, size: 16, color: Colors.green.shade600),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(e.value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      icon: Icon(Icons.close, size: 18, color: Colors.red.shade400),
                      tooltip: 'Eltávolítás',
                      onPressed: () => _gyakorlatTorlese(e.key, e.value),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildLista() {
    if (_betolt && _talalatok.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Gyakorlatok letöltése a Git repóból...'),
            SizedBox(height: 4),
            Text('Első alkalommal 10–30 mp', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      );
    }

    if (_hiba != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(_hiba!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
              FilledButton(onPressed: () => _kereses(_keresoController.text), child: const Text('Újra')),
            ],
          ),
        ),
      );
    }

    if (_talalatok.isEmpty) {
      return const Center(child: Text('Nincs találat'));
    }

    return ListView.separated(
      itemCount: _talalatok.length,
      separatorBuilder: (_, index) => Divider(height: 1, indent: 16, color: Colors.grey.shade200),
      itemBuilder: (context, index) {
        final g = _talalatok[index];
        final kivalasztott = _kivalasztottId == g.id;
        final hozzaad = _hozzaadasAlatt == g.id;
        final marHozzaadva = _hozzaadottNevek.containsKey(g.id);
        final reszletek = kivalasztott ? (_kivalasztottReszletek ?? g) : null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              tileColor: kivalasztott ? const Color(0xFF1E88E5).withValues(alpha: 0.06) : null,
              title: Text(
                g.name,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: marHozzaadva ? Colors.green.shade700 : null,
                ),
              ),
              subtitle: Text(
                [g.muscleGroup, g.equipment, g.category].where((s) => s.isNotEmpty).join(' · '),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              trailing: hozzaad
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : marHozzaadva
                      ? IconButton(
                          icon: Icon(Icons.remove_circle_outline, color: Colors.red.shade400),
                          tooltip: 'Eltávolítás',
                          onPressed: () => _gyakorlatTorlese(g.id, g.name),
                        )
                      : Icon(
                          kivalasztott ? Icons.expand_less : Icons.add_circle_outline,
                          color: const Color(0xFF1E88E5),
                        ),
              onTap: hozzaad ? null : () => _gyakorlatKivalasztasa(g),
            ),
            if (kivalasztott && reszletek != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                        child: _reszletekBetolt
                            ? const AspectRatio(
                                aspectRatio: 2.2,
                                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              )
                            : ExerciseMediaPreview(images: reszletek.images, compact: true),
                      ),
                      ExerciseInfoSor(meta: reszletek),
                      if (marHozzaadva)
                        InlineGyakorlatPanel(
                          exerciseId: reszletek.id,
                          exerciseName: reszletek.name,
                          onFrissult: () {},
                          csakSorozatok: true,
                        )
                      else
                        HelyiSorozatSzerkeszto(
                          sorozatok: _sorozatSablonok[reszletek.id] ?? WorkoutSessionModel.alapSorozatok(),
                          onValtozas: (uj) => setState(() => _sorozatSablonok[reszletek.id] = uj),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: marHozzaadva
                            ? OutlinedButton.icon(
                                onPressed: () => _gyakorlatTorlese(reszletek.id, reszletek.name),
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                label: const Text('Eltávolítás az edzésből', style: TextStyle(color: Colors.red)),
                              )
                            : FilledButton.icon(
                                onPressed: hozzaad ? null : () => _gyakorlatHozzaadasa(reszletek),
                                icon: const Icon(Icons.add),
                                label: const Text('Hozzáadás az edzéshez'),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
