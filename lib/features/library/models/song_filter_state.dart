import 'package:soundwave/features/player/models/song_model.dart';

enum SongCategoryFilter {
  all,
  favorites,
  recentlyPlayed,
  recentlyAdded,
  downloads,
  unknownSongs,
  artists,
  albums,
  genres,
  // New genre-based categories
  hindi,
  marathi,
  romantic,
  partyDance,
  trending,
  lofi,
  panjabi,
  devotional,
  studyMusic;

  String get label {
    switch (this) {
      case SongCategoryFilter.all:
        return 'All Songs';
      case SongCategoryFilter.favorites:
        return 'Favorites';
      case SongCategoryFilter.recentlyPlayed:
        return 'Recently Played';
      case SongCategoryFilter.recentlyAdded:
        return 'Recently Added';
      case SongCategoryFilter.downloads:
        return 'Downloads';
      case SongCategoryFilter.unknownSongs:
        return 'Unknown Songs';
      case SongCategoryFilter.artists:
        return 'Singers';
      case SongCategoryFilter.albums:
        return 'Albums';
      case SongCategoryFilter.genres:
        return 'Genres';
      case SongCategoryFilter.hindi:
        return 'Hindi';
      case SongCategoryFilter.marathi:
        return 'Marathi';
      case SongCategoryFilter.romantic:
        return 'Romantic';
      case SongCategoryFilter.partyDance:
        return 'Party/Dance';
      case SongCategoryFilter.trending:
        return 'Trending';
      case SongCategoryFilter.lofi:
        return 'Lofi';
      case SongCategoryFilter.panjabi:
        return 'Panjabi';
      case SongCategoryFilter.devotional:
        return 'Devotional';
      case SongCategoryFilter.studyMusic:
        return 'Study Music';
    }
  }
}

enum DurationFilter {
  all,
  under3Min,
  threeToFiveMin,
  above5Min;

  String get label {
    switch (this) {
      case DurationFilter.all:
        return 'Any Duration';
      case DurationFilter.under3Min:
        return 'Under 3 min';
      case DurationFilter.threeToFiveMin:
        return '3–5 min';
      case DurationFilter.above5Min:
        return 'Above 5 min';
    }
  }
}

enum SongSizeFilter {
  all,
  under5MB,
  fiveToFifteenMB,
  above15MB;

  String get label {
    switch (this) {
      case SongSizeFilter.all:
        return 'Any Size';
      case SongSizeFilter.under5MB:
        return '< 5 MB';
      case SongSizeFilter.fiveToFifteenMB:
        return '5–15 MB';
      case SongSizeFilter.above15MB:
        return '> 15 MB (HQ)';
    }
  }
}

enum SongSortOption {
  nameAsc,
  nameDesc,
  artistAsc,
  artistDesc,
  albumAsc,
  durationAsc,
  durationDesc,
  sizeDesc,
  sizeAsc,
  recentlyAdded,
  dateOldest,
  recentlyPlayed;

  String get label {
    switch (this) {
      case SongSortOption.nameAsc:
        return 'Name: A to Z';
      case SongSortOption.nameDesc:
        return 'Name: Z to A';
      case SongSortOption.artistAsc:
        return 'Singer: A to Z';
      case SongSortOption.artistDesc:
        return 'Singer: Z to A';
      case SongSortOption.albumAsc:
        return 'Album Name';
      case SongSortOption.durationAsc:
        return 'Duration: Shortest first';
      case SongSortOption.durationDesc:
        return 'Duration: Longest first';
      case SongSortOption.sizeDesc:
        return 'File Size: Largest first';
      case SongSortOption.sizeAsc:
        return 'File Size: Smallest first';
      case SongSortOption.recentlyAdded:
        return 'Date: Newest first';
      case SongSortOption.dateOldest:
        return 'Date: Oldest first';
      case SongSortOption.recentlyPlayed:
        return 'Recently Played';
    }
  }
}

class SongFilterState {
  final SongCategoryFilter category;
  final String? selectedArtist;
  final String? selectedAlbum;
  final String? selectedGenre;
  final DurationFilter duration;
  final SongSizeFilter size;
  final SongSortOption sortBy;
  final String searchQuery;

  const SongFilterState({
    this.category = SongCategoryFilter.all,
    this.selectedArtist,
    this.selectedAlbum,
    this.selectedGenre,
    this.duration = DurationFilter.all,
    this.size = SongSizeFilter.all,
    this.sortBy = SongSortOption.nameAsc,
    this.searchQuery = '',
  });

  bool get hasActiveFilters =>
      category != SongCategoryFilter.all ||
      selectedArtist != null ||
      selectedAlbum != null ||
      selectedGenre != null ||
      duration != DurationFilter.all ||
      size != SongSizeFilter.all ||
      searchQuery.trim().isNotEmpty;

