import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundwave/app/theme/app_colors.dart';
import 'package:soundwave/app/theme/text_styles.dart';
import 'package:soundwave/core/widgets/album_artwork.dart';
import 'package:soundwave/core/widgets/animated_equalizer.dart';
import 'package:soundwave/core/widgets/glass_card.dart';
import 'package:soundwave/core/widgets/gradient_button.dart';
import 'package:soundwave/features/player/presentation/now_playing_screen.dart';
import 'package:soundwave/shared/providers/library_provider.dart';
import 'package:soundwave/shared/providers/player_provider.dart';
import 'package:soundwave/shared/providers/theme_provider.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final activeTheme = ref.watch(themeProvider);
    final song = playerState.currentSong;

    if (song == null) {
      return const SizedBox.shrink();
    }

    final durationMs = playerState.duration.inMilliseconds;
    final positionMs = playerState.position.inMilliseconds;
    final progress = (durationMs > 0)
        ? (positionMs / durationMs).clamp(0.0, 1.0)
        : 0.0;

    final isFav = ref.watch(libraryProvider).isFavorite(song.id);

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity < -220) {
          HapticFeedback.mediumImpact();
          ref.read(playerProvider.notifier).skipToNext();
        } else if (velocity > 220) {
          HapticFeedback.mediumImpact();
          ref.read(playerProvider.notifier).skipToPrevious();
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: GlassCard(
          borderRadius: 24,
          blur: 24,
          color: activeTheme.secondaryBackground.withValues(alpha: 0.9),
          // Lifted, saturated wash so the bar reads like the home-screen widget
          // instead of blending into the page behind it.
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              activeTheme.primaryAccent.withValues(alpha: 0.42),
              activeTheme.highlightColor.withValues(alpha: 0.22),
            ],
          ),
          borderColor: activeTheme.highlightColor.withValues(alpha: 0.5),
          shadows: [
            BoxShadow(
              color: activeTheme.primaryAccent.withValues(alpha: 0.3),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          padding: const EdgeInsets.only(left: 12, right: 12, top: 11, bottom: 10),
          onTap: () {
            Navigator.of(context).push(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    const NowPlayingScreen(),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                  if (MediaQuery.disableAnimationsOf(context)) {
                    return FadeTransition(opacity: animation, child: child);
                  }
                  final curved = CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  );
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 1),
                      end: Offset.zero,
                    ).animate(curved),
                    child: FadeTransition(
                      opacity: curved,
                      child: child,
                    ),
                  );
                },
              ),
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  // Round cover with a glowing ring, like the launcher widget.
                  Hero(
                    tag: 'album_art_${song.id}',
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: activeTheme.highlightColor.withValues(alpha: 0.7),
                          width: 1.6,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: activeTheme.primaryAccent.withValues(alpha: 0.4),
                            blurRadius: 18,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: AlbumArtwork(
                        size: 54,
                        borderRadius: 27,
                        artworkUrl: song.artworkPath,
                        albumId: song.albumId,
                        songId: song.rawId,
                        songTitle: song.title,
                        songArtist: song.artist,
                      ),
                    ),
                  ),
                  const SizedBox(width: 13),
                  // Song Title & Artist
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.songTitle.copyWith(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                song.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.artistName.copyWith(
                                  fontSize: 13,
                                  color: Colors.white.withValues(alpha: 0.82),
                                ),
                              ),
                            ),
                            if (playerState.isPlaying) ...[
                              const SizedBox(width: 8),
                              AnimatedEqualizer(
                                isPlaying: true,
                                size: 12,
                                color: activeTheme.primaryAccent,
                                barCount: 3,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Favorite Heart button with reactive state & tactile feedback
                  IconButton(
                    tooltip: isFav ? 'Remove from favorites' : 'Add to favorites',
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      transitionBuilder: (child, animation) => ScaleTransition(
                        scale: Tween<double>(begin: 0.78, end: 1.0).animate(
                          CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
                        ),
                        child: child,
                      ),
                      child: Icon(
                        isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        key: ValueKey<bool>(isFav),
                        color: isFav ? activeTheme.highlightColor : AppColors.textMuted,
                        size: 22,
                      ),
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      ref.read(libraryProvider.notifier).toggleFavorite(song);
                    },
                  ),
                  // Play / Pause Circle with morph animation
                  GradientButton.circle(
                    size: 46,
                    gradient: activeTheme.accentGradient,
                    glowColor: activeTheme.primaryAccent,
                    onPressed: () {
                      ref.read(playerProvider.notifier).togglePlayPause();
                    },
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      transitionBuilder: (child, animation) => ScaleTransition(
                        scale: Tween<double>(begin: 0.85, end: 1.0).animate(animation),
                        child: FadeTransition(opacity: animation, child: child),
                      ),
                      child: Icon(
                        playerState.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        key: ValueKey<bool>(playerState.isPlaying),
                        color: activeTheme.onAccentGradient,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Gradient progress bar, matching the widget's coloured track
              SizedBox(
                height: 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: progress,
                          heightFactor: 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  activeTheme.primaryAccent,
                                  activeTheme.highlightColor,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
