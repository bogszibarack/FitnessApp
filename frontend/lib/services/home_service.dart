import '../models/daily_health_data.dart';
import '../models/nutrition_models.dart';
import '../utils/platform_utils.dart';
import 'device_health_service.dart';
import 'local_store.dart';
import 'nutrition_service.dart';

class MealCalories {
  const MealCalories({this.reggeli = 0, this.ebed = 0, this.vacsora = 0, this.nasi = 0});

  final int reggeli;
  final int ebed;
  final int vacsora;
  final int nasi;
}

class HomeLoadResult {
  const HomeLoadResult({
    required this.data,
    required this.meals,
    required this.naplo,
    required this.source,
    this.permissionNeeded = false,
  });

  final DailyHealthData data;
  final MealCalories meals;
  final DailyNutritionModel naplo;
  final String source;
  final bool permissionNeeded;
}

class HomeService {
  HomeService._();
  static final HomeService instance = HomeService._();

  final _health = DeviceHealthService.instance;
  final _nutrition = NutritionService.instance;

  Future<HomeLoadResult> loadToday() async {
    DailyNutritionModel naplo;
    try {
      naplo = await _nutrition.maiNaplo();
    } catch (e) {
      naplo = DailyNutritionModel(
        date: DateTime.now(),
        targetCalories: 2000,
        eatenFoods: [],
        totalCalories: 0,
        totalProtein: 0,
        totalCarbs: 0,
        totalFat: 0,
        remainingCalories: 2000,
      );
    }

    final meals = MealCalories(
      reggeli: naplo.kcalEtkezeshez(EtkezesTipus.reggeli),
      ebed: naplo.kcalEtkezeshez(EtkezesTipus.ebed),
      vacsora: naplo.kcalEtkezeshez(EtkezesTipus.vacsora),
      nasi: naplo.kcalEtkezeshez(EtkezesTipus.nasi),
    );

    final target = naplo.targetCalories.round();
    final carbsGoal = naplo.targetCarbs > 0
        ? naplo.targetCarbs.round()
        : (target * 0.5 / 4).round();
    final proteinGoal = naplo.targetProtein > 0
        ? naplo.targetProtein.round()
        : (target * 0.25 / 4).round();
    final fatGoal = naplo.targetFat > 0
        ? naplo.targetFat.round()
        : (target * 0.25 / 9).round();

    var burned = 0;
    var steps = 0;
    var distanceKm = 0.0;
    var moveKcal = 0;
    var exerciseMin = 0;
    var standHours = 0;
    var permissionNeeded = false;
    var source = 'backend';

    if (_health.isSupported) {
      final healthEnabled = await _isDeviceHealthEnabled();

      if (healthEnabled) {
        try {
          final health = await _health.fetchToday();
          burned = health.caloriesBurned;
          steps = health.steps;
          distanceKm = health.distanceKm;
          moveKcal = health.moveKcal;
          exerciseMin = health.exerciseMinutes;
          standHours = health.standHours;
          source = 'merged';
          await _recordHealthSync();
        } catch (_) {
          permissionNeeded = true;
          source = isAppleHealthPlatform ? 'apple_health' : 'health_connect';
        }
      } else {
        permissionNeeded = true;
        source = isAppleHealthPlatform ? 'apple_health' : 'health_connect';
      }
    }

    final data = DailyHealthData(
      moveKcal: moveKcal,
      moveGoalKcal: 500,
      exerciseMinutes: exerciseMin,
      exerciseGoalMinutes: 30,
      standHours: standHours,
      standGoalHours: 12,
      steps: steps,
      distanceKm: distanceKm,
      caloriesConsumed: naplo.totalCalories.round(),
      caloriesBurned: burned,
      calorieGoal: target,
      carbsGrams: naplo.totalCarbs.round(),
      proteinGrams: naplo.totalProtein.round(),
      fatGrams: naplo.totalFat.round(),
      carbsGoalGrams: carbsGoal,
      proteinGoalGrams: proteinGoal,
      fatGoalGrams: fatGoal,
      isFromAppleHealth: source == 'merged',
    );

    return HomeLoadResult(
      data: data,
      meals: meals,
      naplo: naplo,
      source: source,
      permissionNeeded: permissionNeeded,
    );
  }

  Future<bool> _isDeviceHealthEnabled() async {
    if (isAppleHealthPlatform) {
      return await LocalStore.instance.getHealthEnabled();
    }
    if (isHealthConnectPlatform) {
      return await LocalStore.instance.getGoogleFitEnabled();
    }
    return false;
  }

  Future<void> _recordHealthSync() async {
    if (isAppleHealthPlatform) {
      await LocalStore.instance.setAppleHealthLastSync(DateTime.now());
      await LocalStore.instance.setAppleHealthLastError(null);
    } else if (isHealthConnectPlatform) {
      await LocalStore.instance.setGoogleFitLastSync(DateTime.now());
      await LocalStore.instance.setGoogleFitLastError(null);
    }
  }
}
