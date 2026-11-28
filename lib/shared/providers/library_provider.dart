import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundwave/features/library/models/playlist_model.dart';
import 'package:soundwave/features/library/services/library_storage_service.dart';
import 'package:soundwave/features/library/services/local_audio_scanner.dart';
import 'package:soundwave/features/online/services/download_service.dart';
import 'package:soundwave/features/player/models/song_model.dart';

final storageServiceProvider = Provider<LibraryStorageService>((ref) {
  throw UnimplementedError('StorageService must be overridden in main');
});

class LibraryState {
  final List<SongModel> allSongs;
  final List<SongModel> localSongs;
  final List<SongModel> downloadedSongs;
  final List<PlaylistModel> playlists;
  final Set<String> favoriteIds;
  final List<String> recentlyPlayedIds;
  final List<SongModel> recentlyPlayedSongs;

  /// When each song was last played (epoch millis), used for day sections.
  final Map<String, int> recentlyPlayedTimes;
  final bool isScanning;
  final String? scanError;

  const LibraryState({
    required this.allSongs,
    this.localSongs = const [],
    this.downloadedSongs = const [],
    this.playlists = const [],
    this.favoriteIds = const {},
    this.recentlyPlayedIds = const [],
    this.recentlyPlayedSongs = const [],
    this.recentlyPlayedTimes = const {},
    this.isScanning = false,
    this.scanError,
  });

  List<SongModel> get favoriteSongs =>
      allSongs.where((s) => favoriteIds.contains(s.id)).toList();

  bool isFavorite(String songId) => favoriteIds.contains(songId);

  bool isDownloaded(String songId) => downloadedSongs.any((s) => s.id == songId);

  LibraryState copyWith({
    List<SongModel>? allSongs,
    List<SongModel>? localSongs,
    List<SongModel>? downloadedSongs,
    List<PlaylistModel>? playlists,
    Set<String>? favoriteIds,
    List<String>? recentlyPlayedIds,
    List<SongModel>? recentlyPlayedSongs,
    Map<String, int>? recentlyPlayedTimes,
    bool? isScanning,
    String? scanError,
  }) {
    return LibraryState(
      allSongs: allSongs ?? this.allSongs,
      localSongs: localSongs ?? this.localSongs,
      downloadedSongs: downloadedSongs ?? this.downloadedSongs,
      playlists: playlists ?? this.playlists,
      favoriteIds: favoriteIds ?? this.favoriteIds,
      recentlyPlayedIds: recentlyPlayedIds ?? this.recentlyPlayedIds,
      recentlyPlayedSongs: recentlyPlayedSongs ?? this.recentlyPlayedSongs,
      recentlyPlayedTimes: recentlyPlayedTimes ?? this.recentlyPlayedTimes,
      isScanning: isScanning ?? this.isScanning,
      scanError: scanError,
    );
  }
}

class LibraryNotifier extends Notifier<LibraryState> {
  LibraryStorageService get _storage => ref.read(storageServiceProvider);
  final LocalAudioScanner _scanner = LocalAudioScanner();
  bool _isDisposed = false;

  List<SongModel> _mergeAllSongs(
    List<SongModel> downloaded,
    List<SongModel> local,
  ) {
    final downloadedIds = downloaded.map((s) => s.id).toSet();
    final downloadedPaths = downloaded
        .map((s) => s.audioPath)
        .where((p) => p.isNotEmpty)
        .toSet();
    return [
      ...downloaded,
      ...local.where(
        (s) =>
            !downloadedIds.contains(s.id) &&
            !downloadedPaths.contains(s.audioPath),
      ),
    ];
  }

  bool _hasValidLocalArtwork(SongModel song) {
    if (kIsWeb) return true;
    final art = song.artworkPath?.trim();
    if (art == null ||
        art.isEmpty ||
        art.startsWith('http://') ||
        art.startsWith('https://') ||
        art.startsWith('assets/') ||
        art.startsWith('asset://')) {
      return false;
    }
    final normalized = art.startsWith('file://')
        ? (Uri.tryParse(art)?.toFilePath() ?? art.substring(7))
        : art;
    final file = File(normalized);
    return file.existsSync() && file.lengthSync() > 0;
  }

