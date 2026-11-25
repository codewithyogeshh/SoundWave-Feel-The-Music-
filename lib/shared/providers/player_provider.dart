import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundwave/core/constants/sample_music_data.dart';
import 'package:soundwave/features/online/services/online_music_service.dart';
import 'package:soundwave/features/player/models/song_model.dart';
import 'package:soundwave/features/player/services/audio_handler.dart';
import 'package:soundwave/features/player/services/queue_variety.dart';
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

  // Last-session persistence (resume the song, queue and position on launch).
  bool _userStartedPlayback = false;
  Timer? _sessionSaveTimer;
  String? _lastSavedSignature;

  // Actual listening time, accrued while the music is really playing.
  int _listenedBufferMs = 0;
  Duration _lastListenedPosition = Duration.zero;

  /// Where playback should start when the restored song is played again.
  Duration? _resumePosition;

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
      _sessionSaveTimer?.cancel();
      unawaited(_saveSession(force: true));
      unawaited(_flushListenedTime());
      _playbackSub?.cancel();
      _mediaSub?.cancel();
      _posSub?.cancel();
      _durSub?.cancel();
      _bufSub?.cancel();
    });

    _initStreams();

    final initialSongs = SampleMusicData.initialSongs;
    final initialSong = initialSongs.isNotEmpty ? initialSongs.first : null;
    final savedSpeed = _savedPlaybackSpeed();
    if ((savedSpeed - 1.0).abs() > 0.001) {
      unawaited(_handler.setPlaybackSpeed(savedSpeed));
    }

    // Restore after build() returns so the notifier state exists.
    unawaited(Future.microtask(_restoreLastSession));

    return PlayerState(
      currentSong: initialSong,
      queue: initialSongs,
      duration: initialSong?.duration ?? Duration.zero,
      playbackSpeed: savedSpeed,
    );
  }

  void _initStreams() {
    _playbackSub = _handler.playbackState.listen((playbackState) {
      if (_isDisposed) return;
      final qIdx = playbackState.queueIndex;
      final validIdx = (qIdx != null && qIdx >= 0 && qIdx < state.queue.length)
          ? qIdx
          : null;
      final handlerSong = _handler.currentSong;
      SongModel? syncedSong;
      if (validIdx != null) {
        final queueSong = state.queue[validIdx];
        syncedSong = (handlerSong != null && handlerSong.id == queueSong.id)
            ? handlerSong
            : queueSong;
      }

      if (!playbackState.playing) {
        _scheduleSessionSave(immediate: true);
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
      _accrueListenedTime(pos);
      state = state.copyWith(position: pos);
      _scheduleSessionSave();
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
        final fallback =
            _handler.currentSong ?? state.queue[_handler.currentIndex];
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
    _userStartedPlayback = true;
    _resumePosition = null;
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
      final offline = downloadedSongs
          .where((s) => s.id == candidate.id)
          .firstOrNull;
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
    // A search result list is full of jhankar/lo-fi copies of the same song.
    // Drop the extra versions so the queue stays varied.
    final rawLength = effectiveQueue.length;
    effectiveQueue = QueueVariety.trimRepeats(
      effectiveQueue,
      currentId: trackToPlay.id,
    );
    final removedRepeats = rawLength - effectiveQueue.length;
    final targetIndex = effectiveQueue.indexWhere(
      (s) => s.id == trackToPlay.id,
    );
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
    final needsOnlineResolve =
        trackToPlay.sourceType == AudioSourceType.network &&
        trackToPlay.id.startsWith('online_') &&
        (trackToPlay.audioPath.isEmpty ||
            trackToPlay.audioPath.contains('jiotunepreview.jio.com'));

    if (needsOnlineResolve) {
      await _handler.pause();
      if (requestId != _playRequestId || _isDisposed) return;

      final resolvedTrack = await OnlineMusicService.resolveFullTrack(
        trackToPlay,
      );
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

    // The old copies were removed, so add songs of the same vibe to keep the
    // music going instead of ending after two tracks.
    if (removedRepeats > 0) {
      unawaited(_topUpQueueWithSimilar(trackToPlay, requestId));
    }
  }

  /// Adds a handful of songs that match the current track's vibe (same artist,
  /// genre or mood) to the end of the queue, skipping anything already queued
  /// or another version of the same song.
  Future<void> _topUpQueueWithSimilar(SongModel seed, int requestId) async {
    final similar = await QueueVariety.similarVibeSongs(seed);
    if (_isDisposed || requestId != _playRequestId) return;

    final existing = state.queue;
    final additions = <SongModel>[];
    for (final candidate in similar) {
      if (additions.length >= 12) break;
      if (existing.any((s) => s.id == candidate.id)) continue;
      if (existing.any((s) => QueueVariety.sameFamily(s, candidate))) continue;
      if (additions.any((s) => QueueVariety.sameFamily(s, candidate))) continue;
      final currentId = state.currentSong?.id;
      if (currentId != null && candidate.id == currentId) continue;
      additions.add(candidate);
    }
    if (additions.isEmpty) return;

    final newQueue = <SongModel>[...existing, ...additions];
    final currentSong = state.currentSong;
    final newIndex = currentSong == null
        ? state.currentIndex
        : newQueue.indexWhere((s) => s.id == currentSong.id);
    final safeIndex = newIndex < 0 ? state.currentIndex : newIndex;

    state = state.copyWith(queue: newQueue, currentIndex: safeIndex);
    _beginTrackConfirmation(currentSong);
    await _handler.updateSongQueue(newQueue, newIndex: safeIndex);
  }

  /// Cleans a queue that was built before the variety filter existed (or by a
  /// list that was full of copies of one song) and tops it up with same-vibe
  /// songs. Safe to call whenever the player screen opens: it does nothing
  /// when the queue is already varied.
  Future<void> refreshQueueVariety() async {
    final current = state.currentSong;
    if (current == null || state.queue.isEmpty) return;

    final trimmed = QueueVariety.trimRepeats(
      state.queue,
      currentId: current.id,
    );
    if (trimmed.length >= state.queue.length) return;

    final newIndex = trimmed.indexWhere((s) => s.id == current.id);
    final safeIndex = newIndex < 0 ? 0 : newIndex;
    state = state.copyWith(queue: trimmed, currentIndex: safeIndex);
    _beginTrackConfirmation(current);
    await _handler.updateSongQueue(trimmed, newIndex: safeIndex);
    await _topUpQueueWithSimilar(current, _playRequestId);
  }

  Future<void> pause() async {
    ++_playRequestId;
    await _handler.pause();
  }

  Future<void> togglePlayPause() async {
    _userStartedPlayback = true;
    if (state.isPlaying) {
      await pause();
    } else {
      final resumeAt = _resumePosition;
      _resumePosition = null;
      if (_handler.currentSong == null && state.currentSong != null) {
        await playTrack(state.currentSong!, queue: state.queue);
        if (resumeAt != null && resumeAt > Duration.zero) {
          await seek(resumeAt);
        }
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
    try {
      await ref.read(storageServiceProvider).savePlaybackSpeed(speed);
    } catch (_) {
      // Allows isolated tests without a storage override.
    }
  }

  // ---------------------------------------------------------------------------
  // Last session (resume last song + position, persisted playback speed)
  // ---------------------------------------------------------------------------

  double _savedPlaybackSpeed() {
    try {
      return ref.read(storageServiceProvider).getPlaybackSpeed();
    } catch (_) {
      return 1.0;
    }
  }

  /// Restores the queue, track and position the app last saved, without
  /// starting playback. Skipped as soon as the user taps something first.
  Future<void> _restoreLastSession() async {
    if (_isDisposed) return;
    try {
      final storage = ref.read(storageServiceProvider);
      final session = storage.getPlaybackSession();
      if (session == null || session.queue.isEmpty) return;
      final index = session.index.clamp(0, session.queue.length - 1);
      final song = session.queue[index];

      // Skip dead local files so a deleted song never blocks startup.
      if (song.sourceType == AudioSourceType.file &&
          !kIsWeb &&
          !File(song.audioPath).existsSync()) {
        return;
      }
      if (_isDisposed || _userStartedPlayback) return;

      // Saved queues from older builds may still hold ten versions of one
      // song; keep the queue varied when it is restored on launch.
      final restoredQueue = QueueVariety.trimRepeats(
        session.queue,
        currentId: song.id,
      );
      final restoredIndex = restoredQueue.indexWhere((s) => s.id == song.id);

      state = state.copyWith(
        queue: restoredQueue,
        currentIndex: restoredIndex >= 0 ? restoredIndex : 0,
        currentSong: song,
        position: session.position,
        duration: song.duration,
        isPlaying: false,
      );

      // Nothing is preloaded, so playback stays silent until the user taps
      // play; that tap then continues from the saved position.
      _resumePosition = session.position;
    } catch (_) {
      // Fresh installs, tests without storage, or unreadable sessions.
    }
  }

  void _scheduleSessionSave({bool immediate = false}) {
    if (_isDisposed || state.queue.isEmpty) return;
    if (immediate) {
      _sessionSaveTimer?.cancel();
      _sessionSaveTimer = null;
      unawaited(_saveSession());
      return;
    }
    if (_sessionSaveTimer?.isActive ?? false) return;
    _sessionSaveTimer = Timer(const Duration(seconds: 5), () {
      _sessionSaveTimer = null;
      unawaited(_saveSession());
    });
  }

  /// Counts forward playback progress as real listening time. Seeks and
  /// track changes are skipped, and writes are batched to spare flash storage.
  void _accrueListenedTime(Duration position) {
    final delta = position - _lastListenedPosition;
    _lastListenedPosition = position;
    if (!state.isPlaying) return;
    if (delta <= Duration.zero || delta > const Duration(seconds: 2)) return;
    _listenedBufferMs += delta.inMilliseconds;
    if (_listenedBufferMs >= 10000) {
      unawaited(_flushListenedTime());
    }
  }

  Future<void> _flushListenedTime() async {
    final ms = _listenedBufferMs;
    if (ms < 1000) return;
    _listenedBufferMs = 0;
    try {
      await ref
          .read(storageServiceProvider)
          .addListenedSeconds(ms ~/ 1000);
    } catch (_) {
      // Storage is not available yet (or in isolated tests).
    }
  }

  Future<void> _saveSession({bool force = false}) async {
    try {
      final current = state.currentSong;
      if (current == null || state.queue.isEmpty) return;
      final position = state.position;
      final signature =
          '${current.id}|${state.currentIndex}|${position.inSeconds ~/ 5}';
      if (!force && signature == _lastSavedSignature) return;
      _lastSavedSignature = signature;
      await ref
          .read(storageServiceProvider)
          .savePlaybackSession(
            queue: state.queue,
            index: state.currentIndex,
            position: position,
          );
    } catch (_) {
      // Storage is not available yet (or in isolated tests).
    }
  }

  Future<void> reorderQueue(
    int oldIndex,
    int newIndex, {
    bool isAdjusted = false,
  }) async {
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
      final updatedIdx = newQueue.indexWhere(
        (s) => s.id == state.currentSong!.id,
      );
      if (updatedIdx >= 0) {
        newCurrentIndex = updatedIdx;
      }
    }

    state = state.copyWith(queue: newQueue, currentIndex: newCurrentIndex);

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

    state = state.copyWith(queue: [current], currentIndex: 0);

    _beginTrackConfirmation(current);
    await _handler.clearUpcomingQueue();
  }
}

final playerProvider = NotifierProvider<PlayerNotifier, PlayerState>(
  PlayerNotifier.new,
);
