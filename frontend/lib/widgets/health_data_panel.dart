import 'package:flutter/material.dart';

import '../models/daily_health_data.dart';

/// Sajat Fitness App UI — Apple Health adatok, NEM Apple Fitness gyűrűk.
class HealthDataPanel extends StatelessWidget {
  const HealthDataPanel({
    super.key,
    required this.data,
    required this.isLiveAppleHealth,
    required this.formatNumber,
    required this.formatDistance,
  });

  final DailyHealthData data;
  final bool isLiveAppleHealth;
  final String Function(int) formatNumber;
  final String Function(double) formatDistance;

  static const _primary = Color(0xFF1E88E5);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSourceHeader(),
        const SizedBox(height: 12),
        _buildMetricsGrid(),
        const SizedBox(height: 16),
        _buildGoalsCard(),
      ],
    );
  }

  Widget _buildSourceHeader() {
    return Row(
      children: [
        const Text(
          'Mai mozgás',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.black87),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isLiveAppleHealth ? const Color(0xFFE8F5E9) : const Color(0xFFE3F2FD),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isLiveAppleHealth ? const Color(0xFF34C759) : _primary,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isLiveAppleHealth ? Icons.favorite : Icons.cloud_outlined,
                size: 14,
                color: isLiveAppleHealth ? const Color(0xFF34C759) : _primary,
              ),
              const SizedBox(width: 4),
              Text(
                isLiveAppleHealth ? 'Apple Health' : 'Backend / demo',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isLiveAppleHealth ? const Color(0xFF2E7D32) : _primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.45,
      children: [
        _MetricTile(
          icon: Icons.directions_walk_rounded,
          label: 'Lépés',
          value: formatNumber(data.steps),
          unit: 'lépés',
          color: const Color(0xFF7C4DFF),
        ),
        _MetricTile(
          icon: Icons.route_rounded,
          label: 'Távolság',
          value: formatDistance(data.distanceKm).replaceAll(' KM', ''),
          unit: 'km',
          color: _primary,
        ),
        _MetricTile(
          icon: Icons.local_fire_department_rounded,
          label: 'Aktív kalória',
          value: '${data.moveKcal}',
          unit: 'kcal',
          color: const Color(0xFFFF6D00),
        ),
        _MetricTile(
          icon: Icons.timer_outlined,
          label: 'Edzés idő',
          value: '${data.exerciseMinutes}',
          unit: 'perc',
          color: const Color(0xFF00BFA5),
        ),
      ],
    );
  }

  Widget _buildGoalsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Napi célok',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 14),
          _GoalBar(
            label: 'Mozgás',
            current: data.moveKcal,
            goal: data.moveGoalKcal,
            unit: 'kcal',
            color: const Color(0xFFFF6D00),
          ),
          const SizedBox(height: 12),
          _GoalBar(
            label: 'Edzés',
            current: data.exerciseMinutes,
            goal: data.exerciseGoalMinutes,
            unit: 'perc',
            color: const Color(0xFF00BFA5),
          ),
          const SizedBox(height: 12),
          _GoalBar(
            label: 'Állás',
            current: data.standHours,
            goal: data.standGoalHours,
            unit: 'óra',
            color: _primary,
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const Spacer(),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Text(unit, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoalBar extends StatelessWidget {
  const _GoalBar({
    required this.label,
    required this.current,
    required this.goal,
    required this.unit,
    required this.color,
  });

  final String label;
  final int current;
  final int goal;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final progress = goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0.0;
    final percent = (progress * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const Spacer(),
            Text(
              '$current / $goal $unit',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(width: 8),
            Text('$percent%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: color.withValues(alpha: 0.15),
            color: color,
          ),
        ),
      ],
    );
  }
}
