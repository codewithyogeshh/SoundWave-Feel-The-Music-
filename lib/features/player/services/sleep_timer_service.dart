import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundwave/shared/providers/player_provider.dart';

class SleepTimerState {
  final bool isActive;
  final int totalMinutes;
  final Duration remaining;
  final bool isFading;
  final double currentVolume;

  const SleepTimerState({
    this.isActive = false,
    this.totalMinutes = 0,
    this.remaining = Duration.zero,
    this.isFading = false,
    this.currentVolume = 1.0,
  });

  SleepTimerState copyWith({
    bool? isActive,
    int? totalMinutes,
    Duration? remaining,
    bool? isFading,
    double? currentVolume,
  }) {
    return SleepTimerState(
      isActive: isActive ?? this.isActive,
      totalMinutes: totalMinutes ?? this.totalMinutes,
      remaining: remaining ?? this.remaining,
      isFading: isFading ?? this.isFading,
      currentVolume: currentVolume ?? this.currentVolume,
    );
  }
}

class SleepTimerNotifier extends Notifier<SleepTimerState> {
  Timer? _timer;
  static const int _fadeSeconds = 25;

  @override
  SleepTimerState build() {
    ref.onDispose(() {
      _timer?.cancel();
    });
    return const SleepTimerState();
  }

  void startTimer(int minutes, {bool enableFade = true}) {
    _timer?.cancel();
    final duration = Duration(minutes: minutes);
    state = SleepTimerState(
      isActive: true,
      totalMinutes: minutes,
      remaining: duration,
      isFading: false,
      currentVolume: 1.0,
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

  void addMinutes(int minutes) {
    if (!state.isActive) {
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
