import 'dart:io';

import 'package:flutter/services.dart';
import 'package:health/health.dart';

import '../models/daily_health_data.dart';

class AppleHealthService {
  AppleHealthService._();
  static final AppleHealthService instance = AppleHealthService._();

  static const _summaryChannel = MethodChannel('com.fitnessapp/activity_summary');

  final Health _health = Health();
  bool _configured = false;

  bool get isSupported => Platform.isIOS;

  static const _readTypes = [
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.BASAL_ENERGY_BURNED,
    HealthDataType.EXERCISE_TIME,
    HealthDataType.APPLE_STAND_HOUR,
    HealthDataType.STEPS,
    HealthDataType.DISTANCE_WALKING_RUNNING,
    HealthDataType.DIETARY_ENERGY_CONSUMED,
    HealthDataType.DIETARY_CARBS_CONSUMED,
    HealthDataType.DIETARY_PROTEIN_CONSUMED,
    HealthDataType.DIETARY_FATS_CONSUMED,
  ];

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  Future<bool> requestPermissions() async {
    if (!isSupported) return false;

    await _ensureConfigured();

    final permissions = _readTypes.map((_) => HealthDataAccess.READ).toList();
    final granted = await _health.requestAuthorization(_readTypes, permissions: permissions);

    try {
      await _summaryChannel.invokeMethod<bool>('requestAuthorization');
    } catch (_) {}

    return granted;
  }

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

    final summary = await _fetchActivitySummary();
    final steps = await _health.getTotalStepsInInterval(start, end) ?? 0;
    final distanceM = await _sumQuantity(HealthDataType.DISTANCE_WALKING_RUNNING, start, end);
    final consumed = await _sumQuantity(HealthDataType.DIETARY_ENERGY_CONSUMED, start, end);
    final basal = await _sumQuantity(HealthDataType.BASAL_ENERGY_BURNED, start, end);
    final carbs = await _sumQuantity(HealthDataType.DIETARY_CARBS_CONSUMED, start, end);
    final protein = await _sumQuantity(HealthDataType.DIETARY_PROTEIN_CONSUMED, start, end);
    final fat = await _sumQuantity(HealthDataType.DIETARY_FATS_CONSUMED, start, end);

    final moveKcal = summary?['moveKcal'] ?? (await _sumQuantity(HealthDataType.ACTIVE_ENERGY_BURNED, start, end)).round();
    final moveGoal = summary?['moveGoalKcal'] ?? 500;
    final exerciseMin = summary?['exerciseMinutes'] ?? (await _sumQuantity(HealthDataType.EXERCISE_TIME, start, end)).round();
    final exerciseGoal = summary?['exerciseGoalMinutes'] ?? 30;
    final standHours = summary?['standHours'] ?? 0;
    final standGoal = summary?['standGoalHours'] ?? 12;

    final calorieGoal = (basal + moveGoal).round().clamp(1500, 6000);
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
      caloriesConsumed: consumed.round(),
      caloriesBurned: moveKcal,
      calorieGoal: calorieGoal,
      carbsGrams: carbs.round(),
      proteinGrams: protein.round(),
      fatGrams: fat.round(),
      carbsGoalGrams: carbsGoal,
      proteinGoalGrams: proteinGoal,
      fatGoalGrams: fatGoal,
      isFromAppleHealth: true,
    );
  }

  Future<Map<String, int>?> _fetchActivitySummary() async {
    try {
      final result = await _summaryChannel.invokeMethod<Map<dynamic, dynamic>>('fetchTodaySummary');
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
