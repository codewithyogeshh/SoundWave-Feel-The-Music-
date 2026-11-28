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
  final List<String> onlineSuggestions;
  final bool hasMoreOnline;
  final bool isLoadingMore;
  final int onlinePage;
  final int onlineTotal;

  const SearchState({
    this.query = '',
    this.filter = SearchFilter.all,
    this.results = const [],
    this.onlineResults = const [],
    this.isSearchingOnline = false,
    this.trendingOnline = const [],
    this.recentSearches = const [],
    this.suggestions = const [],
    this.onlineSuggestions = const [],
    this.hasMoreOnline = false,
    this.isLoadingMore = false,
    this.onlinePage = 1,
    this.onlineTotal = 0,
  });

  /// Every song the current search found so far, online results first, ready
  /// to be played or reordered as one long playlist.
  List<SongModel> get allOnlineAndLocal => [
        ...onlineResults,
        ...results.where((local) => !onlineResults.any((o) => o.id == local.id)),
      ];

  SearchState copyWith({
    String? query,
    SearchFilter? filter,
    List<SongModel>? results,
    List<SongModel>? onlineResults,
    bool? isSearchingOnline,
    List<SongModel>? trendingOnline,
    List<String>? recentSearches,
    List<String>? suggestions,
    List<String>? onlineSuggestions,
    bool? hasMoreOnline,
    bool? isLoadingMore,
    int? onlinePage,
    int? onlineTotal,
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
      onlineSuggestions: onlineSuggestions ?? this.onlineSuggestions,
      hasMoreOnline: hasMoreOnline ?? this.hasMoreOnline,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      onlinePage: onlinePage ?? this.onlinePage,
      onlineTotal: onlineTotal ?? this.onlineTotal,
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
      _debounceTimer = Timer(const Duration(milliseconds: 350), () {
        _performOnlineSearch(trimmed);
        _loadSuggestions(trimmed);
      });
    } else {
      state = state.copyWith(
        onlineResults: [],
        isSearchingOnline: false,
        onlineSuggestions: [],
        hasMoreOnline: false,
        isLoadingMore: false,
        onlinePage: 1,
        onlineTotal: 0,
      );
    }
  }

  /// Live typing suggestions so search feels like YouTube Music: a short list
  /// of real songs/artists appears while the user is still typing.
  Future<void> _loadSuggestions(String query) async {
    try {
      final suggestions = await OnlineMusicService.searchSuggestions(query);
      if (_isDisposed) return;
      if (state.query.trim() != query.trim()) return;
      state = state.copyWith(onlineSuggestions: suggestions);
    } catch (e) {
      debugPrint('Suggestion error: $e');
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
    state = state.copyWith(isSearchingOnline: true, isLoadingMore: false);
    try {
      final page = await OnlineMusicService.searchPage(query);
      if (_isDisposed) return;
      if (state.query.trim() == query.trim()) {
        state = state.copyWith(
          onlineResults: page.songs,
          isSearchingOnline: false,
          hasMoreOnline: page.hasMore,
          onlinePage: 1,
          onlineTotal: page.total,
        );
      }
    } catch (e) {
      debugPrint('Online search error: $e');
      if (!_isDisposed) {
        state = state.copyWith(isSearchingOnline: false);
      }
    }
  }

  /// Loads the next page of search results for the current query. Called by
  /// the search screen when the list is scrolled near the bottom, so results
  /// never stop at one short page.
  Future<void> loadMoreResults() async {
    if (_isDisposed || state.isLoadingMore || !state.hasMoreOnline) return;
    final query = state.query.trim();
    if (query.isEmpty) return;

    final nextPage = state.onlinePage + 1;
    state = state.copyWith(isLoadingMore: true);
    try {
      final page = await OnlineMusicService.searchPage(query, page: nextPage);
      if (_isDisposed) return;
      if (state.query.trim() != query) return;

      final existingIds = state.onlineResults.map((s) => s.id).toSet();
      final existingTitles = state.onlineResults
          .map((s) => '${s.title.toLowerCase()}|${s.artist.toLowerCase()}')
          .toSet();
      final fresh = page.songs.where((song) {
        if (existingIds.contains(song.id)) return false;
        final key = '${song.title.toLowerCase()}|${song.artist.toLowerCase()}';
        return existingTitles.add(key);
      }).toList();

      state = state.copyWith(
        onlineResults: [...state.onlineResults, ...fresh],
        hasMoreOnline: page.hasMore && fresh.isNotEmpty,
        isLoadingMore: false,
        onlinePage: nextPage,
        onlineTotal: page.total > 0 ? page.total : state.onlineTotal,
      );
    } catch (e) {
      debugPrint('Load more search error: $e');
      if (!_isDisposed) {
        state = state.copyWith(isLoadingMore: false, hasMoreOnline: false);
      }
    }
  }

  Future<void> submitSearch(String query, {bool addToHistory = true}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    if (addToHistory) await _storage.addRecentSearch(trimmed);
    state = state.copyWith(
      recentSearches: _storage.getRecentSearches(),
    );
    _performLocalSearch(trimmed);
    await _performOnlineSearch(trimmed);
  }

  Future<void> clearHistory() async {
    await _storage.clearRecentSearches();
    state = state.copyWith(recentSearches: []);
  }
}

final searchProvider =
    NotifierProvider<SearchNotifier, SearchState>(SearchNotifier.new);
