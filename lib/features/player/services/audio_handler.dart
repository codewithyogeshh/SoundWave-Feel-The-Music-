import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:soundwave/features/online/services/online_music_service.dart';
import 'package:soundwave/features/player/models/song_model.dart';

Future<SoundWaveAudioHandler> initAudioService() async {
  return await AudioService.init(
    builder: () => SoundWaveAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.soundwave.app.channel.audio',
      androidNotificationChannelName: 'SoundWave Playback',
      androidNotificationChannelDescription: 'Music playback controls',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidShowNotificationBadge: true,
    ),
  );
}

class SoundWaveAudioHandler extends BaseAudioHandler with SeekHandler {
  static const Map<String, String> _httpHeaders = {
    'User-Agent': 'Mozilla/5.0 (Linux; Android 14)',
  };

  static SoundWaveAudioHandler? _activeInstance;

  /// Disposes any orphaned native just_audio ExoPlayer instances left behind
  /// by an interrupted startup or engine restart before creating a new handler.
  static Future<void> disposeOrphanedNativePlayers() async {
    try {
      await const MethodChannel('com.ryanheise.just_audio.methods')
          .invokeMethod<void>('disposeAllPlayers');
    } catch (_) {
      // Ignored in tests or platforms without a registered native channel.
    }
  }

  /// Resolves either a remote HTTPS URL or an offline cached local banner file
  /// URI so Android notifications & lockscreen controls render artwork offline.
  static Uri? resolveArtUri(String? artworkPath) {
    if (artworkPath == null) return null;
    final trimmed = artworkPath.trim();
    if (trimmed.isEmpty) return null;

    if (trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('content://')) {
      return Uri.tryParse(trimmed);
    }

    if (trimmed.startsWith('assets/') || trimmed.startsWith('asset://')) {
      return null;
    }

    if (!kIsWeb) {
      final filePath = trimmed.startsWith('file://')
          ? (Uri.tryParse(trimmed)?.toFilePath() ?? trimmed.substring(7))
          : trimmed;
      final file = File(filePath);
      if (file.existsSync()) {
        return Uri.file(file.path);
      }
    }
    return null;
  }

  // Disable just_audio's built-in interruption listeners so only SoundWaveAudioHandler
  // handles audio focus & becoming-noisy events without duplicate/blind resumes.
  // Platform equalizer effects are attached through the AudioPipeline at construction
  // (this just_audio version has no setAndroidAudioEffects). They default to disabled
  // and are enabled/configured by _restoreEqualizer().
  late final AndroidEqualizer _androidEqualizer;
  late final AndroidLoudnessEnhancer _loudnessEnhancer;
  late final AudioPlayer _player;
  List<SongModel> _currentQueue = [];
  int _currentIndex = 0;
  bool _isShuffle = false;
  List<int> _shuffledIndices = [];
  int _shufflePointer = 0;
  AudioServiceRepeatMode _repeatMode = AudioServiceRepeatMode.none;

  void _rebuildShuffleIndices() {
    if (_currentQueue.isEmpty) {
      _shuffledIndices = [];
      _shufflePointer = 0;
      return;
    }
    final indices = List<int>.generate(_currentQueue.length, (i) => i);
    indices.remove(_currentIndex);
    indices.shuffle();
    _shuffledIndices = [_currentIndex, ...indices];
    _shufflePointer = 0;
  }

  int _loadGeneration = 0;
  bool _isTransitioningTrack = false;

  // Persisted platform equalizer settings (applied to the audio engine).
  bool _lastEqEnabled = true;
  List<double> _lastEqGains = const [5.5, 4.0, -1.0, 2.0, 3.5];
  double _lastBassBoost = 0.65;
  double _lastVirtualizer = 0.30;
  bool _userPausedDuringLoad = false;
  bool _wasPlayingBeforeInterruption = false;
  double _volumeBeforeDuck = 1.0;
  bool _disposed = false;

  late final Future<void> _audioSessionReady;
  StreamSubscription<void>? _noisySub;
  StreamSubscription<AudioInterruptionEvent>? _interruptionSub;
  StreamSubscription<PlaybackEvent>? _playbackEventSub;
  StreamSubscription<ProcessingState>? _processingStateSub;

