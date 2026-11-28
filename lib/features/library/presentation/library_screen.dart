import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundwave/app/theme/app_colors.dart';
import 'package:soundwave/app/theme/text_styles.dart';
import 'package:soundwave/app/theme/theme_model.dart';
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
import 'package:soundwave/features/library/utils/history_grouping.dart';
import 'package:soundwave/features/library/widgets/song_filter_bar.dart';
import 'package:soundwave/features/online/presentation/downloads_screen.dart';
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
        child: Stack(
          children: [
            _LibraryAmbientGlow(theme: activeTheme),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(activeTheme, libState),
                _buildStatsStrip(activeTheme, libState),
                const SizedBox(height: 14),
                _buildTabBar(activeTheme, libState),
                const SizedBox(height: 6),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _buildPlaylistsTab(libState.playlists),
                      _buildSongsTab(libState.allSongs, libState.favoriteIds, libState.recentlyPlayedIds),
                      _buildFavoritesTab(libState.favoriteSongs, libState.favoriteIds, libState.recentlyPlayedIds),
                      _buildRecentlyPlayedTab(libState.recentlyPlayedSongs, libState.favoriteIds, libState.recentlyPlayedIds, activeTheme, libState.recentlyPlayedTimes),
                      _buildDeviceAudioTab(libState),
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

  // ---------------------------------------------------------------------------
  // Decorated library chrome: hero header, quick stats and pill tabs.
  // ---------------------------------------------------------------------------

  Widget _buildHeader(AppThemeType activeTheme, LibraryState libState) {
    final totalSongs = libState.allSongs.length;
    final playlistCount = libState.playlists.length;
    final downloadCount = libState.downloadedSongs.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 12),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: activeTheme.primaryGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: activeTheme.primaryAccent.withValues(alpha: 0.55),
                  blurRadius: 22,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(
              Icons.library_music_rounded,
              color: activeTheme.onPrimaryGradient,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (rect) =>
                      activeTheme.primaryGradient.createShader(rect),
                  blendMode: BlendMode.srcIn,
                  child: Text(
                    'Your Library',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.screenTitle.copyWith(
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '$totalSongs songs • $playlistCount playlists • $downloadCount downloaded',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.subtitle.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary.withValues(alpha: 0.88),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildHeaderAction(
            icon: Icons.download_for_offline_outlined,
            tooltip: 'Downloads & storage',
            activeTheme: activeTheme,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DownloadsScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
          GradientButton.circle(
            size: 40,
            gradient: activeTheme.accentGradient,
            glowColor: activeTheme.primaryAccent,
            onPressed: () => _showCreatePlaylistDialog(context),
            child: Icon(
              Icons.add_rounded,
              color: activeTheme.onAccentGradient,
              size: 23,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderAction({
    required IconData icon,
    required String tooltip,
    required AppThemeType activeTheme,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.glassWhite,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: activeTheme.highlightColor.withValues(alpha: 0.22),
            ),
          ),
          child: Icon(icon, color: Colors.white, size: 21),
        ),
      ),
    );
  }

  Widget _buildStatsStrip(AppThemeType activeTheme, LibraryState libState) {
    final stats = [
      _LibStat('Songs', libState.allSongs.length, Icons.music_note_rounded, 1),
      _LibStat('Playlists', libState.playlists.length, Icons.queue_music_rounded, 0),
      _LibStat('Favorites', libState.favoriteIds.length, Icons.favorite_rounded, 2),
      _LibStat('Device', libState.localSongs.length, Icons.smartphone_rounded, 4),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            activeTheme.primaryAccent.withValues(alpha: 0.22),
            AppColors.glassWhite.withValues(alpha: 0.04),
          ],
        ),
        border: Border.all(
          color: activeTheme.highlightColor.withValues(alpha: 0.26),
        ),
        boxShadow: [
          BoxShadow(
            color: activeTheme.primaryAccent.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          for (var i = 0; i < stats.length; i++) ...[
            if (i > 0)
              Container(
                width: 1,
                height: 28,
                color: AppColors.glassBorderSubtle,
              ),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _tabController.animateTo(stats[i].tab),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        stats[i].icon,
                        size: 16,
                        color: activeTheme.highlightColor,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${stats[i].value}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          height: 1,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        stats[i].label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabBar(AppThemeType activeTheme, LibraryState libState) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.glassWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.glassBorderSubtle),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicator: BoxDecoration(
          gradient: activeTheme.accentGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: activeTheme.primaryAccent.withValues(alpha: 0.45),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: EdgeInsets.zero,
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textMuted,
        labelPadding: const EdgeInsets.symmetric(horizontal: 13),
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 12.5,
          letterSpacing: -0.2,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12.5,
        ),
        dividerColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
        tabs: [
          Tab(height: 36, text: 'Playlists ${libState.playlists.length}'),
          Tab(height: 36, text: 'Songs ${libState.allSongs.length}'),
          Tab(height: 36, text: 'Favorites ${libState.favoriteIds.length}'),
          Tab(height: 36, text: 'Recent ${libState.recentlyPlayedSongs.length}'),
          Tab(height: 36, text: 'Device ${libState.localSongs.length}'),
        ],
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

    final activeTheme = ref.watch(themeProvider);

    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 175),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.84,
      ),
      itemCount: playlists.length,
      itemBuilder: (context, index) {
        final pl = playlists[index];
        final firstSong = pl.songs.firstOrNull;
        final coverArt = (firstSong?.artworkPath?.isNotEmpty ?? false)
            ? firstSong!.artworkPath
            : pl.coverImage;
        return _buildPlaylistCard(activeTheme, pl, firstSong, coverArt);
      },
    );
  }

  Widget _buildPlaylistCard(
    AppThemeType activeTheme,
    PlaylistModel pl,
    SongModel? firstSong,
    String? coverArt,
  ) {
    return GlassCard(
      borderRadius: 22,
      blur: 0,
      padding: EdgeInsets.zero,
      color: AppColors.glassWhiteMedium,
      borderColor: activeTheme.highlightColor.withValues(alpha: 0.24),
      shadows: [
        BoxShadow(
          color: activeTheme.primaryAccent.withValues(alpha: 0.2),
          blurRadius: 18,
          offset: const Offset(0, 10),
        ),
      ],
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PlaylistDetailScreen(playlistId: pl.id),
          ),
        );
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          AlbumArtwork(
            size: 200,
            borderRadius: 0,
            artworkUrl: coverArt,
            albumId: firstSong?.albumId,
            songId: firstSong?.rawId,
            songTitle: pl.name,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  activeTheme.primaryBackground.withValues(alpha: 0.22),
                  activeTheme.deepBackground.withValues(alpha: 0.94),
                ],
                stops: const [0.34, 0.6, 1.0],
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 11,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  pl.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.songTitle.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${pl.songCount} songs • ${pl.isCustom ? "Custom" : "Curated"}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.artistName.copyWith(
                    fontSize: 10.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: _buildPlaylistMenu(activeTheme, pl),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistMenu(AppThemeType activeTheme, PlaylistModel pl) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.38),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        iconSize: 18,
        tooltip: 'Playlist options',
        color: activeTheme.secondaryBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.glassBorderSubtle),
        ),
        icon: const Icon(
          Icons.more_vert_rounded,
          color: Colors.white,
          size: 18,
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
              final shuffled = List<SongModel>.of(pl.songs)..shuffle();
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
    AppThemeType activeTheme,
    Map<String, int> playedTimes,
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
          child: _buildRecentHeader(recent, activeTheme),
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
            delegate: SliverChildListDelegate(
              _buildHistoryRows(filteredRecent, playedTimes),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 175)),
      ],
    );
  }

  /// Rows for the history list: a Today / Yesterday / Earlier header followed
  /// by its tracks, each tagged with the time it was played.
  List<Widget> _buildHistoryRows(
    List<SongModel> songs,
    Map<String, int> playedTimes,
  ) {
    final rows = <Widget>[];
    for (final section in groupHistorySongs(songs, playedTimes)) {
      rows.add(_buildHistorySectionHeader(section));
      for (final song in section.songs) {
        rows.add(
          SongTrackTile(
            key: ValueKey('recent_${song.id}'),
            song: song,
            playlist: songs,
            trailingLabel: formatPlayedTime(playedTimes[song.id]),
          ),
        );
      }
    }
    return rows;
  }

  Widget _buildHistorySectionHeader(HistorySection section) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 6),
      child: Row(
        children: [
          Text(
            section.bucket.label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(height: 1, color: AppColors.glassBorderSubtle),
          ),
          const SizedBox(width: 8),
          Text(
            '${section.songs.length}',
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  /// Header for the Recently Played tab: how many tracks are stored, play all
  /// and shuffle for the whole history, and a way to clear it.
  Widget _buildRecentHeader(List<SongModel> recent, AppThemeType activeTheme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      child: GlassCard(
        borderRadius: 20,
        blur: 0,
        color: AppColors.glassWhiteMedium,
        borderColor: AppColors.glassBorderSubtle,
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.history_rounded,
                  color: AppColors.textMuted,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your listening history',
                        style: AppTextStyles.songTitle.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${recent.length} tracks saved • grouped by day',
                        style: AppTextStyles.artistName.copyWith(
                          fontSize: 11.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildRecentActionPill(
                  'Play all',
                  Icons.play_arrow_rounded,
                  activeTheme,
                  filled: true,
                  onTap: () => _playHistory(recent),
                ),
                const SizedBox(width: 8),
                _buildRecentActionPill(
                  'Shuffle',
                  Icons.shuffle_rounded,
                  activeTheme,
                  onTap: () => _playHistory(recent, shuffle: true),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Clear listening history',
                  onPressed: _confirmClearHistory,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActionPill(
    String label,
    IconData icon,
    AppThemeType activeTheme, {
    required VoidCallback onTap,
    bool filled = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          gradient: filled ? activeTheme.accentGradient : null,
          color: filled ? null : AppColors.glassWhiteMedium,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: filled
                ? activeTheme.highlightColor.withValues(alpha: 0.6)
                : AppColors.glassBorderSubtle,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: filled
                  ? activeTheme.onAccentGradient
                  : activeTheme.primaryAccent,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: filled
                    ? activeTheme.onAccentGradient
                    : AppColors.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Plays the whole history as the queue, starting from the newest track or
  /// from a random one when shuffle is on.
  void _playHistory(List<SongModel> songs, {bool shuffle = false}) {
    if (songs.isEmpty) return;
    final queue = shuffle ? (List<SongModel>.of(songs)..shuffle()) : songs;
    ref.read(playerProvider.notifier).playTrack(queue.first, queue: queue);
  }

  Future<void> _confirmClearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.secondaryBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Clear listening history?',
          style: TextStyle(color: Colors.white, fontSize: 17),
        ),
        content: const Text(
          'Every song is removed from Recently Played. Downloads, playlists and favourites stay as they are.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Clear',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(libraryProvider.notifier).clearHistory();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Listening history cleared.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
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
/// Soft theme-coloured light bleeding in behind the library content.
class _LibraryAmbientGlow extends StatelessWidget {
  const _LibraryAmbientGlow({required this.theme});

  final AppThemeType theme;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              top: -70,
              right: -50,
              width: 250,
              height: 250,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      theme.primaryAccent.withValues(alpha: 0.30),
                      theme.highlightColor.withValues(alpha: 0.10),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 110,
              left: -90,
              width: 230,
              height: 230,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      theme.secondaryAccent.withValues(alpha: 0.20),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One quick-stat tile in the library header strip.
class _LibStat {
  final String label;
  final int value;
  final IconData icon;
  final int tab;

  const _LibStat(this.label, this.value, this.icon, this.tab);
}
