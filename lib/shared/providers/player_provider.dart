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

      state = state.copyWith(
        isPlaying: playbackState.playing,
        isShuffle: playbackState.shuffleMode == AudioServiceShuffleMode.all,
        repeatMode: playbackState.repeatMode,
        currentIndex: validIdx,
        currentSong: syncedSong,
      );
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
    if (requestId == _playRequestId && !_isDisposed && _handler.currentSong != null) {
      state = state.copyWith(
        currentSong: _handler.currentSong,
        currentIndex: _handler.currentIndex,
      );
    }
  }

  Future<void> skipToPrevious() async {
    final int requestId = ++_playRequestId;
    await _handler.skipToPrevious();
    if (requestId == _playRequestId && !_isDisposed && _handler.currentSong != null) {
      state = state.copyWith(
        currentSong: _handler.currentSong,
        currentIndex: _handler.currentIndex,
      );
    }
  }

  Future<void> toggleShuffle() async {
    await _handler.toggleShuffle();
    state = state.copyWith(isShuffle: !state.isShuffle);
  }

  Future<void> cycleRepeatMode() async {
    await _handler.cycleRepeatMode();
  }
}

final playerProvider =
    NotifierProvider<PlayerNotifier, PlayerState>(PlayerNotifier.new);