  @override
  LibraryState build() {
    _isDisposed = false;
    ref.onDispose(() => _isDisposed = true);

    final cachedSongs = _storage.getLocalSongs();
    final downloaded = _storage.getDownloadedSongs();

    // If cache is empty, scan local songs in background
    if (cachedSongs.isEmpty) {
      Future.microtask(() => scanLocalMusic());
    }

    // Backfill offline cover banners for any previously downloaded songs
    if (downloaded.isNotEmpty) {
      Future.microtask(() => repairOfflineDownloadArtworks());
    }

    return LibraryState(
      allSongs: _mergeAllSongs(downloaded, cachedSongs),
      localSongs: cachedSongs,
      downloadedSongs: downloaded,
      playlists: _storage.getPlaylists(),
      favoriteIds: _storage.getFavoriteIds(),
      recentlyPlayedIds: _storage.getRecentlyPlayedIds(),
      recentlyPlayedSongs: _storage.getRecentlyPlayedSongs(),
      recentlyPlayedTimes: _storage.getRecentlyPlayedTimes(),
    );
  }

  Future<void> repairOfflineDownloadArtworks() async {
    if (kIsWeb || _isDisposed) return;

    final snapshot = List<SongModel>.from(state.downloadedSongs);
    final repairedById = <String, SongModel>{};

    for (final song in snapshot) {
      if (_isDisposed) return;
      if (_hasValidLocalArtwork(song)) continue;

      final localArtPath = await DownloadService.ensureLocalArtworkForSong(song);
      if (_isDisposed) return;

      if (localArtPath != null && localArtPath != song.artworkPath) {
        final updated = song.copyWith(artworkPath: localArtPath);
        await _storage.saveDownloadedSong(updated);
        repairedById[updated.id] = updated;
      }
    }

    if (repairedById.isEmpty || _isDisposed) return;

    final updatedDownloads = _storage.getDownloadedSongs();
    final updatedPlaylists = state.playlists.map((p) {
      final hasMatch = p.songs.any((s) => repairedById.containsKey(s.id));
      if (!hasMatch) return p;
      return p.copyWith(
        songs: p.songs.map((s) => repairedById[s.id] ?? s).toList(),
      );
    }).toList();

    await _storage.savePlaylists(updatedPlaylists);
    if (_isDisposed) return;

    state = state.copyWith(
      downloadedSongs: updatedDownloads,
      allSongs: _mergeAllSongs(updatedDownloads, state.localSongs),
      playlists: updatedPlaylists,
    );
  }

  Future<void> addDownloadedSong(SongModel song) async {
    await _storage.saveDownloadedSong(song);
    if (_isDisposed) return;
    final updatedDownloads = _storage.getDownloadedSongs();

    // Sync into 'pl_my_downloads' playlist
    final updatedPlaylists = state.playlists.map((p) {
      if (p.id == 'pl_my_downloads') {
        final songs = List<SongModel>.from(p.songs);
        songs.removeWhere((s) => s.id == song.id);
        songs.insert(0, song);
        return p.copyWith(songs: songs);
      }
      return p;
    }).toList();

    await _storage.savePlaylists(updatedPlaylists);
    if (_isDisposed) return;

    state = state.copyWith(
      downloadedSongs: updatedDownloads,
      allSongs: _mergeAllSongs(updatedDownloads, state.localSongs),
      playlists: updatedPlaylists,
    );
  }

  Future<void> removeDownloadedSong(String songId) async {
    await _storage.removeDownloadedSong(songId);
    if (_isDisposed) return;
    final updatedDownloads = _storage.getDownloadedSongs();

    final updatedPlaylists = state.playlists.map((p) {
      if (p.id == 'pl_my_downloads') {
        final songs = p.songs.where((s) => s.id != songId).toList();
        return p.copyWith(songs: songs);
      }
      return p;
    }).toList();

    await _storage.savePlaylists(updatedPlaylists);
    if (_isDisposed) return;

    state = state.copyWith(
      downloadedSongs: updatedDownloads,
      allSongs: _mergeAllSongs(updatedDownloads, state.localSongs),
      playlists: updatedPlaylists,
    );
  }

