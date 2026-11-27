import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: GlassCard(
          borderRadius: 30,
          blur: 26,
          color: activeTheme.secondaryBackground.withValues(alpha: 0.92),
          // Lifted, saturated wash so the bar reads like a home-screen widget
          // instead of blending into the page behind it.
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              activeTheme.primaryAccent.withValues(alpha: 0.66),
              activeTheme.highlightColor.withValues(alpha: 0.4),
              activeTheme.primaryAccent.withValues(alpha: 0.3),
            ],
            stops: const [0.0, 0.62, 1.0],
          ),
          borderColor: activeTheme.highlightColor.withValues(alpha: 0.7),
          shadows: [
            BoxShadow(
              color: activeTheme.primaryAccent.withValues(alpha: 0.45),
              blurRadius: 30,
              spreadRadius: 1,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.34),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
          padding: const EdgeInsets.only(left: 14, right: 12, top: 13, bottom: 12),
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
                  // Round cover wrapped in a glowing gradient ring, like the
                  // launcher widget.
                  Hero(
                    tag: 'album_art_${song.id}',
                    child: Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.95),
                            activeTheme.highlightColor,
                            activeTheme.primaryAccent,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: activeTheme.primaryAccent.withValues(alpha: 0.55),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: activeTheme.secondaryBackground,
                        ),
                        child: AlbumArtwork(
                          size: 64,
                          borderRadius: 32,
                          artworkUrl: song.artworkPath,
                          albumId: song.albumId,
                          songId: song.rawId,
                          songTitle: song.title,
                          songArtist: song.artist,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
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
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.35,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                song.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.artistName.copyWith(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.9),
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
                        color: isFav
                            ? activeTheme.highlightColor
                            : Colors.white.withValues(alpha: 0.72),
                        size: 24,
                      ),
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      ref.read(libraryProvider.notifier).toggleFavorite(song);
                    },
                  ),
                  // Play / Pause Circle with morph animation
                  GradientButton.circle(
                    size: 54,
                    gradient: activeTheme.accentGradient,
                    glowColor: activeTheme.primaryAccent,
                    onPressed: () {
                      ref.read(playerProvider.notifier).togglePlayPause();
                    },
                    // Play ⇄ pause: the new glyph turns in with a small
                    // overshoot, the old one turns out — so a tap reads as one
                    // movement instead of two icons swapping.
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        final curved = CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutBack,
                        );
                        return FadeTransition(
                          opacity: animation,
                          child: RotationTransition(
                            turns: Tween<double>(begin: -0.14, end: 0.0)
                                .animate(curved),
                            child: ScaleTransition(
                              scale: Tween<double>(begin: 0.6, end: 1.0)
                                  .animate(curved),
                              child: child,
                            ),
                          ),
                        );
                      },
                      child: Icon(
                        playerState.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        key: ValueKey<bool>(playerState.isPlaying),
                        color: activeTheme.onAccentGradient,
                        size: 30,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Gradient progress bar, matching the widget's coloured track
              SizedBox(
                height: 5,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(
                        color: Colors.white.withValues(alpha: 0.2),
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
                                  Colors.white.withValues(alpha: 0.95),
                                  activeTheme.highlightColor,
                                  activeTheme.primaryAccent,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: activeTheme.highlightColor.withValues(alpha: 0.6),
                                  blurRadius: 8,
                                ),
                              ],
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
