import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soundwave/core/constants/sample_music_data.dart';
import 'package:soundwave/features/library/models/playlist_model.dart';
import 'package:soundwave/features/player/models/song_model.dart';

/// Queue + position captured when the app last saved its playback state.
class SavedPlaybackSession {
  final List<SongModel> queue;
  final int index;
  final Duration position;

  const SavedPlaybackSession({
    required this.queue,
    required this.index,
    required this.position,
  });
}

class LibraryStorageService {
  static const String _keyPlaylists = 'sw_playlists';
  static const String _keyFavorites = 'sw_favorites';
  static const String _keyRecentlyPlayed = 'sw_recently_played';
  static const String _keyRecentSearches = 'sw_recent_searches';
  static const String _keyTotalSongsPlayed = 'sw_stats_songs_played';
  static const String _keyUserProfile = 'sw_user_profile';
  static const String _keyAudioPrompted = 'sw_audio_prompted';
  static const String _keyLocalSongs = 'sw_local_songs_cache';
  static const String _keyDownloadedSongs = 'sw_downloaded_songs';
  static const String _keyLastQueue = 'sw_last_queue';
  static const String _keyLastIndex = 'sw_last_index';
  static const String _keyLastPositionMs = 'sw_last_position_ms';
  static const String _keyPlaybackSpeed = 'sw_playback_speed';

  final SharedPreferences _prefs;

  SharedPreferences get prefs => _prefs;

  LibraryStorageService(this._prefs);

