import 'package:soundwave/features/player/models/song_model.dart';
import 'package:soundwave/features/library/models/playlist_model.dart';

class SampleMusicData {
  // Pure local music mode - All tracks are sourced from the user's real device!
  static const List<SongModel> initialSongs = [];

  static List<PlaylistModel> get initialPlaylists => [
    PlaylistModel(
      id: 'pl_my_downloads',
      name: 'Downloaded Songs',
      description: 'Your offline audio tracks from device storage.',
      coverImage: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&q=80',
      songs: const [],
      createdAt: DateTime.now(),
      isCustom: false,
    ),
    PlaylistModel(
      id: 'pl_my_favorites',
      name: 'Favorite Tracks',
      description: 'Tracks you have marked with a heart.',
      coverImage: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=600&q=80',
      songs: const [],
      createdAt: DateTime.now(),
      isCustom: false,
    ),
  ];
}
