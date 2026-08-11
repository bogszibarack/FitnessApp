import '../models/health_workout.dart';
import '../models/integration_status.dart';
import '../utils/platform_utils.dart';
import 'device_health_service.dart';
import 'health_connect_service.dart';
import 'local_store.dart';
import 'strava_service.dart';
import 'workout_service.dart';

/// Coordinates third-party integrations: permissions, sync, diary import.
class IntegrationsService {
  IntegrationsService._();
  static final IntegrationsService instance = IntegrationsService._();

  final _health = DeviceHealthService.instance;
  final _strava = StravaService.instance;
  final _workouts = WorkoutService.instance;

  String get _healthSource =>
      isAppleHealthPlatform ? 'apple_health' : 'health_connect';

  Future<IntegrationStatus> appleHealthStatus() async {
    final enabled = await LocalStore.instance.getHealthEnabled();
    final lastSync = await LocalStore.instance.getAppleHealthLastSync();
    final lastError = await LocalStore.instance.getAppleHealthLastError();
    final imported = await LocalStore.instance.getAppleHealthImportedCount();
    return IntegrationStatus(
      connected: enabled && isAppleHealthPlatform,
      lastSyncAt: lastSync,
      lastError: lastError,
      detail: isAppleHealthPlatform
          ? (imported > 0
              ? '$imported edzés a naplóban · aktivitás sync'
              : 'Aktivitás + edzések → Flexio napló')
          : 'Csak iOS eszközön elérhető',
    );
  }

  Future<IntegrationStatus> googleFitStatus() async {
    final enabled = await LocalStore.instance.getGoogleFitEnabled();
    final lastSync = await LocalStore.instance.getGoogleFitLastSync();
    final lastError = await LocalStore.instance.getGoogleFitLastError();
    final imported = await LocalStore.instance.getGoogleFitImportedCount();
    return IntegrationStatus(
      connected: enabled && isHealthConnectPlatform,
      lastSyncAt: lastSync,
      lastError: lastError,
      detail: isHealthConnectPlatform
          ? (imported > 0
              ? '$imported edzés a naplóban · Health Connect'
              : 'Health Connect → Flexio napló')
          : 'Csak Androidon (Health Connect)',
    );
  }

  Future<IntegrationStatus> watchStatus() async {
    final enabled = await LocalStore.instance.getWatchEnabled();
    final lastSync = await LocalStore.instance.getWatchLastSync();
    final lastError = await LocalStore.instance.getWatchLastError();
    final workoutCount = await LocalStore.instance.getWatchWorkoutCount();
    final imported = await LocalStore.instance.getWatchImportedCount();
    final detail = imported > 0
        ? '$imported edzés a naplóban'
        : (workoutCount > 0
            ? '$workoutCount edzés az utolsó szinkronból'
            : (isAppleHealthPlatform
                ? 'Apple Watch → Flexio napló'
                : 'Okosóra → Flexio napló'));
    return IntegrationStatus(
      connected: enabled && isDeviceHealthPlatform,
      lastSyncAt: lastSync,
      lastError: lastError,
      detail: detail,
    );
  }

  Future<IntegrationStatus> stravaStatus() async {
    final connected = await _strava.isConnected();
    final lastSync = await LocalStore.instance.getStravaLastSync();
    final lastError = await LocalStore.instance.getStravaLastError();
    final activityCount = await LocalStore.instance.getStravaActivityCount();
    final imported = await LocalStore.instance.getStravaImportedCount();

    String detail;
    if (!_strava.isConfigured) {
      detail = 'Nincs konfigurálva (STRAVA_CLIENT_ID hiányzik)';
    } else if (connected && imported > 0) {
      detail = '$imported aktivitás a Flexio naplóban';
    } else if (connected && activityCount > 0) {
      detail = '$activityCount aktivitás szinkronizálva';
    } else if (connected) {
      detail = 'Csatlakoztatva — szinkron a kapcsolóval';
    } else {
      detail = 'Futás és kerékpár → Flexio napló';
    }

    return IntegrationStatus(
      connected: connected,
      lastSyncAt: lastSync,
      lastError: lastError,
      detail: detail,
    );
  }

  Future<bool> connectAppleHealth() async {
    if (!isAppleHealthPlatform) return false;
    try {
      await _health.requestPermissions();
      await LocalStore.instance.setHealthEnabled(true);
      await _syncAppleHealth();
      return true;
    } catch (e) {
      await LocalStore.instance.setAppleHealthLastError(e.toString());
      await LocalStore.instance.setHealthEnabled(false);
      return false;
    }
  }

  Future<void> disconnectAppleHealth() async {
    await LocalStore.instance.setHealthEnabled(false);
    await LocalStore.instance.setAppleHealthLastSync(null);
    await LocalStore.instance.setAppleHealthLastError(null);
  }

