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

/// Family provider for intelligent song recommendations based on active song
final recommendedSongsProvider =
    FutureProvider.family<List<SongModel>, SongModel>((ref, currentSong) async {
  final cleanArtist = currentSong.artist.split(',')[0].split('&')[0].trim();

  if (cleanArtist.isNotEmpty && cleanArtist != 'Unknown Artist') {
    try {
      final byArtist = await OnlineMusicService.searchSongs(cleanArtist);
      final filtered = byArtist.where((s) => s.id != currentSong.id).take(8).toList();
      if (filtered.isNotEmpty) return filtered;
    } catch (_) {}
  }

  if (currentSong.genre.isNotEmpty && currentSong.genre != 'ONLINE') {
    try {
      final byGenre = await OnlineMusicService.getGenreSongs(currentSong.genre);
      final filtered = byGenre.where((s) => s.id != currentSong.id).take(8).toList();
      if (filtered.isNotEmpty) return filtered;
    } catch (_) {}
  }

  try {
    final trending = await OnlineMusicService.getTrendingSongs();
    final filtered = trending.where((s) => s.id != currentSong.id).take(8).toList();
    if (filtered.isNotEmpty) return filtered;
  } catch (_) {}

  return [];
});

