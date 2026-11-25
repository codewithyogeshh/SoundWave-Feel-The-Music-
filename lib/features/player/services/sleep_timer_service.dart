import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundwave/shared/providers/player_provider.dart';

/// How the sleep timer decides when to stop playback.
///
/// [countdown] is the classic "stop after N minutes" mode.
/// [endOfTrack] stops as soon as the current song finishes.
enum SleepTimerMode { countdown, endOfTrack }

class SleepTimerState {
  final bool isActive;
  final int totalMinutes;
  final Duration remaining;
  final bool isFading;
  final double currentVolume;
  final SleepTimerMode mode;

  const SleepTimerState({
    this.isActive = false,
    this.totalMinutes = 0,
    this.remaining = Duration.zero,
    this.isFading = false,
    this.currentVolume = 1.0,
    this.mode = SleepTimerMode.countdown,
  });

  SleepTimerState copyWith({
    bool? isActive,
    int? totalMinutes,
    Duration? remaining,
    bool? isFading,
    double? currentVolume,
    SleepTimerMode? mode,
  }) {
    return SleepTimerState(
      isActive: isActive ?? this.isActive,
      totalMinutes: totalMinutes ?? this.totalMinutes,
      remaining: remaining ?? this.remaining,
      isFading: isFading ?? this.isFading,
      currentVolume: currentVolume ?? this.currentVolume,
      mode: mode ?? this.mode,
    );
  }
}

class SleepTimerNotifier extends Notifier<SleepTimerState> {
  Timer? _timer;
  static const int _fadeSeconds = 25;

  /// Song that must finish before an [SleepTimerMode.endOfTrack] timer fires.
  String? _endOfTrackSongId;

  @override
  SleepTimerState build() {
    ref.onDispose(() {
      _timer?.cancel();
    });
    return const SleepTimerState();
  }

  void startTimer(int minutes, {bool enableFade = true}) {
    _timer?.cancel();
    _endOfTrackSongId = null;
    final duration = Duration(minutes: minutes);
    state = SleepTimerState(
      isActive: true,
      totalMinutes: minutes,
      remaining: duration,
      isFading: false,
      currentVolume: 1.0,
      mode: SleepTimerMode.countdown,
    );

    // Ensure volume starts at full
    _setVolumeSafe(1.0);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.remaining.inSeconds <= 1) {
        timer.cancel();
        // Restore volume back to 1.0 before pausing so next playback is crystal clear
        _setVolumeSafe(1.0);
        state = const SleepTimerState(isActive: false, currentVolume: 1.0);
        // Pause music playback cleanly when timer expires
        ref.read(playerProvider.notifier).pause();
      } else {
        final newRemaining = state.remaining - const Duration(seconds: 1);
        final shouldFade = enableFade && newRemaining.inSeconds <= _fadeSeconds;
        double nextVolume = 1.0;

        if (shouldFade) {
          // Smooth ease-out cubic fade
          final progress = (newRemaining.inSeconds / _fadeSeconds).clamp(0.0, 1.0);
          nextVolume = (progress * progress).clamp(0.05, 1.0);
          _setVolumeSafe(nextVolume);
        }

        state = state.copyWith(
          remaining: newRemaining,
          isFading: shouldFade,
          currentVolume: nextVolume,
        );
      }
    });
  }

  /// Stops playback right after the song that is playing now.
  ///
  /// The next track is paused the moment it becomes current, so nothing of the
  /// following song is heard.
  void startEndOfTrack() {
    _timer?.cancel();
    final player = ref.read(playerProvider);
    _endOfTrackSongId = player.currentSong?.id;
    if (_endOfTrackSongId == null) {
      state = const SleepTimerState();
      return;
    }

    _setVolumeSafe(1.0);
    state = const SleepTimerState(
      isActive: true,
      remaining: Duration.zero,
      mode: SleepTimerMode.endOfTrack,
    );

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_endOfTrackSongId == null) {
        _timer?.cancel();
        return;
      }
      final now = ref.read(playerProvider);
      final songChanged = now.currentSong?.id != _endOfTrackSongId;
      if (songChanged) {
        _timer?.cancel();
        _endOfTrackSongId = null;
        state = const SleepTimerState();
        ref.read(playerProvider.notifier).pause();
        return;
      }
      // The user stopped playback themselves: the timer has nothing left to do.
      if (!now.isPlaying) {
        _timer?.cancel();
        _endOfTrackSongId = null;
        state = const SleepTimerState();
      }
    });
  }

  void addMinutes(int minutes) {
    if (!state.isActive || state.mode != SleepTimerMode.countdown) {
      startTimer(minutes);
      return;
    }
    final extended = state.remaining + Duration(minutes: minutes);
    state = state.copyWith(
      totalMinutes: state.totalMinutes + minutes,
      remaining: extended,
      isFading: false,
      currentVolume: 1.0,
    );
    _setVolumeSafe(1.0);
  }

  void cancelTimer() {
    _timer?.cancel();
    _endOfTrackSongId = null;
    _setVolumeSafe(1.0);
    state = const SleepTimerState(isActive: false, currentVolume: 1.0);
  }

  void _setVolumeSafe(double volume) {
    try {
      ref.read(audioHandlerProvider).setPlaybackVolume(volume);
    } catch (_) {
      // Allows isolated widget tests where audioHandlerProvider is mocked
    }
  }
}

final sleepTimerProvider =
    NotifierProvider<SleepTimerNotifier, SleepTimerState>(
  SleepTimerNotifier.new,
);
