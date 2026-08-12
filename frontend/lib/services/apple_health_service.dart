import 'package:flutter/services.dart';
import 'package:health/health.dart';

import '../models/daily_health_data.dart';
import '../models/health_workout.dart';
import '../utils/platform_utils.dart';

class AppleHealthService {
  AppleHealthService._();
  static final AppleHealthService instance = AppleHealthService._();

  static const _summaryChannel = MethodChannel('com.fitnessapp/activity_summary');

  final Health _health = Health();
  bool _configured = false;

  bool get isSupported => isAppleHealthPlatform;

  // Csak a megbízható, automatikusan gyűjtött adattípusok.
  // Az étkezési adatokat (DIETARY_*) kihagyjuk – azokat a saját napló kezeli.
  // Az APPLE_STAND_HOUR-t kihagyjuk – category típus, csak activity summary-ból jön.
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

    // Timeout mindenhol: ha a HealthKit hívás beragad, az onboarding
    // ne pörögjön örökké — a felhasználó továbbléphet.
    try {
      final permissions = _readTypes.map((_) => HealthDataAccess.READ).toList();
      await _health
          .requestAuthorization(_readTypes, permissions: permissions)
          .timeout(const Duration(seconds: 45));
    } catch (_) {}

    // Natív activity summary engedély
    try {
      await _summaryChannel
          .invokeMethod<bool>('requestAuthorization')
          .timeout(const Duration(seconds: 20));
    } catch (_) {}

    // iOS-on nem lehet megbízhatóan ellenőrizni, hogy az engedélyt megadták-e.
    // Az engedélyezési dialógus megjelent – true visszatérési érték.
    return true;
  }

  // iOS privacy miatt ez mindig false-t adna vissza – ne használjuk.
  // Helyette a SharedPreferences 'health_enabled' flagot kell olvasni.
  @Deprecated('Use SharedPreferences health_enabled flag instead')
  Future<bool> hasPermissions() async {
    if (!isSupported) return false;
    await _ensureConfigured();
    final result = await _health.hasPermissions(_readTypes);
    return result ?? false;
  }

  Future<DailyHealthData> fetchToday() async {
    if (!isSupported) {
      return DailyHealthData.empty();
    }

    await _ensureConfigured();

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = now;

    // Natív activity summary (Move/Exercise/Stand gyűrűk)
    final summary = await _fetchActivitySummary();

    // Lépések – legmegbízhatóbb adat iPhone-on
    int steps = 0;
    try {
      steps = await _health.getTotalStepsInInterval(start, end) ?? 0;
    } catch (_) {}

    final distanceM = await _sumQuantity(HealthDataType.DISTANCE_WALKING_RUNNING, start, end);
    final basal = await _sumQuantity(HealthDataType.BASAL_ENERGY_BURNED, start, end);

    int moveKcal;
    int exerciseMin;
    if (summary != null) {
      moveKcal = summary['moveKcal'] ?? 0;
      exerciseMin = summary['exerciseMinutes'] ?? 0;
    } else {
      moveKcal = (await _sumQuantity(HealthDataType.ACTIVE_ENERGY_BURNED, start, end)).round();
      exerciseMin = (await _sumQuantity(HealthDataType.EXERCISE_TIME, start, end)).round();
    }

    final moveGoal = summary?['moveGoalKcal'] ?? 500;
    final exerciseGoal = summary?['exerciseGoalMinutes'] ?? 30;
    final standHours = summary?['standHours'] ?? 0;
    final standGoal = summary?['standGoalHours'] ?? 12;

    final calorieGoal = (basal.round() + moveGoal).clamp(1500, 6000);
    final carbsGoal = (calorieGoal * 0.5 / 4).round();
    final proteinGoal = (calorieGoal * 0.25 / 4).round();
    final fatGoal = (calorieGoal * 0.25 / 9).round();

    return DailyHealthData(
      moveKcal: moveKcal,
      moveGoalKcal: moveGoal,
      exerciseMinutes: exerciseMin,
      exerciseGoalMinutes: exerciseGoal,
      standHours: standHours,
      standGoalHours: standGoal,
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
          distanceM = value.totalDistance?.toDouble();
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

  Future<Map<String, int>?> _fetchActivitySummary() async {
    try {
      final result = await _summaryChannel
          .invokeMethod<Map<dynamic, dynamic>>('fetchTodaySummary')
          .timeout(const Duration(seconds: 10));
      if (result == null) return null;

      return {
        'moveKcal': (result['moveKcal'] as num?)?.round() ?? 0,
        'moveGoalKcal': (result['moveGoalKcal'] as num?)?.round() ?? 500,
        'exerciseMinutes': (result['exerciseMinutes'] as num?)?.round() ?? 0,
        'exerciseGoalMinutes': (result['exerciseGoalMinutes'] as num?)?.round() ?? 30,
        'standHours': (result['standHours'] as num?)?.round() ?? 0,
        'standGoalHours': (result['standGoalHours'] as num?)?.round() ?? 12,
      };
    } catch (_) {
      return null;
    }
  }

  Future<double> _sumQuantity(HealthDataType type, DateTime start, DateTime end) async {
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
