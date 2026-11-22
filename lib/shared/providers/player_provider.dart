import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundwave/core/constants/sample_music_data.dart';
import 'package:soundwave/features/online/services/online_music_service.dart';
import 'package:soundwave/features/player/models/song_model.dart';
import 'package:soundwave/features/player/services/audio_handler.dart';
import 'package:soundwave/shared/providers/library_provider.dart';

final audioHandlerProvider = Provider<SoundWaveAudioHandler>((ref) {
  throw UnimplementedError('AudioHandler must be overridden in main');
});

class PlayerState {
  final SongModel? currentSong;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final Duration bufferedPosition;
  final List<SongModel> queue;
  final int currentIndex;
  final bool isShuffle;
  final AudioServiceRepeatMode repeatMode;
  final double playbackSpeed;

  const PlayerState({
    this.currentSong,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.bufferedPosition = Duration.zero,
    this.queue = const [],
    this.currentIndex = 0,
    this.isShuffle = false,
    this.repeatMode = AudioServiceRepeatMode.none,
    this.playbackSpeed = 1.0,
  });

  PlayerState copyWith({
    SongModel? currentSong,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    Duration? bufferedPosition,
    List<SongModel>? queue,
    int? currentIndex,
    bool? isShuffle,
    AudioServiceRepeatMode? repeatMode,
    double? playbackSpeed,
  }) {
    return PlayerState(
      currentSong: currentSong ?? this.currentSong,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      bufferedPosition: bufferedPosition ?? this.bufferedPosition,
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      isShuffle: isShuffle ?? this.isShuffle,
      repeatMode: repeatMode ?? this.repeatMode,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
    );
  }
}

class PlayerNotifier extends Notifier<PlayerState> {
  SoundWaveAudioHandler get _handler => ref.read(audioHandlerProvider);
  StreamSubscription? _playbackSub;
  StreamSubscription? _mediaSub;
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _bufSub;
  int _playRequestId = 0;
  bool _isDisposed = false;

  // While a local queue/track mutation is awaiting confirmation from the audio
  // engine, stale playback events (e.g. an older queueIndex still in flight from
  // a previous loadQueue) are ignored so they cannot regress the current track.
  bool _awaitingTrackConfirmation = false;
  SongModel? _expectedSongDuringPending;

  @override
  PlayerState build() {
    _isDisposed = false;
    ref.onDispose(() {
      _isDisposed = true;
      ++_playRequestId;
      _playbackSub?.cancel();
      _mediaSub?.cancel();
      _posSub?.cancel();
      _durSub?.cancel();
      _bufSub?.cancel();
    });

    _initStreams();

    final initialSongs = SampleMusicData.initialSongs;
    final initialSong = initialSongs.isNotEmpty ? initialSongs.first : null;

    return PlayerState(
      currentSong: initialSong,
      queue: initialSongs,
      duration: initialSong?.duration ?? Duration.zero,
    );
  }

  void _initStreams() {
    _playbackSub = _handler.playbackState.listen((playbackState) {
      if (_isDisposed) return;
      final qIdx = playbackState.queueIndex;
      final validIdx =
          (qIdx != null && qIdx >= 0 && qIdx < state.queue.length) ? qIdx : null;
      final handlerSong = _handler.currentSong;
      SongModel? syncedSong;
      if (validIdx != null) {
        final queueSong = state.queue[validIdx];
        syncedSong = (handlerSong != null && handlerSong.id == queueSong.id)
            ? handlerSong
            : queueSong;
      }

      if (_acceptTrackConfirmation(syncedSong)) {
        state = state.copyWith(
          isPlaying: playbackState.playing,
          isShuffle: playbackState.shuffleMode == AudioServiceShuffleMode.all,
          repeatMode: playbackState.repeatMode,
          playbackSpeed: playbackState.speed,
          currentIndex: validIdx,
          currentSong: syncedSong,
        );
      } else {
        state = state.copyWith(
          isPlaying: playbackState.playing,
          isShuffle: playbackState.shuffleMode == AudioServiceShuffleMode.all,
          repeatMode: playbackState.repeatMode,
          playbackSpeed: playbackState.speed,
        );
      }
    });

    _posSub = _handler.player.positionStream.listen((pos) {
      if (_isDisposed) return;
      state = state.copyWith(position: pos);
    });

    _durSub = _handler.player.durationStream.listen((dur) {
      if (_isDisposed) return;
      if (dur != null) {
        state = state.copyWith(duration: dur);
      }
    });

    _bufSub = _handler.player.bufferedPositionStream.listen((buf) {
      if (_isDisposed) return;
      state = state.copyWith(bufferedPosition: buf);
    });

    _mediaSub = _handler.mediaItem.listen((item) {
      if (_isDisposed || item == null) return;
      if (_awaitingTrackConfirmation &&
          item.id != _expectedSongDuringPending?.id) {
        return;
      }
      if (_awaitingTrackConfirmation) {
        _awaitingTrackConfirmation = false;
        _expectedSongDuringPending = null;
      }
      final idx = state.queue.indexWhere((s) => s.id == item.id);
      if (idx >= 0) {
        final handlerSong = _handler.currentSong;
        final updatedSong = (handlerSong != null && handlerSong.id == item.id)
            ? handlerSong
            : state.queue[idx];
        state = state.copyWith(
          currentSong: updatedSong,
          currentIndex: idx,
          duration: (item.duration != null && item.duration! > Duration.zero)
              ? item.duration
              : updatedSong.duration,
        );
      } else if (state.queue.isNotEmpty &&
          _handler.currentIndex >= 0 &&
          _handler.currentIndex < state.queue.length) {
        final fallback = _handler.currentSong ?? state.queue[_handler.currentIndex];
        state = state.copyWith(
          currentSong: fallback,
          currentIndex: _handler.currentIndex,
          duration: (item.duration != null && item.duration! > Duration.zero)
              ? item.duration
              : fallback.duration,
        );
      }
    });
  }

