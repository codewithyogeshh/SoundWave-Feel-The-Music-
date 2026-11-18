import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundwave/shared/providers/player_provider.dart';

class SleepTimerState {
  final bool isActive;
  final int totalMinutes;
  final Duration remaining;

  const SleepTimerState({
    this.isActive = false,
    this.totalMinutes = 0,
    this.remaining = Duration.zero,
  });

  SleepTimerState copyWith({
    bool? isActive,
    int? totalMinutes,
    Duration? remaining,
  }) {
    return SleepTimerState(
      isActive: isActive ?? this.isActive,
      totalMinutes: totalMinutes ?? this.totalMinutes,
      remaining: remaining ?? this.remaining,
    );
  }
}

class SleepTimerNotifier extends Notifier<SleepTimerState> {
  Timer? _timer;

  @override
  SleepTimerState build() {
    ref.onDispose(() {
      _timer?.cancel();
    });
    return const SleepTimerState();
  }

  void startTimer(int minutes) {
    _timer?.cancel();
    final duration = Duration(minutes: minutes);
    state = SleepTimerState(
      isActive: true,
      totalMinutes: minutes,
      remaining: duration,
    );

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.remaining.inSeconds <= 1) {
        timer.cancel();
        state = const SleepTimerState(isActive: false);
        // Pause music playback cleanly when timer expires
        ref.read(playerProvider.notifier).pause();
      } else {
        state = state.copyWith(
          remaining: state.remaining - const Duration(seconds: 1),
        );
      }
    });
  }

  void cancelTimer() {
    _timer?.cancel();
    state = const SleepTimerState(isActive: false);
  }
}

final sleepTimerProvider =
    NotifierProvider<SleepTimerNotifier, SleepTimerState>(
  SleepTimerNotifier.new,
);

