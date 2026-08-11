import '../models/integration_status.dart';
import '../utils/platform_utils.dart';
import 'device_health_service.dart';
import 'health_connect_service.dart';
import 'local_store.dart';
import 'strava_service.dart';

/// Coordinates third-party integrations: permissions, sync, and persisted state.
class IntegrationsService {
  IntegrationsService._();
  static final IntegrationsService instance = IntegrationsService._();

  final _health = DeviceHealthService.instance;
  final _strava = StravaService.instance;

  Future<IntegrationStatus> appleHealthStatus() async {
    final enabled = await LocalStore.instance.getHealthEnabled();
    final lastSync = await LocalStore.instance.getAppleHealthLastSync();
    final lastError = await LocalStore.instance.getAppleHealthLastError();
    return IntegrationStatus(
      connected: enabled && isAppleHealthPlatform,
      lastSyncAt: lastSync,
      lastError: lastError,
      detail: isAppleHealthPlatform
          ? 'Aktivitás és kalória adatok'
          : 'Csak iOS eszközön elérhető',
    );
  }

  Future<IntegrationStatus> googleFitStatus() async {
    final enabled = await LocalStore.instance.getGoogleFitEnabled();
    final lastSync = await LocalStore.instance.getGoogleFitLastSync();
    final lastError = await LocalStore.instance.getGoogleFitLastError();
    return IntegrationStatus(
      connected: enabled && isHealthConnectPlatform,
      lastSyncAt: lastSync,
      lastError: lastError,
      detail: isHealthConnectPlatform
          ? 'Health Connect aktivitás és lépések'
          : 'Csak Androidon (Health Connect)',
    );
  }

  Future<IntegrationStatus> watchStatus() async {
    final enabled = await LocalStore.instance.getWatchEnabled();
    final lastSync = await LocalStore.instance.getWatchLastSync();
    final lastError = await LocalStore.instance.getWatchLastError();
    final workoutCount = await LocalStore.instance.getWatchWorkoutCount();
    final detail = workoutCount > 0
        ? '$workoutCount edzés az utolsó szinkronból'
        : (isAppleHealthPlatform
            ? 'Apple Watch adatok Apple Health-en keresztül'
            : 'Okosóra adatok Health Connect-en keresztül');
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

    String detail;
    if (!_strava.isConfigured) {
      detail = 'Nincs konfigurálva (STRAVA_CLIENT_ID hiányzik)';
    } else if (connected && activityCount > 0) {
      detail = '$activityCount aktivitás szinkronizálva';
    } else if (connected) {
      detail = 'Csatlakoztatva — szinkron a kapcsolóval';
    } else {
      detail = 'Futás és kerékpár aktivitások';
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
      await _strava.syncRecentActivities();
      return true;
    } catch (e) {
      await LocalStore.instance.setStravaLastError(e.toString());
      await LocalStore.instance.setStravaConnected(false);
      throw e;
    }
  }

  Future<void> disconnectStrava() async {
    await _strava.disconnect();
  }

  Future<void> _syncAppleHealth() async {
    await _health.fetchToday();
    await LocalStore.instance.setAppleHealthLastSync(DateTime.now());
    await LocalStore.instance.setAppleHealthLastError(null);
  }

  Future<void> _syncGoogleFit() async {
    await HealthConnectService.instance.fetchToday();
    await LocalStore.instance.setGoogleFitLastSync(DateTime.now());
    await LocalStore.instance.setGoogleFitLastError(null);
  }

  Future<void> _syncWatch() async {
    final workouts = await _health.fetchRecentWorkouts(days: 7);
    await LocalStore.instance.setWatchWorkoutCount(workouts.length);
    await LocalStore.instance.setWatchLastSync(DateTime.now());
    await LocalStore.instance.setWatchLastError(null);
  }
}
