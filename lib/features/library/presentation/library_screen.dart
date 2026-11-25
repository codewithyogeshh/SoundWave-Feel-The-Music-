import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundwave/app/theme/app_colors.dart';
import 'package:soundwave/app/theme/text_styles.dart';
import 'package:soundwave/core/widgets/album_artwork.dart';
import 'package:soundwave/core/widgets/empty_state_widget.dart';
import 'package:soundwave/core/widgets/featured_music_banner.dart';
import 'package:soundwave/core/widgets/glass_card.dart';
import 'package:soundwave/core/widgets/gradient_button.dart';
import 'package:soundwave/core/widgets/loading_widget.dart';
import 'package:soundwave/core/widgets/song_track_tile.dart';
import 'package:soundwave/features/library/models/playlist_model.dart';
import 'package:soundwave/features/library/models/song_filter_state.dart';
import 'package:soundwave/features/library/presentation/playlist_detail_screen.dart';
import 'package:soundwave/features/library/widgets/song_filter_bar.dart';
import 'package:soundwave/features/player/models/song_model.dart';
import 'package:soundwave/shared/providers/library_provider.dart';
import 'package:soundwave/shared/providers/player_provider.dart';
import 'package:soundwave/shared/providers/theme_provider.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  SongFilterState _songsFilter = const SongFilterState();
  SongFilterState _favsFilter = const SongFilterState();
  SongFilterState _recentFilter = const SongFilterState();
  SongFilterState _deviceFilter = const SongFilterState();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final libState = ref.watch(libraryProvider);
    final activeTheme = ref.watch(themeProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Your Library', style: AppTextStyles.screenTitle),
                  GradientButton.circle(
                    size: 38,
                    gradient: activeTheme.accentGradient,
                    glowColor: activeTheme.primaryAccent,
                    onPressed: () => _showCreatePlaylistDialog(context),
                    child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                  ),
                ],
              ),
            ),

            // Tab Bar
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: activeTheme.primaryAccent,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.label,
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.textMuted,
              labelPadding: const EdgeInsets.symmetric(horizontal: 14),
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: -0.2),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              dividerColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              tabs: [
                Tab(text: 'Playlists (${libState.playlists.length})'),
                Tab(text: 'Songs (${libState.allSongs.length})'),
                Tab(text: 'Favorites (${libState.favoriteIds.length})'),
                Tab(text: 'Recently Played'),
                Tab(text: 'Device Audio (${libState.localSongs.length})'),
              ],
            ),

            const SizedBox(height: 8),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildPlaylistsTab(libState.playlists),
                  _buildSongsTab(libState.allSongs, libState.favoriteIds, libState.recentlyPlayedIds),
                  _buildFavoritesTab(libState.favoriteSongs, libState.favoriteIds, libState.recentlyPlayedIds),
                  _buildRecentlyPlayedTab(libState.recentlyPlayedSongs, libState.favoriteIds, libState.recentlyPlayedIds),
                  _buildDeviceAudioTab(libState),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistsTab(List<PlaylistModel> playlists) {
    if (playlists.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.playlist_add_rounded,
        title: 'No playlists yet',
        message: 'Organize your music into custom playlists tailored to your vibes.',
        buttonText: 'Create Playlist',
        onButtonPressed: () => _showCreatePlaylistDialog(context),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(left: 20, right: 20, top: 8, bottom: 175),
      itemCount: playlists.length,
      itemBuilder: (context, index) {
        final pl = playlists[index];
        final firstSong = pl.songs.firstOrNull;
        final coverArt = (firstSong?.artworkPath?.isNotEmpty ?? false)
            ? firstSong!.artworkPath
            : pl.coverImage;
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: GlassCard(
            borderRadius: 16,
            blur: 0,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: AppColors.glassWhiteMedium,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PlaylistDetailScreen(playlistId: pl.id),
                ),
              );
            },
            child: Row(
              children: [
                AlbumArtwork(
                  size: 46,
                  borderRadius: 12,
                  artworkUrl: coverArt,
                  albumId: firstSong?.albumId,
                  songId: firstSong?.rawId,
                  songTitle: pl.name,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pl.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.songTitle.copyWith(fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${pl.songCount} Songs • ${pl.isCustom ? "Custom" : "Curated"}',
                        style: AppTextStyles.artistName.copyWith(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                  color: AppColors.secondaryBackground,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(
                      color: AppColors.glassBorderSubtle,
                    ),
                  ),
                  onSelected: (val) {
                    if (val == 'play') {
                      if (pl.songs.isNotEmpty) {
                        ref.read(playerProvider.notifier).playTrack(
                              pl.songs.first,
                              queue: pl.songs,
                            );
                      }
                    } else if (val == 'shuffle') {
                      if (pl.songs.isNotEmpty) {
                        final shuffled = List<SongModel>.of(pl.songs)
                          ..shuffle();
                        ref.read(playerProvider.notifier).playTrack(
                              shuffled.first,
                              queue: shuffled,
                            );
                      }
                    } else if (val == 'rename') {
                      _showRenamePlaylistDialog(context, pl);
                    } else if (val == 'delete') {
                      _showDeletePlaylistDialog(context, pl);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'play',
                      child: Row(
                        children: [
                          Icon(Icons.play_arrow_rounded, color: AppColors.neonBlue, size: 20),
                          SizedBox(width: 10),
                          Text('Play All', style: TextStyle(color: Colors.white, fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'shuffle',
                      child: Row(
                        children: [
                          Icon(Icons.shuffle_rounded, color: AppColors.purple, size: 18),
                          SizedBox(width: 10),
                          Text('Shuffle Play', style: TextStyle(color: Colors.white, fontSize: 13)),
                        ],
                      ),
                    ),
                    if (pl.isCustom) ...[
                      const PopupMenuItem(
                        value: 'rename',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, color: AppColors.purple, size: 18),
                            SizedBox(width: 10),
                            Text('Rename', style: TextStyle(color: Colors.white, fontSize: 13)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                            SizedBox(width: 10),
                            Text('Delete', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSongsTab(
    List<SongModel> songs,
    Set<String> favoriteIds,
    List<String> recentlyPlayedIds,
  ) {
    if (songs.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.music_note_rounded,
        title: 'No songs available',
        message: 'Scan device audio or check online sources.',
      );
    }

    final filteredSongs = SongFilterHelper.filterAndSort(
      songs: songs,
      filterState: _songsFilter,
      favoriteIds: favoriteIds,
      recentlyPlayedIds: recentlyPlayedIds,
    );

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: FeaturedMusicBanner(
            song: songs.firstOrNull,
            queue: songs,
            badgeText: 'FEATURED TRACK',
          ),
        ),
        SliverToBoxAdapter(
          child: SongFilterBar(
            filterState: _songsFilter,
            allSongs: songs,
            filteredCount: filteredSongs.length,
            onFilterChanged: (newState) {
              setState(() => _songsFilter = newState);
            },
          ),
        ),
        if (filteredSongs.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 24, bottom: 175),
              child: EmptyStateWidget(
                icon: Icons.filter_alt_off_rounded,
                title: 'No matching tracks',
                message: 'No songs match your active filter criteria.',
                buttonText: 'Clear All Filters',
                onButtonPressed: () {
                  setState(() => _songsFilter = const SongFilterState());
                },
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final song = filteredSongs[index];
                return SongTrackTile(
                  key: ValueKey('song_${song.id}'),
                  song: song,
                  playlist: filteredSongs,
                );
              },
              childCount: filteredSongs.length,
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 175)),
      ],
    );
  }

  Widget _buildFavoritesTab(
    List<SongModel> favs,
    Set<String> favoriteIds,
    List<String> recentlyPlayedIds,
  ) {
    if (favs.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.favorite_border_rounded,
        title: 'No favorites yet',
        message: 'Tap the heart icon on any song to add it to your favorites.',
      );
    }

    final filteredFavs = SongFilterHelper.filterAndSort(
      songs: favs,
      filterState: _favsFilter,
      favoriteIds: favoriteIds,
      recentlyPlayedIds: recentlyPlayedIds,
    );

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: FeaturedMusicBanner(
            song: favs.firstOrNull,
            queue: favs,
            badgeText: 'FAVORITE PICK',
          ),
        ),
        SliverToBoxAdapter(
          child: SongFilterBar(
            filterState: _favsFilter,
            allSongs: favs,
            filteredCount: filteredFavs.length,
            onFilterChanged: (newState) {
              setState(() => _favsFilter = newState);
            },
          ),
        ),
        if (filteredFavs.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 24, bottom: 175),
              child: EmptyStateWidget(
                icon: Icons.filter_alt_off_rounded,
                title: 'No matching favorites',
                message: 'No favorite songs match your active filters.',
                buttonText: 'Reset Filters',
                onButtonPressed: () {
                  setState(() => _favsFilter = const SongFilterState());
                },
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final song = filteredFavs[index];
                return SongTrackTile(
                  key: ValueKey('fav_${song.id}'),
                  song: song,
                  playlist: filteredFavs,
                );
              },
              childCount: filteredFavs.length,
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 175)),
      ],
    );
  }

  Widget _buildRecentlyPlayedTab(
    List<SongModel> recent,
    Set<String> favoriteIds,
    List<String> recentlyPlayedIds,
  ) {
    if (recent.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.history_rounded,
        title: 'Nothing played recently',
        message: 'Start playing tracks to see your listening history here.',
      );
    }

    final filteredRecent = SongFilterHelper.filterAndSort(
      songs: recent,
      filterState: _recentFilter,
      favoriteIds: favoriteIds,
      recentlyPlayedIds: recentlyPlayedIds,
    );

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: FeaturedMusicBanner(
            song: recent.firstOrNull,
            queue: recent,
            badgeText: 'RECENT REPLAY',
          ),
        ),
        SliverToBoxAdapter(
          child: SongFilterBar(
            filterState: _recentFilter,
            allSongs: recent,
            filteredCount: filteredRecent.length,
            onFilterChanged: (newState) {
              setState(() => _recentFilter = newState);
            },
          ),
        ),
        if (filteredRecent.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 24, bottom: 175),
              child: EmptyStateWidget(
                icon: Icons.filter_alt_off_rounded,
                title: 'No matching tracks',
                message: 'No recently played tracks match your active filters.',
                buttonText: 'Reset Filters',
                onButtonPressed: () {
                  setState(() => _recentFilter = const SongFilterState());
                },
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final song = filteredRecent[index];
                return SongTrackTile(
                  key: ValueKey('recent_${song.id}'),
                  song: song,
                  playlist: filteredRecent,
                );
              },
              childCount: filteredRecent.length,
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 175)),
      ],
    );
  }

  Widget _buildDeviceAudioTab(LibraryState state) {
    if (state.isScanning) {
      return const LoadingWidget(message: 'Scanning your device for audio files...');
    }

    final localSongs = state.localSongs;
    final filteredLocal = SongFilterHelper.filterAndSort(
      songs: localSongs,
      filterState: _deviceFilter,
      favoriteIds: state.favoriteIds,
      recentlyPlayedIds: state.recentlyPlayedIds,
    );

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Scan Button Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: GlassCard(
              borderRadius: 18,
              blur: 14,
              padding: const EdgeInsets.all(14),
              color: AppColors.secondaryBackground.withValues(alpha: 0.8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.neonBlue.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.folder_open_rounded, color: AppColors.neonBlue, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Local Storage Scanner', style: AppTextStyles.songTitle),
                        const SizedBox(height: 2),
                        Text(
                          '${state.localSongs.length} local files discovered',
                          style: AppTextStyles.subtitle.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  GradientButton.pill(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    onPressed: () {
                      ref.read(libraryProvider.notifier).scanLocalMusic();
                    },
                    text: 'Scan Now',
                    icon: Icons.refresh_rounded,
                  ),
                ],
              ),
            ),
          ),
        ),

        // Device Songs List or Empty
        if (localSongs.isEmpty)
          SliverToBoxAdapter(
            child: EmptyStateWidget(
              icon: Icons.audio_file_outlined,
              title: 'No local music scanned',
              message: 'Scan your device to play offline MP3 and audio files directly inside SoundWave.',
              buttonText: 'Scan Device Music',
              onButtonPressed: () {
                ref.read(libraryProvider.notifier).scanLocalMusic();
              },
            ),
          )
        else ...[
          SliverToBoxAdapter(
            child: FeaturedMusicBanner(
              song: localSongs.firstOrNull,
              queue: localSongs,
              badgeText: 'DEVICE AUDIO',
            ),
          ),
          SliverToBoxAdapter(
            child: SongFilterBar(
              filterState: _deviceFilter,
              allSongs: localSongs,
              filteredCount: filteredLocal.length,
              onFilterChanged: (newState) {
                setState(() => _deviceFilter = newState);
              },
            ),
          ),
          if (filteredLocal.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 24, bottom: 175),
                child: EmptyStateWidget(
                  icon: Icons.filter_alt_off_rounded,
                  title: 'No matching audio files',
                  message: 'No local files match your active filters.',
                  buttonText: 'Reset Filters',
                  onButtonPressed: () {
                    setState(() => _deviceFilter = const SongFilterState());
                  },
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final song = filteredLocal[index];
                  return SongTrackTile(
                    key: ValueKey('local_${song.id}'),
                    song: song,
                    playlist: filteredLocal,
                  );
                },
                childCount: filteredLocal.length,
              ),
            ),
        ],

        const SliverToBoxAdapter(child: SizedBox(height: 175)),
      ],
    );
  }

  void _showRenamePlaylistDialog(BuildContext context, PlaylistModel playlist) {
    final controller = TextEditingController(text: playlist.name);
    final activeTheme = ref.read(themeProvider);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: activeTheme.secondaryBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Rename Playlist', style: AppTextStyles.cardTitle.copyWith(fontSize: 18)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'New Name',
            labelStyle: TextStyle(color: activeTheme.primaryAccent),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          GradientButton.pill(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                ref.read(libraryProvider.notifier).renamePlaylist(playlist.id, newName);
                Navigator.pop(ctx);
              }
            },
            text: 'Save',
            icon: Icons.check_rounded,
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  void _showDeletePlaylistDialog(BuildContext context, PlaylistModel playlist) {
    final activeTheme = ref.read(themeProvider);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: activeTheme.secondaryBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Playlist', style: AppTextStyles.cardTitle.copyWith(fontSize: 18)),
        content: Text(
          'Are you sure you want to delete "${playlist.name}"? This will not delete your audio files.',
          style: AppTextStyles.subtitle.copyWith(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: () {
              ref.read(libraryProvider.notifier).deletePlaylist(playlist.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final activeTheme = ref.read(themeProvider);

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: activeTheme.secondaryBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('New Playlist', style: AppTextStyles.cardTitle.copyWith(fontSize: 20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Playlist Name',
                  labelStyle: TextStyle(color: activeTheme.primaryAccent),
                  hintText: 'e.g., Midnight Vibes',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                  hintText: 'e.g., Chill night drive tracks',
                  hintStyle: TextStyle(color: AppColors.textMuted),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
            ),
            GradientButton.pill(
              onPressed: () {
                final name = titleController.text.trim();
                if (name.isNotEmpty) {
                  ref.read(libraryProvider.notifier).createPlaylist(
                        name,
                        description: descController.text.trim(),
                      );
                  Navigator.pop(ctx);
                }
              },
              text: 'Create',
              icon: Icons.check_rounded,
            ),
          ],
        );
      },
    ).whenComplete(() {
      titleController.dispose();
      descController.dispose();
    });
  }
}
