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
  static const String _keyRecentlyPlayedSongs = 'sw_recently_played_songs';
  static const String _keyRecentlyPlayedTimes = 'sw_recently_played_at';
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
  static const String _keyPlaybackVolume = 'sw_playback_volume';
  static const String _keyAudioFadeMs = 'sw_audio_fade_ms';
  static const String _keyListenedSeconds = 'sw_stats_listened_seconds';
  static const String _keyPauseOnUnplug = 'sw_pause_on_headphone_unplug';
  static const String _keyBatterySaver = 'sw_battery_saver';
  static const String _keyHighQualityStreams = 'sw_high_quality_streams';
  static const String _keyPauseOnLowBattery = 'sw_pause_on_low_battery';
  static const String _keyStopWhenSwipedAway = 'sw_stop_on_task_removed';
  static const String _keySleepTimerMinutes = 'sw_sleep_timer_minutes';
  static const String _keyShuffleEnabled = 'sw_shuffle_enabled';
  static const String _keyRepeatMode = 'sw_repeat_mode';
  static const String _keyLyricsCache = 'sw_lyrics_cache_v1';
  static const String _keyLyricsOffsets = 'sw_lyrics_offsets_v1';

  /// Enough lyrics for a long offline session without bloating preferences.
  static const int _lyricsCacheLimit = 150;

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

  // --- PLAYBACK VOLUME ---
  double getPlaybackVolume() {
    final volume = _prefs.getDouble(_keyPlaybackVolume) ?? 1.0;
    return volume.clamp(0.0, 1.0);
  }

  Future<void> savePlaybackVolume(double volume) async {
    await _prefs.setDouble(_keyPlaybackVolume, volume.clamp(0.0, 1.0));
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
    if (list.length > 100) {
      list = list.sublist(0, 100);
    }
    await _prefs.setStringList(_keyRecentlyPlayed, list);
    await incrementTotalSongsPlayed();
  }

  /// Full songs (not just ids) so history also works for online tracks that
  /// are not in the device library.
  List<SongModel> getRecentlyPlayedSongs() {
    final raw = _prefs.getStringList(_keyRecentlyPlayedSongs);
    if (raw == null || raw.isEmpty) return [];
    try {
      return raw.map((str) => SongModel.fromJson(str)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> addRecentlyPlayedSong(SongModel song) async {
    if (song.id.isEmpty) return;
    final current = getRecentlyPlayedSongs();
    current.removeWhere((s) => s.id == song.id);
    current.insert(0, song);
    final trimmed = current.length > 100 ? current.sublist(0, 100) : current;
    await _prefs.setStringList(
      _keyRecentlyPlayedSongs,
      trimmed.map((s) => s.toJson()).toList(),
    );
    // Remember when each track was played so the list can be grouped by day.
    final times = getRecentlyPlayedTimes();
    final keptIds = trimmed.map((s) => s.id).toSet();
    times.removeWhere((id, _) => !keptIds.contains(id));
    times[song.id] = DateTime.now().millisecondsSinceEpoch;
    await _saveRecentlyPlayedTimes(times);
    // Keeps the id list and play-count stats in step with the history.
    await addRecentlyPlayed(song.id);
  }

  /// Last played time (epoch millis) for every remembered song id.
  Map<String, int> getRecentlyPlayedTimes() {
    final raw = _prefs.getString(_keyRecentlyPlayedTimes);
    if (raw == null || raw.isEmpty) return <String, int>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, int>{};
      final result = <String, int>{};
      decoded.forEach((key, value) {
        if (key is String && value is int) result[key] = value;
      });
      return result;
    } catch (_) {
      return <String, int>{};
    }
  }

  Future<void> _saveRecentlyPlayedTimes(Map<String, int> times) async {
    await _prefs.setString(_keyRecentlyPlayedTimes, jsonEncode(times));
  }

  Future<void> clearRecentlyPlayedSongs() async {
    await _prefs.remove(_keyRecentlyPlayedSongs);
    await _prefs.remove(_keyRecentlyPlayed);
    await _prefs.remove(_keyRecentlyPlayedTimes);
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

  /// Total time music has actually been playing, kept across launches.
  int getListenedSeconds() {
    return _prefs.getInt(_keyListenedSeconds) ?? 0;
  }

  Future<void> addListenedSeconds(int seconds) async {
    if (seconds <= 0) return;
    await _prefs.setInt(
      _keyListenedSeconds,
      getListenedSeconds() + seconds,
    );
  }

  // --- PLAYBACK & BATTERY PREFERENCES ---

  /// Defaults to true: unplugging headphones has always paused playback.
  bool getPauseOnHeadphoneUnplug() {
    return _prefs.getBool(_keyPauseOnUnplug) ?? true;
  }

  Future<void> setPauseOnHeadphoneUnplug(bool value) async {
    await _prefs.setBool(_keyPauseOnUnplug, value);
  }

  /// How long the volume takes to rise/fall around playback, in milliseconds.
  /// 0 turns the fade off; the shipped default is 700 ms.
  int getAudioFadeMs() {
    return (_prefs.getInt(_keyAudioFadeMs) ?? 700).clamp(0, 5000);
  }

  Future<void> setAudioFadeMs(int value) async {
    await _prefs.setInt(_keyAudioFadeMs, value.clamp(0, 5000));
  }

  bool getBatterySaver() {
    return _prefs.getBool(_keyBatterySaver) ?? false;
  }

  Future<void> setBatterySaver(bool value) async {
    await _prefs.setBool(_keyBatterySaver, value);
  }

  /// Online tracks stream at 320 kbps unless the user picks data saver.
  bool getHighQualityStreams() {
    return _prefs.getBool(_keyHighQualityStreams) ?? true;
  }

  Future<void> setHighQualityStreams(bool value) async {
    await _prefs.setBool(_keyHighQualityStreams, value);
  }

  /// Defaults to true: stop at 15% so the last percent is not spent on music.
  bool getPauseOnLowBattery() {
    return _prefs.getBool(_keyPauseOnLowBattery) ?? true;
  }

  Future<void> setPauseOnLowBattery(bool value) async {
    await _prefs.setBool(_keyPauseOnLowBattery, value);
  }

  /// Defaults to false: swiping the app away keeps background music playing.
  bool getStopWhenSwipedAway() {
    return _prefs.getBool(_keyStopWhenSwipedAway) ?? false;
  }

  Future<void> setStopWhenSwipedAway(bool value) async {
    await _prefs.setBool(_keyStopWhenSwipedAway, value);
  }

  /// Sleep-timer length the user picked last, offered first next time.
  int getSleepTimerMinutes() {
    return _prefs.getInt(_keySleepTimerMinutes) ?? 30;
  }

  Future<void> setSleepTimerMinutes(int minutes) async {
    if (minutes <= 0) return;
    await _prefs.setInt(_keySleepTimerMinutes, minutes);
  }

  /// Shuffle and repeat are remembered so the next launch keeps the same mood.
  bool getShuffleEnabled() {
    return _prefs.getBool(_keyShuffleEnabled) ?? false;
  }

  Future<void> setShuffleEnabled(bool value) async {
    await _prefs.setBool(_keyShuffleEnabled, value);
  }

  /// One of `none`, `all` or `one`.
  String getRepeatMode() {
    return _prefs.getString(_keyRepeatMode) ?? 'none';
  }

  Future<void> setRepeatMode(String mode) async {
    await _prefs.setString(_keyRepeatMode, mode);
  }

  // --- OFFLINE LYRICS CACHE ---
  //
  // Lyrics used to be fetched from LRCLIB on every player open, which meant a
  // blank karaoke pane the moment the phone lost signal. Every successful
  // fetch is now cached by song id so lyrics open instantly and work offline.
  Map<String, dynamic> _readJsonObject(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      final decoded = json.decode(raw);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  String? getCachedLyrics(String cacheKey) {
    final entry = _readJsonObject(_keyLyricsCache)[cacheKey];
    if (entry is String) {
      return entry.isEmpty ? null : entry;
    }
    // Legacy entries were stored as {"lrc": ..., "at": ...}.
    if (entry is Map && entry['lrc'] is String) {
      final lrc = entry['lrc'] as String;
      return lrc.isEmpty ? null : lrc;
    }
    return null;
  }

  int getCachedLyricsCount() => _readJsonObject(_keyLyricsCache).length;

  /// On-device size of the cached lyrics payload, shown in Profile.
  int getCachedLyricsBytes() {
    final raw = _prefs.getString(_keyLyricsCache);
    if (raw == null || raw.isEmpty) return 0;
    return utf8.encode(raw).length;
  }

  Future<void> putCachedLyrics(String cacheKey, String lrc) async {
    if (cacheKey.isEmpty || lrc.trim().isEmpty) return;
    final cache = _readJsonObject(_keyLyricsCache);
    // Re-inserting keeps map order, so remove first to mark this entry newest.
    cache.remove(cacheKey);
    cache[cacheKey] = lrc;

    // JSON object order is insertion order in Dart, so the first keys are the
    // oldest lyrics and are dropped first once the cache is full.
    if (cache.length > _lyricsCacheLimit) {
      final excess = cache.length - _lyricsCacheLimit;
      for (final key in cache.keys.take(excess).toList()) {
        cache.remove(key);
      }
    }

    await _prefs.setString(_keyLyricsCache, json.encode(cache));
  }

  Future<void> clearCachedLyrics() async {
    await _prefs.remove(_keyLyricsCache);
  }

  // --- LYRICS SYNC OFFSET ---
  //
  // Streaming services master lyrics slightly differently from each release,
  // so the user can nudge the karaoke timing per song. Kept between launches.
  int getLyricsOffsetMs(String songId) {
    final value = _readJsonObject(_keyLyricsOffsets)[songId];
    final offset = value is int ? value : int.tryParse('$value') ?? 0;
    return offset.clamp(-10000, 10000);
  }

  Future<void> setLyricsOffsetMs(String songId, int offsetMs) async {
    if (songId.isEmpty) return;
    final offsets = _readJsonObject(_keyLyricsOffsets);
    final clamped = offsetMs.clamp(-10000, 10000);
    if (clamped == 0) {
      offsets.remove(songId);
    } else {
      offsets[songId] = clamped;
    }
    await _prefs.setString(_keyLyricsOffsets, json.encode(offsets));
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
      'equalizerPreset': 'Vibrant Bass Boost',
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
