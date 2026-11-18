import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundwave/app/theme/app_colors.dart';
import 'package:soundwave/app/theme/text_styles.dart';
import 'package:soundwave/core/widgets/album_artwork.dart';
import 'package:soundwave/core/widgets/app_background.dart';
import 'package:soundwave/core/widgets/empty_state_widget.dart';
import 'package:soundwave/core/widgets/gradient_button.dart';
import 'package:soundwave/core/widgets/song_track_tile.dart';
import 'package:soundwave/features/library/models/playlist_model.dart';
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
                    Text(
                      playlist.name,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.screenTitle.copyWith(fontSize: 24),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      playlist.description.isNotEmpty
                          ? playlist.description
                          : '${playlist.songCount} Tracks curated for you',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.subtitle,
                    ),
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
    final allSongs = ref.read(libraryProvider).allSongs;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.primaryBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, controller) {
            return Column(
              children: [
                Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text('Add Songs to ${playlist.name}', style: AppTextStyles.sectionTitle),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    itemCount: allSongs.length,
                    itemBuilder: (_, index) {
                      final song = allSongs[index];
                      final alreadyIn = playlist.songs.any((s) => s.id == song.id);
                      return ListTile(
                        leading: AlbumArtwork(
                          size: 44,
                          borderRadius: 10,
                          artworkUrl: song.artworkPath,
                          albumId: song.albumId,
                          songId: song.rawId,
                          songTitle: song.title,
                          songArtist: song.artist,
                        ),
                        title: Text(song.title, style: AppTextStyles.songTitle),
                        subtitle: Text(song.artist, style: AppTextStyles.artistName),
                        trailing: Icon(
                          alreadyIn ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                          color: alreadyIn ? AppColors.neonBlue : Colors.white,
                        ),
                        onTap: () {
                          if (!alreadyIn) {
                            ref
                                .read(libraryProvider.notifier)
                                .addSongToPlaylist(playlist.id, song);
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
