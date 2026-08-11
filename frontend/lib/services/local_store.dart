import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

/// Single access point for [SharedPreferences] in the app.
class LocalStore {
  LocalStore._();
  static final LocalStore instance = LocalStore._();

  static const onboardingComplete = 'onboardingComplete';
  static const currentUserName = 'currentUserName';
  static const accessToken = 'accessToken';
  static const refreshToken = 'refreshToken';
  static const healthEnabled = 'healthEnabled';
  static const googleFitEnabled = 'googleFitEnabled';
  static const watchEnabled = 'watchEnabled';
  static const stravaConnected = 'stravaConnected';
  static const stravaAccessToken = 'stravaAccessToken';
  static const stravaRefreshToken = 'stravaRefreshToken';
  static const stravaExpiresAt = 'stravaExpiresAt';
  static const stravaActivityCount = 'stravaActivityCount';
  static const stravaImportedCount = 'stravaImportedCount';
  static const appleHealthLastSync = 'appleHealthLastSync';
  static const appleHealthLastError = 'appleHealthLastError';
  static const appleHealthImportedCount = 'appleHealthImportedCount';
  static const googleFitLastSync = 'googleFitLastSync';
  static const googleFitLastError = 'googleFitLastError';
  static const googleFitImportedCount = 'googleFitImportedCount';
  static const watchLastSync = 'watchLastSync';
  static const watchLastError = 'watchLastError';
  static const watchWorkoutCount = 'watchWorkoutCount';
  static const watchImportedCount = 'watchImportedCount';
  static const stravaLastSync = 'stravaLastSync';
  static const stravaLastError = 'stravaLastError';
  static const themeMode = 'themeMode';
  static const soundEnabled = 'soundEnabled';
  static const soundPr = 'soundPr';
  static const uiLanguage = 'uiLanguage';

  static const _legacyKeys = [
    'onboarding_complete',
    'current_user_name',
    'health_enabled',
    'tema_mod',
    'sound_hangok',
    'sound_pr_hang',
    'local_accounts',
    'naplo_streak',
    'streak_utolso_datum',
  ];

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  Future<({bool onboardingComplete, String? userName})> loadSession() async {
    final prefs = await _prefs;
    final done = prefs.getBool(onboardingComplete) ??
        prefs.getBool('onboarding_complete') ??
        false;
    final user = prefs.getString(currentUserName) ??
        prefs.getString('current_user_name');
    if (user != null && user.isNotEmpty) {
      ApiConfig.defaultUserName = user;
    }
    return (onboardingComplete: done, userName: user);
  }

  Future<String?> getAccessToken() async {
    final prefs = await _prefs;
    return prefs.getString(accessToken);
  }

  Future<String?> getRefreshToken() async {
    final prefs = await _prefs;
    return prefs.getString(refreshToken);
  }

