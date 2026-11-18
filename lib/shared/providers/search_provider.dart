import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundwave/features/library/services/library_storage_service.dart';
import 'package:soundwave/features/online/services/online_music_service.dart';
import 'package:soundwave/features/player/models/song_model.dart';
import 'package:soundwave/shared/providers/library_provider.dart';

enum SearchFilter { all, online, songs, artists, albums, localOnly }

class SearchState {
  final String query;
  final SearchFilter filter;
  final List<SongModel> results;
  final List<SongModel> onlineResults;
  final bool isSearchingOnline;
  final List<SongModel> trendingOnline;
  final List<String> recentSearches;
  final List<String> suggestions;

  const SearchState({
    this.query = '',
    this.filter = SearchFilter.all,
    this.results = const [],
    this.onlineResults = const [],
    this.isSearchingOnline = false,
    this.trendingOnline = const [],
    this.recentSearches = const [],
    this.suggestions = const [],
  });

  SearchState copyWith({
    String? query,
    SearchFilter? filter,
    List<SongModel>? results,
    List<SongModel>? onlineResults,
    bool? isSearchingOnline,
    List<SongModel>? trendingOnline,
    List<String>? recentSearches,
    List<String>? suggestions,
  }) {
    return SearchState(
      query: query ?? this.query,
      filter: filter ?? this.filter,
      results: results ?? this.results,
      onlineResults: onlineResults ?? this.onlineResults,
      isSearchingOnline: isSearchingOnline ?? this.isSearchingOnline,
      trendingOnline: trendingOnline ?? this.trendingOnline,
      recentSearches: recentSearches ?? this.recentSearches,
      suggestions: suggestions ?? this.suggestions,
    );
  }
}

class SearchNotifier extends Notifier<SearchState> {
  LibraryStorageService get _storage => ref.read(storageServiceProvider);
  List<SongModel> get _allSongs => ref.read(libraryProvider).allSongs;
  Timer? _debounceTimer;
  bool _isDisposed = false;

  @override
  SearchState build() {
    _isDisposed = false;
    ref.onDispose(() {
      _isDisposed = true;
      _debounceTimer?.cancel();
    });

    // Load trending online songs on initial build
    Future.microtask(() => loadTrendingOnline());

    return SearchState(
      recentSearches: _storage.getRecentSearches(),
    );
  }

  Future<void> refreshTrending() => loadTrendingOnline();

  Future<void> loadTrendingOnline() async {
    try {
      final trending = await OnlineMusicService.getTrendingSongs();
      if (_isDisposed) return;
      if (trending.isNotEmpty) {
        state = state.copyWith(trendingOnline: trending);
      }
    } catch (e) {
      debugPrint('Error loading trending online songs: $e');
    }
  }

  void setFilter(SearchFilter filter) {
    state = state.copyWith(filter: filter);
    _performLocalSearch(state.query);
  }

  void onQueryChanged(String query) {
    _performLocalSearch(query);

    // Debounce online search to avoid spamming the API
    _debounceTimer?.cancel();
    final trimmed = query.trim();
    if (trimmed.length >= 2) {
      _debounceTimer = Timer(const Duration(milliseconds: 400), () {
        _performOnlineSearch(trimmed);
      });
    } else {
      state = state.copyWith(onlineResults: [], isSearchingOnline: false);
    }
  }

  void _performLocalSearch(String query) {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) {
      state = state.copyWith(
        query: query,
        results: [],
        suggestions: [],
      );
      return;
    }

    final suggestions = <String>{};
    for (final song in _allSongs) {
      if (song.title.toLowerCase().contains(trimmed)) {
        suggestions.add(song.title);
      }
      if (song.artist.toLowerCase().contains(trimmed)) {
        suggestions.add(song.artist);
      }
    }

    final filtered = _allSongs.where((song) {
      final matchesQuery = song.title.toLowerCase().contains(trimmed) ||
          song.artist.toLowerCase().contains(trimmed) ||
          song.album.toLowerCase().contains(trimmed) ||
          song.genre.toLowerCase().contains(trimmed);

      if (!matchesQuery) return false;

      switch (state.filter) {
        case SearchFilter.all:
        case SearchFilter.songs:
          return true;
        case SearchFilter.online:
          return false; // Online only tab hides local songs
        case SearchFilter.artists:
          return song.artist.toLowerCase().contains(trimmed);
        case SearchFilter.albums:
          return song.album.toLowerCase().contains(trimmed);
        case SearchFilter.localOnly:
          return song.isLocal;
      }
    }).toList();

    state = state.copyWith(
      query: query,
      results: filtered,
      suggestions: suggestions.take(5).toList(),
    );
  }

  Future<void> _performOnlineSearch(String query) async {
    if (_isDisposed) return;
    state = state.copyWith(isSearchingOnline: true);
    try {
      final onlineSongs = await OnlineMusicService.searchSongs(query);
      if (_isDisposed) return;
      if (state.query.trim() == query.trim()) {
        state = state.copyWith(
          onlineResults: onlineSongs,
          isSearchingOnline: false,
        );
      }
    } catch (e) {
      debugPrint('Online search error: $e');
      if (!_isDisposed) {
        state = state.copyWith(isSearchingOnline: false);
      }
    }
  }

  Future<void> submitSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    await _storage.addRecentSearch(trimmed);
    state = state.copyWith(
      recentSearches: _storage.getRecentSearches(),
    );
    _performLocalSearch(trimmed);
    _performOnlineSearch(trimmed);
  }

  Future<void> clearHistory() async {
    await _storage.clearRecentSearches();
    state = state.copyWith(recentSearches: []);
  }
}

final searchProvider =
    NotifierProvider<SearchNotifier, SearchState>(SearchNotifier.new);
