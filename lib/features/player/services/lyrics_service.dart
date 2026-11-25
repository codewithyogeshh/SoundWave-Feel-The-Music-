import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:soundwave/features/library/services/library_storage_service.dart';
import 'package:soundwave/features/player/models/lyrics_model.dart';
import 'package:soundwave/features/player/models/song_model.dart';
import 'package:soundwave/shared/providers/library_provider.dart';
import 'package:soundwave/shared/providers/player_provider.dart';

class LyricsService {
  /// Fast path for lyrics already loaded in this session, so reopening the
  /// player does not even touch SharedPreferences.
  static final Map<String, String> _memoryCache = <String, String>{};

  /// Identifies a track's lyrics. Ids are unique per source (online ids,
  /// downloaded ids and local file ids never collide).
  static String cacheKeyFor(SongModel song) => song.id;
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

  /// Fetches published lyrics for a track — synchronized when a provider has
  /// an LRC master, plain text otherwise, and empty when nothing is published.
  ///
  /// Lyrics are never invented: a track with no published lyrics returns an
  /// empty [LyricsData] so the player can show its "no lyrics" state honestly.
  ///
  /// Cached lyrics win over the network, which is what makes karaoke work on a
  /// flight or in a weak-signal area after the song has been opened once.
  static Future<LyricsData> getLyricsForSong(
    SongModel? song, {
    LibraryStorageService? storage,
  }) async {
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

    final cacheKey = cacheKeyFor(song);
    final cached = _memoryCache[cacheKey] ?? storage?.getCachedLyrics(cacheKey);
    if (cached != null && cached.trim().isNotEmpty) {
      _memoryCache[cacheKey] = cached;
      return LyricsData.parseLrc(cached, songId: song.id)
          .copyWith(fromCache: true);
    }

    // Real lyrics only, in order of quality: LRCLIB (synced, then plain),
    // then JioSaavn's plain lyrics for online tracks.
    final onlineLrc = await _fetchOnlineLrc(song.title, song.artist);
    if (onlineLrc != null && onlineLrc.isNotEmpty) {
      await _cacheLyrics(cacheKey, onlineLrc, storage);
      return LyricsData.parseLrc(onlineLrc, songId: song.id);
    }

    // Attempt online API fetch if network track via JioSaavn
    if (song.sourceType == AudioSourceType.network && song.id.startsWith('online_')) {
      final saavnLrc = await _fetchOnlineLyrics(song.id.substring(7));
      if (saavnLrc != null && saavnLrc.isNotEmpty) {
        await _cacheLyrics(cacheKey, saavnLrc, storage);
        return LyricsData.parseLrc(saavnLrc, songId: song.id);
      }
    }

    // Nothing published for this track: report it empty instead of showing
    // made-up lines as if they were the song's lyrics.
    return LyricsData(lines: const [], isSynced: false, songId: song.id);
  }

  static Future<void> _cacheLyrics(
    String cacheKey,
    String lrc,
    LibraryStorageService? storage,
  ) async {
    _memoryCache[cacheKey] = lrc;
    if (storage == null) return;
    try {
      await storage.putCachedLyrics(cacheKey, lrc);
    } catch (_) {
      // A failed cache write must never break the lyrics that just loaded.
    }
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

  /// Fetches published lyrics from the LRCLIB database. Synced LRC wins; when
  /// only plain lyrics exist they are returned instead (parsed as unsynced, so
  /// the viewer can show them without pretending to follow the song).
  static Future<String?> _fetchOnlineLrc(String rawTitle, String rawArtist) async {
    final title = _cleanTitle(rawTitle);
    final artist = _cleanArtist(rawArtist);
    String? plain;

    String? pickSynced(Map<String, dynamic> item) {
      final synced = item['syncedLyrics']?.toString();
      if (synced != null && synced.trim().isNotEmpty) return synced;
      final plainLyrics = item['plainLyrics']?.toString();
      if (plainLyrics != null && plainLyrics.trim().isNotEmpty) {
        plain ??= plainLyrics;
      }
      return null;
    }

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
        final synced = pickSynced(data);
        if (synced != null) return synced;
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
          if (item is! Map<String, dynamic>) continue;
          final synced = pickSynced(item);
          if (synced != null) return synced;
        }
      }
    } catch (_) {}

    return plain;
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

}

/// Per-song karaoke sync nudge, in milliseconds. Positive values push lyrics
/// later, negative values pull them earlier.
final lyricsOffsetProvider =
    NotifierProvider<LyricsOffsetNotifier, int>(LyricsOffsetNotifier.new);

class LyricsOffsetNotifier extends Notifier<int> {
  String? _songId;

  @override
  int build() {
    final songId = ref.watch(playerProvider.select((s) => s.currentSong?.id));
    _songId = songId;
    if (songId == null) return 0;
    try {
      return ref.read(storageServiceProvider).getLyricsOffsetMs(songId);
    } catch (_) {
      return 0;
    }
  }

  static const int stepMs = 250;

  Future<void> nudge(int deltaMs) async {
    final songId = _songId;
    if (songId == null) return;
    final next = (state + deltaMs).clamp(-10000, 10000);
    if (next == state) return;
    state = next;
    try {
      await ref.read(storageServiceProvider).setLyricsOffsetMs(songId, next);
    } catch (_) {
      // Persistence is best effort; the nudge still applies this session.
    }
  }

  Future<void> reset() => nudge(-state);
}

final currentSongLyricsProvider = FutureProvider<LyricsData>((ref) async {
  final song = ref.watch(playerProvider.select((s) => s.currentSong));
  final offsetMs = ref.watch(lyricsOffsetProvider);

  LibraryStorageService? storage;
  try {
    storage = ref.read(storageServiceProvider);
  } catch (_) {
    // Isolated tests may not override storage.
  }

  final lyrics = await LyricsService.getLyricsForSong(song, storage: storage);
  return lyrics.shifted(Duration(milliseconds: offsetMs));
});

/// True while the karaoke pane is showing lyrics served from the local cache.
final lyricsFromCacheProvider = Provider<bool>((ref) {
  return ref.watch(currentSongLyricsProvider).asData?.value.fromCache ?? false;
});
