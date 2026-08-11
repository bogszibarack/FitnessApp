import 'package:health/health.dart';

import '../models/daily_health_data.dart';
import '../models/health_workout.dart';
import '../utils/platform_utils.dart';

/// Android Health Connect (Google Fit–style activity data via the health package).
class HealthConnectService {
  HealthConnectService._();
  static final HealthConnectService instance = HealthConnectService._();

  final Health _health = Health();
  bool _configured = false;

  bool get isSupported => isHealthConnectPlatform;

  static const _readTypes = [
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.BASAL_ENERGY_BURNED,
    HealthDataType.EXERCISE_TIME,
    HealthDataType.STEPS,
    HealthDataType.DISTANCE_WALKING_RUNNING,
    HealthDataType.WORKOUT,
  ];

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    try {
      await _health.configure().timeout(const Duration(seconds: 10));
      _configured = true;
    } catch (_) {}
  }

  Future<bool> requestPermissions() async {
    if (!isSupported) return false;
    await _ensureConfigured();

    try {
      final permissions = _readTypes.map((_) => HealthDataAccess.READ).toList();
      final granted = await _health
          .requestAuthorization(_readTypes, permissions: permissions)
          .timeout(const Duration(seconds: 45));
      return granted;
    } catch (_) {
      return false;
    }
  }

  Future<bool> hasPermissions() async {
    if (!isSupported) return false;
    await _ensureConfigured();
    try {
      final result = await _health.hasPermissions(_readTypes);
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<DailyHealthData> fetchToday() async {
    if (!isSupported) return DailyHealthData.empty();

    await _ensureConfigured();

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = now;

    int steps = 0;
    try {
      steps = await _health.getTotalStepsInInterval(start, end) ?? 0;
    } catch (_) {}

    final distanceM =
        await _sumQuantity(HealthDataType.DISTANCE_WALKING_RUNNING, start, end);
    final moveKcal =
        (await _sumQuantity(HealthDataType.ACTIVE_ENERGY_BURNED, start, end))
            .round();
    final exerciseMin =
        (await _sumQuantity(HealthDataType.EXERCISE_TIME, start, end)).round();
    final basal =
        (await _sumQuantity(HealthDataType.BASAL_ENERGY_BURNED, start, end))
            .round();

    final calorieGoal = (basal + 500).clamp(1500, 6000);
    final carbsGoal = (calorieGoal * 0.5 / 4).round();
    final proteinGoal = (calorieGoal * 0.25 / 4).round();
    final fatGoal = (calorieGoal * 0.25 / 9).round();

    return DailyHealthData(
      moveKcal: moveKcal,
      moveGoalKcal: 500,
      exerciseMinutes: exerciseMin,
      exerciseGoalMinutes: 30,
      standHours: 0,
      standGoalHours: 12,
      steps: steps,
      distanceKm: distanceM / 1000,
      caloriesConsumed: 0,
      caloriesBurned: moveKcal,
      calorieGoal: calorieGoal,
      carbsGrams: 0,
      proteinGrams: 0,
      fatGrams: 0,
      carbsGoalGrams: carbsGoal,
      proteinGoalGrams: proteinGoal,
      fatGoalGrams: fatGoal,
      isFromAppleHealth: true,
    );
  }

  /// Recent workout sessions from Health Connect (watch / fitness apps).
  Future<List<HealthWorkout>> fetchRecentWorkouts({int days = 7}) async {
    if (!isSupported) return [];
    await _ensureConfigured();

    final end = DateTime.now();
    final start = end.subtract(Duration(days: days));

    try {
      final points = await _health.getHealthDataFromTypes(
        types: [HealthDataType.WORKOUT],
        startTime: start,
        endTime: end,
      );

      return points.map((point) {
        final value = point.value;
        String title = 'Edzés';
        double? distanceM;
        if (value is WorkoutHealthValue) {
          title = value.workoutActivityType.name;
          distanceM = value.totalDistance;
        }
        final durationMin = point.dateTo.difference(point.dateFrom).inMinutes;
        return HealthWorkout(
          title: title,
          startedAt: point.dateFrom,
          durationMinutes: durationMin,
          distanceKm: distanceM != null ? distanceM / 1000 : null,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<double> _sumQuantity(
    HealthDataType type,
    DateTime start,
    DateTime end,
  ) async {
    try {
      final points = await _health.getHealthDataFromTypes(
        types: [type],
        startTime: start,
        endTime: end,
      );
      return points.fold<double>(0, (sum, point) {
        final value = point.value;
        if (value is NumericHealthValue) {
          return sum + value.numericValue;
        }
        return sum;
      });
    } catch (_) {
      return 0;
    }
  }
}
