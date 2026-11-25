import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:soundwave/features/library/services/library_storage_service.dart';
import 'package:soundwave/features/player/services/audio_handler.dart';

/// Pauses playback when the phone reaches a critically low battery level while
/// running on battery power, so the last percent or two are not spent on music.
/// It only checks every couple of minutes and never interrupts a charging phone.
class BatteryGuard {
  BatteryGuard(this._handler, this._storage);

  final SoundWaveAudioHandler _handler;
  final LibraryStorageService _storage;

  static const int lowBatteryThreshold = 15;
  static const Duration _interval = Duration(minutes: 2);

  Timer? _timer;
  bool _checking = false;

  /// Starts the periodic check (a no-op when the user turned the setting off).
  void start() {
    _timer?.cancel();
    // Give the first track time to load before the first battery read.
    unawaited(
      Future<void>.delayed(const Duration(seconds: 5), () => check()),
    );
    _timer = Timer.periodic(_interval, (_) => unawaited(check()));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> check() async {
    if (_checking) return;
    if (!_storage.getPauseOnLowBattery()) return;
    if (!_handler.player.playing) return;

    _checking = true;
    try {
      final level = await Battery().batteryLevel;
      if (level > lowBatteryThreshold) return;

      final state = await Battery().batteryState;
      if (state == BatteryState.charging || state == BatteryState.full) return;

      // Re-check after the awaits: the user may have paused or changed the
      // setting in the meantime, and we must never override that.
      if (!_storage.getPauseOnLowBattery()) return;
      if (!_handler.player.playing) return;

      await _handler.pause();
      debugPrint('Battery guard paused playback at $level%');
    } catch (e) {
      // Battery APIs are unavailable on some devices/web; skipping is fine.
      debugPrint('Battery guard skipped: $e');
    } finally {
      _checking = false;
    }
  }
}