  Future<bool> connectGoogleFit() async {
    if (!isHealthConnectPlatform) return false;
    try {
      final granted = await HealthConnectService.instance.requestPermissions();
      if (!granted) {
        await LocalStore.instance.setGoogleFitLastError('Health Connect engedély megtagadva.');
        await LocalStore.instance.setGoogleFitEnabled(false);
        return false;
      }
      await LocalStore.instance.setGoogleFitEnabled(true);
      await _syncGoogleFit();
      return true;
    } catch (e) {
      await LocalStore.instance.setGoogleFitLastError(e.toString());
      await LocalStore.instance.setGoogleFitEnabled(false);
      return false;
    }
  }

  Future<void> disconnectGoogleFit() async {
    await LocalStore.instance.setGoogleFitEnabled(false);
    await LocalStore.instance.setGoogleFitLastSync(null);
    await LocalStore.instance.setGoogleFitLastError(null);
  }

  Future<bool> connectWatch() async {
    if (!isDeviceHealthPlatform) return false;
    try {
      final granted = await _health.requestPermissions();
      if (!granted && isHealthConnectPlatform) {
        await LocalStore.instance.setWatchLastError('Health engedély szükséges az óra adatokhoz.');
        await LocalStore.instance.setWatchEnabled(false);
        return false;
      }
      await LocalStore.instance.setWatchEnabled(true);
      await _syncWatch();
      return true;
    } catch (e) {
      await LocalStore.instance.setWatchLastError(e.toString());
      await LocalStore.instance.setWatchEnabled(false);
      return false;
    }
  }

  Future<void> disconnectWatch() async {
    await LocalStore.instance.setWatchEnabled(false);
    await LocalStore.instance.setWatchLastSync(null);
    await LocalStore.instance.setWatchLastError(null);
    await LocalStore.instance.setWatchWorkoutCount(0);
  }

  Future<bool> connectStrava() async {
    if (!_strava.isConfigured) {
      throw StravaNotConfiguredException(
        'Strava OAuth nincs konfigurálva. Szükséges: STRAVA_CLIENT_ID és STRAVA_CLIENT_SECRET.',
      );
    }
    try {
      await _strava.connect();
      await _syncStravaToDiary();
      return true;
    } catch (e) {
      await LocalStore.instance.setStravaLastError(e.toString());
      await LocalStore.instance.setStravaConnected(false);
      rethrow;
    }
  }

  Future<void> disconnectStrava() async {
    await _strava.disconnect();
  }

  Future<void> _syncAppleHealth() async {
    await _health.fetchToday();
    final workouts = await _health.fetchRecentWorkouts(days: 14);
    final result = await _importHealthWorkouts(workouts, source: _healthSource);
    await LocalStore.instance.setAppleHealthImportedCount(result.imported + result.skipped);
    await LocalStore.instance.setAppleHealthLastSync(DateTime.now());
    await LocalStore.instance.setAppleHealthLastError(null);
  }

  Future<void> _syncGoogleFit() async {
    await HealthConnectService.instance.fetchToday();
    final workouts = await HealthConnectService.instance.fetchRecentWorkouts(days: 14);
    final result = await _importHealthWorkouts(workouts, source: 'health_connect');
    await LocalStore.instance.setGoogleFitImportedCount(result.imported + result.skipped);
    await LocalStore.instance.setGoogleFitLastSync(DateTime.now());
    await LocalStore.instance.setGoogleFitLastError(null);
  }

  Future<void> _syncWatch() async {
    final workouts = await _health.fetchRecentWorkouts(days: 14);
    await LocalStore.instance.setWatchWorkoutCount(workouts.length);
    // Same ExternalId/source as Health so re-sync does not duplicate.
    final result = await _importHealthWorkouts(workouts, source: _healthSource);
    await LocalStore.instance.setWatchImportedCount(result.imported + result.skipped);
    await LocalStore.instance.setWatchLastSync(DateTime.now());
    await LocalStore.instance.setWatchLastError(null);
  }

  Future<void> _syncStravaToDiary() async {
    final activities = await _strava.syncRecentActivities(days: 14);
    final items = activities
        .where((a) => a.id > 0)
        .map((a) => {
              'externalId': 'strava:${a.id}',
              'source': 'strava',
              'title': a.name,
              'startTime': a.startedAt.toIso8601String(),
              'durationSeconds': a.durationMinutes * 60,
              'distanceKm': a.distanceKm,
              'activityType': a.type,
            })
        .toList();
    final result = await _workouts.importExternalWorkouts(items);
    await LocalStore.instance.setStravaImportedCount(result.imported + result.skipped);
  }

  Future<WorkoutImportResult> _importHealthWorkouts(
    List<HealthWorkout> workouts, {
    required String source,
  }) async {
    final items = workouts.map((w) {
      final id =
          'health:${w.startedAt.toUtc().millisecondsSinceEpoch}:${w.durationMinutes}:${w.title}';
      return {
        'externalId': id,
        'source': source,
        'title': w.title.isEmpty ? 'Edzés' : w.title,
        'startTime': w.startedAt.toIso8601String(),
        'durationSeconds': w.durationMinutes * 60,
        if (w.distanceKm != null) 'distanceKm': w.distanceKm,
        'activityType': w.title,
      };
    }).toList();
    return _workouts.importExternalWorkouts(items);
  }
}
