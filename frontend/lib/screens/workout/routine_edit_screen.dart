import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../models/exercise_model.dart';
import '../../models/routine_model.dart';
import '../../models/workout_models.dart';
import '../../services/workout_service.dart';
import '../../widgets/exercise_workout_widgets.dart';
import 'exercise_picker_screen.dart';

/// Új vagy mentett rutin szerkesztése.
class RoutineEditScreen extends StatefulWidget {
  const RoutineEditScreen({
    super.key,
    required this.rutin,
    this.ujRutin = false,
  });

  final RoutineModel rutin;
  final bool ujRutin;

  @override
  State<RoutineEditScreen> createState() => _RoutineEditScreenState();
}

class _RoutineEditScreenState extends State<RoutineEditScreen> {
  final _service = WorkoutService.instance;
  late final TextEditingController _cimController;
  late List<LoggedExerciseModel> _gyakorlatok;
  bool _mentes = false;

  bool get _ujRutin => widget.ujRutin || widget.rutin.id.isEmpty;

  @override
  void initState() {
    super.initState();
    _cimController = TextEditingController(text: widget.rutin.title);
    if (widget.rutin.gyakorlatSablonok.isNotEmpty) {
      _gyakorlatok = List.from(widget.rutin.gyakorlatSablonok);
    } else {
      _gyakorlatok = widget.rutin.exerciseIds.asMap().entries.map((e) {
        final idx = e.key;
        return LoggedExerciseModel(
          exerciseId: e.value,
          exerciseName: idx < widget.rutin.exerciseNames.length ? widget.rutin.exerciseNames[idx] : e.value,
          sets: WorkoutSessionModel.alapSorozatok(),
        );
      }).toList();
    }
  }

  Future<void> _gyakorlatHozzaadasa() async {
    final kizarva = _gyakorlatok.map((g) => g.exerciseId).toSet();
    final uj = await Navigator.of(context).push<ExerciseModel>(
      MaterialPageRoute(builder: (_) => ExercisePickerScreen(kizarvaIds: kizarva)),
    );
    if (uj == null || !mounted) return;

    setState(() {
      _gyakorlatok.add(LoggedExerciseModel(
        exerciseId: uj.id,
        exerciseName: uj.name,
        sets: WorkoutSessionModel.alapSorozatok(),
      ));
    });
  }

  Future<void> _mentesInditasa() async {
    final cim = _cimController.text.trim();
    if (cim.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add meg a rutin nevét!')),
      );
      return;
    }
    if (_gyakorlatok.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adj hozzá legalább egy gyakorlatot!')),
      );
      return;
    }

    setState(() => _mentes = true);
    try {
      final friss = widget.rutin.copyWith(
        title: cim,
        exerciseIds: _gyakorlatok.map((g) => g.exerciseId).toList(),
        exerciseNames: _gyakorlatok.map((g) => g.exerciseName).toList(),
        gyakorlatSablonok: _gyakorlatok,
      );

      if (_ujRutin) {
        await _service.rutinMentese(
          RoutineModel(
            id: '',
            title: friss.title,
            difficulty: widget.rutin.difficulty.isNotEmpty ? widget.rutin.difficulty : 'beginner',
            targetMuscle: widget.rutin.targetMuscle.isNotEmpty ? widget.rutin.targetMuscle : 'Full Body',
            sportCategory: widget.rutin.sportCategory.isNotEmpty ? widget.rutin.sportCategory : 'gym',
            exerciseIds: friss.exerciseIds,
            exerciseNames: friss.exerciseNames,
            creatorName: ApiConfig.defaultUserName,
            gyakorlatSablonok: friss.gyakorlatSablonok,
          ),
        );
      } else {
        await _service.rutinModositas(friss);
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red.shade700),
      );
      setState(() => _mentes = false);
    }
  }

  Future<void> _torles() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rutin törlése'),
        content: Text('Biztosan törlöd: ${widget.rutin.title}?'),
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
    if (ok != true) return;

    try {
      await _service.rutinTorlese(widget.rutin.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red.shade700),
      );
    }
  }

  @override
  void dispose() {
    _cimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          _ujRutin ? 'Új rutin' : 'Rutin szerkesztése',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        actions: [
          if (!_ujRutin)
            IconButton(onPressed: _torles, icon: Icon(Icons.delete_outline, color: Colors.red.shade400)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _cimController,
            decoration: const InputDecoration(
              labelText: 'Rutin neve',
              hintText: 'pl. Hétfői mell edzés',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Gyakorlatok', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const Spacer(),
              TextButton.icon(
                onPressed: _gyakorlatHozzaadasa,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Hozzáadás'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_gyakorlatok.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                'Még nincs gyakorlat. Nyomd meg a „Hozzáadás” gombot.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
              ),
            )
          else
            ..._gyakorlatok.asMap().entries.map((e) {
              final g = e.value;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ExpansionTile(
                  title: Text(g.exerciseName, style: const TextStyle(fontWeight: FontWeight.w600)),
                  trailing: IconButton(
                    icon: Icon(Icons.close, color: Colors.red.shade400, size: 20),
                    onPressed: () => setState(() => _gyakorlatok.removeWhere((x) => x.exerciseId == g.exerciseId)),
                  ),
                  children: [
                    HelyiSorozatSzerkeszto(
                      sorozatok: g.sets,
                      onValtozas: (uj) => setState(() {
                        _gyakorlatok[e.key] = LoggedExerciseModel(
                          exerciseId: g.exerciseId,
                          exerciseName: g.exerciseName,
                          sets: uj,
                        );
                      }),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _mentes ? null : _mentesInditasa,
            child: _mentes
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(_ujRutin ? 'Rutin mentése' : 'Mentés'),
          ),
        ],
      ),
    );
  }
}
