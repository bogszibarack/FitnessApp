import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

/// Single access point for [SharedPreferences] in the app.
class LocalStore {
  LocalStore._();
  static final LocalStore instance = LocalStore._();

  static const onboardingComplete = 'onboardingComplete';
  static const currentUserName = 'currentUserName';
  static const healthEnabled = 'healthEnabled';
  static const themeMode = 'themeMode';
  static const soundEnabled = 'soundEnabled';
  static const soundPr = 'soundPr';

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

  Future<void> setSession(String userName) async {
    ApiConfig.defaultUserName = userName;
    final prefs = await _prefs;
    await prefs.setBool(onboardingComplete, true);
    await prefs.setString(currentUserName, userName);
    await prefs.remove('local_accounts');
  }

  Future<void> clearSession() async {
    ApiConfig.defaultUserName = '';
    final prefs = await _prefs;
    await prefs.setBool(onboardingComplete, false);
    await prefs.remove(currentUserName);
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
}
