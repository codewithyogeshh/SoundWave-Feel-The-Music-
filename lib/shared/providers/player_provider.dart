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
  final double volume;

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
    this.volume = 1.0,
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
    double? volume,
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
      volume: volume ?? this.volume,
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

  // Volume restored when unmuting, so "पुन्हा आवाज" brings back the old level.
  double _volumeBeforeMute = 0.7;

  // Actual listening time, accrued while the music is really playing.
  int _listenedBufferMs = 0;
  Duration _lastListenedPosition = Duration.zero;

    /// Where playback should start when the restored song is played again.
  Duration? _resumePosition;

  // Queue auto-continue: remembers which song already got more tracks added.
  String? _continuedForSongId;
  bool _continuingQueue = false;

  // While a local queue/track mutation is awaiting confirmation from the audio
  // engine, stale playback events (e.g. an older queueIndex still in flight from
  // a previous loadQueue) are ignored so they cannot regress the current track.
  bool _awaitingTrackConfirmation = false;
  SongModel? _expectedSongDuringPending;

  /// Last track written to the listening history, so a repeated media event
  /// for the same song does not add it twice in a row.
  String? _lastRecordedSongId;

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
    unawaited(_restorePlaybackModes());

    final initialSongs = SampleMusicData.initialSongs;
    final initialSong = initialSongs.isNotEmpty ? initialSongs.first : null;
    final savedSpeed = _savedPlaybackSpeed();
    if ((savedSpeed - 1.0).abs() > 0.001) {
      unawaited(_handler.setPlaybackSpeed(savedSpeed));
    }
    final savedVolume = _savedPlaybackVolume();
    if ((savedVolume - 1.0).abs() > 0.001) {
      unawaited(_handler.setPlaybackVolume(savedVolume));
      if (savedVolume > 0.01) _volumeBeforeMute = savedVolume;
    }

    // Restore after build() returns so the notifier state exists.
    unawaited(Future.microtask(_restoreLastSession));

    return PlayerState(
      currentSong: initialSong,
      queue: initialSongs,
      duration: initialSong?.duration ?? Duration.zero,
      playbackSpeed: savedSpeed,
      volume: savedVolume,
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

      // The last song of the queue started: keep the music going with tracks
      // that share its vibe.
      if (playbackState.playing) {
        unawaited(_continueQueueIfNeeded());
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
        _recordHistory(updatedSong);
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
        _recordHistory(fallback);
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

  /// Saves the track that just started into the listening history, so it can
  /// be replayed later without searching for it again. Online songs are kept
  /// as full song records, not just ids.
  void _recordHistory(SongModel? song) {
    if (song == null || song.id.isEmpty) return;
    if (_lastRecordedSongId == song.id) return;
    _lastRecordedSongId = song.id;
    try {
      unawaited(
        ref
            .read(libraryProvider.notifier)
            .recordPlayed(song)
            .catchError((Object _) {}),
      );
    } catch (_) {
      // Allows isolated tests without libraryProvider overrides.
    }
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

    // Either the old copies were removed or the list was short: add songs of
    // the same vibe so "next" keeps playing good, related music instead of
    // ending after a couple of tracks.
    if (removedRepeats > 0 || effectiveQueue.length < 12) {
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

  /// Title of the song a skip would play next, shuffle order included, so the
  /// home widget can show the real "Next" even while shuffling.
  String? get upcomingSongTitle => _handler.upcomingSong?.title;

  Future<void> toggleShuffle() async {
    await _handler.toggleShuffle();
    state = state.copyWith(isShuffle: !state.isShuffle);
    try {
      await ref
          .read(storageServiceProvider)
          .setShuffleEnabled(state.isShuffle);
    } catch (_) {
      // Storage is optional in isolated tests.
    }
  }

  Future<void> cycleRepeatMode() async {
    await _handler.cycleRepeatMode();
    final mode = _handler.playbackState.value.repeatMode;
    state = state.copyWith(repeatMode: mode);
    try {
      await ref.read(storageServiceProvider).setRepeatMode(_repeatModeName(mode));
    } catch (_) {
      // Storage is optional in isolated tests.
    }
  }

  /// Restores the shuffle/repeat choices the user had when they last listened.
  Future<void> _restorePlaybackModes() async {
    try {
      final storage = ref.read(storageServiceProvider);
      final shuffle = storage.getShuffleEnabled();
      final repeat = _repeatModeFromName(storage.getRepeatMode());

      if (shuffle) {
        await _handler.setShuffleMode(AudioServiceShuffleMode.all);
      }
      if (repeat != AudioServiceRepeatMode.none) {
        await _handler.setRepeatMode(repeat);
      }
      if (_isDisposed) return;
      state = state.copyWith(isShuffle: shuffle, repeatMode: repeat);
    } catch (_) {
      // Fresh installs and isolated tests simply start with defaults.
    }
  }

  String _repeatModeName(AudioServiceRepeatMode mode) {
    switch (mode) {
      case AudioServiceRepeatMode.all:
        return 'all';
      case AudioServiceRepeatMode.one:
        return 'one';
      default:
        return 'none';
    }
  }

  AudioServiceRepeatMode _repeatModeFromName(String name) {
    switch (name) {
      case 'all':
        return AudioServiceRepeatMode.all;
      case 'one':
        return AudioServiceRepeatMode.one;
      default:
        return AudioServiceRepeatMode.none;
    }
  }

  /// When the last queued song starts, add songs with the same vibe so the
  /// music does not suddenly stop at the end of a short queue.
  Future<void> _continueQueueIfNeeded() async {
    final current = state.currentSong;
    if (current == null || _isDisposed) return;
    if (state.repeatMode != AudioServiceRepeatMode.none) return;
    if (state.currentIndex < state.queue.length - 1) return;
    if (_continuedForSongId == current.id || _continuingQueue) return;

    _continuingQueue = true;
    _continuedForSongId = current.id;
    try {
      await _topUpQueueWithSimilar(current, _playRequestId);
    } finally {
      _continuingQueue = false;
    }
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

  /// Sets the playback volume (0.0 = silent, 1.0 = full) and remembers it, so
  /// the level survives an app restart.
  Future<void> setVolume(double volume) async {
    final clamped = volume.clamp(0.0, 1.0);
    if (clamped > 0.01) _volumeBeforeMute = clamped;
    state = state.copyWith(volume: clamped);
    await _handler.setPlaybackVolume(clamped);
    try {
      await ref.read(storageServiceProvider).savePlaybackVolume(clamped);
    } catch (_) {
      // Allows isolated tests without a storage override.
    }
  }

  /// One step louder, up to full volume.
  Future<void> volumeUp({double step = 0.15}) =>
      setVolume(state.volume + step);

  /// One step quieter, down to silence.
  Future<void> volumeDown({double step = 0.15}) =>
      setVolume(state.volume - step);

  /// Silences the player, or brings the previous volume back. Returns true when
  /// the player is now muted.
  Future<bool> toggleMute() async {
    if (state.volume > 0.01) {
      _volumeBeforeMute = state.volume;
      await setVolume(0);
      return true;
    }
    await setVolume(_volumeBeforeMute <= 0.01 ? 0.7 : _volumeBeforeMute);
    return false;
  }

  double _savedPlaybackVolume() {
    try {
      return ref.read(storageServiceProvider).getPlaybackVolume();
    } catch (_) {
      return 1.0;
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

  /// Puts [song] straight after the track that is playing, keeping the rest of
  /// the queue untouched, so it plays next instead of starting a new queue.
  Future<void> playNextInQueue(SongModel song) async {
    final current = state.currentSong;
    if (current == null || state.queue.isEmpty) {
      await playTrack(song);
      return;
    }

    final newQueue = List<SongModel>.from(state.queue);
    final currentIdx = newQueue.indexWhere((s) => s.id == current.id);
    final baseIdx = currentIdx < 0 ? state.currentIndex : currentIdx;
    final insertAt = (baseIdx + 1).clamp(0, newQueue.length);

    // Tapping it twice should not leave two copies back to back.
    if (insertAt < newQueue.length && newQueue[insertAt].id == song.id) return;

    // A song already waiting further down moves up instead of duplicating.
    if (song.id != current.id) {
      newQueue.removeWhere((s) => s.id == song.id);
    }
    final afterCurrent = newQueue.indexWhere((s) => s.id == current.id);
    final safeInsert = ((afterCurrent < 0 ? 0 : afterCurrent) + 1)
        .clamp(0, newQueue.length);
    newQueue.insert(safeInsert, song);

    final newIndex = newQueue.indexWhere((s) => s.id == current.id);
    state = state.copyWith(
      queue: newQueue,
      currentIndex: newIndex < 0 ? 0 : newIndex,
    );

    _beginTrackConfirmation(current);
    await _handler.updateSongQueue(newQueue, newIndex: state.currentIndex);
  }

  /// Adds [song] to the end of the queue without disturbing the current song.
  Future<void> addToQueue(SongModel song) async {
    final current = state.currentSong;
    if (current == null || state.queue.isEmpty) {
      await playTrack(song);
      return;
    }
    if (state.queue.any((s) => s.id == song.id)) return;

    final newQueue = <SongModel>[...state.queue, song];
    state = state.copyWith(queue: newQueue);

    _beginTrackConfirmation(current);
    await _handler.updateSongQueue(newQueue, newIndex: state.currentIndex);
  }
}

final playerProvider = NotifierProvider<PlayerNotifier, PlayerState>(
  PlayerNotifier.new,
);
