import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundwave/app/router.dart';
import 'package:soundwave/app/theme/app_theme.dart';
import 'package:soundwave/features/update/presentation/update_available_dialog.dart';
import 'package:soundwave/features/update/services/update_service.dart';
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
    // Delay the check so it never collides with the first-launch permission
    // sheet and never slows down startup.
    _updateTimer = Timer(const Duration(seconds: 3), _checkForUpdate);
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
