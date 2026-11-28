import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundwave/features/online/services/download_service.dart';
import 'package:soundwave/features/online/services/online_music_service.dart';
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

/// Stops playback at 15% battery while the phone is not charging.
final pauseOnLowBatteryProvider =
    NotifierProvider<PauseOnLowBatteryNotifier, bool>(
      PauseOnLowBatteryNotifier.new,
    );

class PauseOnLowBatteryNotifier extends Notifier<bool> {
  @override
  bool build() {
    try {
      return ref.read(storageServiceProvider).getPauseOnLowBattery();
    } catch (_) {
      return true;
    }
  }

  Future<void> setEnabled(bool value) async {
    state = value;
    try {
      await ref.read(storageServiceProvider).setPauseOnLowBattery(value);
    } catch (_) {}
  }
}

/// Stops playback when the app is swiped away from recent apps.
final stopWhenAppClosedProvider =
    NotifierProvider<StopWhenAppClosedNotifier, bool>(
      StopWhenAppClosedNotifier.new,
    );

class StopWhenAppClosedNotifier extends Notifier<bool> {
  @override
  bool build() {
    bool saved = false;
    try {
      saved = ref.read(storageServiceProvider).getStopWhenSwipedAway();
      ref.read(audioHandlerProvider).stopWhenTaskRemoved = saved;
    } catch (_) {}
    return saved;
  }

  Future<void> setEnabled(bool value) async {
    state = value;
    try {
      ref.read(audioHandlerProvider).stopWhenTaskRemoved = value;
    } catch (_) {}
    try {
      await ref.read(storageServiceProvider).setStopWhenSwipedAway(value);
    } catch (_) {}
  }
}

/// Where new downloads are saved. Picked once in Settings so the app never has
/// to ask again: tapping download simply starts the download there.
final downloadDestinationProvider =
    NotifierProvider<DownloadDestinationNotifier, DownloadDestination>(
      DownloadDestinationNotifier.new,
    );

class DownloadDestinationNotifier extends Notifier<DownloadDestination> {
  @override
  DownloadDestination build() {
    try {
      return ref.read(storageServiceProvider).getDownloadDestination() == 'phone'
          ? DownloadDestination.phoneStorage
          : DownloadDestination.inApp;
    } catch (_) {
      return DownloadDestination.inApp;
    }
  }

  Future<void> setDestination(DownloadDestination destination) async {
    state = destination;
    try {
      await ref
          .read(storageServiceProvider)
          .setDownloadDestination(
            destination == DownloadDestination.phoneStorage ? 'phone' : 'inApp',
          );
    } catch (_) {}
  }
}

/// How slowly the volume rises when a song starts and falls when it pauses.
/// [Duration.zero] plays and stops instantly; the default is 0.7 seconds.
final audioFadeProvider = NotifierProvider<AudioFadeNotifier, Duration>(
  AudioFadeNotifier.new,
);

class AudioFadeNotifier extends Notifier<Duration> {
  @override
  Duration build() {
    int savedMs = 700;
    try {
      savedMs = ref.read(storageServiceProvider).getAudioFadeMs();
      ref
          .read(audioHandlerProvider)
          .setFadeDuration(Duration(milliseconds: savedMs));
    } catch (_) {
      // Storage or the audio engine is not available (isolated tests).
    }
    return Duration(milliseconds: savedMs);
  }

  Future<void> setDuration(Duration duration) async {
    state = duration;
    try {
      ref.read(audioHandlerProvider).setFadeDuration(duration);
    } catch (_) {}
    try {
      await ref
          .read(storageServiceProvider)
          .setAudioFadeMs(duration.inMilliseconds);
    } catch (_) {}
  }
}

/// Picks the 320 kbps or 160 kbps CDN stream for online tracks.
final highQualityStreamProvider =
    NotifierProvider<HighQualityStreamNotifier, bool>(
      HighQualityStreamNotifier.new,
    );

class HighQualityStreamNotifier extends Notifier<bool> {
  @override
  bool build() {
    bool saved = true;
    try {
      saved = ref.read(storageServiceProvider).getHighQualityStreams();
    } catch (_) {
      // Storage unavailable (isolated tests) — keep the 320 kbps default.
    }
    OnlineMusicService.highQualityStreams = saved;
    return saved;
  }

  Future<void> setEnabled(bool value) async {
    state = value;
    OnlineMusicService.highQualityStreams = value;
    try {
      await ref.read(storageServiceProvider).setHighQualityStreams(value);
    } catch (_) {}
  }
}
