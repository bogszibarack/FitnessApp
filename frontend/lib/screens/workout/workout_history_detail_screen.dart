import 'package:flutter/material.dart';

import '../../models/workout_models.dart';
import '../../services/workout_service.dart';
import '../../widgets/exercise_workout_widgets.dart';

/// Befejezett edzés megtekintése és szerkesztése.
class WorkoutHistoryDetailScreen extends StatefulWidget {
  const WorkoutHistoryDetailScreen({super.key, required this.edzes});

  final WorkoutSessionModel edzes;

  @override
  State<WorkoutHistoryDetailScreen> createState() => _WorkoutHistoryDetailScreenState();
}

class _WorkoutHistoryDetailScreenState extends State<WorkoutHistoryDetailScreen> {
  final _service = WorkoutService.instance;
  late final TextEditingController _cimController;
  late List<LoggedExerciseModel> _gyakorlatok;
  bool _mentes = false;

  @override
  void initState() {
    super.initState();
    _cimController = TextEditingController(text: widget.edzes.megjelenitettCim);
    _gyakorlatok = widget.edzes.exercises
        .map((g) => LoggedExerciseModel(
              exerciseId: g.exerciseId,
              exerciseName: g.exerciseName,
              sets: List<LoggedSetModel>.from(g.sets),
            ))
        .toList();
  }

  Future<void> _mentesInditasa() async {
    setState(() => _mentes = true);
    try {
      final friss = widget.edzes.copyWith(
        title: _cimController.text.trim(),
        exercises: _gyakorlatok,
      );
      await _service.edzesTortenetModositas(friss);
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
        title: const Text('Edzés törlése'),
        content: Text('Biztosan törlöd: ${widget.edzes.megjelenitettCim}?'),
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
      await _service.edzesTortenetTorlese(widget.edzes.id);
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
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        title: const Text('Edzés szerkesztése', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        actions: [
          IconButton(onPressed: _torles, icon: Icon(Icons.delete_outline, color: Colors.red.shade400)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _osszefoglaloKartya(),
          const SizedBox(height: 16),
          TextField(
            controller: _cimController,
            decoration: const InputDecoration(
              labelText: 'Edzés neve',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          const Text('Gyakorlatok', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
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
                    sorozatok: g.sets.isEmpty ? WorkoutSessionModel.alapSorozatok() : g.sets,
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
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Változások mentése'),
          ),
        ],
      ),
    );
  }

  Widget _osszefoglaloKartya() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sor('Dátum', widget.edzes.datumSzoveg),
          _sor('Időtartam', widget.edzes.idoSzoveg),
          _sor('Sorozat', '${widget.edzes.osszSorozatSzam}'),
          _sor('Térfogat', '${widget.edzes.osszTomegKg.toStringAsFixed(0)} kg'),
        ],
      ),
    );
  }

  Widget _sor(String cimke, String ertek) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(cimke, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          const Spacer(),
          Text(ertek, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }
}
