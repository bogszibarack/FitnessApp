import 'package:flutter/material.dart';

import '../../models/routine_model.dart';
import '../../services/workout_service.dart';

class _EdzestervOpcio {
  const _EdzestervOpcio({
    required this.id,
    required this.label,
    required this.targetMuscle,
    required this.sportCategory,
    required this.csoport,
  });

  final String id;
  final String label;
  final String targetMuscle;
  final String sportCategory;
  final String csoport;
}

/// AI edzésterv — izomcsoport, PPL, powerlifting, yoga.
class AiExploreScreen extends StatefulWidget {
  const AiExploreScreen({super.key});

  @override
  State<AiExploreScreen> createState() => _AiExploreScreenState();
}

class _AiExploreScreenState extends State<AiExploreScreen> {
  final _service = WorkoutService.instance;

  static const _nehezsegek = ['beginner', 'intermediate', 'advanced'];

  static const _izomMagyar = {
    'Abdominals': 'Has (Abdominals)',
    'Abductors': 'Abduktorok',
    'Adductors': 'Adduktorok',
    'Biceps': 'Biceps',
    'Calves': 'Vádli (Calves)',
    'Cardio': 'Kardió',
    'Chest': 'Mell (Chest)',
    'Forearms': 'Alkar (Forearms)',
    'Full Body': 'Teljes test',
    'Glutes': 'Farizom (Glutes)',
    'Hamstrings': 'Combhajlító (Hamstrings)',
    'Lats': 'Hát (Lats)',
    'Lower Back': 'Alsó hát',
    'Neck': 'Nyak',
    'Quadriceps': 'Combizom (Quadriceps)',
    'Shoulders': 'Váll (Shoulders)',
    'Traps': 'Trapéz (Traps)',
    'Triceps': 'Triceps',
    'Upper Back': 'Felső hát',
    'Other': 'Egyéb',
  };

  static final List<_EdzestervOpcio> _opciok = [
    ...[
      'Abdominals',
      'Abductors',
      'Adductors',
      'Biceps',
      'Calves',
      'Cardio',
      'Chest',
      'Forearms',
      'Full Body',
      'Glutes',
      'Hamstrings',
      'Lats',
      'Lower Back',
      'Neck',
      'Quadriceps',
      'Shoulders',
      'Traps',
      'Triceps',
      'Upper Back',
      'Other',
    ].map(
      (izom) => _EdzestervOpcio(
        id: 'izom_$izom',
        label: _izomMagyar[izom] ?? izom,
        targetMuscle: izom,
        sportCategory: 'gym',
        csoport: 'Izomcsoportok',
      ),
    ),
    const _EdzestervOpcio(
      id: 'ppl_push',
      label: 'Push — mell, váll, triceps',
      targetMuscle: 'Push',
      sportCategory: 'gym',
      csoport: 'Push / Pull / Legs',
    ),
    const _EdzestervOpcio(
      id: 'ppl_pull',
      label: 'Pull — hát, biceps',
      targetMuscle: 'Pull',
      sportCategory: 'gym',
      csoport: 'Push / Pull / Legs',
    ),
    const _EdzestervOpcio(
      id: 'ppl_legs',
      label: 'Legs — láb',
      targetMuscle: 'Legs',
      sportCategory: 'gym',
      csoport: 'Push / Pull / Legs',
    ),
    const _EdzestervOpcio(
      id: 'pl_bench',
      label: 'Bench press',
      targetMuscle: 'Bench',
      sportCategory: 'gym',
      csoport: 'Powerlifting',
    ),
    const _EdzestervOpcio(
      id: 'pl_squat',
      label: 'Squat',
      targetMuscle: 'Squat',
      sportCategory: 'gym',
      csoport: 'Powerlifting',
    ),
    const _EdzestervOpcio(
      id: 'pl_deadlift',
      label: 'Pull — deadlift',
      targetMuscle: 'Deadlift',
      sportCategory: 'gym',
      csoport: 'Powerlifting',
    ),
    const _EdzestervOpcio(
      id: 'yoga',
      label: 'Yoga flow',
      targetMuscle: 'Yoga',
      sportCategory: 'yoga',
      csoport: 'Yoga',
    ),
  ];

  late _EdzestervOpcio _valasztott = _opciok.firstWhere((o) => o.targetMuscle == 'Chest');
  String _nehezseg = 'beginner';
  List<RoutineModel> _variaciok = [];
  bool _betolt = false;
  String? _hiba;

  Future<void> _generalas() async {
    setState(() {
      _betolt = true;
      _hiba = null;
    });
    try {
      final lista = await _service.aiAjanlatok(
        difficulty: _nehezseg,
        targetMuscle: _valasztott.targetMuscle,
        sportCategory: _valasztott.sportCategory,
      );
      if (!mounted) return;
      setState(() {
        _variaciok = lista;
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

  Future<void> _mentes(RoutineModel rutin) async {
    try {
      await _service.rutinMentese(rutin);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mentve: ${rutin.title}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red.shade700),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('AI edzésterv', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Válaszd ki mit szeretnél edzeni — az AI 3 variációt készít, gyakorlatlistával.',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _valasztott.id,
            decoration: const InputDecoration(
              labelText: 'Edzés típusa',
              border: OutlineInputBorder(),
            ),
            items: _dropdownElemek(),
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _valasztott = _opciok.firstWhere((o) => o.id == v);
              });
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _nehezseg,
            decoration: const InputDecoration(labelText: 'Nehézség', border: OutlineInputBorder()),
            items: _nehezsegek.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
            onChanged: (v) => setState(() => _nehezseg = v ?? _nehezseg),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _betolt ? null : _generalas,
            icon: _betolt
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(_betolt ? 'Generálás...' : '3 variáció generálása'),
          ),
          if (_hiba != null) ...[
            const SizedBox(height: 12),
            Text(_hiba!, style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
          ],
          const SizedBox(height: 20),
          ..._variaciok.map(_variacioKartya),
        ],
      ),
    );
  }

  List<DropdownMenuItem<String>> _dropdownElemek() {
    final elemek = <DropdownMenuItem<String>>[];
    String? elozoCsoport;

    for (final opcio in _opciok) {
      if (opcio.csoport != elozoCsoport) {
        elozoCsoport = opcio.csoport;
        elemek.add(
          DropdownMenuItem<String>(
            enabled: false,
            value: '__header_${opcio.csoport}',
            child: Text(
              opcio.csoport,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade600,
              ),
            ),
          ),
        );
      }
      elemek.add(
        DropdownMenuItem(
          value: opcio.id,
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(opcio.label),
          ),
        ),
      );
    }

    return elemek;
  }

  Widget _variacioKartya(RoutineModel r) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Color(0xFF1E88E5), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(r.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
                Text(
                  '${r.exerciseNames.length} gyak.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gyakorlatok',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (r.exerciseNames.isEmpty)
                    Text('Nincs gyakorlat', style: TextStyle(fontSize: 13, color: Colors.grey.shade600))
                  else
                    ...r.exerciseNames.asMap().entries.map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 22,
                                  child: Text(
                                    '${e.key + 1}.',
                                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    e.value,
                                    style: const TextStyle(fontSize: 13, height: 1.3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _mentes(r),
                    child: const Text('Mentés'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(r),
                    child: const Text('Indítás'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
