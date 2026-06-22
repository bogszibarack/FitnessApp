import 'package:flutter/material.dart';

/// Kaloria osszefoglalo — sajat dizajn, nem Apple/Yazio gyuru.
class NutritionSummaryCard extends StatelessWidget {
  const NutritionSummaryCard({
    super.key,
    required this.consumed,
    required this.burned,
    required this.goal,
    required this.remaining,
    required this.carbs,
    required this.carbsGoal,
    required this.protein,
    required this.proteinGoal,
    required this.fat,
    required this.fatGoal,
  });

  final int consumed;
  final int burned;
  final int goal;
  final int remaining;
  final int carbs;
  final int carbsGoal;
  final int protein;
  final int proteinGoal;
  final int fat;
  final int fatGoal;

  static const _accent = Color(0xFF1E88E5);

  @override
  Widget build(BuildContext context) {
    final progress = goal > 0 ? (consumed / goal).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatPill(value: '$consumed', label: 'Bevitt', color: const Color(0xFFFF6D00), unit: 'kcal'),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '$remaining',
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: _accent),
                    ),
                    Text('kcal maradt ma', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 10,
                        backgroundColor: _accent.withValues(alpha: 0.12),
                        color: _accent,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('Cél: $goal kcal', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _StatPill(value: '$burned', label: 'Elégetett', color: const Color(0xFF00BFA5), unit: 'kcal'),
            ],
          ),
          const SizedBox(height: 20),
          _MacroRow(label: 'Szénhidrát', current: carbs, goal: carbsGoal, color: const Color(0xFFFFB300)),
          const SizedBox(height: 10),
          _MacroRow(label: 'Fehérje', current: protein, goal: proteinGoal, color: const Color(0xFFE91E63)),
          const SizedBox(height: 10),
          _MacroRow(label: 'Zsír', current: fat, goal: fatGoal, color: const Color(0xFF7C4DFF)),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.value, required this.label, required this.color, this.unit = ''});

  final String value;
  final String label;
  final Color color;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
        if (unit.isNotEmpty)
          Text(unit, style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.7))),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }
}

class _MacroRow extends StatelessWidget {
  const _MacroRow({
    required this.label,
    required this.current,
    required this.goal,
    required this.color,
  });

  final String label;
  final int current;
  final int goal;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0.0;
    return Row(
      children: [
        SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: p, minHeight: 6, backgroundColor: color.withValues(alpha: 0.15), color: color),
          ),
        ),
        const SizedBox(width: 8),
        Text('$current/${goal}g', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }
}
