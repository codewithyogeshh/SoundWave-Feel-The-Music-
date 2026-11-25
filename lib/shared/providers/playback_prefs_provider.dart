import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundwave/shared/providers/library_provider.dart';
import 'package:soundwave/shared/providers/player_provider.dart';

/// Pauses playback when wired headphones are pulled out or a Bluetooth
/// headset disconnects (the Android "becoming noisy" event).
final pauseOnHeadphoneUnplugProvider =
    NotifierProvider<PauseOnHeadphoneUnplugNotifier, bool>(
      PauseOnHeadphoneUnplugNotifier.new,
    );

class PauseOnHeadphoneUnplugNotifier extends Notifier<bool> {
  @override
  bool build() {
    bool saved = true;
    try {
      saved = ref.read(storageServiceProvider).getPauseOnHeadphoneUnplug();
      ref.read(audioHandlerProvider).pauseOnHeadphoneUnplug = saved;
    } catch (_) {
      // Storage or the audio engine is not available (isolated tests).
    }
    return saved;
  }

  Future<void> setEnabled(bool value) async {
    state = value;
    try {
      ref.read(audioHandlerProvider).pauseOnHeadphoneUnplug = value;
    } catch (_) {}
    try {
      await ref.read(storageServiceProvider).setPauseOnHeadphoneUnplug(value);
    } catch (_) {}
  }
}

/// Battery saver skips the ambient background glow and the platform
/// equalizer/loudness DSP so the phone does less work while music plays.
final batterySaverProvider = NotifierProvider<BatterySaverNotifier, bool>(
  BatterySaverNotifier.new,
);

class BatterySaverNotifier extends Notifier<bool> {
  @override
  bool build() {
    bool saved = false;
    try {
      saved = ref.read(storageServiceProvider).getBatterySaver();
      ref.read(audioHandlerProvider).setBatterySaver(saved);
    } catch (_) {
      // Storage or the audio engine is not available (isolated tests).
    }
    return saved;
  }

  Future<void> setEnabled(bool value) async {
    state = value;
    try {
      ref.read(audioHandlerProvider).setBatterySaver(value);
    } catch (_) {}
    try {
      await ref.read(storageServiceProvider).setBatterySaver(value);
    } catch (_) {}
  }
}
