import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/workout_models.dart';
import '../../services/plan_service.dart';
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
  bool _betolt = true;
  Timer? _stopper;
  String? _nyitottGyakorlatId;

  @override
  void initState() {
    super.initState();
    _frissites();
    _stopper = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_edzes != null && mounted) setState(() {});
    });
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
    final hozzaadva = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddExerciseScreen()),
    );
    if (hozzaadva == true) await _frissites();
  }

  void _gyakorlatNyitasa(String exerciseId) {
    setState(() {
      _nyitottGyakorlatId = _nyitottGyakorlatId == exerciseId ? null : exerciseId;
    });
  }

  Future<void> _befejezes() async {
    if (_edzes == null) return;
    _stopper?.cancel();

    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => WorkoutSummaryScreen(
          edzes: _edzes!,
          onMentes: (cim, mentRutin, progresszioSzazalek) async {
            if (cim.isNotEmpty) {
              await _service.updateWorkoutTitle(cim);
            }
            final befejezett = await _service.finishWorkout();
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

    await _service.discardWorkout();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _stopper?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gyakorlatok = _edzes?.exercises ?? [];

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
              onTap: _elvetes,
            ),
          ),
          const SizedBox(width: 8),
          Center(
            child: ModernButton(
              cimke: 'Befejezés',
              kicsi: true,
              ikon: Icons.check_rounded,
              szin: const Color(0xFF00897B),
              onTap: _befejezes,
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
      body: _betolt
          ? const Center(child: CircularProgressIndicator())
          : _edzes == null
              ? const Center(child: Text('Nincs aktív edzés'))
              : Column(
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
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: gyakorlatok.length,
                          itemBuilder: (context, index) {
                            final g = gyakorlatok[index];
                            final nyitva = _nyitottGyakorlatId == g.exerciseId;
                            final osszSorozat = g.sets.length;
                            final kesz = g.elvegzettSorozatok;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                children: [
                                  ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: kesz > 0
                                          ? Colors.green.shade50
                                          : const Color(0xFF1E88E5).withValues(alpha: 0.12),
                                      child: Text(
                                        '${index + 1}',
                                        style: TextStyle(
                                          color: kesz > 0 ? Colors.green.shade700 : const Color(0xFF1E88E5),
                                          fontWeight: FontWeight.w700,
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
                                        onFrissult: _frissites,
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                  ],
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
