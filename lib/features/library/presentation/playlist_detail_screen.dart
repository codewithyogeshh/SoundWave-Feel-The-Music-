import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundwave/app/theme/app_colors.dart';
import 'package:soundwave/app/theme/text_styles.dart';
import 'package:soundwave/app/theme/theme_model.dart';
import 'package:soundwave/core/widgets/album_artwork.dart';
import 'package:soundwave/core/widgets/app_background.dart';
import 'package:soundwave/core/widgets/empty_state_widget.dart';
import 'package:soundwave/core/widgets/gradient_button.dart';
import 'package:soundwave/core/widgets/premium_sheet.dart';
import 'package:soundwave/core/widgets/song_track_tile.dart';
import 'package:soundwave/features/library/models/playlist_model.dart';
import 'package:soundwave/features/player/models/song_model.dart';
import 'package:soundwave/shared/providers/library_provider.dart';
import 'package:soundwave/shared/providers/player_provider.dart';
import 'package:soundwave/shared/providers/theme_provider.dart';

class PlaylistDetailScreen extends ConsumerWidget {
  final String playlistId;

  const PlaylistDetailScreen({
    super.key,
    required this.playlistId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libState = ref.watch(libraryProvider);
    final activeTheme = ref.watch(themeProvider);
    final playlist = libState.playlists.where((p) => p.id == playlistId).firstOrNull;

    if (playlist == null) {
      return Scaffold(
        body: AppBackground(
          child: Center(
            child: Text('Playlist not found', style: AppTextStyles.screenTitle),
          ),
        ),
      );
    }

    final firstSong = playlist.songs.firstOrNull;
    final headerArtwork = (firstSong?.artworkPath?.isNotEmpty ?? false)
        ? firstSong!.artworkPath
        : playlist.coverImage;

    return Scaffold(
      body: AppBackground(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              pinned: true,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                if (playlist.isCustom)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                    color: AppColors.secondaryBackground,
                    onSelected: (val) {
                      if (val == 'rename') {
                        _showRenameDialog(context, ref, playlist);
                      } else if (val == 'delete') {
                        _confirmDelete(context, ref, playlist);
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'rename',
                        child: Text('Rename Playlist', style: TextStyle(color: Colors.white)),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete Playlist', style: TextStyle(color: Colors.redAccent)),
                      ),
                    ],
                  ),
              ],
            ),

            // Header Banner
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    AlbumArtwork(
                      size: 160,
                      borderRadius: 24,
                      artworkUrl: headerArtwork,
                      albumId: firstSong?.albumId,
                      songId: firstSong?.rawId,
                      songTitle: playlist.name,
                      hasGlow: true,
                      glowColor: activeTheme.primaryAccent,
                    ),
                    const SizedBox(height: 18),
                    ShaderMask(
                      shaderCallback: (rect) =>
                          activeTheme.primaryGradient.createShader(rect),
                      blendMode: BlendMode.srcIn,
                      child: Text(
                        playlist.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.screenTitle.copyWith(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          height: 1.15,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      playlist.description.isNotEmpty
                          ? playlist.description
                          : '${playlist.songCount} Tracks curated for you',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.subtitle.copyWith(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: activeTheme.highlightColor.withValues(alpha: 0.92),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildMetaStrip(activeTheme, playlist),

                    const SizedBox(height: 18),

                    // Play All & Shuffle Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GradientButton(
                          onPressed: () {
                            if (playlist.songs.isNotEmpty) {
                              ref.read(playerProvider.notifier).playTrack(
                                    playlist.songs.first,
                                    queue: playlist.songs,
                                  );
                            }
                          },
                          text: 'Play All',
                          icon: Icons.play_arrow_rounded,
                        ),
                        const SizedBox(width: 14),
                        GradientButton(
                          gradient: const LinearGradient(
                            colors: [Color(0x33FFFFFF), Color(0x1AFFFFFF)],
                          ),
                          onPressed: () {
                            if (playlist.songs.isNotEmpty) {
                              ref.read(playerProvider.notifier).toggleShuffle();
                              ref.read(playerProvider.notifier).playTrack(
                                    playlist.songs.first,
                                    queue: playlist.songs,
                                  );
                            }
                          },
                          text: 'Shuffle',
                          icon: Icons.shuffle_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildAddSongsPill(context, ref, activeTheme, playlist),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Songs List
            if (playlist.songs.isEmpty)
              SliverToBoxAdapter(
                child: EmptyStateWidget(
                  icon: Icons.music_note_rounded,
                  title: 'This playlist is empty',
                  message: 'Add songs from Search, Explore or your Local library.',
                  buttonText: 'Add Songs',
                  onButtonPressed: () => _showAddSongsSheet(context, ref, playlist),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final song = playlist.songs[index];
                    return Dismissible(
                      key: Key('pl_${playlist.id}_${song.id}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: Colors.redAccent.withValues(alpha: 0.7),
                        child: const Icon(Icons.delete_rounded, color: Colors.white),
                      ),
                      onDismissed: (_) {
                        ref
                            .read(libraryProvider.notifier)
                            .removeSongFromPlaylist(playlist.id, song.id);
                      },
                      child: SongTrackTile(
                        key: ValueKey('pl_track_${playlist.id}_${song.id}'),
                        song: song,
                        playlist: playlist.songs,
                      ),
                    );
                  },
                  childCount: playlist.songs.length,
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 175)),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaStrip(AppThemeType activeTheme, PlaylistModel playlist) {
    final total = playlist.songs.fold<Duration>(
      Duration.zero,
      (sum, song) => sum + song.duration,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.glassWhite.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: activeTheme.highlightColor.withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: activeTheme.primaryAccent.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 8,
        children: [
          _metaItem(
            activeTheme,
            Icons.library_music_rounded,
            '${playlist.songCount} ${playlist.songCount == 1 ? 'song' : 'songs'}',
          ),
          _metaItem(
            activeTheme,
            Icons.schedule_rounded,
            _formatTotalDuration(total),
          ),
          _metaItem(
            activeTheme,
            playlist.isCustom
                ? Icons.edit_note_rounded
                : Icons.auto_awesome_rounded,
            playlist.isCustom ? 'Your playlist' : 'Smart mix',
          ),
        ],
      ),
    );
  }

  Widget _metaItem(AppThemeType activeTheme, IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: activeTheme.highlightColor),
        const SizedBox(width: 5),
        Text(
          label,
          style: AppTextStyles.subtitle.copyWith(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.86),
          ),
        ),
      ],
    );
  }

  String _formatTotalDuration(Duration total) {
    if (total.inMinutes < 1) return 'Under a minute';
    final hours = total.inHours;
    final minutes = total.inMinutes.remainder(60);
    if (hours == 0) return '$minutes min';
    return minutes == 0 ? '$hours hr' : '$hours hr $minutes min';
  }

  Widget _buildAddSongsPill(
    BuildContext context,
    WidgetRef ref,
    AppThemeType activeTheme,
    PlaylistModel playlist,
  ) {
    return GestureDetector(
      onTap: () => _showAddSongsSheet(context, ref, playlist),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.glassWhiteMedium,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: activeTheme.highlightColor.withValues(alpha: 0.32),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.playlist_add_rounded,
              size: 15,
              color: activeTheme.highlightColor,
            ),
            const SizedBox(width: 6),
            Text(
              'Add songs',
              style: AppTextStyles.subtitle.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(
    BuildContext context,
    WidgetRef ref,
    PlaylistModel playlist,
  ) {
    final controller = TextEditingController(text: playlist.name);
    final activeTheme = ref.read(themeProvider);
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: activeTheme.secondaryBackground,
          title: const Text('Rename Playlist', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'New playlist name',
              hintStyle: TextStyle(color: AppColors.textMuted),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
            ),
            TextButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  ref.read(libraryProvider.notifier).renamePlaylist(playlist.id, name);
                  Navigator.pop(ctx);
                }
              },
              child: Text('Rename', style: TextStyle(color: activeTheme.primaryAccent)),
            ),
          ],
        );
      },
    ).whenComplete(controller.dispose);
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    PlaylistModel playlist,
  ) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.secondaryBackground,
          title: const Text('Delete Playlist?', style: TextStyle(color: Colors.white)),
          content: Text(
            'Are you sure you want to delete "${playlist.name}"? This cannot be undone.',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
            ),
            TextButton(
              onPressed: () {
                ref.read(libraryProvider.notifier).deletePlaylist(playlist.id);
                Navigator.pop(ctx); // Close dialog
                Navigator.pop(context); // Go back to library
              },
              child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        );
      },
    );
  }

  void _showAddSongsSheet(
    BuildContext context,
    WidgetRef ref,
    PlaylistModel playlist,
  ) {
    final activeTheme = ref.read(themeProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.78,
          minChildSize: 0.45,
          maxChildSize: 0.94,
          expand: false,
          builder: (_, controller) {
            return Container(
              decoration: premiumSheetDecoration(activeTheme, radius: 28),
              child: Consumer(
                builder: (context, sheetRef, _) {
                  final libState = sheetRef.watch(libraryProvider);
                  final live = libState.playlists
                          .where((p) => p.id == playlist.id)
                          .firstOrNull ??
                      playlist;
                  final allSongs = libState.allSongs;

                  return Column(
                    children: [
                      PremiumSheetHandle(theme: activeTheme),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: PremiumSheetHeader(
                          theme: activeTheme,
                          icon: Icons.playlist_add_rounded,
                          title: 'Add Songs',
                          subtitle: 'To ${live.name} • '
                              '${live.songCount} '
                              '${live.songCount == 1 ? 'song' : 'songs'}',
                          trailing: PremiumSheetPill(
                            label: '${allSongs.length}',
                            icon: Icons.library_music_rounded,
                            color: activeTheme.highlightColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildSheetHairline(activeTheme),
                      Expanded(
                        child: allSongs.isEmpty
                            ? Center(
                                child: Text(
                                  'No songs in your library yet',
                                  style: AppTextStyles.subtitle.copyWith(
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                controller: controller,
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  10,
                                  16,
                                  24,
                                ),
                                itemCount: allSongs.length,
                                itemBuilder: (_, index) {
                                  final song = allSongs[index];
                                  final alreadyIn = live.songs.any(
                                    (s) => s.id == song.id,
                                  );
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: _buildAddSongRow(
                                      sheetRef,
                                      activeTheme,
                                      live,
                                      song,
                                      alreadyIn,
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSheetHairline(AppThemeType activeTheme) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            activeTheme.highlightColor.withValues(alpha: 0.45),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  Widget _buildAddSongRow(
    WidgetRef ref,
    AppThemeType activeTheme,
    PlaylistModel playlist,
    SongModel song,
    bool alreadyIn,
  ) {
    return GestureDetector(
      onTap: alreadyIn
          ? null
          : () {
              ref
                  .read(libraryProvider.notifier)
                  .addSongToPlaylist(playlist.id, song);
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: alreadyIn
              ? activeTheme.primaryAccent.withValues(alpha: 0.12)
              : AppColors.glassWhite.withValues(alpha: 0.04),
          border: Border.all(
            color: alreadyIn
                ? activeTheme.highlightColor.withValues(alpha: 0.4)
                : AppColors.glassBorderSubtle,
          ),
        ),
        child: Row(
          children: [
            AlbumArtwork(
              size: 44,
              borderRadius: 11,
              artworkUrl: song.artworkPath,
              albumId: song.albumId,
              songId: song.rawId,
              songTitle: song.title,
              songArtist: song.artist,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.songTitle.copyWith(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.artistName.copyWith(fontSize: 11.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (alreadyIn)
              PremiumSheetPill(
                label: 'ADDED',
                icon: Icons.check_rounded,
                color: activeTheme.highlightColor,
              )
            else
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: activeTheme.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: activeTheme.primaryAccent.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.add_rounded,
                  size: 18,
                  color: activeTheme.onPrimaryGradient,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