  SoundWaveAudioHandler() {
    final previous = _activeInstance;
    if (previous != null && !identical(previous, this)) {
      previous._disposePreviousInstance();
    }
    _activeInstance = this;
    _androidEqualizer = AndroidEqualizer();
    _loudnessEnhancer = AndroidLoudnessEnhancer();
    _player = AudioPlayer(
      handleInterruptions: false,
      audioPipeline: AudioPipeline(
        androidAudioEffects: [_androidEqualizer, _loudnessEnhancer],
      ),
    );
    _audioSessionReady = _initAudioSession();
    _listenToPlayerStreams();
  }

  AudioPlayer get player => _player;
  List<SongModel> get currentQueue => _currentQueue;
  int get currentIndex => _currentIndex;
  SongModel? get currentSong =>
      (_currentIndex >= 0 && _currentIndex < _currentQueue.length)
          ? _currentQueue[_currentIndex]
          : null;

  void _disposePreviousInstance() {
    if (_disposed) return;
    _disposed = true;
    ++_loadGeneration;
    _isTransitioningTrack = false;
    _wasPlayingBeforeInterruption = false;
    _noisySub?.cancel();
    _interruptionSub?.cancel();
    _playbackEventSub?.cancel();
    _processingStateSub?.cancel();
    unawaited(_player.dispose().catchError((_) {}));
  }

