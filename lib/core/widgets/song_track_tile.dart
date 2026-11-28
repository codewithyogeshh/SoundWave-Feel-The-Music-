import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundwave/app/theme/app_colors.dart';
import 'package:soundwave/app/theme/text_styles.dart';
import 'package:soundwave/core/utils/duration_formatter.dart';
import 'package:soundwave/core/widgets/album_artwork.dart';
import 'package:soundwave/core/widgets/animated_equalizer.dart';
import 'package:soundwave/core/widgets/glass_card.dart';
import 'package:soundwave/features/player/models/song_model.dart';
import 'package:soundwave/shared/providers/library_provider.dart';
import 'package:soundwave/shared/providers/player_provider.dart';
import 'package:soundwave/shared/providers/theme_provider.dart';

class SongTrackTile extends ConsumerWidget {
  final SongModel song;
  final List<SongModel> playlist;
  final VoidCallback? onMoreOptions;

  /// Small label on the right of the row, e.g. when a history track was
  /// last played. Hidden when null or empty.
  final String? trailingLabel;

  const SongTrackTile({
    super.key,
    required this.song,
    required this.playlist,
    this.onMoreOptions,
    this.trailingLabel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final activeTheme = ref.watch(themeProvider);
    final isCurrent = playerState.currentSong?.id == song.id;
    final isPlaying = isCurrent && playerState.isPlaying;
    final isFav = ref.watch(libraryProvider).isFavorite(song.id);

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
            // Left: High Quality Artwork (60dp with 14dp radius)
            AlbumArtwork(
              size: 60,
              borderRadius: 14,
              artworkUrl: song.artworkPath,
              albumId: song.albumId,
              songId: song.rawId,
              songTitle: song.title,
              songArtist: song.artist,
              hasGlow: isCurrent,
              glowColor: activeTheme.primaryAccent,
            ),
            const SizedBox(width: 14),

            // Center: Title, Artist, Album, Duration
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Song Title
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.songTitle.copyWith(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: isCurrent ? activeTheme.primaryAccent : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),

                  // Metadata Subtitle: Artist • Album • Duration
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.artistName.copyWith(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      if (song.album.isNotEmpty && song.album != 'SoundWave Originals') ...[
                        const SizedBox(width: 4),
                        const Text(
                          '•',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 10),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            song.album,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.artistName.copyWith(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 4),
                      const Text(
                        '•',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 10),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DurationFormatter.format(song.duration),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: activeTheme.primaryAccent,
                        ),
                      ),
                      if (song.fileSizeFormatted.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        const Text('•', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                        const SizedBox(width: 4),
                        Text(
                          song.fileSizeFormatted,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),

            // Right: Optional label such as the last played time
            if (trailingLabel != null && trailingLabel!.isNotEmpty) ...[
              Text(
                trailingLabel!,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 2),
            ],

            // Right: Playing Equalizer Indicator
            if (isPlaying) ...[
              AnimatedEqualizer(
                isPlaying: true,
                size: 16,
                color: activeTheme.highlightColor,
              ),
              const SizedBox(width: 2),
            ],

            // Right: Animated Favorite Heart Button
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
                  size: 20,
                ),
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                ref.read(libraryProvider.notifier).toggleFavorite(song);
              },
            ),

            // Right: More Options Popup Menu (3-dots)
            PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert_rounded,
                color: AppColors.textMuted,
                size: 20,
              ),
              color: activeTheme.secondaryBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.glassBorderSubtle),
              ),
              onSelected: (val) {
                if (val == 'play_next') {
                  ref.read(playerProvider.notifier).playNextInQueue(song);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Playing next: "${song.title}"'),
                      backgroundColor: AppColors.secondaryBackground,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } else if (val == 'add_to_queue') {
                  ref.read(playerProvider.notifier).addToQueue(song);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Added to queue: "${song.title}"'),
                      backgroundColor: AppColors.secondaryBackground,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } else if (val == 'add_to_playlist') {
                  _showAddToPlaylistDialog(context, ref, song);
                } else if (val == 'share') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Sharing "${song.title}" by ${song.artist}'),
                      backgroundColor: AppColors.secondaryBackground,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } else if (val == 'details') {
                  _showSongDetailsDialog(context, song);
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'play_next',
                  child: Row(
                    children: [
                      Icon(Icons.queue_play_next_rounded, color: AppColors.neonBlue, size: 18),
                      SizedBox(width: 10),
                      Text('Play Next', style: TextStyle(color: Colors.white, fontSize: 13)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'add_to_queue',
                  child: Row(
                    children: [
                      Icon(Icons.playlist_add_rounded, color: AppColors.neonBlue, size: 18),
                      SizedBox(width: 10),
                      Text('Add to Queue', style: TextStyle(color: Colors.white, fontSize: 13)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'add_to_playlist',
                  child: Row(
                    children: [
                      Icon(Icons.playlist_add_rounded, color: AppColors.purple, size: 18),
                      SizedBox(width: 10),
                      Text('Add to Playlist', style: TextStyle(color: Colors.white, fontSize: 13)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'share',
                  child: Row(
                    children: [
                      Icon(Icons.share_outlined, color: AppColors.textSecondary, size: 18),
                      SizedBox(width: 10),
                      Text('Share Song', style: TextStyle(color: Colors.white, fontSize: 13)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'details',
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: AppColors.textMuted, size: 18),
                      SizedBox(width: 10),
                      Text('Song Details', style: TextStyle(color: Colors.white, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddToPlaylistDialog(BuildContext context, WidgetRef ref, SongModel song) {
    final playlists = ref.read(libraryProvider).playlists;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.secondaryBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text('Add to Playlist', style: AppTextStyles.cardTitle.copyWith(fontSize: 18)),
        content: SizedBox(
          width: double.maxFinite,
          child: playlists.isEmpty
              ? const Text('No custom playlists yet. Create one in Library.',
                  style: TextStyle(color: AppColors.textSecondary))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: playlists.length,
                  itemBuilder: (context, idx) {
                    final pl = playlists[idx];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: AlbumArtwork(size: 38, borderRadius: 8, artworkUrl: pl.coverImage),
                      title: Text(pl.name, style: const TextStyle(color: Colors.white, fontSize: 14)),
                      subtitle: Text('${pl.songCount} songs',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                      trailing: const Icon(Icons.add_circle_outline_rounded,
                          color: AppColors.neonBlue, size: 22),
                      onTap: () {
                        ref.read(libraryProvider.notifier).addSongToPlaylist(pl.id, song);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Added "${song.title}" to "${pl.name}"'),
                            backgroundColor: AppColors.secondaryBackground,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
        ],
      ),
    );
  }

  void _showSongDetailsDialog(BuildContext context, SongModel song) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.secondaryBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            AlbumArtwork(
              size: 42,
              borderRadius: 10,
              artworkUrl: song.artworkPath,
              songId: song.rawId,
              albumId: song.albumId,
              songTitle: song.title,
              songArtist: song.artist,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.cardTitle.copyWith(fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Artist', song.artist),
            _buildDetailRow('Album', song.album),
            _buildDetailRow('Duration', DurationFormatter.format(song.duration)),
            _buildDetailRow('Genre', song.genre),
            _buildDetailRow('Format', song.audioPath.split('.').last.toUpperCase()),
            if (song.fileSizeFormatted.isNotEmpty)
              _buildDetailRow('File Size', song.fileSizeFormatted),
            _buildDetailRow('Type', song.isLocal ? 'Offline Storage' : 'Streamed'),
            if (song.dateAdded != null)
              _buildDetailRow(
                'Added Date',
                '${song.dateAdded!.day}/${song.dateAdded!.month}/${song.dateAdded!.year}',
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: AppColors.neonBlue)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

