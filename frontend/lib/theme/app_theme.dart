import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';

import '../services/local_store.dart';

/// Theme mode controller — persisted via [LocalStore], applied immediately.
class ThemeController {
  ThemeController._();

  static final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.system);

  static String get currentId => switch (mode.value) {
        ThemeMode.light => 'vilagos',
        ThemeMode.dark => 'sotet',
        ThemeMode.system => 'rendszer',
      };

  static Future<void> load() async {
    final id = await LocalStore.instance.getThemeMode();
    setFromId(id, persist: false);
  }

  static Future<void> setFromId(String id, {bool persist = true}) async {
    mode.value = switch (id) {
      'vilagos' => ThemeMode.light,
      'sotet' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    AppColors.refresh();
    if (persist) {
      await LocalStore.instance.setThemeMode(id);
    }
  }

  /// Whether dark mode is active (follows OS when in system mode).
  static bool get isDarkActive {
    switch (mode.value) {
      case ThemeMode.dark:
        return true;
      case ThemeMode.light:
        return false;
      case ThemeMode.system:
        return PlatformDispatcher.instance.platformBrightness == Brightness.dark;
    }
  }
}

/// Theme-aware color palette used directly by screens.
class AppColors {
  AppColors._();

  static bool _dark = false;
  static bool get dark => _dark;

  static void refresh() {
    _dark = ThemeController.isDarkActive;
  }

  static Color get hatter => _dark ? const Color(0xFF0E1013) : const Color(0xFFF2F2F7);
  static Color get felulet => _dark ? const Color(0xFF15181D) : Colors.white;
  static Color get kartya => _dark ? const Color(0xFF1D2127) : Colors.white;
  static Color get szoveg => _dark ? const Color(0xFFF1F2F4) : Colors.black87;
  static Color get mellekSzoveg => _dark ? const Color(0xFFA0A7B1) : const Color(0xFF757575);
  static Color get halvanySzoveg => _dark ? const Color(0xFF6F7680) : const Color(0xFF9E9E9E);
  static Color get szegely => _dark ? const Color(0xFF2A2F37) : const Color(0xFFE8E8EC);
  static Color get halvanyKitoltes => _dark ? const Color(0xFF262B33) : const Color(0xFFF2F2F7);
  static Color get arnyek => _dark
      ? Colors.black.withValues(alpha: 0.4)
      : Colors.black.withValues(alpha: 0.05);
}

ThemeData lightTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E88E5)),
    scaffoldBackgroundColor: Colors.grey.shade50,
  );
}

ThemeData darkTheme() {
  final sema = ColorScheme.fromSeed(
    seedColor: const Color(0xFF1E88E5),
    brightness: Brightness.dark,
    surface: const Color(0xFF15181D),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: sema,
    scaffoldBackgroundColor: const Color(0xFF0E1013),
    cardColor: const Color(0xFF1D2127),
    dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF1D2127)),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF15181D),
      foregroundColor: Color(0xFFF1F2F4),
    ),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Color(0xFF1D2127)),
  );
}

