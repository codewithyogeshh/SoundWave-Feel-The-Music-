import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soundwave/core/constants/sample_music_data.dart';
import 'package:soundwave/features/library/models/playlist_model.dart';
import 'package:soundwave/features/player/models/song_model.dart';

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

  // --- PLAYLISTS ---
  List<PlaylistModel> getPlaylists() {
    final raw = _prefs.getStringList(_keyPlaylists);
    if (raw == null || raw.isEmpty) {
      final initial = SampleMusicData.initialPlaylists;
      savePlaylists(initial);
      return initial;
    }
    try {
      final loaded = raw.map((jsonStr) => PlaylistModel.fromJson(jsonStr)).toList();
      // Purge any legacy dummy playlists from earlier builds
      final cleaned = loaded.where((p) =>
        p.id == 'pl_my_downloads' ||
        p.id == 'pl_my_favorites' ||
        p.isCustom
      ).toList();

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
