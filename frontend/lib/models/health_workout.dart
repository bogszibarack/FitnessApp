class HealthWorkout {
  const HealthWorkout({
    required this.title,
    required this.startedAt,
    required this.durationMinutes,
    this.distanceKm,
  });

  final String title;
  final DateTime startedAt;
  final int durationMinutes;
  final double? distanceKm;
}
