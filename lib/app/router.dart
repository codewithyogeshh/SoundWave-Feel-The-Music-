import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:soundwave/app/presentation/main_shell.dart';
import 'package:soundwave/features/library/presentation/playlist_detail_screen.dart';
import 'package:soundwave/features/online/presentation/downloads_screen.dart';
import 'package:soundwave/features/player/presentation/equalizer_screen.dart';
import 'package:soundwave/features/player/presentation/now_playing_screen.dart';

/// Root navigator key, so app-level flows such as the "Update available"
/// prompt can open a dialog without a widget context.
final rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const MainShell(),
    ),
    GoRoute(
      path: '/now-playing',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const NowPlayingScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(curved),
            child: FadeTransition(opacity: curved, child: child),
          );
        },
      ),
    ),
    GoRoute(
      path: '/equalizer',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const EqualizerScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(curved),
            child: FadeTransition(opacity: curved, child: child),
          );
        },
      ),
    ),
    GoRoute(
      path: '/downloads',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const DownloadsScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(curved),
            child: FadeTransition(opacity: curved, child: child),
          );
        },
      ),
    ),
    GoRoute(
      path: '/playlist/:id',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return PlaylistDetailScreen(playlistId: id);
      },
    ),
  ],
);
