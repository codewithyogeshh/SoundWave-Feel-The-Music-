import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundwave/features/online/services/online_music_service.dart';
import 'package:soundwave/features/player/models/song_model.dart';

/// Provider for trending online tracks (auto-cached)
final onlineTrendingProvider = FutureProvider<List<SongModel>>((ref) async {
  return OnlineMusicService.getTrendingSongs();
});

/// Family provider for genre-specific online tracks
final onlineGenreSongsProvider =
    FutureProvider.family<List<SongModel>, String>((ref, genre) async {
  return OnlineMusicService.getGenreSongs(genre);
});

