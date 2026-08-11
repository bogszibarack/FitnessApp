import 'package:flutter/services.dart';

import 'local_store.dart';

/// In-app sounds and haptics. Settings persisted via [LocalStore].
class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  bool _soundEnabled = true;
  bool _prSound = true;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    final settings = await LocalStore.instance.getSoundSettings();
    _soundEnabled = settings.soundEnabled;
    _prSound = settings.soundPr;
  }

  Future<void> inicializalas() => init();

  Future<void> saveSettings({bool? soundEnabled, bool? prSound}) async {
    if (soundEnabled != null) _soundEnabled = soundEnabled;
    if (prSound != null) _prSound = prSound;
    await LocalStore.instance.setSoundSettings(
      soundEnabled: soundEnabled,
      soundPr: prSound,
    );
  }

  Future<void> beallitasMentes({bool? hangok, bool? prHang}) async {
    await saveSettings(soundEnabled: hangok, prSound: prHang);
  }

  bool get soundEnabled => _soundEnabled;
  bool get prSoundEnabled => _soundEnabled && _prSound;
  bool get hangokAktiv => soundEnabled;
  bool get prHangAktiv => prSoundEnabled;

  Future<void> playPrSound() async {
    if (!prSoundEnabled) return;
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await SystemSound.play(SystemSoundType.alert);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await HapticFeedback.mediumImpact();
  }

  Future<void> prHangJatszas() => playPrSound();

  Future<void> playWorkoutCompleteSound() async {
    if (!_soundEnabled) return;
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 180));
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.lightImpact();
  }

  Future<void> edzesBefejezesHang() => playWorkoutCompleteSound();

  Future<void> playRestCompleteSound() async {
    if (!_soundEnabled) return;
    await HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 60));
    await SystemSound.play(SystemSoundType.click);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.lightImpact();
  }
}
