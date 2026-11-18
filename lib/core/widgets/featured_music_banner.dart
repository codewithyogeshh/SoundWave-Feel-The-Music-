import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundwave/app/theme/app_colors.dart';
import 'package:soundwave/app/theme/text_styles.dart';
import 'package:soundwave/core/widgets/album_artwork.dart';
import 'package:soundwave/core/widgets/glass_card.dart';
import 'package:soundwave/core/widgets/gradient_button.dart';
import 'package:soundwave/features/player/models/song_model.dart';
import 'package:soundwave/shared/providers/player_provider.dart';
import 'package:soundwave/shared/providers/theme_provider.dart';

class FeaturedMusicBanner extends ConsumerWidget {
  final SongModel? song;
  final List<SongModel> queue;
  final String? badgeText;
  final VoidCallback? onPlay;

  const FeaturedMusicBanner({
    super.key,
    required this.song,
    this.queue = const [],
    this.badgeText,
    this.onPlay,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (song == null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: GlassCard(
          borderRadius: 22,
          blur: 14,
          padding: const EdgeInsets.all(20),
          color: AppColors.secondaryBackground.withValues(alpha: 0.6),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('No Featured Track', style: AppTextStyles.songTitle),
                    const SizedBox(height: 2),
                    Text(
                      'Scan local audio or play music to feature songs here.',
                      style: AppTextStyles.subtitle.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final targetSong = song!;
    final playerState = ref.watch(playerProvider);
    final activeTheme = ref.watch(themeProvider);
    final isPlayingThis = playerState.currentSong?.id == targetSong.id && playerState.isPlaying;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      height: 155,
      child: GlassCard(
        borderRadius: 22,
        blur: 0,
        padding: EdgeInsets.zero,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            activeTheme.secondaryBackground.withValues(alpha: 0.96),
            activeTheme.primaryBackground.withValues(alpha: 0.90),
          ],
        ),
        borderColor: activeTheme.primaryAccent.withValues(alpha: 0.32),
        child: Stack(
          children: [
            // Ambient glow behind banner
            Positioned(
              right: -10,
              top: -10,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: activeTheme.primaryAccent.withValues(alpha: 0.18),
                ),
              ),
            ),

            // Content Row
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Clear Artwork with Neon Glow
                  AlbumArtwork(
                    size: 110,
                    borderRadius: 18,
                    artworkUrl: targetSong.artworkPath,
                    albumId: targetSong.albumId,
                    songId: targetSong.rawId,
                    songTitle: targetSong.title,
                    songArtist: targetSong.artist,
                    hasGlow: true,
                    glowColor: activeTheme.primaryAccent,
                  ),
                  const SizedBox(width: 16),

                  // Metadata & Actions
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Theme Pill Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: activeTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            badgeText ?? 'FEATURED TRACK',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Title
                        Text(
                          targetSong.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.cardTitle.copyWith(
                            fontSize: 16,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),

                        // Artist & Album
                        Text(
                          '${targetSong.artist} • ${targetSong.album}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.artistName.copyWith(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Play Now Button
                        Row(
                          children: [
                            GradientButton.pill(
                              height: 32,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              onPressed: () {
                                if (isPlayingThis) {
                                  ref.read(playerProvider.notifier).togglePlayPause();
                                } else {
                                  final q = queue.isNotEmpty ? queue : [targetSong];
                                  ref.read(playerProvider.notifier).playTrack(targetSong, queue: q);
                                }
                                onPlay?.call();
                              },
                              text: isPlayingThis ? 'Playing' : 'Play Track',
                              icon: isPlayingThis ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