  static Future<LibraryStorageService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return LibraryStorageService(prefs);
  }

  // --- DOWNLOADED SONGS PERSISTENCE ---
  List<SongModel> getDownloadedSongs() {
    final raw = _prefs.getStringList(_keyDownloadedSongs);
    if (raw == null || raw.isEmpty) return [];
    try {
      return raw.map((str) => SongModel.fromJson(str)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveDownloadedSong(SongModel song) async {
    final current = getDownloadedSongs();
    current.removeWhere((s) => s.id == song.id);
    current.insert(0, song);
    final raw = current.map((s) => s.toJson()).toList();
    await _prefs.setStringList(_keyDownloadedSongs, raw);
  }

  Future<void> removeDownloadedSong(String songId) async {
    final current = getDownloadedSongs();
    current.removeWhere((s) => s.id == songId);
    final raw = current.map((s) => s.toJson()).toList();
    await _prefs.setStringList(_keyDownloadedSongs, raw);
  }

  bool isSongDownloaded(String songId) {
    final current = getDownloadedSongs();
    return current.any((s) => s.id == songId);
  }

  // --- LOCAL SONGS PERSISTENCE ---
  List<SongModel> getLocalSongs() {
    final raw = _prefs.getStringList(_keyLocalSongs);
    if (raw == null || raw.isEmpty) return [];
    try {
      return raw.map((str) => SongModel.fromJson(str)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveLocalSongs(List<SongModel> songs) async {
    final raw = songs.map((s) => s.toJson()).toList();
    await _prefs.setStringList(_keyLocalSongs, raw);
  }

  // --- LAST PLAYBACK SESSION (resume where the user left off) ---
  SavedPlaybackSession? getPlaybackSession() {
    final raw = _prefs.getStringList(_keyLastQueue);
    if (raw == null || raw.isEmpty) return null;
    try {
      final songs = raw.map((s) => SongModel.fromJson(s)).toList();
      if (songs.isEmpty) return null;
      final index = (_prefs.getInt(_keyLastIndex) ?? 0).clamp(
        0,
        songs.length - 1,
      );
      final positionMs = _prefs.getInt(_keyLastPositionMs) ?? 0;
      return SavedPlaybackSession(
        queue: songs,
        index: index,
        position: Duration(milliseconds: positionMs < 0 ? 0 : positionMs),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> savePlaybackSession({
    required List<SongModel> queue,
    required int index,
    required Duration position,
  }) async {
    if (queue.isEmpty) return;
    final safeIndex = index.clamp(0, queue.length - 1);
    await _prefs.setStringList(
      _keyLastQueue,
      queue.map((s) => s.toJson()).toList(),
    );
    await _prefs.setInt(_keyLastIndex, safeIndex);
    await _prefs.setInt(_keyLastPositionMs, position.inMilliseconds);
  }

  Future<void> clearPlaybackSession() async {
    await _prefs.remove(_keyLastQueue);
    await _prefs.remove(_keyLastIndex);
    await _prefs.remove(_keyLastPositionMs);
  }

  // --- PLAYBACK SPEED ---
  double getPlaybackSpeed() {
    final speed = _prefs.getDouble(_keyPlaybackSpeed) ?? 1.0;
    return speed.clamp(0.5, 2.5);
  }

  Future<void> savePlaybackSpeed(double speed) async {
    await _prefs.setDouble(_keyPlaybackSpeed, speed.clamp(0.5, 2.5));
  }

  // --- PLAYLISTS ---
  List<PlaylistModel> getPlaylists() {
    final raw = _prefs.getStringList(_keyPlaylists);
    if (raw == null || raw.isEmpty) {
      final initial = SampleMusicData.initialPlaylists;
      savePlaylists(initial);
      return initial;
    }
    try {
      final loaded = raw
          .map((jsonStr) => PlaylistModel.fromJson(jsonStr))
          .toList();
      // Purge any legacy dummy playlists from earlier builds
      final cleaned = loaded
          .where(
            (p) =>
                p.id == 'pl_my_downloads' ||
                p.id == 'pl_my_favorites' ||
                p.isCustom,
          )
          .toList();

      if (cleaned.isEmpty) {
        final initial = SampleMusicData.initialPlaylists;
        savePlaylists(initial);
        return initial;
      }
      return cleaned;
    } catch (_) {
      return SampleMusicData.initialPlaylists;
    }
  }

  Future<void> savePlaylists(List<PlaylistModel> playlists) async {
    final raw = playlists.map((p) => p.toJson()).toList();
    await _prefs.setStringList(_keyPlaylists, raw);
  }

  // --- FAVORITES ---
  Set<String> getFavoriteIds() {
    final list = _prefs.getStringList(_keyFavorites);
    return list?.toSet() ?? <String>{};
  }

  Future<void> saveFavoriteIds(Set<String> ids) async {
    await _prefs.setStringList(_keyFavorites, ids.toList());
  }

  // --- RECENTLY PLAYED ---
  List<String> getRecentlyPlayedIds() {
    return _prefs.getStringList(_keyRecentlyPlayed) ?? [];
  }

  Future<void> addRecentlyPlayed(String songId) async {
    List<String> list = List.from(getRecentlyPlayedIds());
    list.remove(songId);
    list.insert(0, songId);
    if (list.length > 50) {
      list = list.sublist(0, 50);
    }
    await _prefs.setStringList(_keyRecentlyPlayed, list);
    await incrementTotalSongsPlayed();
  }

  // --- RECENT SEARCHES ---
  List<String> getRecentSearches() {
    return _prefs.getStringList(_keyRecentSearches) ?? [];
  }

  Future<void> addRecentSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    List<String> searches = List.from(getRecentSearches());
    searches.remove(trimmed);
    searches.insert(0, trimmed);
    if (searches.length > 20) {
      searches = searches.sublist(0, 20);
    }
    await _prefs.setStringList(_keyRecentSearches, searches);
  }

  Future<void> clearRecentSearches() async {
    await _prefs.remove(_keyRecentSearches);
  }

  // --- STATS ---
  int getTotalSongsPlayed() {
    return _prefs.getInt(_keyTotalSongsPlayed) ?? 0;
  }

  Future<void> incrementTotalSongsPlayed() async {
    final current = getTotalSongsPlayed();
    await _prefs.setInt(_keyTotalSongsPlayed, current + 1);
  }

  // --- USER PROFILE ---
  Map<String, dynamic> getUserProfile() {
    final raw = _prefs.getString(_keyUserProfile);
    if (raw != null) {
      try {
        final profile = json.decode(raw) as Map<String, dynamic>;
        if (profile['username'] == 'Alex Vance') {
          profile['username'] = 'My Music';
          saveUserProfile(profile);
        }
        return profile;
      } catch (_) {}
    }
    return {
      'username': 'My Music',
      'email': 'Device Offline Library',
      'avatarUrl': '',
      'audioQuality': 'HD Lossless (320 kbps)',
      'equalizerPreset': 'Vibrant Bass Boost',
      'gaplessPlayback': true,
      'normalizeVolume': true,
    };
  }

  Future<void> saveUserProfile(Map<String, dynamic> profile) async {
    await _prefs.setString(_keyUserProfile, json.encode(profile));
  }

  // --- AUDIO PERMISSION ONBOARDING PROMPT ---
  bool hasPromptedAudioPermission() {
    return _prefs.getBool(_keyAudioPrompted) ?? false;
  }

  Future<void> setPromptedAudioPermission(bool value) async {
    await _prefs.setBool(_keyAudioPrompted, value);
  }
}
