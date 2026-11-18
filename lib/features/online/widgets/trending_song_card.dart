import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundwave/app/theme/app_colors.dart';
import 'package:soundwave/app/theme/text_styles.dart';
import 'package:soundwave/core/widgets/album_artwork.dart';
import 'package:soundwave/core/widgets/glass_card.dart';
import 'package:soundwave/features/online/widgets/download_options_sheet.dart';
import 'package:soundwave/features/player/models/song_model.dart';
import 'package:soundwave/shared/providers/download_provider.dart';
import 'package:soundwave/shared/providers/library_provider.dart';
import 'package:soundwave/shared/providers/player_provider.dart';
import 'package:soundwave/shared/providers/theme_provider.dart';

class TrendingSongCard extends ConsumerWidget {
  final SongModel song;
  final List<SongModel> playlist;

  const TrendingSongCard({
    super.key,
    required this.song,
    required this.playlist,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final libState = ref.watch(libraryProvider);
    final downloadState = ref.watch(downloadProvider);
    final activeTheme = ref.watch(themeProvider);

    final isCurrent = playerState.currentSong?.id == song.id;
    final isPlaying = isCurrent && playerState.isPlaying;
    final downloadedSong =
        libState.downloadedSongs.where((s) => s.id == song.id).firstOrNull;
    final isDownloaded = downloadedSong != null;
    final effectiveArtwork = (downloadedSong?.artworkPath?.isNotEmpty ?? false)
        ? downloadedSong!.artworkPath
        : song.artworkPath;
    final isDownloading = downloadState.isDownloading(song.id);
    final downloadProgress = downloadState.getProgress(song.id);

    return Container(
      width: 156,
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: GlassCard(
        borderRadius: 20,
        blur: 0,
        color: isCurrent
            ? activeTheme.secondaryBackground.withValues(alpha: 0.92)
            : AppColors.glassWhiteMedium,
        borderColor: isCurrent
            ? activeTheme.primaryAccent.withValues(alpha: 0.78)
            : AppColors.glassBorderSubtle,
        padding: const EdgeInsets.all(10),
        onTap: () {
          HapticFeedback.selectionClick();
          if (isCurrent) {
            ref.read(playerProvider.notifier).togglePlayPause();
          } else {
            ref.read(playerProvider.notifier).playTrack(song, queue: playlist);
            ref.read(libraryProvider.notifier).recordPlayed(song);
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Artwork Stack with Play / Download Overlay
            Stack(
              children: [
                AlbumArtwork(
                  size: 136,
                  borderRadius: 14,
                  artworkUrl: effectiveArtwork,
                  albumId: downloadedSong?.albumId ?? song.albumId,
                  songId: downloadedSong?.rawId ?? song.rawId,
                  songTitle: song.title,
                  songArtist: song.artist,
                  hasGlow: isCurrent,
                  glowColor: activeTheme.primaryAccent,
                ),

                // Top Left Quality / Offline Pill
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: (isDownloaded
                                ? Colors.greenAccent
                                : activeTheme.primaryAccent)
                            .withValues(alpha: 0.6),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      isDownloaded ? 'OFFLINE' : '320 KBPS',
                      style: TextStyle(
                        color: isDownloaded
                            ? Colors.greenAccent
                            : activeTheme.primaryAccent,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),

                // Bottom Right Download Button
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      showDownloadOptionsSheet(context, song);
                    },
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.78),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDownloaded
                              ? Colors.greenAccent
                              : activeTheme.primaryAccent.withValues(alpha: 0.55),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: isDownloading
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  value: downloadProgress > 0 ? downloadProgress : null,
                                  strokeWidth: 2,
                                  color: activeTheme.primaryAccent,
                                ),
                              )
                            : Icon(
                                isDownloaded
                                    ? Icons.check_circle_rounded
                                    : Icons.arrow_circle_down_rounded,
                                color: isDownloaded
                                    ? Colors.greenAccent
                                    : activeTheme.primaryAccent,
                                size: 20,
                              ),
                      ),
                    ),
                  ),
                ),

                if (isPlaying)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.pause_circle_filled_rounded,
                          color: activeTheme.primaryAccent,
                          size: 38,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 8),

            // Song Title
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.songTitle.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isCurrent ? activeTheme.primaryAccent : Colors.white,
              ),
            ),
            const SizedBox(height: 2),

            // Artist Name
            Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.artistName.copyWith(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

