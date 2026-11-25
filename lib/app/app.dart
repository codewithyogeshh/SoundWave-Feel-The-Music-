import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundwave/app/router.dart';
import 'package:soundwave/app/theme/app_theme.dart';
import 'package:soundwave/features/update/presentation/update_available_dialog.dart';
import 'package:soundwave/features/update/services/update_service.dart';
import 'package:soundwave/features/widget/services/home_widget_service.dart';
import 'package:soundwave/shared/providers/library_provider.dart';
import 'package:soundwave/shared/providers/player_provider.dart';
import 'package:soundwave/shared/providers/theme_provider.dart';

class SoundWaveApp extends ConsumerStatefulWidget {
  const SoundWaveApp({super.key});

  @override
  ConsumerState<SoundWaveApp> createState() => _SoundWaveAppState();
}

class _SoundWaveAppState extends ConsumerState<SoundWaveApp> {
  Timer? _updateTimer;
  Timer? _widgetProgressTimer;

  @override
  void initState() {
    super.initState();
    // Home screen widget: receive play/pause, next and previous taps.
    HomeWidgetService.listen(_handleWidgetAction);
    // Paint the widget with whatever is already loaded (e.g. the resumed song).
    Future.microtask(_syncHomeWidget);
    // A button tapped while the app was closed is replayed once we are up.
    Future.microtask(_runPendingWidgetAction);
    // Keep the widget progress bar moving while music plays.
    _widgetProgressTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      if (ref.read(playerProvider).isPlaying) _syncHomeWidget();
    });
    // Delay the check so it never collides with the first-launch permission
    // sheet and never slows down startup.
    _updateTimer = Timer(const Duration(seconds: 3), _checkForUpdate);
  }

  void _handleWidgetAction(String action) {
    final player = ref.read(playerProvider.notifier);
    switch (action) {
      case 'playPause':
        player.togglePlayPause();
        break;
      case 'next':
      case 'prev':
        if (_hasActivePlayback()) {
          if (action == 'next') {
            player.skipToNext();
          } else {
            player.skipToPrevious();
          }
        } else {
          // Nothing is loaded yet, so a skip starts the first song instead of
          // doing nothing at all.
          final playerState = ref.read(playerProvider);
          final song = playerState.currentSong;
          if (song != null) {
            player.playTrack(song, queue: playerState.queue);
          }
        }
        break;
    }
  }

  Future<void> _runPendingWidgetAction() async {
    final action = await HomeWidgetService.consumePendingAction();
    if (action == null || !mounted) return;
    // Let the restored session settle so the tap acts on the right song.
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    _handleWidgetAction(action);
  }

  /// True when a real song is loaded or the user already started playback.
  bool _hasActivePlayback() {
    final playerState = ref.read(playerProvider);
    if (playerState.isPlaying || playerState.position > Duration.zero) {
      return true;
    }
    final session = ref.read(storageServiceProvider).getPlaybackSession();
    return session != null && session.queue.isNotEmpty;
  }

  /// Title and artist for the widget. Falls back to the last saved session so
  /// the demo track the app preloads for browsing never shows up as "current".
  ({String title, String artist, String? artwork}) _widgetLabels() {
    final playerState = ref.read(playerProvider);
    var song = playerState.currentSong;
    if (!playerState.isPlaying && playerState.position <= Duration.zero) {
      final session = ref.read(storageServiceProvider).getPlaybackSession();
      if (session != null && session.queue.isNotEmpty) {
        song = session.queue[session.index.clamp(0, session.queue.length - 1)];
      } else {
        song = null;
      }
    }
    return (
      title: song?.title ?? 'SoundWave',
      artist: song?.artist ?? 'Tap to open',
      artwork: song?.artworkPath,
    );
  }

  void _syncHomeWidget() {
    if (!mounted) return;
    final labels = _widgetLabels();
    final playerState = ref.read(playerProvider);
    HomeWidgetService.update(
      title: labels.title,
      artist: labels.artist,
      artwork: labels.artwork,
      isPlaying: playerState.isPlaying,
      position: playerState.position,
      duration: playerState.duration,
    );
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _widgetProgressTimer?.cancel();
    super.dispose();
  }

  /// Asks GitHub for a newer release a few seconds after launch so a fresh APK
  /// is never hunted for manually. Stays silent when offline.
  Future<void> _checkForUpdate() async {
    if (!mounted) return;

    final update = await UpdateService.check();
    if (update == null || !mounted) return;

    final dialogContext = rootNavigatorKey.currentContext;
    if (dialogContext == null) return;

    await UpdateAvailableDialog.show(dialogContext, update);
  }

  @override
  Widget build(BuildContext context) {
    final activeTheme = ref.watch(themeProvider);

    // Keep the home screen widget in step with the player.
    ref.listen<PlayerState>(playerProvider, (previous, next) {
      if (previous?.currentSong?.id == next.currentSong?.id &&
          previous?.isPlaying == next.isPlaying) {
        return;
      }
      final labels = _widgetLabels();
      HomeWidgetService.update(
        title: labels.title,
        artist: labels.artist,
        artwork: labels.artwork,
        isPlaying: next.isPlaying,
        position: next.position,
        duration: next.duration,
      );
    });

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    return MaterialApp.router(
      title: 'SoundWave',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.fromType(activeTheme),
      routerConfig: appRouter,
    );
  }
}
