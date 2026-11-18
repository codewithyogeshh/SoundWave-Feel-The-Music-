import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundwave/app/theme/app_colors.dart';
import 'package:soundwave/app/theme/text_styles.dart';
import 'package:soundwave/core/widgets/album_artwork.dart';
import 'package:soundwave/core/widgets/glass_card.dart';
import 'package:soundwave/core/widgets/gradient_button.dart';
import 'package:soundwave/features/library/models/playlist_model.dart';
import 'package:soundwave/shared/providers/player_provider.dart';

class FeaturedCard extends StatefulWidget {
  final PlaylistModel playlist;
  final VoidCallback? onPlay;

  const FeaturedCard({
    super.key,
    required this.playlist,
    this.onPlay,
  });

  @override
  State<FeaturedCard> createState() => _FeaturedCardState();
}

class _FeaturedCardState extends State<FeaturedCard> {
  final int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      height: 200,
      child: GlassCard(
        borderRadius: 26,
        blur: 16,
        padding: EdgeInsets.zero,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.secondaryBackground.withValues(alpha: 0.9),
            AppColors.primaryBackground.withValues(alpha: 0.8),
          ],
        ),
        child: Stack(
          children: [
            // Right-aligned Artwork with Gradient Mask
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 190,
              child: ShaderMask(
                shaderCallback: (rect) {
                  return const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.transparent,
                      Colors.black87,
                      Colors.black,
                    ],
                    stops: [0.0, 0.35, 1.0],
                  ).createShader(rect);
                },
                blendMode: BlendMode.dstIn,
                child: AlbumArtwork(
                  size: 200,
                  borderRadius: 0,
                  artworkUrl: widget.playlist.coverImage,
                ),
              ),
            ),

            // Content Left Overlay
            Padding(
              padding: const EdgeInsets.only(left: 22, top: 22, bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.playlist.name,
                        style: AppTextStyles.cardTitle.copyWith(fontSize: 22),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: 170,
                        child: Text(
                          widget.playlist.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.subtitle.copyWith(fontSize: 12),
                        ),
                      ),
                    ],
                  ),

                  // "Play Now" Pill Button (Compact height)
                  Consumer(
                    builder: (context, ref, _) {
                      return GradientButton.pill(
                        height: 32,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 4,
                        ),
                        onPressed: () {
                          if (widget.playlist.songs.isNotEmpty) {
                            ref.read(playerProvider.notifier).playTrack(
                                  widget.playlist.songs.first,
                                  queue: widget.playlist.songs,
                                );
                          }
                          widget.onPlay?.call();
                        },
                        text: 'Play Now',
                        icon: Icons.play_arrow_rounded,
                      );
                    },
                  ),
                ],
              ),
            ),

            // Carousel Page Indicator Dots at Bottom Center
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  final isActive = index == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: isActive ? 16 : 6,
                    height: 5,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: isActive
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.25),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
