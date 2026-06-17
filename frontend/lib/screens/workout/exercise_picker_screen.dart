import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/exercise_model.dart';
import '../../services/exercise_service.dart';
import '../../widgets/exercise_workout_widgets.dart';

/// Gyakorlat kiválasztása rutin összeállításhoz.
class ExercisePickerScreen extends StatefulWidget {
  const ExercisePickerScreen({super.key, this.kizarvaIds = const {}});

  final Set<String> kizarvaIds;

  @override
  State<ExercisePickerScreen> createState() => _ExercisePickerScreenState();
}

class _ExercisePickerScreenState extends State<ExercisePickerScreen> {
  final _service = ExerciseService.instance;
  final _keresoController = TextEditingController();

  List<ExerciseModel> _talalatok = [];
  bool _betolt = false;
  String? _hiba;
  String? _kivalasztottId;
  ExerciseModel? _reszletek;
  bool _reszletekBetolt = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _kereses('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _keresoController.dispose();
    super.dispose();
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
      final lista = await _service.kereses(szoveg);
      if (!mounted) return;
      setState(() {
        _talalatok = lista.where((g) => !widget.kizarvaIds.contains(g.id)).toList();
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

  Future<void> _kivalasztas(ExerciseModel gyakorlat) async {
    if (_kivalasztottId == gyakorlat.id) {
      setState(() {
        _kivalasztottId = null;
        _reszletek = null;
      });
      return;
    }

    setState(() {
      _kivalasztottId = gyakorlat.id;
      _reszletek = gyakorlat;
      _reszletekBetolt = true;
    });

    try {
      final reszletes = await _service.gyakorlatLekerdezese(gyakorlat.id);
      if (!mounted || _kivalasztottId != gyakorlat.id) return;
      setState(() {
        _reszletek = reszletes ?? gyakorlat;
        _reszletekBetolt = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _reszletekBetolt = false);
    }
  }

  void _hozzaadas(ExerciseModel gyakorlat) {
    Navigator.of(context).pop(gyakorlat);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Gyakorlat hozzáadása', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _keresoController,
              decoration: InputDecoration(
                hintText: 'Keresés név vagy izom szerint...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
              ),
              onChanged: _onKeresesValtozott,
            ),
          ),
          Expanded(child: _lista()),
        ],
      ),
    );
  }

  Widget _lista() {
    if (_betolt) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_hiba != null) {
      return Center(child: Text(_hiba!, style: TextStyle(color: Colors.red.shade700, fontSize: 13)));
    }
    if (_talalatok.isEmpty) {
      return const Center(child: Text('Nincs találat'));
    }

    return ListView.separated(
      itemCount: _talalatok.length,
      separatorBuilder: (_, __) => Divider(height: 1, indent: 16, color: Colors.grey.shade200),
      itemBuilder: (context, index) {
        final g = _talalatok[index];
        final kivalasztott = _kivalasztottId == g.id;
        final reszletek = kivalasztott ? (_reszletek ?? g) : null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              tileColor: kivalasztott ? const Color(0xFF1E88E5).withValues(alpha: 0.06) : null,
              title: Text(g.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              subtitle: Text(
                [g.muscleGroup, g.equipment, g.category].where((s) => s.isNotEmpty).join(' · '),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              trailing: Icon(
                kivalasztott ? Icons.expand_less : Icons.add_circle_outline,
                color: const Color(0xFF1E88E5),
              ),
              onTap: () => _kivalasztas(g),
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
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: FilledButton.icon(
                          onPressed: () => _hozzaadas(reszletek),
                          icon: const Icon(Icons.add),
                          label: const Text('Hozzáadás a rutinhoz'),
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