  /// True when [candidate] matches the song we expect the engine to be playing
  /// after a recent local mutation. While pending, stale media/playback events
  /// that disagree are ignored so they cannot regress the current track.
  bool _acceptTrackConfirmation(SongModel? candidate) {
    if (!_awaitingTrackConfirmation) return true;
    final expected = _expectedSongDuringPending;
    if (expected != null && candidate != null && candidate.id == expected.id) {
      _awaitingTrackConfirmation = false;
      _expectedSongDuringPending = null;
      return true;
    }
    return false;
  }

  void _beginTrackConfirmation(SongModel? expected) {
    _awaitingTrackConfirmation = true;
    _expectedSongDuringPending = expected;
  }

  Future<void> playTrack(SongModel song, {List<SongModel>? queue}) async {
    final int requestId = ++_playRequestId;

    // Prefer downloaded offline song + banner when already saved locally
    List<SongModel> downloadedSongs = const [];
    try {
      downloadedSongs = ref.read(libraryProvider).downloadedSongs;
    } catch (_) {
      // Allows isolated tests without libraryProvider overrides
    }

    SongModel preferOfflineCopy(SongModel candidate) {
      if (kIsWeb || downloadedSongs.isEmpty) return candidate;
      final offline =
          downloadedSongs.where((s) => s.id == candidate.id).firstOrNull;
      if (offline != null &&
          offline.audioPath.isNotEmpty &&
          File(offline.audioPath).existsSync()) {
        if ((offline.artworkPath == null || offline.artworkPath!.isEmpty) &&
            candidate.artworkPath != null &&
            candidate.artworkPath!.isNotEmpty) {
          return offline.copyWith(artworkPath: candidate.artworkPath);
        }
        return offline;
      }
      return candidate;
    }

    SongModel trackToPlay = preferOfflineCopy(song);
    final rawQueue = queue ?? [trackToPlay];
    var effectiveQueue = rawQueue
        .map((s) => s.id == trackToPlay.id ? trackToPlay : preferOfflineCopy(s))
        .toList();
    final targetIndex = effectiveQueue.indexWhere((s) => s.id == trackToPlay.id);
    final initialIndex = targetIndex >= 0 ? targetIndex : 0;

    // Optimistic UI update so MiniPlayer / highlights respond immediately without overlap
    state = state.copyWith(
      currentSong: trackToPlay,
      queue: effectiveQueue,
      currentIndex: initialIndex,
      isPlaying: false,
      position: Duration.zero,
      duration: trackToPlay.duration,
    );

    // If it's an online track needing URL resolution, silence previous playback first
    final needsOnlineResolve = trackToPlay.sourceType == AudioSourceType.network &&
        trackToPlay.id.startsWith('online_') &&
        (trackToPlay.audioPath.isEmpty ||
            trackToPlay.audioPath.contains('jiotunepreview.jio.com'));

    if (needsOnlineResolve) {
      await _handler.pause();
      if (requestId != _playRequestId || _isDisposed) return;

      final resolvedTrack = await OnlineMusicService.resolveFullTrack(trackToPlay);
      if (requestId != _playRequestId || _isDisposed) return;

      if (resolvedTrack != null) {
        trackToPlay = resolvedTrack;
      } else {
        final resolvedUrl = await OnlineMusicService.resolveStreamUrl(
          trackToPlay.id,
          fallbackUrl: trackToPlay.audioPath,
        );
        if (requestId != _playRequestId || _isDisposed) return;

        if (resolvedUrl != null &&
            resolvedUrl.isNotEmpty &&
            !resolvedUrl.contains('jiotunepreview')) {
          trackToPlay = trackToPlay.copyWith(audioPath: resolvedUrl);
        }
      }

      effectiveQueue = effectiveQueue
          .map((s) => s.id == trackToPlay.id ? trackToPlay : s)
          .toList();

      state = state.copyWith(
        currentSong: trackToPlay,
        queue: effectiveQueue,
        currentIndex: initialIndex,
        position: Duration.zero,
        duration: trackToPlay.duration,
      );
    }

    if (requestId != _playRequestId || _isDisposed) return;
    _beginTrackConfirmation(trackToPlay);
    await _handler.loadQueue(effectiveQueue, initialIndex: initialIndex);
  }

