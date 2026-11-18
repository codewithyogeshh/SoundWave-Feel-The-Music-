import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundwave/app/theme/app_colors.dart';
import 'package:soundwave/app/theme/text_styles.dart';
import 'package:soundwave/core/utils/duration_formatter.dart';
import 'package:soundwave/core/widgets/album_artwork.dart';
import 'package:soundwave/core/widgets/animated_equalizer.dart';
import 'package:soundwave/core/widgets/glass_card.dart';
import 'package:soundwave/features/online/widgets/download_options_sheet.dart';
import 'package:soundwave/features/player/models/song_model.dart';
import 'package:soundwave/shared/providers/download_provider.dart';
import 'package:soundwave/shared/providers/library_provider.dart';
import 'package:soundwave/shared/providers/player_provider.dart';
import 'package:soundwave/shared/providers/theme_provider.dart';

class OnlineSongTile extends ConsumerWidget {
  final SongModel song;
  final List<SongModel> playlist;
  final VoidCallback? onMoreOptions;

  const OnlineSongTile({
    super.key,
    required this.song,
    required this.playlist,
    this.onMoreOptions,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final libState = ref.watch(libraryProvider);
    final downloadState = ref.watch(downloadProvider);
    final activeTheme = ref.watch(themeProvider);

    final isCurrent = playerState.currentSong?.id == song.id;
    final isPlaying = isCurrent && playerState.isPlaying;
    final isFav = libState.isFavorite(song.id);
    final downloadedSong =
        libState.downloadedSongs.where((s) => s.id == song.id).firstOrNull;
    final isDownloaded = downloadedSong != null;
    final effectiveArtwork = (downloadedSong?.artworkPath?.isNotEmpty ?? false)
        ? downloadedSong!.artworkPath
        : song.artworkPath;
    final isDownloading = downloadState.isDownloading(song.id);
    final downloadProgress = downloadState.getProgress(song.id);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: GlassCard(
        borderRadius: 18,
        blur: 0,
        color: isCurrent
            ? activeTheme.secondaryBackground.withValues(alpha: 0.90)
            : AppColors.glassWhiteMedium,
        borderColor: isCurrent
            ? activeTheme.primaryAccent.withValues(alpha: 0.7)
            : AppColors.glassBorderSubtle,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        onTap: () {
          HapticFeedback.selectionClick();
          ref.read(playerProvider.notifier).playTrack(song, queue: playlist);
          ref.read(libraryProvider.notifier).recordPlayed(song);
        },
        child: Row(
          children: [
            // Artwork (54dp with 12dp radius)
            AlbumArtwork(
              size: 54,
              borderRadius: 12,
              artworkUrl: effectiveArtwork,
              albumId: downloadedSong?.albumId ?? song.albumId,
              songId: downloadedSong?.rawId ?? song.rawId,
              songTitle: song.title,
              songArtist: song.artist,
              hasGlow: isCurrent,
              glowColor: activeTheme.primaryAccent,
            ),
            const SizedBox(width: 14),

            // Metadata: Title, Artist, Quality/Offline status, Duration
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.songTitle.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isCurrent ? activeTheme.primaryAccent : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.artistName.copyWith(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (isDownloaded)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Colors.greenAccent.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.offline_pin_rounded, color: Colors.greenAccent, size: 10),
                              SizedBox(width: 3),
                              Text(
                                'OFFLINE',
                                style: TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: activeTheme.primaryAccent.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: activeTheme.primaryAccent.withValues(alpha: 0.32),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            '320 KBPS',
                            style: TextStyle(
                              color: activeTheme.primaryAccent,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      const SizedBox(width: 6),
                      Text(
                        DurationFormatter.format(song.duration),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),

            // Equalizer if playing
            if (isPlaying) ...[
              AnimatedEqualizer(
                isPlaying: true,
                size: 16,
                color: activeTheme.primaryAccent,
              ),
              const SizedBox(width: 2),
            ],

            // Download Action Button
            IconButton(
              icon: isDownloading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        value: downloadProgress > 0 ? downloadProgress : null,
                        strokeWidth: 2.2,
                        color: activeTheme.primaryAccent,
                      ),
                    )
                  : Icon(
                      isDownloaded
                          ? Icons.check_circle_rounded
                          : Icons.arrow_circle_down_rounded,
                      color: isDownloaded
                          ? Colors.greenAccent
                          : activeTheme.primaryAccent.withValues(alpha: 0.88),
                      size: 24,
                    ),
              tooltip: isDownloaded ? 'Downloaded Offline' : 'Download 320kbps',
              onPressed: () {
                HapticFeedback.lightImpact();
                showDownloadOptionsSheet(context, song);
              },
            ),

            // Heart Favorite Button
            IconButton(
              tooltip: isFav ? 'Remove from favorites' : 'Add to favorites',
              icon: Icon(
                isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: isFav ? activeTheme.highlightColor : AppColors.textMuted,
                size: 20,
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                ref.read(libraryProvider.notifier).toggleFavorite(song);
              },
            ),
          ],
        ),
      ),
    );
  }
}

