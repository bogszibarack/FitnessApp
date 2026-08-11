import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../services/local_store.dart';
import '../services/settings_service.dart';

/// UI locale controller — persisted via [LocalStore], applied immediately.
class LocaleController {
  LocaleController._();

  static final ValueNotifier<Locale> locale =
      ValueNotifier(const Locale('hu'));

  static const supportedLocales = [Locale('hu'), Locale('en')];

  static const localizationsDelegates = [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  static String get currentId => locale.value.languageCode;

  /// Normalizes to supported ids: `hu` or `en` (German and others map to `hu`).
  static String normalizeId(String id) =>
      id.toLowerCase() == 'en' ? 'en' : 'hu';

  static Future<void> load() async {
    final id = await LocalStore.instance.getUiLanguage();
    setFromId(id, persist: false);
  }

  /// Pull language from backend settings when the user is logged in.
  static Future<void> syncFromBackend() async {
    try {
      final session = await LocalStore.instance.loadSession();
      if (!session.onboardingComplete) return;
      final userName = session.userName;
      if (userName == null || userName.isEmpty) return;

      final service = SettingsService(userName: userName);
      final data = await service.getSzekcio(
        '/api/settings/$userName/language',
      );
      final lang = (data['language'] ?? data['nyelv']) as String?;
      if (lang != null && lang.isNotEmpty) {
        await setFromId(lang);
      }
    } catch (_) {}
  }

  static Future<void> setFromId(String id, {bool persist = true}) async {
    final normalized = normalizeId(id);
    locale.value = Locale(normalized);
    if (persist) {
      await LocalStore.instance.setUiLanguage(normalized);
    }
  }
}