  Future<void> _initAudioSession() async {
    try {
      final session = await AudioSession.instance;
      if (_disposed) return;
      await session.configure(const AudioSessionConfiguration.music());
      if (_disposed) return;

      _noisySub = session.becomingNoisyEventStream.listen((_) {
        if (_disposed) return;
        _wasPlayingBeforeInterruption = false;
        pause();
      });

      _interruptionSub = session.interruptionEventStream.listen((event) {
        if (_disposed) return;
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.duck:
              _volumeBeforeDuck = _player.volume;
              _player.setVolume((_volumeBeforeDuck * 0.4).clamp(0.1, 1.0));
              _wasPlayingBeforeInterruption = false;
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              if (_player.playing) {
                _wasPlayingBeforeInterruption = true;
                pause();
              } else {
                _wasPlayingBeforeInterruption = false;
              }
              break;
          }
        } else {
          switch (event.type) {
            case AudioInterruptionType.duck:
              _player.setVolume(_volumeBeforeDuck);
              _wasPlayingBeforeInterruption = false;
              break;
            case AudioInterruptionType.pause:
              if (_wasPlayingBeforeInterruption) {
                _wasPlayingBeforeInterruption = false;
                play();
              }
              break;
            case AudioInterruptionType.unknown:
              _wasPlayingBeforeInterruption = false;
              break;
          }
        }
      });
    } catch (e) {
      debugPrint('AudioSession init error: $e');
    }
  }

  void _listenToPlayerStreams() {
    // Player state -> PlaybackState stream for system notification
    _playbackEventSub = _player.playbackEventStream.listen((PlaybackEvent event) {
      if (_disposed) return;
      final isPlaying = _player.playing;
      playbackState.add(
        playbackState.value.copyWith(
          controls: [
            MediaControl.skipToPrevious,
            if (isPlaying) MediaControl.pause else MediaControl.play,
            MediaControl.skipToNext,
            MediaControl.stop,
          ],
          systemActions: const {
            MediaAction.seek,
            MediaAction.seekForward,
            MediaAction.seekBackward,
          },
          androidCompactActionIndices: const [0, 1, 2],
          processingState: const {
            ProcessingState.idle: AudioProcessingState.idle,
            ProcessingState.loading: AudioProcessingState.loading,
            ProcessingState.buffering: AudioProcessingState.buffering,
            ProcessingState.ready: AudioProcessingState.ready,
            ProcessingState.completed: AudioProcessingState.completed,
          }[_player.processingState]!,
          playing: isPlaying,
          updatePosition: _player.position,
          bufferedPosition: _player.bufferedPosition,
          speed: _player.speed,
          queueIndex: _currentIndex,
        ),
      );
    });

    // Auto next on song completion & dynamic equalizer attachment
    _processingStateSub =
        _player.processingStateStream.distinct().listen((state) {
      if (_disposed || _isTransitioningTrack) return;
      if (state == ProcessingState.ready) {
        _restoreEqualizer();
      }
      if (state == ProcessingState.completed) {
        if (_repeatMode == AudioServiceRepeatMode.one) {
          seek(Duration.zero);
          play();
        } else if (hasNext || _isShuffle || _repeatMode == AudioServiceRepeatMode.all) {
          skipToNext();
        } else {
          pause();
          seek(Duration.zero);
        }
      }
    });
  }

  bool get hasNext => _currentIndex < _currentQueue.length - 1;
  bool get hasPrevious => _currentIndex > 0;

  MediaItem _toMediaItem(SongModel s) {
    final artUri = resolveArtUri(s.artworkPath);
    return MediaItem(
      id: s.id,
      title: s.title,
      artist: s.artist,
      album: s.album,
      duration: s.duration,
      artUri: artUri,
      artHeaders: (artUri != null &&
              (artUri.scheme == 'http' || artUri.scheme == 'https'))
          ? _httpHeaders
          : null,
    );
  }

  Future<void> _safePausePlayer() async {
    try {
      await _player.pause();
    } catch (_) {}
  }

  Future<void> loadQueue(List<SongModel> songs, {int initialIndex = 0}) async {
    if (songs.isEmpty || _disposed) return;

    final int gen = ++_loadGeneration;
    _isTransitioningTrack = true;
    _userPausedDuringLoad = false;
    _wasPlayingBeforeInterruption = false;

    _currentQueue = List.from(songs);
    _currentIndex = initialIndex.clamp(0, _currentQueue.length - 1);
    if (_isShuffle) {
      _rebuildShuffleIndices();
    }

    // Silence any currently playing audio immediately before async resolution/loading
    await _safePausePlayer();
    if (gen != _loadGeneration || _disposed) return;

    // Update queue media items immediately so lockscreen/notification reflect the new track
    final mediaItems = _currentQueue.map(_toMediaItem).toList();
    queue.add(mediaItems);

    await _loadTrackInternal(
      _currentQueue[_currentIndex],
      generation: gen,
      autoPlay: true,
    );
  }

  Future<void> _loadTrackInternal(
    SongModel song, {
    required int generation,
    bool autoPlay = false,
  }) async {
    if (generation != _loadGeneration || _disposed) return;

    SongModel track = song;
    final provisionalMediaItem = _toMediaItem(track);
    mediaItem.add(provisionalMediaItem);

    // Reset notification position/index right away when switching tracks
    playbackState.add(
      playbackState.value.copyWith(
        updatePosition: Duration.zero,
        bufferedPosition: Duration.zero,
        queueIndex: _currentIndex,
        processingState: AudioProcessingState.loading,
      ),
    );

    try {
      // Ensure AudioSession attributes are configured BEFORE first ExoPlayer activation
      await _audioSessionReady;
      if (generation != _loadGeneration || _disposed) return;

      // Resolve full-length 320kbps network track only when needed and cancelable
      if (track.sourceType == AudioSourceType.network &&
          track.id.startsWith('online_') &&
          (track.audioPath.isEmpty ||
              track.audioPath.contains('jiotunepreview.jio.com'))) {
        final resolved = await OnlineMusicService.resolveFullTrack(track);
        if (generation != _loadGeneration || _disposed) return;
        if (resolved != null) {
          track = resolved;
          if (_currentIndex >= 0 && _currentIndex < _currentQueue.length) {
            _currentQueue[_currentIndex] = track;
          }
        }
      }

      if (generation != _loadGeneration || _disposed) return;

      final finalMediaItem = _toMediaItem(track);
      mediaItem.add(finalMediaItem);

      final AudioSource source;
      if (track.sourceType == AudioSourceType.asset) {
        source = AudioSource.asset(track.audioPath);
      } else if (track.sourceType == AudioSourceType.file) {
        if (!kIsWeb && !File(track.audioPath).existsSync()) {
          debugPrint('Offline audio file missing: ${track.audioPath}');
          return;
        }
        source = AudioSource.file(track.audioPath);
      } else {
        if (track.audioPath.isEmpty) return;
        source = AudioSource.uri(
          Uri.parse(track.audioPath),
          headers: _httpHeaders,
          tag: finalMediaItem,
        );
      }

      // just_audio_web caches the loaded audio source tree by message id and
      // reuses the previous HTMLAudioElement URI. Every setAudioSource call
      // shares that same cached root, so on web a newly selected song was
      // silently ignored and the previous track kept playing. Stopping the
      // player disposes the web platform player (and its cache) so the next
      // source really loads.
      if (kIsWeb) {
        await _player.stop();
        if (generation != _loadGeneration || _disposed) return;
      }

      await _player.setAudioSource(source);
      if (generation != _loadGeneration || _disposed) return;

      // Re-apply the persisted platform equalizer to the freshly loaded source.
      await _restoreEqualizer();
      if (generation != _loadGeneration || _disposed) return;

      _isTransitioningTrack = false;

      if (autoPlay && !_userPausedDuringLoad) {
        unawaited(
          _player.play().catchError((Object e) {
            if (generation == _loadGeneration && !_disposed) {
              debugPrint('Error starting playback: $e');
            }
          }),
        );
      }
    } on PlayerInterruptedException {
      // Expected whenever user skips rapidly to a newer song.
    } catch (e) {
      if (generation == _loadGeneration && !_disposed) {
        debugPrint('Error loading audio track: $e');
      }
    } finally {
      if (generation == _loadGeneration) {
        _isTransitioningTrack = false;
      }
    }
  }

  @override
  Future<void> play() async {
    if (_disposed) return;
    _userPausedDuringLoad = false;
    await _audioSessionReady;
    if (_disposed || _userPausedDuringLoad) return;
    unawaited(
      _player.play().catchError((Object e) {
        if (!_disposed) {
          debugPrint('Play error: $e');
        }
      }),
    );
  }

  @override
  Future<void> pause() async {
    if (_disposed) return;
    _wasPlayingBeforeInterruption = false;
    _userPausedDuringLoad = true;
    try {
      await _player.pause();
    } catch (e) {
      debugPrint('Pause error: $e');
    }
  }

  @override
  Future<void> stop() async {
    ++_loadGeneration;
    _isTransitioningTrack = false;
    _wasPlayingBeforeInterruption = false;
    _userPausedDuringLoad = true;
    try {
      await _player.stop();
    } catch (e) {
      debugPrint('Stop error: $e');
    }
    await super.stop();
  }

  @override
  Future<void> onNotificationDeleted() => stop();

  @override
  Future<void> onTaskRemoved() async {
    if (!_player.playing) {
      await stop();
    }
    await super.onTaskRemoved();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (_currentQueue.isEmpty || _disposed) return;
    if (_isShuffle) {
      if (_shuffledIndices.length != _currentQueue.length) {
        _rebuildShuffleIndices();
      }
      _shufflePointer = (_shufflePointer + 1) % _shuffledIndices.length;
      final nextIndex = _shuffledIndices[_shufflePointer];
      await skipToQueueItem(nextIndex);
    } else if (hasNext) {
      await skipToQueueItem(_currentIndex + 1);
    } else if (_repeatMode == AudioServiceRepeatMode.all) {
      await skipToQueueItem(0);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_currentQueue.isEmpty || _disposed) return;
    if (_player.position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }
    if (_isShuffle) {
      if (_shuffledIndices.length != _currentQueue.length) {
        _rebuildShuffleIndices();
      }
      _shufflePointer = (_shufflePointer - 1 + _shuffledIndices.length) % _shuffledIndices.length;
      final prevIndex = _shuffledIndices[_shufflePointer];
      await skipToQueueItem(prevIndex);
    } else if (hasPrevious) {
      await skipToQueueItem(_currentIndex - 1);
    } else if (_repeatMode == AudioServiceRepeatMode.all) {
      await skipToQueueItem(_currentQueue.length - 1);
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _currentQueue.length || _disposed) return;
    final int gen = ++_loadGeneration;
    _isTransitioningTrack = true;
    _userPausedDuringLoad = false;
    _wasPlayingBeforeInterruption = false;
    _currentIndex = index;

    await _safePausePlayer();
    if (gen != _loadGeneration || _disposed) return;

    await _loadTrackInternal(
      _currentQueue[_currentIndex],
      generation: gen,
      autoPlay: true,
    );
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    _repeatMode = repeatMode;
    playbackState.add(playbackState.value.copyWith(repeatMode: repeatMode));
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    _isShuffle = shuffleMode == AudioServiceShuffleMode.all;
    if (_isShuffle) {
      _rebuildShuffleIndices();
    }
    playbackState.add(playbackState.value.copyWith(shuffleMode: shuffleMode));
  }

  Future<void> toggleShuffle() async {
    final next = !_isShuffle;
    await setShuffleMode(
      next ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none,
    );
  }

  Future<void> cycleRepeatMode() async {
    AudioServiceRepeatMode nextMode;
    switch (_repeatMode) {
      case AudioServiceRepeatMode.none:
        nextMode = AudioServiceRepeatMode.all;
        break;
      case AudioServiceRepeatMode.all:
        nextMode = AudioServiceRepeatMode.one;
        break;
      case AudioServiceRepeatMode.one:
      default:
        nextMode = AudioServiceRepeatMode.none;
        break;
    }
    await setRepeatMode(nextMode);
  }

  Future<void> setPlaybackSpeed(double speed) async {
    if (_disposed) return;
    final clamped = speed.clamp(0.5, 2.5);
    await _player.setSpeed(clamped);
    playbackState.add(playbackState.value.copyWith(speed: clamped));
  }

  Future<void> setPlaybackVolume(double volume) async {
    if (_disposed) return;
    await _player.setVolume(volume.clamp(0.0, 1.0));
  }

  Future<void> updateSongQueue(List<SongModel> newQueue, {int? newIndex}) async {
    if (_disposed) return;
    _currentQueue = List.from(newQueue);
    if (newIndex != null) {
      _currentIndex = newIndex.clamp(0, _currentQueue.isNotEmpty ? _currentQueue.length - 1 : 0);
    }
    if (_isShuffle) {
      _rebuildShuffleIndices();
    }
    final mediaItems = _currentQueue.map(_toMediaItem).toList();
    queue.add(mediaItems);
    playbackState.add(playbackState.value.copyWith(queueIndex: _currentIndex));
  }

  Future<void> removeFromQueue(int index) async {
    if (_disposed || index < 0 || index >= _currentQueue.length) return;
    if (_currentQueue.length <= 1) return;

    final wasPlayingThis = index == _currentIndex;
    _currentQueue.removeAt(index);
    if (index < _currentIndex) {
      _currentIndex--;
    } else if (_currentIndex >= _currentQueue.length) {
      _currentIndex = _currentQueue.length - 1;
    }

    final mediaItems = _currentQueue.map(_toMediaItem).toList();
    queue.add(mediaItems);
    playbackState.add(playbackState.value.copyWith(queueIndex: _currentIndex));

    if (wasPlayingThis && _currentQueue.isNotEmpty) {
      await skipToQueueItem(_currentIndex);
    }
  }

  Future<void> clearUpcomingQueue() async {
    if (_disposed || _currentQueue.isEmpty) return;
    final current = currentSong;
    if (current == null) return;
    _currentQueue = [current];
    _currentIndex = 0;
    final mediaItems = _currentQueue.map(_toMediaItem).toList();
    queue.add(mediaItems);
    playbackState.add(playbackState.value.copyWith(queueIndex: 0));
  }

  // ---------------------------------------------------------------------------
  // Platform Equalizer Engine
  // ---------------------------------------------------------------------------

  /// Updates the persisted equalizer settings and applies them to the audio
  /// engine immediately (Android: AndroidEqualizer + BassBoost + Virtualizer).
  Future<void> updateEqualizer({
    bool? enabled,
    List<double>? bandGains,
    double? bassBoost,
    double? virtualizer,
  }) async {
    if (enabled != null) _lastEqEnabled = enabled;
    if (bandGains != null && bandGains.length == 5) {
      _lastEqGains = List<double>.from(bandGains);
    }
    if (bassBoost != null) _lastBassBoost = bassBoost;
    if (virtualizer != null) _lastVirtualizer = virtualizer;
    await _restoreEqualizer();
  }

  bool get isEqualizerEnabled => _lastEqEnabled;

  /// Applies the current stored equalizer to the live player. On non-Android
  /// platforms (or when the platform effect is unsupported) it is a no-op.
  Future<void> _restoreEqualizer() async {
    if (_disposed || kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android) return;

    try {
      // Effects are part of the player's AudioPipeline and default to disabled.
      // Enable both so they are heard; if the user turned the EQ off, bypass them.
      await _androidEqualizer.setEnabled(_lastEqEnabled);
      await _loudnessEnhancer.setEnabled(_lastEqEnabled);
      if (!_lastEqEnabled) return;

      // Effective band gains: preset curve + dynamic bass-boost emphasis on the low bands (60Hz & 230Hz)
      final gains = List<double>.from(_lastEqGains);
      gains[0] = (gains[0] + _lastBassBoost * 5.0).clamp(-12.0, 12.0);
      gains[1] = (gains[1] + _lastBassBoost * 3.0).clamp(-12.0, 12.0);

      // Timeout guarded in case parameters completer is waiting on native ExoPlayer audio session
      final params = await _androidEqualizer.parameters.timeout(
        const Duration(milliseconds: 400),
      );
      final count = params.bands.length < gains.length ? params.bands.length : gains.length;
      for (int i = 0; i < count; i++) {
        await params.bands[i].setGain(gains[i]);
      }

      // Virtualizer -> dynamic presence and loudness boost
      await _loudnessEnhancer.setTargetGain((_lastVirtualizer * 3.5).clamp(0.0, 5.0));
    } catch (e) {
      debugPrint('Equalizer apply status: $e');
    }
  }
}
