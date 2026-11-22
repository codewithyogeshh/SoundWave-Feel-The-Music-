import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:soundwave/features/player/models/lyrics_model.dart';
import 'package:soundwave/features/player/models/song_model.dart';
import 'package:soundwave/shared/providers/player_provider.dart';

class LyricsService {
  static const Map<String, String> _builtinLyrics = {
    'sample_1': '''
[00:02.00] In the quiet of the midnight air
[00:07.50] Footsteps echo like a gentle prayer
[00:14.20] City lights begin to slowly fade
[00:20.80] In the sanctuary that we made
[00:27.50] Dreams tonight, burning bright and free
[00:34.20] Sail away on a neon sea
[00:41.00] Hold my hand through the darkest sound
[00:47.80] Till tomorrow we are glory-bound
[00:55.00] Feel the rhythm in the pulsing floor
[01:02.20] We won't look back anymore
[01:09.00] Dreams tonight, burning bright and free
[01:16.40] You and I for eternity
''',
    'sample_2': '''
[00:03.00] Underneath the violet strobe and rain
[00:09.40] Wash away the memory of pain
[00:16.00] Midnight echoes whisper in the dark
[00:23.00] Striking fire from a single spark
[00:30.50] Run away before the morning sun
[00:37.20] Look at what the rhythm has begun
[00:44.80] Bass is rolling through the velvet street
[00:51.50] Every heartbeat moving to the beat
[00:58.80] Midnight echoes calling out your name
[01:06.00] Nothing's ever gonna be the same
''',
    'sample_3': '''
[00:02.50] Electric skies above the avenue
[00:08.80] Coloring the night in shades of blue
[00:15.50] Speed of sound and laser-guided light
[00:22.00] Taking over everything in sight
[00:29.00] Neon horizon, shining on the crowd
[00:36.00] Turn the music up and scream it loud
[00:43.00] Synchronize the wave and feel the rise
[00:50.00] Starlight flashing in each other's eyes
[00:57.20] Neon horizon pulling us ahead
[01:04.50] Living every moment that we said
''',
  };

  /// Fetches or generates synchronized lyrics for any track
  static Future<LyricsData> getLyricsForSong(SongModel? song) async {
    if (song == null) {
      return const LyricsData(lines: [], isSynced: false);
    }

    // Check built-in matched sample ID
    if (_builtinLyrics.containsKey(song.id)) {
      return LyricsData.parseLrc(_builtinLyrics[song.id]!, songId: song.id);
    }

    // Match by title keywords
    final lowerTitle = song.title.toLowerCase();
    for (final entry in _builtinLyrics.entries) {
      if (lowerTitle.contains(entry.key.replaceAll('sample_', ''))) {
        return LyricsData.parseLrc(entry.value, songId: song.id);
      }
    }

    // Attempt real online synchronized LRC lyrics via LRCLIB
    final onlineLrc = await _fetchOnlineLrc(song.title, song.artist);
    if (onlineLrc != null && onlineLrc.isNotEmpty) {
      return LyricsData.parseLrc(onlineLrc, songId: song.id);
    }

    // Attempt online API fetch if network track via JioSaavn
    if (song.sourceType == AudioSourceType.network && song.id.startsWith('online_')) {
      final saavnLrc = await _fetchOnlineLyrics(song.id.substring(7));
      if (saavnLrc != null && saavnLrc.isNotEmpty) {
        return LyricsData.parseLrc(saavnLrc, songId: song.id);
      }
    }

    // Rhythmic procedural synced lyrics so any local or online song has interactive karaoke!
    return _generateDynamicSyncedLyrics(song);
  }

  static String _cleanTitle(String title) {
    var t = title
        .replaceAll(RegExp(r'\(From[^\)]*\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\(feat[^\)]*\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[[^\]]*\]'), '')
        .replaceAll(RegExp(r'\(Original[^\)]*\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\(Audio[^\)]*\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\(Video[^\)]*\)', caseSensitive: false), '');
    t = t.split(' - ')[0].split(' (')[0].trim();
    return t.isNotEmpty ? t : title;
  }

  static String _cleanArtist(String artist) {
    return artist.split(',')[0].split('&')[0].trim();
  }

  /// Fetches real synchronized LRC lyrics from LRCLIB database
  static Future<String?> _fetchOnlineLrc(String rawTitle, String rawArtist) async {
    final title = _cleanTitle(rawTitle);
    final artist = _cleanArtist(rawArtist);

    // 1. Direct match by track_name & artist_name
    try {
      final uri = Uri.parse(
        'https://lrclib.net/api/get?track_name=${Uri.encodeComponent(title)}&artist_name=${Uri.encodeComponent(artist)}',
      );
      final res = await http.get(uri, headers: {
        'User-Agent': 'SoundWaveMusic/1.0',
      }).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final synced = data['syncedLyrics']?.toString();
        if (synced != null && synced.trim().isNotEmpty) {
          return synced;
        }
      }
    } catch (_) {}

    // 2. Search query by clean title + clean artist
    try {
      final q = Uri.encodeComponent('$title $artist'.trim());
      final uri = Uri.parse('https://lrclib.net/api/search?q=$q');
      final res = await http.get(uri, headers: {
        'User-Agent': 'SoundWaveMusic/1.0',
      }).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final list = json.decode(utf8.decode(res.bodyBytes)) as List<dynamic>;
        for (final item in list) {
          final synced = item['syncedLyrics']?.toString();
          if (synced != null && synced.trim().isNotEmpty) {
            return synced;
          }
        }
      }
    } catch (_) {}

    return null;
  }

  static Future<String?> _fetchOnlineLyrics(String songId) async {
    try {
      final uri = Uri.parse(
        'https://www.jiosaavn.com/api.php?__call=lyrics.getLyrics&lyrics_id=$songId&_format=json&_marker=0&cc=in',
      );
      final res = await http.get(uri, headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
      }).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final lyrics = data['lyrics']?.toString();
        if (lyrics != null && lyrics.trim().isNotEmpty) {
          return lyrics.replaceAll('<br>', '\n').replaceAll('<br/>', '\n');
        }
      }
    } catch (_) {
      // Ignore network failures
    }
    return null;
  }

  static LyricsData _generateDynamicSyncedLyrics(SongModel song) {
    final title = song.title;
    final artist = song.artist;
    final dur = song.duration.inSeconds > 30 ? song.duration.inSeconds : 180;
    final interval = (dur / 12).clamp(8, 22).toDouble();

    final verses = [
      '♪ Music Intro • Feel the SoundWave ♪',
      'Listen to the rhythm of "$title"',
      'Melody flowing from $artist',
      'Let the bassline carry you away',
      'Every frequency locked in tune',
      'Echoes dancing under the silver moon',
      'High fidelity streaming in your ears',
      'Washing off the weight of yesterday',
      'Feel the crescendo rising up high',
      'Soundwaves soaring to the sky',
      'Harmonies blending pure and sweet',
      'Lose yourself inside the beat',
      '♪ Outro • Pure SoundWave Experience ♪',
    ];

    final lines = <LyricLine>[];
    for (int i = 0; i < verses.length; i++) {
      final seconds = (i * interval).toInt();
      if (seconds >= dur) break;
      lines.add(
        LyricLine(
          timestamp: Duration(seconds: seconds),
          text: verses[i],
        ),
      );
    }

    return LyricsData(lines: lines, isSynced: true, songId: song.id);
  }
}

final currentSongLyricsProvider = FutureProvider<LyricsData>((ref) async {
  final song = ref.watch(playerProvider.select((s) => s.currentSong));
  return await LyricsService.getLyricsForSong(song);
});
