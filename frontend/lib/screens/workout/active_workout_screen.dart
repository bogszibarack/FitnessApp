import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/workout_models.dart';
import '../../services/plan_service.dart';
import '../../services/settings_service.dart';
import '../../services/sound_service.dart';
import '../../services/workout_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/exercise_workout_widgets.dart';
import '../../widgets/modern_button.dart';
import 'add_exercise_screen.dart';
import 'workout_summary_screen.dart';

class ActiveWorkoutScreen extends StatefulWidget {
  const ActiveWorkoutScreen({super.key, required this.edzesCim});

  final String edzesCim;

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> {
  final _service = WorkoutService.instance;
  WorkoutSessionModel? _edzes;
  WorkoutSettings _beallitasok = WorkoutSettings.alap;
  bool _betolt = true;
  Timer? _stopper;
  Timer? _pihenoTimer;
  int? _pihenoHatralevo;
  int _pihenoOsszes = 0;
  String? _nyitottGyakorlatId;

  @override
  void initState() {
    super.initState();
    _inditas();
    _stopper = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_edzes != null && mounted) setState(() {});
    });
  }

  Future<void> _inditas() async {
    await _beallitasokBetoltese();
    await _frissites();
  }

  Future<void> _beallitasokBetoltese() async {
    try {
      final settingsService = await SettingsService.letrehozasa();
      final beallitasok = await settingsService.getWorkoutSettings();
      await SoundService.instance.beallitasMentes(
        hangok: beallitasok.sounds,
        prHang: beallitasok.prSound,
      );
      if (!mounted) return;
      setState(() => _beallitasok = beallitasok);
    } catch (_) {
      // Alapértelmezett beállítások maradnak.
    }
  }

  Future<void> _frissites() async {
    setState(() => _betolt = _edzes == null);
    try {
      final edzes = await _service.activeWorkout();
      if (!mounted) return;
      setState(() {
        _edzes = edzes;
        _betolt = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _betolt = false);
    }
  }

  String _formazottIdo() {
    final mp = _edzes?.elteltMasodperc ?? 0;
    final perc = mp ~/ 60;
    final masodperc = mp % 60;
    return '${perc.toString().padLeft(2, '0')}:${masodperc.toString().padLeft(2, '0')}';
  }

  Future<void> _gyakorlatHozzaadasa() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final hozzaadva = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddExerciseScreen()),
    );
    if (hozzaadva == true) await _frissites();
  }

  void _gyakorlatNyitasa(String exerciseId) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _nyitottGyakorlatId = _nyitottGyakorlatId == exerciseId ? null : exerciseId;
    });
  }

  void _billentyuzetElrejtese() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  bool _pihenoIndithato(int gyakorlatIndex) {
    if (!_beallitasok.restTimerEnabled) return false;
    if (!_beallitasok.smartSuperset) return true;

    final gyakorlatok = _edzes?.exercises ?? [];
    final parosElso = gyakorlatIndex % 2 == 0;
    final vanPartnere = gyakorlatIndex + 1 < gyakorlatok.length;
    if (parosElso && vanPartnere) return false;
    return true;
  }

  void _pihenoInditasa() {
    _pihenoTimer?.cancel();
    final mp = _beallitasok.restTimerSeconds;
    if (mp <= 0) return;

    setState(() {
      _pihenoOsszes = mp;
      _pihenoHatralevo = mp;
    });

    _pihenoTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_pihenoHatralevo == null || _pihenoHatralevo! <= 1) {
        timer.cancel();
        _pihenoBefejezese();
        return;
      }
      setState(() => _pihenoHatralevo = _pihenoHatralevo! - 1);
    });
  }

  Future<void> _pihenoBefejezese() async {
    _pihenoTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _pihenoHatralevo = null;
      _pihenoOsszes = 0;
    });
    await SoundService.instance.playRestCompleteSound();
  }

  void _pihenoKihagyasa() {
    _pihenoTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _pihenoHatralevo = null;
      _pihenoOsszes = 0;
    });
  }

  void _sorozatKesz(int gyakorlatIndex) {
    if (_pihenoIndithato(gyakorlatIndex)) {
      _pihenoInditasa();
    }
  }

  bool _szuperszettPar(int index, int osszes) {
    return _beallitasok.smartSuperset && index % 2 == 0 && index + 1 < osszes;
  }

  String _gyakorlatCimke(int index, int osszes) {
    if (!_beallitasok.smartSuperset) return '${index + 1}';
    if (_szuperszettPar(index, osszes)) return 'A1';
    if (index > 0 && _szuperszettPar(index - 1, osszes)) return 'A2';
    return '${index + 1}';
  }

  Future<void> _befejezes() async {
    if (_edzes == null) return;
    _stopper?.cancel();
    _pihenoKihagyasa();

    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => WorkoutSummaryScreen(
          edzes: _edzes!,
          onMentes: (cim, mentRutin, progresszioSzazalek, megoszt) async {
            if (cim.isNotEmpty) {
              await _service.updateWorkoutTitle(cim);
            }
            final befejezett = megoszt
                ? await _service.finishAndShareWorkout()
                : await _service.finishWorkout();
            if (mentRutin) {
              await PlanService.instance.saveFromWorkout(session: befejezett, title: cim);
            }
            if (mounted) Navigator.of(context).popUntil((r) => r.isFirst || !r.isCurrent);
          },
        ),
      ),
    );
  }

  Future<void> _elvetes() async {
    final megerosites = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edzés elvetése'),
        content: const Text('Biztosan elveted? Az adatok nem lesznek mentve.'),
        actions: [
          TextButton(
            onPressed: () {
              Haptics.light();
              Navigator.pop(ctx, false);
            },
            child: const Text('Mégse'),
          ),
          ModernButton(
            cimke: 'Elvetés',
            kicsi: true,
            szin: Colors.red,
            onTap: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (megerosites != true) return;

    _pihenoKihagyasa();
    await _service.discardWorkout();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _stopper?.cancel();
    _pihenoTimer?.cancel();
    super.dispose();
  }

  Widget _gyakorlatKartya(LoggedExerciseModel g, int index, int osszes) {
    final nyitva = _nyitottGyakorlatId == g.exerciseId;
    final osszSorozat = g.sets.length;
    final kesz = g.elvegzettSorozatok;
    final cimke = _gyakorlatCimke(index, osszes);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: kesz > 0
                  ? Colors.green.shade50
                  : const Color(0xFF1E88E5).withValues(alpha: 0.12),
              child: Text(
                cimke,
                style: TextStyle(
                  color: kesz > 0 ? Colors.green.shade700 : const Color(0xFF1E88E5),
                  fontWeight: FontWeight.w700,
                  fontSize: cimke.length > 2 ? 11 : 14,
                ),
              ),
            ),
            title: Text(g.exerciseName, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              osszSorozat == 0
                  ? 'Nyisd ki a sorozatokhoz'
                  : '$kesz / $osszSorozat sorozat kész',
            ),
            trailing: Icon(nyitva ? Icons.expand_less : Icons.expand_more),
            onTap: () {
              Haptics.selection();
              _gyakorlatNyitasa(g.exerciseId);
            },
          ),
          if (nyitva)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: InlineGyakorlatPanel(
                key: ValueKey(g.exerciseId),
                exerciseId: g.exerciseId,
                exerciseName: g.exerciseName,
                trackRpe: _beallitasok.trackRpe,
                onFrissult: _frissites,
                onSorozatKesz: () => _sorozatKesz(index),
              ),
            ),
        ],
      ),
    );
  }

  Widget _szuperszettCsoport(List<LoggedExerciseModel> gyakorlatok, int parIndex) {
    final i = parIndex * 2;
    final g1 = gyakorlatok[i];
    final g2 = gyakorlatok[i + 1];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF7043).withValues(alpha: 0.45), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF7043).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.merge_rounded, size: 14, color: Color(0xFFFF7043)),
                      SizedBox(width: 4),
                      Text(
                        'Szuperszett',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFFF7043),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  'A1 → A2',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          _gyakorlatKartya(g1, i, gyakorlatok.length),
          Divider(height: 1, color: const Color(0xFFFF7043).withValues(alpha: 0.25)),
          _gyakorlatKartya(g2, i + 1, gyakorlatok.length),
        ],
      ),
    );
  }

  List<Widget> _gyakorlatListaElemek(List<LoggedExerciseModel> gyakorlatok) {
    if (!_beallitasok.smartSuperset) {
      return List.generate(
        gyakorlatok.length,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _gyakorlatKartya(gyakorlatok[index], index, gyakorlatok.length),
        ),
      );
    }

    final elemek = <Widget>[];
    var i = 0;
    while (i < gyakorlatok.length) {
      if (i + 1 < gyakorlatok.length) {
        elemek.add(_szuperszettCsoport(gyakorlatok, i ~/ 2));
        i += 2;
      } else {
        elemek.add(Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _gyakorlatKartya(gyakorlatok[i], i, gyakorlatok.length),
        ));
        i++;
      }
    }
    return elemek;
  }

  @override
  Widget build(BuildContext context) {
    final gyakorlatok = _edzes?.exercises ?? [];
    final pihenoAktiv = _pihenoHatralevo != null;

    return Scaffold(
      backgroundColor: AppColors.hatter,
      appBar: AppBar(
        backgroundColor: AppColors.felulet,
        foregroundColor: AppColors.szoveg,
        elevation: 0.5,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.edzesCim, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            Text(_formazottIdo(), style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
          ],
        ),
        actions: [
          Center(
            child: ModernButton(
              cimke: 'Elvetés',
              kicsi: true,
              kitoltott: false,
              szin: Colors.red,
              onTap: () {
                _billentyuzetElrejtese();
                _elvetes();
              },
            ),
          ),
          const SizedBox(width: 8),
          Center(
            child: ModernButton(
              cimke: 'Befejezés',
              kicsi: true,
              ikon: Icons.check_rounded,
              szin: const Color(0xFF00897B),
              onTap: () {
                _billentyuzetElrejtese();
                _befejezes();
              },
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      floatingActionButton: _edzes == null
          ? null
          : ModernButton(
              cimke: 'Gyakorlat',
              ikon: Icons.add,
              szin: const Color(0xFF1E88E5),
              onTap: _gyakorlatHozzaadasa,
            ),
      body: GestureDetector(
        onTap: _billentyuzetElrejtese,
        behavior: HitTestBehavior.deferToChild,
        child: _betolt
            ? const Center(child: CircularProgressIndicator())
            : _edzes == null
                ? const Center(child: Text('Nincs aktív edzés'))
                : Stack(
                    children: [
                      Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: Row(
                              children: [
                                Expanded(child: _infoKartya('Sorozat', '${_edzes!.osszSorozatSzam}')),
                                const SizedBox(width: 8),
                                Expanded(child: _infoKartya('Térfogat', '${_edzes!.osszTomegKg.toStringAsFixed(0)} kg')),
                                const SizedBox(width: 8),
                                Expanded(child: _infoKartya('Gyakorlat', '${gyakorlatok.length}')),
                              ],
                            ),
                          ),
                          if (gyakorlatok.isEmpty)
                            Expanded(
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.fitness_center, size: 56, color: Colors.grey.shade400),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'Adj hozzá az első gyakorlatot',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 20),
                                      ModernButton(
                                        cimke: 'Gyakorlat keresése',
                                        ikon: Icons.search,
                                        onTap: _gyakorlatHozzaadasa,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          else
                            Expanded(
                              child: ListView(
                                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                                padding: EdgeInsets.fromLTRB(16, 16, 16, pihenoAktiv ? 100 : 16),
                                children: [
                                  ..._gyakorlatListaElemek(gyakorlatok),
                                  // Üres terület a billentyűzet elrejtéséhez koppintással
                                  SizedBox(
                                    height: 120,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: _billentyuzetElrejtese,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      if (pihenoAktiv)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: PihenoIdozitoBanner(
                            hatralevoMp: _pihenoHatralevo!,
                            osszesMp: _pihenoOsszes,
                            onKihagyas: _pihenoKihagyasa,
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }

  Widget _infoKartya(String cimke, String ertek) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.kartya,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.szegely),
      ),
      child: Column(
        children: [
          Text(cimke, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          Text(ertek, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        ],
      ),
    );
  }
}