  Future<void> setSession(
    String userName, {
    String? accessToken,
    String? refreshToken,
  }) async {
    ApiConfig.defaultUserName = userName;
    final prefs = await _prefs;
    await prefs.setBool(onboardingComplete, true);
    await prefs.setString(currentUserName, userName);
    if (accessToken != null && accessToken.isNotEmpty) {
      await prefs.setString(LocalStore.accessToken, accessToken);
    }
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await prefs.setString(LocalStore.refreshToken, refreshToken);
    }
    await prefs.remove('local_accounts');
  }

  Future<void> setTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    final prefs = await _prefs;
    await prefs.setString(LocalStore.accessToken, accessToken);
    await prefs.setString(LocalStore.refreshToken, refreshToken);
  }

  Future<void> clearSession() async {
    ApiConfig.defaultUserName = '';
    final prefs = await _prefs;
    await prefs.setBool(onboardingComplete, false);
    await prefs.remove(currentUserName);
    await prefs.remove(accessToken);
    await prefs.remove(refreshToken);
    for (final key in _legacyKeys) {
      await prefs.remove(key);
    }
  }

  Future<bool> getHealthEnabled() async {
    final prefs = await _prefs;
    return prefs.getBool(healthEnabled) ?? prefs.getBool('health_enabled') ?? false;
  }

  Future<void> setHealthEnabled(bool value) async {
    final prefs = await _prefs;
    await prefs.setBool(healthEnabled, value);
  }

  Future<bool> getGoogleFitEnabled() async {
    final prefs = await _prefs;
    return prefs.getBool(googleFitEnabled) ?? false;
  }

  Future<void> setGoogleFitEnabled(bool value) async {
    final prefs = await _prefs;
    await prefs.setBool(googleFitEnabled, value);
  }

  Future<bool> getWatchEnabled() async {
    final prefs = await _prefs;
    return prefs.getBool(watchEnabled) ?? false;
  }

  Future<void> setWatchEnabled(bool value) async {
    final prefs = await _prefs;
    await prefs.setBool(watchEnabled, value);
  }

  Future<bool> getStravaConnected() async {
    final prefs = await _prefs;
    return prefs.getBool(stravaConnected) ?? false;
  }

  Future<void> setStravaConnected(bool value) async {
    final prefs = await _prefs;
    await prefs.setBool(stravaConnected, value);
  }

  Future<void> setStravaTokens({
    required String accessToken,
    required String refreshToken,
    DateTime? expiresAt,
  }) async {
    final prefs = await _prefs;
    await prefs.setString(stravaAccessToken, accessToken);
    await prefs.setString(stravaRefreshToken, refreshToken);
    if (expiresAt != null) {
      await prefs.setString(stravaExpiresAt, expiresAt.toIso8601String());
    } else {
      await prefs.remove(stravaExpiresAt);
    }
  }

  Future<void> clearStravaTokens() async {
    final prefs = await _prefs;
    await prefs.remove(stravaAccessToken);
    await prefs.remove(stravaRefreshToken);
    await prefs.remove(stravaExpiresAt);
    await prefs.remove(stravaActivityCount);
  }

  Future<String?> getStravaAccessToken() async {
    final prefs = await _prefs;
    return prefs.getString(stravaAccessToken);
  }

  Future<String?> getStravaRefreshToken() async {
    final prefs = await _prefs;
    return prefs.getString(stravaRefreshToken);
  }

  Future<DateTime?> getStravaExpiresAt() async {
    final prefs = await _prefs;
    final raw = prefs.getString(stravaExpiresAt);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<int> getStravaActivityCount() async {
    final prefs = await _prefs;
    return prefs.getInt(stravaActivityCount) ?? 0;
  }

  Future<void> setStravaActivityCount(int count) async {
    final prefs = await _prefs;
    await prefs.setInt(stravaActivityCount, count);
  }

  Future<int> getStravaImportedCount() async {
    final prefs = await _prefs;
    return prefs.getInt(stravaImportedCount) ?? 0;
  }

  Future<void> setStravaImportedCount(int count) async {
    final prefs = await _prefs;
    await prefs.setInt(stravaImportedCount, count);
  }

  Future<int> getAppleHealthImportedCount() async {
    final prefs = await _prefs;
    return prefs.getInt(appleHealthImportedCount) ?? 0;
  }

  Future<void> setAppleHealthImportedCount(int count) async {
    final prefs = await _prefs;
    await prefs.setInt(appleHealthImportedCount, count);
  }

  Future<int> getGoogleFitImportedCount() async {
    final prefs = await _prefs;
    return prefs.getInt(googleFitImportedCount) ?? 0;
  }

  Future<void> setGoogleFitImportedCount(int count) async {
    final prefs = await _prefs;
    await prefs.setInt(googleFitImportedCount, count);
  }

  Future<int> getWatchImportedCount() async {
    final prefs = await _prefs;
    return prefs.getInt(watchImportedCount) ?? 0;
  }

  Future<void> setWatchImportedCount(int count) async {
    final prefs = await _prefs;
    await prefs.setInt(watchImportedCount, count);
  }

  Future<DateTime?> _readSync(String key) async {
    final prefs = await _prefs;
    final raw = prefs.getString(key);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> _writeSync(String key, DateTime? value) async {
    final prefs = await _prefs;
    if (value == null) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, value.toIso8601String());
    }
  }

  Future<String?> _readError(String key) async {
    final prefs = await _prefs;
    return prefs.getString(key);
  }

  Future<void> _writeError(String key, String? value) async {
    final prefs = await _prefs;
    if (value == null || value.isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, value);
    }
  }

  Future<DateTime?> getAppleHealthLastSync() => _readSync(appleHealthLastSync);
  Future<void> setAppleHealthLastSync(DateTime? v) => _writeSync(appleHealthLastSync, v);
  Future<String?> getAppleHealthLastError() => _readError(appleHealthLastError);
  Future<void> setAppleHealthLastError(String? v) => _writeError(appleHealthLastError, v);

  Future<DateTime?> getGoogleFitLastSync() => _readSync(googleFitLastSync);
  Future<void> setGoogleFitLastSync(DateTime? v) => _writeSync(googleFitLastSync, v);
  Future<String?> getGoogleFitLastError() => _readError(googleFitLastError);
  Future<void> setGoogleFitLastError(String? v) => _writeError(googleFitLastError, v);

  Future<DateTime?> getWatchLastSync() => _readSync(watchLastSync);
  Future<void> setWatchLastSync(DateTime? v) => _writeSync(watchLastSync, v);
  Future<String?> getWatchLastError() => _readError(watchLastError);
  Future<void> setWatchLastError(String? v) => _writeError(watchLastError, v);

  Future<int> getWatchWorkoutCount() async {
    final prefs = await _prefs;
    return prefs.getInt(watchWorkoutCount) ?? 0;
  }

  Future<void> setWatchWorkoutCount(int count) async {
    final prefs = await _prefs;
    await prefs.setInt(watchWorkoutCount, count);
  }

  Future<DateTime?> getStravaLastSync() => _readSync(stravaLastSync);
  Future<void> setStravaLastSync(DateTime? v) => _writeSync(stravaLastSync, v);
  Future<String?> getStravaLastError() => _readError(stravaLastError);
  Future<void> setStravaLastError(String? v) => _writeError(stravaLastError, v);

  Future<String> getThemeMode() async {
    final prefs = await _prefs;
    return prefs.getString(themeMode) ?? prefs.getString('tema_mod') ?? 'rendszer';
  }

  Future<void> setThemeMode(String id) async {
    final prefs = await _prefs;
    await prefs.setString(themeMode, id);
  }

  Future<({bool soundEnabled, bool soundPr})> getSoundSettings() async {
    final prefs = await _prefs;
    return (
      soundEnabled: prefs.getBool(soundEnabled) ?? prefs.getBool('sound_hangok') ?? true,
      soundPr: prefs.getBool(soundPr) ?? prefs.getBool('sound_pr_hang') ?? true,
    );
  }

  Future<void> setSoundSettings({bool? soundEnabled, bool? soundPr}) async {
    final prefs = await _prefs;
    if (soundEnabled != null) {
      await prefs.setBool(LocalStore.soundEnabled, soundEnabled);
    }
    if (soundPr != null) {
      await prefs.setBool(LocalStore.soundPr, soundPr);
    }
  }

  Future<String> getUiLanguage() async {
    final prefs = await _prefs;
    final lang = prefs.getString(uiLanguage);
    if (lang == 'en' || lang == 'hu') return lang!;
    return 'hu';
  }

  Future<void> setUiLanguage(String lang) async {
    final prefs = await _prefs;
    await prefs.setString(uiLanguage, lang == 'en' ? 'en' : 'hu');
  }
}
