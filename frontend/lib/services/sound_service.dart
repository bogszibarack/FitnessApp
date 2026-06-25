import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kezeli az in-app hangokat és rezgéseket.
/// Beállítások SharedPreferences-be mentve, hogy az edzésbeállítás képernyőn
/// kikapcsolt PR hang valóban hatásos legyen.
class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  static const _kulcsHangok = 'sound_hangok';
  static const _kulcsPrHang = 'sound_pr_hang';

  bool _hangok = true;
  bool _prHang = true;
  bool _inicializalva = false;

  Future<void> inicializalas() async {
    if (_inicializalva) return;
    _inicializalva = true;
    final prefs = await SharedPreferences.getInstance();
    _hangok = prefs.getBool(_kulcsHangok) ?? true;
    _prHang = prefs.getBool(_kulcsPrHang) ?? true;
  }

  Future<void> beallitasMentes({bool? hangok, bool? prHang}) async {
    final prefs = await SharedPreferences.getInstance();
    if (hangok != null) {
      _hangok = hangok;
      await prefs.setBool(_kulcsHangok, hangok);
    }
    if (prHang != null) {
      _prHang = prHang;
      await prefs.setBool(_kulcsPrHang, prHang);
    }
  }

  bool get hangokAktiv => _hangok;
  bool get prHangAktiv => _hangok && _prHang;

  /// PR hang: erős ütés-haptic + rendszer alert hang.
  Future<void> prHangJatszas() async {
    if (!_hangok || !_prHang) return;
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await SystemSound.play(SystemSoundType.alert);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await HapticFeedback.mediumImpact();
  }

  /// Edzés befejezés: háromszoros leszálló haptic (fanfár érzet).
  Future<void> edzesBefejezesHang() async {
    if (!_hangok) return;
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 180));
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.lightImpact();
  }
}
