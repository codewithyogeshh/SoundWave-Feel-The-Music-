import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:soundwave/app/presentation/main_shell.dart';
import 'package:soundwave/features/library/presentation/playlist_detail_screen.dart';
import 'package:soundwave/features/player/presentation/now_playing_screen.dart';

final appRouter = GoRouter(
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
      path: '/playlist/:id',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return PlaylistDetailScreen(playlistId: id);
      },
    ),
  ],
);