  bool isDownloaded(String songId) {
    return state.downloadedSongs.any((s) => s.id == songId);
  }

  Future<void> scanLocalMusic({bool silent = false}) async {
    if (_isDisposed) return;
    if (!silent) {
      state = state.copyWith(isScanning: true, scanError: null);
    }
    try {
      final scanned = await _scanner.scanLocalAudio();
      if (_isDisposed) return;

      // Save real scanned songs into permanent storage
      await _storage.saveLocalSongs(scanned);
      if (_isDisposed) return;

      state = state.copyWith(
        localSongs: scanned,
        allSongs: _mergeAllSongs(state.downloadedSongs, scanned),
        isScanning: false,
      );
    } catch (e) {
      if (_isDisposed) return;
      state = state.copyWith(
        isScanning: false,
        scanError: 'Failed to scan device music: $e',
      );
    }
  }

  Future<void> toggleFavorite(SongModel song) async {
    final updated = Set<String>.from(state.favoriteIds);
    if (updated.contains(song.id)) {
      updated.remove(song.id);
    } else {
      updated.add(song.id);
    }

    state = state.copyWith(favoriteIds: updated);
    await _storage.saveFavoriteIds(updated);
  }

  bool isFavorite(String songId) => state.favoriteIds.contains(songId);

  Future<void> recordPlayed(SongModel song) async {
    await _storage.addRecentlyPlayedSong(song);
    state = state.copyWith(
      recentlyPlayedIds: _storage.getRecentlyPlayedIds(),
      recentlyPlayedSongs: _storage.getRecentlyPlayedSongs(),
      recentlyPlayedTimes: _storage.getRecentlyPlayedTimes(),
    );
  }

  /// Wipes the listening history but leaves downloads, playlists and
  /// favourites untouched.
  Future<void> clearHistory() async {
    await _storage.clearRecentlyPlayedSongs();
    state = state.copyWith(
      recentlyPlayedIds: const [],
      recentlyPlayedSongs: const [],
      recentlyPlayedTimes: const {},
    );
  }

  Future<void> createPlaylist(String name, {String description = ''}) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return;

    final newPlaylist = PlaylistModel(
      id: 'pl_custom_${DateTime.now().millisecondsSinceEpoch}',
      name: trimmedName,
      description: description,
      coverImage:
          'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&q=80',
      songs: [],
      createdAt: DateTime.now(),
      isCustom: true,
    );

    final updated = [...state.playlists, newPlaylist];
    state = state.copyWith(playlists: updated);
    await _storage.savePlaylists(updated);
  }

  Future<void> renamePlaylist(String id, String newName) async {
    final updated = state.playlists.map((p) {
      if (p.id == id) {
        return p.copyWith(name: newName);
      }
      return p;
    }).toList();

    state = state.copyWith(playlists: updated);
    await _storage.savePlaylists(updated);
  }

  Future<void> deletePlaylist(String id) async {
    final updated = state.playlists.where((p) => p.id != id).toList();
    state = state.copyWith(playlists: updated);
    await _storage.savePlaylists(updated);
  }

  Future<void> addSongToPlaylist(String playlistId, SongModel song) async {
    final updated = state.playlists.map((p) {
      if (p.id == playlistId) {
        if (p.songs.any((s) => s.id == song.id)) return p;
        return p.copyWith(songs: [...p.songs, song]);
      }
      return p;
    }).toList();

    state = state.copyWith(playlists: updated);
    await _storage.savePlaylists(updated);
  }

  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    final updated = state.playlists.map((p) {
      if (p.id == playlistId) {
        return p.copyWith(
          songs: p.songs.where((s) => s.id != songId).toList(),
        );
      }
      return p;
    }).toList();

    state = state.copyWith(playlists: updated);
    await _storage.savePlaylists(updated);
  }
}

final libraryProvider =
    NotifierProvider<LibraryNotifier, LibraryState>(LibraryNotifier.new);
