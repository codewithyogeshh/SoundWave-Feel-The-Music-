import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundwave/app/theme/app_colors.dart';
import 'package:soundwave/app/theme/text_styles.dart';
import 'package:soundwave/core/widgets/album_artwork.dart';
import 'package:soundwave/core/widgets/glass_card.dart';
import 'package:soundwave/features/online/services/download_service.dart';
import 'package:soundwave/features/player/models/song_model.dart';
import 'package:soundwave/shared/providers/download_provider.dart';
import 'package:soundwave/shared/providers/library_provider.dart';
import 'package:soundwave/shared/providers/playback_prefs_provider.dart';
import 'package:soundwave/shared/providers/player_provider.dart';

/// Starts the download straight away in the folder chosen in Settings, so the
/// app never asks "where should this go?" again. The sheet is only shown for a
/// song that is already downloaded or downloading (progress, play, delete).
void showDownloadOptionsSheet(BuildContext context, SongModel song) {
  final container = ProviderScope.containerOf(context, listen: false);
  final isDownloaded = container
      .read(libraryProvider)
      .downloadedSongs
      .any((s) => s.id == song.id);
  final isDownloading = container.read(downloadProvider).isDownloading(song.id);

  if (!isDownloaded && !isDownloading) {
    _startDownload(context, container, song);
    return;
  }

  showModalBottomSheet(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => DownloadOptionsSheet(song: song),
  );
}

Future<void> _startDownload(
  BuildContext context,
  ProviderContainer container,
  SongModel song,
) async {
  final destination = container.read(downloadDestinationProvider);
  final toPhone = destination == DownloadDestination.phoneStorage;
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        toPhone
            ? 'Downloading "${song.title}" to phone storage (Music/SoundWave)…'
            : 'Downloading "${song.title}" inside SoundWave…',
      ),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ),
  );
  final res = await container
      .read(downloadProvider.notifier)
      .downloadSong(song, destination: destination);
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        res.success
            ? (toPhone
                  ? 'Saved to phone storage (Music/SoundWave)'
                  : 'Downloaded "${song.title}" for offline playback!')
            : 'Download failed: ${res.error ?? "Unknown error"}',
      ),
      backgroundColor: res.success ? null : Colors.redAccent,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

class DownloadOptionsSheet extends ConsumerWidget {
  final SongModel song;

  const DownloadOptionsSheet({
    super.key,
    required this.song,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadState = ref.watch(downloadProvider);
    final libState = ref.watch(libraryProvider);
    final toPhoneStorage =
        ref.watch(downloadDestinationProvider) ==
        DownloadDestination.phoneStorage;
    final isDownloading = downloadState.isDownloading(song.id);
    final progress = downloadState.getProgress(song.id);
    final downloadedSong =
        libState.downloadedSongs.where((s) => s.id == song.id).firstOrNull;
    final isAlreadyDownloaded = downloadedSong != null;
    final effectiveArtwork = (downloadedSong?.artworkPath?.isNotEmpty ?? false)
        ? downloadedSong!.artworkPath
        : song.artworkPath;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle Pill
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Song Info Header Card
            GlassCard(
              borderRadius: 20,
              blur: 16,
              color: AppColors.glassWhiteMedium,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  AlbumArtwork(
                    size: 54,
                    borderRadius: 14,
                    artworkUrl: effectiveArtwork,
                    albumId: downloadedSong?.albumId ?? song.albumId,
                    songId: downloadedSong?.rawId ?? song.rawId,
                    songTitle: song.title,
                    songArtist: song.artist,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.songTitle.copyWith(fontSize: 15),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.artistName.copyWith(fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.neonBlue.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppColors.neonBlue.withValues(alpha: 0.4),
                                  width: 0.8,
                                ),
                              ),
                              child: const Text(
                                '320 KBPS CD QUALITY',
                                style: TextStyle(
                                  color: AppColors.neonBlue,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.magenta.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                '100% AD-FREE',
                                style: TextStyle(
                                  color: AppColors.magenta,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Downloading Progress Indicator (when active)
            if (isDownloading) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.secondaryBackground,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.neonBlue,
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Downloading 320 kbps audio & cover banner...',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${(progress * 100).toInt()}%',
                          style: const TextStyle(
                            color: AppColors.neonBlue,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress > 0 ? progress : null,
                        minHeight: 6,
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.neonBlue),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Section Title
            Text(
              isAlreadyDownloaded ? 'Song Downloaded' : 'Saving Download',
              style: AppTextStyles.sectionTitle.copyWith(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 12),

            if (isAlreadyDownloaded) ...[
              // Already downloaded banner
              GlassCard(
                borderRadius: 18,
                blur: 14,
                color: AppColors.neonBlue.withValues(alpha: 0.1),
                borderColor: AppColors.neonBlue.withValues(alpha: 0.3),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Available Offline in SoundWave',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            toPhoneStorage
                                ? 'Audio saved to /Music/SoundWave on this phone.'
                                : 'Song and cover banner saved in SoundWave offline storage.',
                            style: TextStyle(
                              color: AppColors.textSecondary.withValues(alpha: 0.9),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (isAlreadyDownloaded) ...[
              const SizedBox(height: 10),
              // Option 3: Play Offline
              _buildDownloadOption(
                context: context,
                icon: Icons.play_circle_fill_rounded,
                iconColor: Colors.greenAccent,
                title: 'Play Offline Track Now',
                subtitle: 'Start playback immediately from your offline library.',
                isEnabled: true,
                onTap: () {
                  Navigator.pop(context);
                  final downloaded = libState.downloadedSongs.firstWhere(
                    (s) => s.id == song.id,
                    orElse: () => song,
                  );
                  ref.read(playerProvider.notifier).playTrack(downloaded);
                },
              ),
              const SizedBox(height: 10),
              // Option 4: Delete Download
              _buildDownloadOption(
                context: context,
                icon: Icons.delete_outline_rounded,
                iconColor: Colors.redAccent,
                title: 'Delete Download',
                subtitle: 'Remove audio file and cached cover banner from device storage.',
                isEnabled: true,
                onTap: () async {
                  Navigator.pop(context);
                  await ref
                      .read(downloadProvider.notifier)
                      .removeDownload(downloadedSong);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Removed "${song.title}" from offline downloads'),
                        backgroundColor: AppColors.secondaryBackground,
                      ),
                    );
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadOption({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    String? badge,
    Color? badgeColor,
    required bool isEnabled,
    required VoidCallback onTap,
  }) {
    return GlassCard(
      borderRadius: 18,
      blur: 14,
      color: AppColors.glassWhiteMedium,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: isEnabled ? onTap : null,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: (badgeColor ?? AppColors.neonBlue).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            color: badgeColor ?? AppColors.neonBlue,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.arrow_forward_ios_rounded,
            color: AppColors.textMuted.withValues(alpha: 0.6),
            size: 14,
          ),
        ],
      ),
    );
  }
}

