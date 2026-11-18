import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundwave/app/theme/app_colors.dart';
import 'package:soundwave/app/theme/text_styles.dart';
import 'package:soundwave/app/theme/theme_model.dart';
import 'package:soundwave/core/widgets/album_artwork.dart';
import 'package:soundwave/core/widgets/animated_equalizer.dart';
import 'package:soundwave/core/widgets/glass_card.dart';
import 'package:soundwave/core/widgets/gradient_button.dart';
import 'package:soundwave/core/widgets/loading_widget.dart';
import 'package:soundwave/core/widgets/section_header.dart';
import 'package:soundwave/features/library/models/playlist_model.dart';
import 'package:soundwave/features/player/models/song_model.dart';
import 'package:soundwave/shared/providers/library_provider.dart';
import 'package:soundwave/shared/providers/online_music_provider.dart';
import 'package:soundwave/shared/providers/player_provider.dart';
import 'package:soundwave/shared/providers/theme_provider.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  final VoidCallback? onSearchTap;
  final VoidCallback? onSeeAllPlaylists;

  const ExploreScreen({
    super.key,
    this.onSearchTap,
    this.onSeeAllPlaylists,
  });

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  String _selectedGenre = 'Pop';

  final List<Map<String, dynamic>> _genres = [
    {'name': 'Pop', 'icon': Icons.music_note_rounded},
    {'name': 'Lo-Fi', 'icon': Icons.album_rounded},
    {'name': 'Rock', 'icon': Icons.electric_bolt_rounded},
    {'name': 'Hip Hop', 'icon': Icons.mic_external_on_rounded},
    {'name': 'Classical', 'icon': Icons.piano_rounded},
    {'name': 'Electronic', 'icon': Icons.waves_rounded},
    {'name': 'Jazz', 'icon': Icons.nightlife_rounded},
    {'name': 'Ambient', 'icon': Icons.auto_awesome_rounded},
  ];

  @override
  Widget build(BuildContext context) {
    final libState = ref.watch(libraryProvider);
    final activeTheme = ref.watch(themeProvider);
    final allSongs = libState.allSongs;
    final playlists = libState.playlists;
    final onlineTrending = ref.watch(onlineTrendingProvider);
    final onlineList = onlineTrending.asData?.value ?? const <SongModel>[];
    final showOnlineSection = onlineTrending.isLoading || onlineList.isNotEmpty;

    // Filter by genre if selected
    final filteredSongs = _selectedGenre == 'All'
        ? allSongs
        : allSongs.where((s) => s.genre == _selectedGenre).toList();
    final trendingSongs = filteredSongs.isNotEmpty ? filteredSongs : allSongs;

    final madeForYouPlaylists = playlists.length > 3
        ? playlists.sublist(3)
        : playlists;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        color: activeTheme.primaryAccent,
        backgroundColor: activeTheme.secondaryBackground,
        onRefresh: () async {
          HapticFeedback.lightImpact();
          ref.invalidate(onlineTrendingProvider);
          try {
            await ref.read(onlineTrendingProvider.future);
          } catch (_) {}
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            // Header Sliver
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Explore', style: AppTextStyles.screenTitle),
                        const SizedBox(height: 2),
                        Text(
                          'Discover new music everyday',
                          style: AppTextStyles.subtitle,
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        widget.onSearchTap?.call();
                      },
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.glassWhiteMedium,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: const Icon(
                          Icons.search_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Genre Category Chips Horizontal List
            SliverToBoxAdapter(
              child: SizedBox(
                height: 82,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _genres.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final genre = _genres[index];
                    final isSelected = genre['name'] == _selectedGenre;
                    return _buildGenreTile(genre, isSelected, activeTheme);
                  },
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            // "Trending Online Hits" Section (hidden when offline/empty)
            if (showOnlineSection) ...[
              SliverToBoxAdapter(
                child: SectionHeader(
                  title: 'Trending Online Hits',
                  actionText: 'Search',
                  onActionTap: widget.onSearchTap,
                ),
              ),
              onlineTrending.when(
                data: (onlineSongs) {
                  if (onlineSongs.isEmpty) {
                    return const SliverToBoxAdapter(child: SizedBox.shrink());
                  }
                  return SliverToBoxAdapter(
                    child: SizedBox(
                      height: 205,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: onlineSongs.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 14),
                        itemBuilder: (context, index) {
                          final song = onlineSongs[index];
                          return _buildOnlineCard(
                            context,
                            ref,
                            song,
                            onlineSongs,
                            activeTheme,
                          );
                        },
                      ),
                    ),
                  );
                },
                loading: () => SliverToBoxAdapter(
                  child: SizedBox(
                    height: 196,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 3,
                      separatorBuilder: (_, _) => const SizedBox(width: 14),
                      itemBuilder: (_, _) => const ShimmerPlaceholder(
                        width: 135,
                        height: 190,
                        borderRadius: 20,
                      ),
                    ),
                  ),
                ),
                error: (_, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
            ],

            // "Trending Now" Section Header
            SliverToBoxAdapter(
              child: SectionHeader(
                title: 'Trending Now',
                actionText: 'See all',
                onActionTap: widget.onSeeAllPlaylists,
              ),
            ),

            // Trending Tracks List
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final song = trendingSongs[index];
                  return _buildTrendingRow(
                    context,
                    ref,
                    song,
                    trendingSongs,
                    activeTheme,
                  );
                },
                childCount: trendingSongs.length.clamp(0, 5),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            // "Made for you" Section Header
            SliverToBoxAdapter(
              child: SectionHeader(
                title: 'Made for you',
                actionText: 'See all',
                onActionTap: widget.onSeeAllPlaylists,
              ),
            ),

            // Made for you Cards Horizontal List
            SliverToBoxAdapter(
              child: _buildMadeForYouList(context, ref, madeForYouPlaylists),
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: 175),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenreTile(
    Map<String, dynamic> genre,
    bool isSelected,
    AppThemeType activeTheme,
  ) {
    final selectedFg = activeTheme == AppThemeType.midnightOled ||
            activeTheme == AppThemeType.emeraldAurora
        ? const Color(0xFF090D16)
        : Colors.white;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedGenre = genre['name'] as String;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 66,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: isSelected ? activeTheme.primaryGradient : null,
          color: isSelected ? null : AppColors.glassWhiteMedium,
          border: Border.all(
            color: isSelected
                ? activeTheme.highlightColor.withValues(alpha: 0.85)
                : AppColors.glassBorderSubtle,
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeTheme.primaryAccent.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              genre['icon'] as IconData,
              color: isSelected ? selectedFg : Colors.white,
              size: 24,
            ),
            const SizedBox(height: 6),
            Text(
              genre['name'] as String,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? selectedFg : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendingRow(
    BuildContext context,
    WidgetRef ref,
    SongModel song,
    List<SongModel> queue,
    AppThemeType activeTheme,
  ) {
    final playerState = ref.watch(playerProvider);
    final isCurrent = playerState.currentSong?.id == song.id;
    final isPlaying = isCurrent && playerState.isPlaying;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: GlassCard(
        borderRadius: 18,
        blur: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        color: isCurrent
            ? activeTheme.secondaryBackground.withValues(alpha: 0.88)
            : AppColors.glassWhiteMedium,
        borderColor: isCurrent
            ? activeTheme.primaryAccent.withValues(alpha: 0.65)
            : AppColors.glassBorderSubtle,
        onTap: () {
          HapticFeedback.selectionClick();
          ref.read(playerProvider.notifier).playTrack(song, queue: queue);
        },
        child: Row(
          children: [
            AlbumArtwork(
              size: 48,
              borderRadius: 12,
              artworkUrl: song.artworkPath,
              albumId: song.albumId,
              songId: song.rawId,
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
                    style: AppTextStyles.songTitle.copyWith(
                      fontSize: 14,
                      color: isCurrent ? activeTheme.primaryAccent : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.artistName.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            if (isPlaying) ...[
              AnimatedEqualizer(
                isPlaying: true,
                size: 16,
                color: activeTheme.highlightColor,
              ),
              const SizedBox(width: 8),
            ],
            GradientButton.circle(
              size: 34,
              gradient: isCurrent && isPlaying
                  ? activeTheme.accentGradient
                  : const LinearGradient(
                      colors: [Colors.white, Color(0xFFE8EEFF)],
                    ),
              glowColor: activeTheme.primaryAccent,
              onPressed: () {
                if (isCurrent) {
                  ref.read(playerProvider.notifier).togglePlayPause();
                } else {
                  ref.read(playerProvider.notifier).playTrack(song, queue: queue);
                }
              },
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: isCurrent && isPlaying ? Colors.white : Colors.black87,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOnlineCard(
    BuildContext context,
    WidgetRef ref,
    SongModel song,
    List<SongModel> queue,
    AppThemeType activeTheme,
  ) {
    final playerState = ref.watch(playerProvider);
    final libState = ref.watch(libraryProvider);
    final downloadedMatch =
        libState.downloadedSongs.where((s) => s.id == song.id).firstOrNull;
    final effectiveArtwork = (downloadedMatch?.artworkPath?.isNotEmpty ?? false)
        ? downloadedMatch!.artworkPath
        : song.artworkPath;
    final isCurrent = playerState.currentSong?.id == song.id;
    final isPlaying = isCurrent && playerState.isPlaying;

    return SizedBox(
      width: 135,
      child: GlassCard(
        borderRadius: 20,
        blur: 0,
        padding: const EdgeInsets.all(10),
        color: isCurrent
            ? activeTheme.secondaryBackground.withValues(alpha: 0.90)
            : AppColors.glassWhiteMedium,
        borderColor: isCurrent
            ? activeTheme.primaryAccent.withValues(alpha: 0.7)
            : AppColors.glassBorderSubtle,
        onTap: () {
          HapticFeedback.selectionClick();
          ref.read(playerProvider.notifier).playTrack(song, queue: queue);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AlbumArtwork(
                  size: 115,
                  borderRadius: 14,
                  artworkUrl: effectiveArtwork,
                  albumId: downloadedMatch?.albumId ?? song.albumId,
                  songId: downloadedMatch?.rawId ?? song.rawId,
                  songTitle: song.title,
                  songArtist: song.artist,
                ),
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: (downloadedMatch != null
                                ? Colors.greenAccent
                                : activeTheme.primaryAccent)
                            .withValues(alpha: 0.5),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      downloadedMatch != null ? 'OFFLINE' : '320K',
                      style: TextStyle(
                        color: downloadedMatch != null
                            ? Colors.greenAccent
                            : activeTheme.primaryAccent,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: GradientButton.circle(
                    size: 32,
                    gradient: isCurrent && isPlaying
                        ? activeTheme.accentGradient
                        : const LinearGradient(
                            colors: [Colors.white, Color(0xFFF0F4FF)],
                          ),
                    glowColor: activeTheme.primaryAccent,
                    onPressed: () {
                      if (isCurrent) {
                        ref.read(playerProvider.notifier).togglePlayPause();
                      } else {
                        ref.read(playerProvider.notifier).playTrack(song, queue: queue);
                      }
                    },
                    child: Icon(
                      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: isCurrent && isPlaying ? Colors.white : Colors.black87,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.cardTitle.copyWith(
                fontSize: 13,
                color: isCurrent ? activeTheme.primaryAccent : Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.artistName.copyWith(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMadeForYouList(
    BuildContext context,
    WidgetRef ref,
    List<PlaylistModel> playlists,
  ) {
    return SizedBox(
      height: 190,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: playlists.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final pl = playlists[index];
          return SizedBox(
            width: 130,
            child: GlassCard(
              borderRadius: 20,
              blur: 14,
              padding: const EdgeInsets.all(10),
              color: AppColors.glassWhiteMedium,
              onTap: () {
                if (pl.songs.isNotEmpty) {
                  ref.read(playerProvider.notifier).playTrack(
                        pl.songs.first,
                        queue: pl.songs,
                      );
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      AlbumArtwork(
                        size: 110,
                        borderRadius: 14,
                        artworkUrl: pl.coverImage,
                      ),
                      Positioned(
                        bottom: 6,
                        right: 6,
                        child: GradientButton.circle(
                          size: 32,
                          gradient: const LinearGradient(
                            colors: [Colors.white, Color(0xFFF0F4FF)],
                          ),
                          onPressed: () {
                            if (pl.songs.isNotEmpty) {
                              ref.read(playerProvider.notifier).playTrack(
                                    pl.songs.first,
                                    queue: pl.songs,
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
                    pl.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.songTitle.copyWith(fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${pl.songCount} Songs',
                    style: AppTextStyles.artistName.copyWith(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
