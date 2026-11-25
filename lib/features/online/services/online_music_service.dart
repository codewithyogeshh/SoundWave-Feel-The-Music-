import 'dart:convert';
import 'package:dart_des/dart_des.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:soundwave/features/player/models/song_model.dart';

class OnlineMusicService {
  static const String _mobileBaseUrl = 'https://www.jiosaavn.com/api.php';

  /// Browsers block direct calls to JioSaavn (the API sends no CORS headers),
  /// so the web build uses the same-origin proxy deployed at /api/saavn.
  /// Mobile builds keep calling the API directly.
  static String get _directBaseUrl =>
      kIsWeb ? '${Uri.base.origin}/api/saavn' : _mobileBaseUrl;
  static const String _commonParams = '_format=json&_marker=0&cc=in';

  /// Resolve online tracks to 320 kbps AAC, or downshift to 160 kbps when
  /// the user picks data saver in Profile. Applied when a track is resolved,
  /// so already-loaded lists keep the URL they were parsed with.
  static bool highQualityStreams = true;

  /// CDN suffix for one track, honouring [highQualityStreams] and whether
  /// JioSaavn publishes a 320 kbps master for it.
  static String _streamQualityFor(bool has320) =>
      highQualityStreams && has320 ? '_320.mp4' : '_160.mp4';
  static const Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'application/json, text/plain, */*',
  };

  /// Decrypt DES-ECB encrypted media URL into direct CDN stream URL (320kbps / 160kbps)
  static String? decryptMediaUrl(String? encryptedMediaUrl, {String quality = '_320.mp4'}) {
    if (encryptedMediaUrl == null || encryptedMediaUrl.trim().isEmpty) return null;

    try {
      final key = utf8.encode('38346591');
      final des = DES(key: key, mode: DESMode.ECB, paddingType: DESPaddingType.PKCS5);
      final encryptedBytes = base64.decode(encryptedMediaUrl.trim());
      final decryptedBytes = des.decrypt(encryptedBytes);
      final decryptedUrl = utf8.decode(decryptedBytes);

      // Upgrade default preview bitrate (_96.mp4) to high-fidelity 320kbps or 160kbps
      if (quality.isNotEmpty && decryptedUrl.contains('_96.mp4')) {
        return decryptedUrl.replaceAll('_96.mp4', quality);
      }
      return decryptedUrl;
    } catch (e) {
      debugPrint('Error decrypting media URL: $e');
      return null;
    }
  }

  /// Search online songs by query string
  static Future<List<SongModel>> searchSongs(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    try {
      final uri = Uri.parse(
        '$_directBaseUrl?__call=search.getResults&$_commonParams&p=1&n=25&q=${Uri.encodeComponent(trimmed)}',
      );
      final response = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final results = data['results'] as List<dynamic>? ?? [];

        final songs = <SongModel>[];
        for (final item in results) {
          final parsed = _parseSongFromApi(item as Map<String, dynamic>);
          if (parsed != null) {
            songs.add(parsed);
          }
        }
        if (songs.isNotEmpty) return songs;
      }
    } catch (e) {
      debugPrint('Online search error for "$query": $e');
    }

    // Fallback search via autocomplete if search.getResults returned no songs
    return _searchAutocompleteFallback(trimmed);
  }

  /// Autocomplete fallback to discover songs when query is an artist or partial phrase
  static Future<List<SongModel>> _searchAutocompleteFallback(String query) async {
    try {
      final uri = Uri.parse(
        '$_directBaseUrl?__call=autocomplete.get&$_commonParams&includeMetaTags=1&query=${Uri.encodeComponent(query)}',
      );
      final response = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final songsData = data['songs'] as Map<String, dynamic>?;
        final list = songsData?['data'] as List<dynamic>? ?? [];

        final songs = <SongModel>[];
        for (final item in list) {
          final songMap = item as Map<String, dynamic>;
          final id = songMap['id']?.toString();
          if (id != null && id.isNotEmpty) {
            // Resolve full stream details for autocomplete item
            final resolved = await resolveSongById(id);
            if (resolved != null) {
              songs.add(resolved);
            }
          }
        }
        return songs;
      }
    } catch (e) {
      debugPrint('Autocomplete fallback error: $e');
    }
    return [];
  }

  /// Fetch curated trending / chart-topping online songs
  static Future<List<SongModel>> getTrendingSongs() async {
    final trendingList = await searchSongs('top hindi hits');
    if (trendingList.isNotEmpty) return trendingList;
    return searchSongs('trending');
  }

  /// Fetch songs for curated moods and genres
  static Future<List<SongModel>> getGenreSongs(String genre) async {
    final cleanGenre = genre.trim().toLowerCase();
    String query = '$cleanGenre hits';
    if (cleanGenre == 'all' || cleanGenre == 'trending') {
      query = 'top hindi hits';
    } else if (cleanGenre == 'top hindi' || cleanGenre == 'hindi') {
      query = 'top bollywood hindi hits';
    } else if (cleanGenre.contains('marathi')) {
      query = 'marathi trending hits';
    } else if (cleanGenre.contains('romantic')) {
      query = 'romantic hindi hits';
    } else if (cleanGenre.contains('party')) {
      query = 'bollywood party dance hits';
    } else if (cleanGenre.contains('lo-fi') || cleanGenre.contains('lofi')) {
      query = 'lofi hindi chill';
    } else if (cleanGenre.contains('devotional') || cleanGenre.contains('bhakti')) {
      query = 'devotional bhakti hits';
    } else if (cleanGenre.contains('study')) {
      query = 'lofi study focus music';
    } else if (cleanGenre.contains('arijit')) {
      query = 'arijit singh hits';
    } else if (cleanGenre.contains('punjabi')) {
      query = 'top punjabi hits';
    }

    final songs = await searchSongs(query);
    if (songs.isNotEmpty) return songs;
    return getTrendingSongs();
  }

  /// Fetch song details by raw ID and decrypt full-length 320kbps stream
  static Future<SongModel?> resolveSongById(String songId) async {
    final cleanId = songId.startsWith('online_') ? songId.substring(7) : songId;

    try {
      final uri = Uri.parse('$_directBaseUrl?__call=song.getDetails&pids=$cleanId&$_commonParams');
      final response = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final songData = data[cleanId] as Map<String, dynamic>?;
        if (songData != null) {
          return _parseSongFromApi(songData);
        }
      }
    } catch (e) {
      debugPrint('Error resolving song by id $songId: $e');
    }
    return null;
  }

  /// Resolve full track info including 320kbps stream URL and full duration
  static Future<SongModel?> resolveFullTrack(SongModel song) async {
    final cleanId = song.id.startsWith('online_') ? song.id.substring(7) : song.id;
    final resolved = await resolveSongById(cleanId);
    if (resolved != null) {
      return resolved;
    }
    return null;
  }

  /// Resolve direct audio stream URL with safe fallback
  static Future<String?> resolveStreamUrl(String songId, {String? fallbackUrl}) async {
    // If fallbackUrl is already a verified full-length saavncdn mp4 stream, keep it
    if (fallbackUrl != null &&
        fallbackUrl.isNotEmpty &&
        fallbackUrl.contains('aac.saavncdn.com') &&
        !fallbackUrl.contains('jiotunepreview')) {
      return fallbackUrl;
    }

    final resolved = await resolveSongById(songId);
    if (resolved != null && resolved.audioPath.isNotEmpty && !resolved.audioPath.contains('jiotunepreview')) {
      return resolved.audioPath;
    }

    return fallbackUrl;
  }

  /// Parse song payload from direct JioSaavn API with decrypted 320kbps stream URL
  static SongModel? _parseSongFromApi(Map<String, dynamic> item) {
    final rawId = item['id']?.toString() ?? UniqueKey().toString();
    final rawTitle = item['song']?.toString() ?? item['title']?.toString() ?? 'Unknown Song';
    final rawAlbum = item['album']?.toString() ?? 'Single';

    String rawArtist = item['primary_artists']?.toString() ?? '';
    if (rawArtist.isEmpty) rawArtist = item['singers']?.toString() ?? '';
    if (rawArtist.isEmpty) rawArtist = item['music']?.toString() ?? '';
    if (rawArtist.isEmpty) {
      final moreInfo = item['more_info'] as Map<String, dynamic>? ?? {};
      rawArtist = moreInfo['singers']?.toString() ?? item['description']?.toString() ?? 'Featured Artist';
    }

    final durationSeconds = int.tryParse(item['duration']?.toString() ?? '0') ?? 0;

    // Decrypt encrypted_media_url to get full-length 320kbps / 160kbps stream URL
    final enc = item['encrypted_media_url']?.toString();
    final has320 = item['320kbps']?.toString() == 'true';
    String? fullStreamUrl;
    if (enc != null && enc.isNotEmpty) {
      fullStreamUrl = decryptMediaUrl(enc, quality: _streamQualityFor(has320));
    }

    // High resolution artwork extraction (500x500)
    String? artworkUrl = item['image']?.toString();
    if (artworkUrl == null || artworkUrl.isEmpty) {
      final images = item['images'] as Map<String, dynamic>?;
      artworkUrl = images?['500x500']?.toString() ?? images?['150x150']?.toString();
    }
    if (artworkUrl != null) {
      if (artworkUrl.contains('150x150')) {
        artworkUrl = artworkUrl.replaceAll('150x150', '500x500');
      } else if (artworkUrl.contains('50x50')) {
        artworkUrl = artworkUrl.replaceAll('50x50', '500x500');
      }
    }

    // Direct playable path must be the full decrypted track
    final playablePath = (fullStreamUrl != null && fullStreamUrl.isNotEmpty) ? fullStreamUrl : '';
    if (playablePath.isEmpty) {
      return null;
    }

    final language = item['language']?.toString().toUpperCase() ?? 'ONLINE';

    return SongModel(
      id: 'online_$rawId',
      title: _cleanHtml(rawTitle),
      artist: _cleanHtml(rawArtist),
      album: _cleanHtml(rawAlbum),
      duration: Duration(seconds: durationSeconds > 0 ? durationSeconds : 210),
      audioPath: playablePath,
      sourceType: AudioSourceType.network,
      artworkPath: artworkUrl,
      isLocal: false,
      isHd: true,
      genre: language,
      dateAdded: DateTime.now(),
    );
  }

  /// Clean HTML entities from titles, albums, and artist strings
  static String _cleanHtml(String text) {
    return text
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&#039;', "'")
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ')
        .trim();
  }
}
