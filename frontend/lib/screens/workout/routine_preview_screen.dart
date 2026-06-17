import 'package:flutter/material.dart';

import '../../models/exercise_model.dart';
import '../../models/routine_model.dart';
import '../../models/workout_models.dart';
import '../../services/exercise_service.dart';
import '../../services/workout_service.dart';
import '../../widgets/exercise_workout_widgets.dart';

/// AI (vagy egyéb) rutin előnézete — gyakorlat részletek, mint hozzáadásnál.
class RoutinePreviewScreen extends StatefulWidget {
  const RoutinePreviewScreen({
    super.key,
    required this.rutin,
    this.ai = false,
  });

  final RoutineModel rutin;
  final bool ai;

  @override
  State<RoutinePreviewScreen> createState() => _RoutinePreviewScreenState();
}

class _RoutinePreviewScreenState extends State<RoutinePreviewScreen> {
  final _service = WorkoutService.instance;
  final _exerciseService = ExerciseService.instance;

  bool _mentve = false;
  bool _mentesFolyamatban = false;
  String? _kinyitottId;
  final Map<String, ExerciseModel?> _meta = {};
  final Map<String, bool> _metaBetolt = {};
  final Map<String, List<LoggedSetModel>> _sorozatok = {};

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < widget.rutin.exerciseIds.length; i++) {
      final id = widget.rutin.exerciseIds[i];
      _sorozatok[id] = widget.rutin.gyakorlatSablonok
              .where((g) => g.exerciseId == id)
              .map((g) => g.sets)
              .where((s) => s.isNotEmpty)
              .firstOrNull ??
          WorkoutSessionModel.alapSorozatok();
    }
  }

  RoutineModel _rutinSablonokkal() {
    final sablonok = <LoggedExerciseModel>[];
    for (var i = 0; i < widget.rutin.exerciseIds.length; i++) {
      final id = widget.rutin.exerciseIds[i];
      final nev = i < widget.rutin.exerciseNames.length ? widget.rutin.exerciseNames[i] : id;
      sablonok.add(LoggedExerciseModel(
        exerciseId: id,
        exerciseName: nev,
        sets: List<LoggedSetModel>.from(_sorozatok[id] ?? WorkoutSessionModel.alapSorozatok()),
      ));
    }
    return widget.rutin.copyWith(gyakorlatSablonok: sablonok);
  }

  Future<void> _gyakorlatKinyitasa(String id) async {
    if (_kinyitottId == id) {
      setState(() => _kinyitottId = null);
      return;
    }

    setState(() {
      _kinyitottId = id;
      _metaBetolt[id] = _meta[id] == null;
    });

    if (_meta[id] != null) return;

    try {
      final reszletes = await _exerciseService.gyakorlatLekerdezese(id);
      if (!mounted || _kinyitottId != id) return;
      setState(() {
        _meta[id] = reszletes;
        _metaBetolt[id] = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _metaBetolt[id] = false);
    }
  }

  Future<void> _mentes() async {
    if (_mentve || _mentesFolyamatban) return;
    setState(() => _mentesFolyamatban = true);
    try {
      await _service.rutinMentese(_rutinSablonokkal());
      if (!mounted) return;
      setState(() {
        _mentve = true;
        _mentesFolyamatban = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mentve: ${widget.rutin.title}')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _mentesFolyamatban = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red.shade700),
      );
    }
  }

  void _inditas() {
    Navigator.of(context).pop(_rutinSablonokkal());
  }

  String _gyakorlatNev(int index) {
    if (index < widget.rutin.exerciseNames.length) {
      return widget.rutin.exerciseNames[index];
    }
    if (index < widget.rutin.exerciseIds.length) {
      return widget.rutin.exerciseIds[index];
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final rutin = widget.rutin;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          rutin.title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (widget.ai)
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: Color(0xFF1E88E5), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'AI ajánlott edzés',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                if (widget.ai) const SizedBox(height: 8),
                Text(
                  '${rutin.exerciseIds.length} gyakorlat · ${rutin.difficulty}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 6),
                Text(
                  'Koppints egy gyakorlatra a részletekért',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 14),
                if (rutin.exerciseIds.isEmpty)
                  Text('Nincs gyakorlat', style: TextStyle(color: Colors.grey.shade600))
                else
                  ...rutin.exerciseIds.asMap().entries.map((e) => _gyakorlatSor(e.key, e.value)),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: (_mentve || _mentesFolyamatban) ? null : _mentes,
                      icon: _mentesFolyamatban
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(_mentve ? Icons.check : Icons.bookmark_outline),
                      label: Text(_mentve ? 'Mentve' : 'Mentés'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _inditas,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1E88E5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Rutin indítása',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _gyakorlatSor(int index, String exerciseId) {
    final nev = _gyakorlatNev(index);
    final kinyitott = _kinyitottId == exerciseId;
    final meta = _meta[exerciseId];
    final betolt = _metaBetolt[exerciseId] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: kinyitott ? const Color(0xFF1E88E5).withValues(alpha: 0.06) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => _gyakorlatKinyitasa(exerciseId),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${index + 1}.',
                      style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey.shade500),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(nev, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                        if (meta != null)
                          Text(
                            [meta.muscleGroup, meta.equipment, meta.category].where((s) => s.isNotEmpty).join(' · '),
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    kinyitott ? Icons.expand_less : Icons.expand_more,
                    color: const Color(0xFF1E88E5),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (kinyitott)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: betolt
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : meta == null
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text('Nem sikerült betölteni a részleteket.', style: TextStyle(color: Colors.grey.shade600)),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                              child: ExerciseMediaPreview(images: meta.images, compact: true),
                            ),
                            ExerciseInfoSor(meta: meta),
                            ExerciseTamLeiras(meta: meta),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                              child: Text(
                                'Ajánlott sorozatok',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                            HelyiSorozatSzerkeszto(
                              sorozatok: _sorozatok[exerciseId] ?? WorkoutSessionModel.alapSorozatok(),
                              onValtozas: (uj) => setState(() => _sorozatok[exerciseId] = uj),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
            ),
          ),
        Divider(height: 1, color: Colors.grey.shade200),
      ],
    );
  }
}
