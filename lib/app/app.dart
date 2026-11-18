import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundwave/app/router.dart';
import 'package:soundwave/app/theme/app_theme.dart';
import 'package:soundwave/shared/providers/theme_provider.dart';

class SoundWaveApp extends ConsumerWidget {
  const SoundWaveApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

