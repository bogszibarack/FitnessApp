import 'dart:math' as math;

import 'package:flutter/material.dart';

class ActivityRingData {
  const ActivityRingData({
    required this.label,
    required this.current,
    required this.goal,
    required this.unit,
    required this.color,
    required this.progress,
  });

  final String label;
  final String current;
  final String goal;
  final String unit;
  final Color color;
  final double progress;
}

class ActivityRings extends StatelessWidget {
  const ActivityRings({
    super.key,
    required this.rings,
    this.size = 120,
    this.strokeWidth = 14,
    this.gap = 6,
  });

  final List<ActivityRingData> rings;
  final double size;
  final double strokeWidth;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _ActivityRingsPainter(
        rings: rings,
        strokeWidth: strokeWidth,
        gap: gap,
      ),
    );
  }
}

class _ActivityRingsPainter extends CustomPainter {
  _ActivityRingsPainter({
    required this.rings,
    required this.strokeWidth,
    required this.gap,
  });

  final List<ActivityRingData> rings;
  final double strokeWidth;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2 - strokeWidth / 2;

    for (var i = 0; i < rings.length; i++) {
      final radius = maxRadius - i * (strokeWidth + gap);
      final ring = rings[i];

      final trackPaint = Paint()
        ..color = ring.color.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      final progressPaint = Paint()
        ..color = ring.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      const startAngle = -math.pi / 2;
      const sweepAngle = 2 * math.pi;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        trackPaint,
      );

      final clampedProgress = ring.progress.clamp(0.0, 1.0);
      if (clampedProgress > 0) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          sweepAngle * clampedProgress,
          false,
          progressPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ActivityRingsPainter oldDelegate) {
    return oldDelegate.rings != rings;
  }
}