  int get activeFilterCount {
    int count = 0;
    if (category != SongCategoryFilter.all) count++;
    if (selectedArtist != null) count++;
    if (selectedAlbum != null) count++;
    if (selectedGenre != null) count++;
    if (duration != DurationFilter.all) count++;
    if (size != SongSizeFilter.all) count++;
    if (searchQuery.trim().isNotEmpty) count++;
    return count;
  }

  SongFilterState copyWith({
    SongCategoryFilter? category,
    String? selectedArtist,
    String? selectedAlbum,
    String? selectedGenre,
    DurationFilter? duration,
    SongSizeFilter? size,
    SongSortOption? sortBy,
    String? searchQuery,
    bool clearArtist = false,
    bool clearAlbum = false,
    bool clearGenre = false,
  }) {
    return SongFilterState(
      category: category ?? this.category,
      selectedArtist: clearArtist ? null : (selectedArtist ?? this.selectedArtist),
      selectedAlbum: clearAlbum ? null : (selectedAlbum ?? this.selectedAlbum),
      selectedGenre: clearGenre ? null : (selectedGenre ?? this.selectedGenre),
      duration: duration ?? this.duration,
      size: size ?? this.size,
      sortBy: sortBy ?? this.sortBy,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  SongFilterState reset() {
    return const SongFilterState();
  }
}

class SongFilterHelper {
  static List<SongModel> filterAndSort({
    required List<SongModel> songs,
    required SongFilterState filterState,
    required Set<String> favoriteIds,
    required List<String> recentlyPlayedIds,
  }) {
    var list = List<SongModel>.from(songs);

    // 1. Category Filter
    switch (filterState.category) {
      case SongCategoryFilter.all:
        break;
      case SongCategoryFilter.favorites:
        list = list.where((s) => favoriteIds.contains(s.id)).toList();
        break;
      case SongCategoryFilter.recentlyPlayed:
        list = list.where((s) => recentlyPlayedIds.contains(s.id)).toList();
        break;
      case SongCategoryFilter.recentlyAdded:
        break;
      case SongCategoryFilter.downloads:
        list = list.where((s) => s.isLocal).toList();
        break;
      case SongCategoryFilter.unknownSongs:
        list = list.where((s) => s.isUnknownArtist).toList();
        break;
      case SongCategoryFilter.artists:
      case SongCategoryFilter.albums:
      case SongCategoryFilter.genres:
        break;
      // Genre-based category filters
      case SongCategoryFilter.hindi:
        list = list.where((s) {
          final g = s.genre.toLowerCase();
          return g.contains('hindi') || g.contains('bollywood');
        }).toList();
        break;
      case SongCategoryFilter.marathi:
        list = list.where((s) {
          final g = s.genre.toLowerCase();
          return g.contains('marathi');
        }).toList();
        break;
      case SongCategoryFilter.romantic:
        list = list.where((s) {
          final g = s.genre.toLowerCase();
          return g.contains('romantic') || g.contains('love');
        }).toList();
        break;
      case SongCategoryFilter.partyDance:
        list = list.where((s) {
          final g = s.genre.toLowerCase();
          return g.contains('party') || g.contains('dance') || g.contains('edm');
        }).toList();
        break;
      case SongCategoryFilter.trending:
        list = list.where((s) {
          final g = s.genre.toLowerCase();
          return g.contains('trending') || g.contains('popular') || g.contains('viral');
        }).toList();
        break;
      case SongCategoryFilter.lofi:
        list = list.where((s) {
          final g = s.genre.toLowerCase();
          return g.contains('lofi') || g.contains('lo-fi') || g.contains('chill');
        }).toList();
        break;
      case SongCategoryFilter.panjabi:
        list = list.where((s) {
          final g = s.genre.toLowerCase();
          return g.contains('panjabi') || g.contains('punjabi');
        }).toList();
        break;
      case SongCategoryFilter.devotional:
        list = list.where((s) {
          final g = s.genre.toLowerCase();
          return g.contains('devotional') || g.contains('bhakti') || g.contains('spiritual');
        }).toList();
        break;
      case SongCategoryFilter.studyMusic:
        list = list.where((s) {
          final g = s.genre.toLowerCase();
          return g.contains('study') || g.contains('focus') || g.contains('ambient');
        }).toList();
        break;
    }

    // 2. Specific Artist Filter
    if (filterState.selectedArtist != null) {
      final a = filterState.selectedArtist!.trim().toLowerCase();
      list = list.where((s) => s.artist.trim().toLowerCase() == a).toList();
    }

    // 3. Specific Album Filter
    if (filterState.selectedAlbum != null) {
      final al = filterState.selectedAlbum!.trim().toLowerCase();
      list = list.where((s) => s.album.trim().toLowerCase() == al).toList();
    }

    // 4. Specific Genre Filter
    if (filterState.selectedGenre != null) {
      final g = filterState.selectedGenre!.trim().toLowerCase();
      list = list.where((s) => s.genre.trim().toLowerCase() == g).toList();
    }

    // 5. Duration Filter
    switch (filterState.duration) {
      case DurationFilter.all:
        break;
      case DurationFilter.under3Min:
        list = list.where((s) => s.duration.inSeconds < 180).toList();
        break;
      case DurationFilter.threeToFiveMin:
        list = list
            .where((s) =>
                s.duration.inSeconds >= 180 && s.duration.inSeconds <= 300)
            .toList();
        break;
      case DurationFilter.above5Min:
        list = list.where((s) => s.duration.inSeconds > 300).toList();
        break;
    }

    // 6. File Size Filter
    const fiveMB = 5 * 1024 * 1024;
    const fifteenMB = 15 * 1024 * 1024;
    switch (filterState.size) {
      case SongSizeFilter.all:
        break;
      case SongSizeFilter.under5MB:
        list = list.where((s) => (s.fileSize ?? 0) > 0 && (s.fileSize! < fiveMB)).toList();
        break;
      case SongSizeFilter.fiveToFifteenMB:
        list = list.where((s) {
          final sz = s.fileSize ?? 0;
          return sz >= fiveMB && sz <= fifteenMB;
        }).toList();
        break;
      case SongSizeFilter.above15MB:
        list = list.where((s) => (s.fileSize ?? 0) > fifteenMB).toList();
        break;
    }

    // 7. Search Query
    final query = filterState.searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((s) {
        final title = s.title.toLowerCase();
        final artist = s.artist.toLowerCase();
        final album = s.album.toLowerCase();
        return title.contains(query) ||
            artist.contains(query) ||
            album.contains(query);
      }).toList();
    }

    // 8. Sort Options
    switch (filterState.sortBy) {
      case SongSortOption.nameAsc:
        list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case SongSortOption.nameDesc:
        list.sort((a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
        break;
      case SongSortOption.artistAsc:
        list.sort((a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()));
        break;
      case SongSortOption.artistDesc:
        list.sort((a, b) => b.artist.toLowerCase().compareTo(a.artist.toLowerCase()));
        break;
      case SongSortOption.albumAsc:
        list.sort((a, b) => a.album.toLowerCase().compareTo(b.album.toLowerCase()));
        break;
      case SongSortOption.durationAsc:
        list.sort((a, b) => a.duration.compareTo(b.duration));
        break;
      case SongSortOption.durationDesc:
        list.sort((a, b) => b.duration.compareTo(a.duration));
        break;
      case SongSortOption.sizeDesc:
        list.sort((a, b) => (b.fileSize ?? 0).compareTo(a.fileSize ?? 0));
        break;
      case SongSortOption.sizeAsc:
        list.sort((a, b) => (a.fileSize ?? 0).compareTo(b.fileSize ?? 0));
        break;
      case SongSortOption.recentlyAdded:
        list.sort((a, b) {
          final da = a.dateAdded ?? DateTime.fromMillisecondsSinceEpoch(0);
          final db = b.dateAdded ?? DateTime.fromMillisecondsSinceEpoch(0);
          return db.compareTo(da);
        });
        break;
      case SongSortOption.dateOldest:
        list.sort((a, b) {
          final da = a.dateAdded ?? DateTime.fromMillisecondsSinceEpoch(0);
          final db = b.dateAdded ?? DateTime.fromMillisecondsSinceEpoch(0);
          return da.compareTo(db);
        });
        break;
      case SongSortOption.recentlyPlayed:
        list.sort((a, b) {
          final idxA = recentlyPlayedIds.indexOf(a.id);
          final idxB = recentlyPlayedIds.indexOf(b.id);
          if (idxA == -1 && idxB == -1) return 0;
          if (idxA == -1) return 1;
          if (idxB == -1) return -1;
          return idxA.compareTo(idxB);
        });
        break;
    }

    return list;
  }

  static List<String> getUniqueArtists(List<SongModel> songs) {
    final set = <String>{};
    for (final s in songs) {
      final a = s.artist.trim();
      if (a.isNotEmpty &&
          a != '<unknown>' &&
          a != 'Unknown Artist' &&
          a != 'Device Storage') {
        set.add(a);
      }
    }
    final list = set.toList();
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  static List<String> getUniqueAlbums(List<SongModel> songs) {
    final set = <String>{};
    for (final s in songs) {
      final al = s.album.trim();
      if (al.isNotEmpty && al != '<unknown>' && al != 'Unknown Album' && al != 'Downloads') {
        set.add(al);
      }
    }
    final list = set.toList();
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  static List<String> getUniqueGenres(List<SongModel> songs) {
    final set = <String>{};
    for (final s in songs) {
      final g = s.genre.trim();
      if (g.isNotEmpty && g != '<unknown>' && g != 'Unknown') {
        set.add(g);
      }
    }
    final list = set.toList();
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }
}
