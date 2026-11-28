import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:soundwave/app/presentation/main_shell.dart';
import 'package:soundwave/core/widgets/premium_transitions.dart';
import 'package:soundwave/features/library/presentation/playlist_detail_screen.dart';
import 'package:soundwave/features/online/presentation/downloads_screen.dart';
import 'package:soundwave/features/online/presentation/storage_manager_screen.dart';
import 'package:soundwave/features/player/presentation/equalizer_screen.dart';
import 'package:soundwave/features/player/presentation/now_playing_screen.dart';

/// Root navigator key, so app-level flows such as the "Update available"
/// prompt can open a dialog without a widget context.
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Every pushed page shares one transition: a fade-through that lifts a few
/// pixels and settles from 98.5% scale, so screens change without a hard cut.
CustomTransitionPage<T> _premiumPage<T>(
  GoRouterState state,
  Widget child, {
  Offset begin = const Offset(0, 0.03),
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    transitionDuration: premiumTransitionDuration,
    reverseTransitionDuration: premiumReverseTransitionDuration,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        premiumPageTransition(
          animation,
          secondaryAnimation,
          child,
          begin: begin,
        ),
  );
}

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
      pageBuilder: (context, state) => _premiumPage(
        state,
        const NowPlayingScreen(),
        begin: const Offset(0, 0.08),
      ),
    ),
    GoRoute(
      path: '/equalizer',
      pageBuilder: (context, state) =>
          _premiumPage(state, const EqualizerScreen()),
    ),
    GoRoute(
      path: '/downloads',
      pageBuilder: (context, state) => _premiumPage(
        state,
        const DownloadsScreen(),
        begin: const Offset(0, 0.06),
      ),
    ),
    GoRoute(
      path: '/storage',
      pageBuilder: (context, state) =>
          _premiumPage(state, const StorageManagerScreen()),
    ),
    GoRoute(
      path: '/playlist/:id',
      pageBuilder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return _premiumPage(state, PlaylistDetailScreen(playlistId: id));
      },
    ),
  ],
);
