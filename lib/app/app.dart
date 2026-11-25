import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundwave/app/router.dart';
import 'package:soundwave/app/theme/app_theme.dart';
import 'package:soundwave/features/update/presentation/update_available_dialog.dart';
import 'package:soundwave/features/update/services/update_service.dart';
import 'package:soundwave/features/widget/services/home_widget_service.dart';
import 'package:soundwave/shared/providers/player_provider.dart';
import 'package:soundwave/shared/providers/theme_provider.dart';

class SoundWaveApp extends ConsumerStatefulWidget {
  const SoundWaveApp({super.key});

  @override
  ConsumerState<SoundWaveApp> createState() => _SoundWaveAppState();
}

class _SoundWaveAppState extends ConsumerState<SoundWaveApp> {
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    // Home screen widget: receive play/pause, next and previous taps.
    HomeWidgetService.listen(_handleWidgetAction);
    // Paint the widget with whatever is already loaded (e.g. the resumed song).
    Future.microtask(_syncHomeWidget);
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
        player.skipToNext();
        break;
      case 'prev':
        player.skipToPrevious();
        break;
    }
  }

  void _syncHomeWidget() {
    if (!mounted) return;
    final playerState = ref.read(playerProvider);
    final song = playerState.currentSong;
    HomeWidgetService.update(
      title: song?.title ?? 'SoundWave',
      artist: song?.artist ?? 'Tap to open',
      isPlaying: playerState.isPlaying,
    );
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
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
      final song = next.currentSong;
      HomeWidgetService.update(
        title: song?.title ?? 'SoundWave',
        artist: song?.artist ?? 'Tap to open',
        isPlaying: next.isPlaying,
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
