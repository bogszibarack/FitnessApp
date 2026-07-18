import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Téma mód vezérlő — SharedPreferences-be mentett, azonnal alkalmazott.
class TemaVezerlo {
  TemaVezerlo._();

  static const _prefKulcs = 'tema_mod';

  /// 'rendszer' | 'vilagos' | 'sotet'
  static final ValueNotifier<ThemeMode> mod = ValueNotifier(ThemeMode.system);

  static String get aktualisId => switch (mod.value) {
        ThemeMode.light => 'vilagos',
        ThemeMode.dark => 'sotet',
        ThemeMode.system => 'rendszer',
      };

  static Future<void> betoltes() async {
    final prefs = await SharedPreferences.getInstance();
    allitasIdbol(prefs.getString(_prefKulcs) ?? 'rendszer', mentes: false);
  }

  static Future<void> allitasIdbol(String id, {bool mentes = true}) async {
    mod.value = switch (id) {
      'vilagos' => ThemeMode.light,
      'sotet' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    AppSzinek.frissites();
    if (mentes) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKulcs, id);
    }
  }

  /// Ténylegesen sötét-e most (rendszer mód esetén az OS beállítása dönt).
  static bool get sotetAktiv {
    switch (mod.value) {
      case ThemeMode.dark:
        return true;
      case ThemeMode.light:
        return false;
      case ThemeMode.system:
        return PlatformDispatcher.instance.platformBrightness == Brightness.dark;
    }
  }
}

/// Téma-függő színpaletta — a képernyők közvetlenül ezt használják,
/// így a hardcoded fehér/fekete színek is követik a dark módot.
class AppSzinek {
  AppSzinek._();

  static bool _sotet = false;
  static bool get sotet => _sotet;

  static void frissites() {
    _sotet = TemaVezerlo.sotetAktiv;
  }

  /// Képernyő háttér (világos szürke ↔ mély sötét).
  static Color get hatter => _sotet ? const Color(0xFF0E1013) : const Color(0xFFF2F2F7);

  /// Fehér felületek: AppBar, világos Scaffold.
  static Color get felulet => _sotet ? const Color(0xFF15181D) : Colors.white;

  /// Kártyák háttere.
  static Color get kartya => _sotet ? const Color(0xFF1D2127) : Colors.white;

  /// Elsődleges szöveg (black87 megfelelője).
  static Color get szoveg => _sotet ? const Color(0xFFF1F2F4) : Colors.black87;

  /// Másodlagos szöveg (grey.shade600-700 megfelelője).
  static Color get mellekSzoveg => _sotet ? const Color(0xFFA0A7B1) : const Color(0xFF757575);

  /// Halvány szöveg / inaktív ikon (grey.shade400-500 megfelelője).
  static Color get halvanySzoveg => _sotet ? const Color(0xFF6F7680) : const Color(0xFF9E9E9E);

  /// Szegélyek, elválasztók (grey.shade200 megfelelője).
  static Color get szegely => _sotet ? const Color(0xFF2A2F37) : const Color(0xFFE8E8EC);

  /// Halvány kitöltés (grey.shade100 / F2F2F7 megfelelője kártyán belül).
  static Color get halvanyKitoltes => _sotet ? const Color(0xFF262B33) : const Color(0xFFF2F2F7);

  /// Árnyék — sötétben erősebb, világosban finom.
  static Color get arnyek => _sotet
      ? Colors.black.withValues(alpha: 0.4)
      : Colors.black.withValues(alpha: 0.05);
}

/// Világos téma.
ThemeData vilagosTema() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E88E5)),
    scaffoldBackgroundColor: Colors.grey.shade50,
  );
}

/// Sötét téma.
ThemeData sotetTema() {
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