  Future<void> pause() async {
    ++_playRequestId;
    await _handler.pause();
  }

  Future<void> togglePlayPause() async {
    if (state.isPlaying) {
      await pause();
    } else {
      if (_handler.currentSong == null && state.currentSong != null) {
        await playTrack(state.currentSong!, queue: state.queue);
      } else {
        ++_playRequestId;
        await _handler.play();
      }
    }
  }

  Future<void> seek(Duration position) async {
    state = state.copyWith(position: position);
    await _handler.seek(position);
  }

  Future<void> skipToNext() async {
    final int requestId = ++_playRequestId;
    await _handler.skipToNext();
    if (requestId == _playRequestId && !_isDisposed) {
      _beginTrackConfirmation(_handler.currentSong);
      if (_handler.currentSong != null) {
        state = state.copyWith(
          currentSong: _handler.currentSong,
          currentIndex: _handler.currentIndex,
        );
      }
    }
  }

  Future<void> skipToPrevious() async {
    final int requestId = ++_playRequestId;
    await _handler.skipToPrevious();
    if (requestId == _playRequestId && !_isDisposed) {
      _beginTrackConfirmation(_handler.currentSong);
      if (_handler.currentSong != null) {
        state = state.copyWith(
          currentSong: _handler.currentSong,
          currentIndex: _handler.currentIndex,
        );
      }
    }
  }

  Future<void> toggleShuffle() async {
    await _handler.toggleShuffle();
    state = state.copyWith(isShuffle: !state.isShuffle);
  }

  Future<void> cycleRepeatMode() async {
    await _handler.cycleRepeatMode();
  }

  Future<void> setPlaybackSpeed(double speed) async {
    state = state.copyWith(playbackSpeed: speed);
    await _handler.setPlaybackSpeed(speed);
  }

  Future<void> reorderQueue(int oldIndex, int newIndex, {bool isAdjusted = false}) async {
    if (oldIndex < 0 ||
        oldIndex >= state.queue.length ||
        newIndex < 0 ||
        newIndex > state.queue.length) {
      return;
    }

    final newQueue = List<SongModel>.from(state.queue);
    if (!isAdjusted && oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = newQueue.removeAt(oldIndex);
    newQueue.insert(newIndex.clamp(0, newQueue.length), item);

    // Track current playing song position
    int newCurrentIndex = state.currentIndex;
    if (state.currentSong != null) {
      final updatedIdx = newQueue.indexWhere((s) => s.id == state.currentSong!.id);
      if (updatedIdx >= 0) {
        newCurrentIndex = updatedIdx;
      }
    }

    state = state.copyWith(
      queue: newQueue,
      currentIndex: newCurrentIndex,
    );

    _beginTrackConfirmation(state.currentSong);
    await _handler.updateSongQueue(newQueue, newIndex: newCurrentIndex);
  }

  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= state.queue.length) return;
    if (state.queue.length <= 1) return; // Keep at least one song in queue

    final isCurrent = index == state.currentIndex;
    final newQueue = List<SongModel>.from(state.queue)..removeAt(index);

    int newCurrentIndex = state.currentIndex;
    if (index < state.currentIndex) {
      newCurrentIndex = (state.currentIndex - 1).clamp(0, newQueue.length - 1);
    } else if (newCurrentIndex >= newQueue.length) {
      newCurrentIndex = newQueue.length - 1;
    }

    final nextSong = newQueue[newCurrentIndex];
    state = state.copyWith(
      queue: newQueue,
      currentIndex: newCurrentIndex,
      currentSong: isCurrent ? nextSong : state.currentSong,
    );

    _beginTrackConfirmation(isCurrent ? nextSong : state.currentSong);
    await _handler.removeFromQueue(index);
  }

  Future<void> clearUpcomingQueue() async {
    if (state.queue.length <= 1) return;
    final current = state.currentSong;
    if (current == null) return;

    state = state.copyWith(
      queue: [current],
      currentIndex: 0,
    );

    _beginTrackConfirmation(current);
    await _handler.clearUpcomingQueue();
  }
}

final playerProvider =
    NotifierProvider<PlayerNotifier, PlayerState>(PlayerNotifier.new);
