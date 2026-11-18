import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundwave/app/theme/app_colors.dart';
import 'package:soundwave/app/theme/text_styles.dart';
import 'package:soundwave/core/widgets/album_artwork.dart';
import 'package:soundwave/core/widgets/glass_card.dart';
import 'package:soundwave/core/widgets/gradient_button.dart';
import 'package:soundwave/features/library/models/playlist_model.dart';
import 'package:soundwave/shared/providers/player_provider.dart';

class RecentlyPlayedList extends ConsumerWidget {
  final List<PlaylistModel> playlists;

  const RecentlyPlayedList({
    super.key,
    required this.playlists,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (playlists.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 180,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: playlists.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final item = playlists[index];
          return _buildCard(context, ref, item);
        },
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    WidgetRef ref,
    PlaylistModel playlist,
  ) {
    return SizedBox(
      width: 130,
      child: GlassCard(
        borderRadius: 20,
        blur: 14,
        padding: const EdgeInsets.all(10),
        color: AppColors.glassWhiteMedium,
        onTap: () {
          if (playlist.songs.isNotEmpty) {
            ref.read(playerProvider.notifier).playTrack(
                  playlist.songs.first,
                  queue: playlist.songs,
                );
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Artwork with small circular play button
            Stack(
              children: [
                AlbumArtwork(
                  size: 110,
                  borderRadius: 14,
                  artworkUrl: playlist.coverImage,
                ),
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: GradientButton.circle(
                    size: 32,
                    gradient: const LinearGradient(
                      colors: [Colors.white, Color(0xFFF0F4FF)],
                    ),
                    hasGlow: true,
                    glowColor: Colors.black,
                    onPressed: () {
                      if (playlist.songs.isNotEmpty) {
                        ref.read(playerProvider.notifier).playTrack(
                              playlist.songs.first,
                              queue: playlist.songs,
                            );
                      }
                    },
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.black87,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              playlist.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.songTitle.copyWith(fontSize: 13),
            ),
            const SizedBox(height: 2),
            Text(
              '${playlist.songCount} Songs',
              style: AppTextStyles.artistName.copyWith(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
