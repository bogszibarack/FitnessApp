import '../models/daily_health_data.dart';
import '../models/health_workout.dart';
import '../utils/platform_utils.dart';
import 'apple_health_service.dart';
import 'health_connect_service.dart';

/// Routes health reads to Apple Health (iOS) or Health Connect (Android).
class DeviceHealthService {
  DeviceHealthService._();
  static final DeviceHealthService instance = DeviceHealthService._();

  bool get isSupported => isDeviceHealthPlatform;

  Future<bool> requestPermissions() async {
    if (isAppleHealthPlatform) {
      return AppleHealthService.instance.requestPermissions();
    }
    if (isHealthConnectPlatform) {
      return HealthConnectService.instance.requestPermissions();
    }
    return false;
  }

  Future<DailyHealthData> fetchToday() async {
    if (isAppleHealthPlatform) {
      return AppleHealthService.instance.fetchToday();
    }
    if (isHealthConnectPlatform) {
      return HealthConnectService.instance.fetchToday();
    }
    return DailyHealthData.empty();
  }

  Future<List<HealthWorkout>> fetchRecentWorkouts({int days = 7}) async {
    if (isAppleHealthPlatform) {
      return AppleHealthService.instance.fetchRecentWorkouts(days: days);
    }
    if (isHealthConnectPlatform) {
      return HealthConnectService.instance.fetchRecentWorkouts(days: days);
    }
    return [];
  }
}
