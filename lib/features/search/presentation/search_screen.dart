import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundwave/app/theme/app_colors.dart';
import 'package:soundwave/app/theme/text_styles.dart';
import 'package:soundwave/app/theme/theme_model.dart';
import 'package:soundwave/core/widgets/album_artwork.dart';
import 'package:soundwave/core/widgets/empty_state_widget.dart';
import 'package:soundwave/core/widgets/glass_card.dart';
import 'package:soundwave/core/widgets/gradient_button.dart';
import 'package:soundwave/features/online/widgets/download_options_sheet.dart';
import 'package:soundwave/features/player/models/song_model.dart';
import 'package:soundwave/shared/providers/download_provider.dart';
import 'package:soundwave/shared/providers/library_provider.dart';
import 'package:soundwave/shared/providers/player_provider.dart';
import 'package:soundwave/shared/providers/search_provider.dart';
import 'package:soundwave/shared/providers/theme_provider.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _resultsScroll = ScrollController();

  /// Voice search: speak a song/artist name and it lands in the search box.
  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _resultsScroll.addListener(_onResultsScroll);
  }

  /// Loads the next page of results before the user reaches the bottom, so the
  /// list keeps scrolling instead of ending after one short page.
  void _onResultsScroll() {
    if (!_resultsScroll.hasClients) return;
    final position = _resultsScroll.position;
    if (position.pixels >= position.maxScrollExtent - 600) {
      ref.read(searchProvider.notifier).loadMoreResults();
    }
  }

  @override
  void dispose() {
    _resultsScroll.removeListener(_onResultsScroll);
    _resultsScroll.dispose();
    _speech.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Picks the phone's own Marathi/Hindi/English (India) speech model when it
  /// has one, so spoken Marathi and Hindi song names are recognised properly.
  Future<String?> _voiceLocale() async {
    try {
      final locales = await _speech.locales();
      for (final prefix in const ['mr', 'hi', 'gu', 'pa', 'ta', 'te', 'kn', 'bn', 'ml', 'en_in']) {
        for (final locale in locales) {
          final id = locale.localeId.toLowerCase().replaceAll('-', '_');
          if (id == prefix || id.startsWith('${prefix}_')) return locale.localeId;
        }
      }
    } catch (_) {
      // Fall back to the phone's default language.
    }
    return null;
  }

  void _showVoiceMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _toggleVoiceSearch() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }

    HapticFeedback.mediumImpact();
    final searchNotifier = ref.read(searchProvider.notifier);
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) return;
          if (status == 'done' || status == 'notListening') {
            setState(() => _isListening = false);
          }
        },
        onError: (error) {
          if (!mounted) return;
          setState(() => _isListening = false);
          _showVoiceMessage(
            error.errorMsg == 'error_no_match'
                ? 'काही समजलं नाही, पुन्हा प्रयत्न करा.'
                : 'आवाज ऐकता आला नाही. माइक्रोफोनची परवानगी दिली आहे का ते पहा.',
          );
        },
      );

      if (!available) {
        _showVoiceMessage(
          'या फोनवर व्हॉइस शोध उपलब्ध नाही. फोनच्या सेटिंग्जमध्ये Google व्हॉइस सेवा चालू करा.',
        );
        return;
      }

      final localeId = await _voiceLocale();
      if (!mounted) return;
      setState(() => _isListening = true);

      await _speech.listen(
        localeId: localeId,
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 3),
        onResult: (result) {
          final words = result.recognizedWords.trim();
          if (words.isEmpty) return;

          _searchController.text = words;
          _searchController.selection = TextSelection.fromPosition(
            TextPosition(offset: words.length),
          );

          if (result.finalResult) {
            if (mounted) setState(() => _isListening = false);
            _focusNode.unfocus();
            HapticFeedback.selectionClick();
            searchNotifier.submitSearch(words);
          }
        },
      );
    } catch (e) {
      if (mounted) setState(() => _isListening = false);
      _showVoiceMessage('व्हॉइस शोध सुरू करता आला नाही. पुन्हा प्रयत्न करा.');
    }
  }

  /// Plays a whole list as the queue. With [shuffle] a random song starts and
  /// shuffle is switched on, like YouTube Music's Shuffle play button.
  void _playAll(List<SongModel> songs, {bool shuffle = false}) {
    if (songs.isEmpty) return;
    HapticFeedback.mediumImpact();
    final player = ref.read(playerProvider.notifier);
    final startIndex = shuffle ? Random().nextInt(songs.length) : 0;
    player.playTrack(songs[startIndex], queue: songs);
    if (shuffle && !ref.read(playerProvider).isShuffle) {
      player.toggleShuffle();
    }
  }

  Widget _buildPlayAllButton(
    String label,
    IconData icon,
    VoidCallback onTap,
    AppThemeType activeTheme, {
    bool filled = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          gradient: filled ? activeTheme.accentGradient : null,
          color: filled ? null : AppColors.glassWhiteMedium,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: filled
                ? activeTheme.highlightColor.withValues(alpha: 0.6)
                : AppColors.glassBorderSubtle,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: filled
                  ? activeTheme.onAccentGradient
                  : activeTheme.primaryAccent,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: filled
                    ? activeTheme.onAccentGradient
                    : AppColors.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);
    final searchNotifier = ref.read(searchProvider.notifier);
    final activeTheme = ref.watch(themeProvider);
    final selectedChipTextColor = activeTheme.onPrimaryAccent;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            gradient: activeTheme.accentGradient,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: activeTheme.highlightColor.withValues(alpha: 0.42),
                                blurRadius: 16,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.search_rounded,
                            color: activeTheme.onAccentGradient,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ShaderMask(
                                shaderCallback: (rect) =>
                                    activeTheme.primaryGradient.createShader(rect),
                                blendMode: BlendMode.srcIn,
                                child: Text(
                                  'Search',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.screenTitle.copyWith(
                                    fontSize: 27,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.4,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Text(
                                'Songs, artists, movies & lyrics',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.subtitle.copyWith(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: activeTheme.highlightColor.withValues(alpha: 0.92),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: activeTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: activeTheme.primaryAccent.withValues(alpha: 0.4),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.bolt_rounded,
                          color: activeTheme.onPrimaryGradient,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '320 kbps',
                          style: TextStyle(
                            color: activeTheme.onPrimaryGradient,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Search Text Field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: GlassCard(
                borderRadius: 18,
                blur: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                color: AppColors.glassWhiteMedium,
                borderColor: searchState.query.isNotEmpty
                    ? activeTheme.primaryAccent.withValues(alpha: 0.5)
                    : AppColors.glassBorderSubtle,
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      color: activeTheme.primaryAccent,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        focusNode: _focusNode,
                        textInputAction: TextInputAction.search,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                        cursorColor: activeTheme.primaryAccent,
                        decoration: InputDecoration(
                          hintText: _isListening
                              ? 'ऐकतंय… गाणं किंवा गायकाचं नाव सांगा'
                              : 'Search any song, artist, movie or lyrics...',
                          hintStyle: TextStyle(
                            color: AppColors.textMuted.withValues(alpha: 0.8),
                            fontSize: 13.5,
                          ),
                          border: InputBorder.none,
                        ),
                        onChanged: (val) {
                          searchNotifier.onQueryChanged(val);
                        },
                        onSubmitted: (val) {
                          searchNotifier.submitSearch(val);
                        },
                      ),
                    ),
                    if (searchState.isSearchingOnline)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(activeTheme.primaryAccent),
                          ),
                        ),
                      ),
                    IconButton(
                      tooltip: _isListening ? 'Stop listening' : 'Search by voice',
                      onPressed: _toggleVoiceSearch,
                      icon: Icon(
                        _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                        color: _isListening
                            ? activeTheme.highlightColor
                            : AppColors.textMuted,
                        size: 21,
                      ),
                    ),
                    if (searchState.query.isNotEmpty || _searchController.text.isNotEmpty)
                      IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppColors.textMuted,
                          size: 20,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          searchNotifier.onQueryChanged('');
                        },
                      ),
                  ],
                ),
              ),
            ),

            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: SearchFilter.values.map((filter) {
                  final isSelected = searchState.filter == filter;
                  String label = 'All';
                  switch (filter) {
                    case SearchFilter.all:
                      label = 'All';
                      break;
                    case SearchFilter.online:
                      label = 'Online';
                      break;
                    case SearchFilter.songs:
                      label = 'Songs';
                      break;
                    case SearchFilter.artists:
                      label = 'Artists';
                      break;
                    case SearchFilter.albums:
                      label = 'Albums';
                      break;
                    case SearchFilter.localOnly:
                      label = 'Device Audio';
                      break;
                  }

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: isSelected,
                      checkmarkColor: selectedChipTextColor,
                      label: Text(label),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? selectedChipTextColor : AppColors.textSecondary,
                      ),
                      backgroundColor: AppColors.glassWhiteMedium,
                      selectedColor: activeTheme.primaryAccent,
                      side: BorderSide(
                        color: isSelected
                            ? activeTheme.highlightColor
                            : AppColors.glassBorderSubtle,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      onSelected: (_) {
                        HapticFeedback.selectionClick();
                        searchNotifier.setFilter(filter);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

            // Live typing suggestions (songs, artists, playlists)
            if (searchState.query.trim().isNotEmpty &&
                searchState.onlineSuggestions.isNotEmpty)
              SizedBox(
                height: 36,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                  itemCount: searchState.onlineSuggestions.take(6).length,
                  itemBuilder: (context, index) {
                    final suggestion = searchState.onlineSuggestions[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _searchController.text = suggestion;
                          searchNotifier.submitSearch(suggestion);
                          _focusNode.unfocus();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.glassWhiteMedium,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.glassBorderSubtle),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search_rounded,
                                size: 14,
                                color: activeTheme.primaryAccent,
                              ),
                              const SizedBox(width: 5),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 220),
                                child: Text(
                                  suggestion,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            // Main Content: Live Results OR Trending/Recent
            Expanded(
              child: _searchController.text.trim().isEmpty
                  ? _buildDefaultExploreView(context, searchState, searchNotifier, activeTheme)
                  : _buildSearchResults(context, searchState, activeTheme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultExploreView(
    BuildContext context,
    SearchState state,
    SearchNotifier notifier,
    AppThemeType activeTheme,
  ) {
    return RefreshIndicator(
      color: activeTheme.primaryAccent,
      backgroundColor: activeTheme.secondaryBackground,
      onRefresh: notifier.refreshTrending,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 175),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Trending Online Songs
            if (state.trendingOnline.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.whatshot_rounded, color: activeTheme.highlightColor, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        'Trending on Instagram',
                        style: AppTextStyles.sectionTitle.copyWith(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      _buildPlayAllButton(
                        'Play all',
                        Icons.play_arrow_rounded,
                        () => _playAll(state.trendingOnline),
                        activeTheme,
                        filled: true,
                      ),
                      const SizedBox(width: 6),
                      _buildPlayAllButton(
                        'Shuffle',
                        Icons.shuffle_rounded,
                        () => _playAll(state.trendingOnline, shuffle: true),
                        activeTheme,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: state.trendingOnline.length.clamp(0, 12),
                itemBuilder: (context, index) {
                  final song = state.trendingOnline[index];
                  return _buildSearchResultTile(song, state.trendingOnline, activeTheme);
                },
              ),
              const SizedBox(height: 24),
            ],

            // Recent Searches
            if (state.recentSearches.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Searches',
                    style: AppTextStyles.sectionTitle.copyWith(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                  ),
                  GestureDetector(
                    onTap: () => notifier.clearHistory(),
                    child: Text(
                      'Clear All',
                      style: AppTextStyles.actionLink.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: state.recentSearches.map((query) {
                  return GestureDetector(
                    onTap: () {
                      _searchController.text = query;
                      notifier.submitSearch(query);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.glassWhiteMedium,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.glassBorderSubtle),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.history_rounded,
                            color: AppColors.textMuted,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            query,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],

            // Popular Artists & Moods
            Text(
              'Explore Online Hits',
              style: AppTextStyles.sectionTitle.copyWith(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
            ),
            const SizedBox(height: 10),
            _buildPopularSearchTile('Arijit Singh Hits', Icons.trending_up_rounded, activeTheme),
            _buildPopularSearchTile('Diljit Dosanjh', Icons.trending_up_rounded, activeTheme),
            _buildPopularSearchTile('Shreya Ghoshal', Icons.trending_up_rounded, activeTheme),
            _buildPopularSearchTile('Anirudh Ravichander', Icons.electric_bolt_rounded, activeTheme),
            _buildPopularSearchTile('The Weeknd', Icons.headphones_rounded, activeTheme),
            _buildPopularSearchTile('Taylor Swift', Icons.favorite_rounded, activeTheme),
            _buildPopularSearchTile('Lo-Fi Chill Beats', Icons.spa_rounded, activeTheme),
          ],
        ),
      ),
    );
  }

  Widget _buildPopularSearchTile(String title, IconData icon, AppThemeType activeTheme) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: activeTheme.primaryAccent, size: 20),
      title: Text(title, style: AppTextStyles.songTitle.copyWith(fontSize: 14)),
      trailing: const Icon(
        Icons.north_west_rounded,
        color: AppColors.textMuted,
        size: 16,
      ),
      onTap: () {
        HapticFeedback.selectionClick();
        _searchController.text = title;
        ref.read(searchProvider.notifier).submitSearch(title);
      },
    );
  }

  Widget _buildSearchResults(
    BuildContext context,
    SearchState state,
    AppThemeType activeTheme,
  ) {
    // Prioritize high-quality online full songs first, followed by local device audio
    final combinedSongs = <SongModel>[];
    if (state.filter != SearchFilter.localOnly) {
      combinedSongs.addAll(state.onlineResults);
    }
    if (state.filter != SearchFilter.online) {
      combinedSongs.addAll(state.results);
    }

    if (combinedSongs.isEmpty) {
      if (state.isSearchingOnline) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: activeTheme.primaryAccent),
              const SizedBox(height: 16),
              const Text(
                'Searching online streams...',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        );
      }

      return EmptyStateWidget(
        icon: Icons.music_off_rounded,
        title: 'No results found',
        message: 'We could not find anything matching "${state.query}". Try searching for another artist or song.',
        buttonText: 'Clear search',
        onButtonPressed: () {
          _searchController.clear();
          ref.read(searchProvider.notifier).onQueryChanged('');
        },
      );
    }

    final loadedLabel = state.onlineTotal > combinedSongs.length
        ? '${state.onlineTotal} songs'
        : '${combinedSongs.length} songs';

    return ListView.builder(
      controller: _resultsScroll,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(left: 20, right: 20, top: 6, bottom: 175),
      itemCount: combinedSongs.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Top results',
                        style: AppTextStyles.sectionTitle.copyWith(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        loadedLabel,
                        style: AppTextStyles.subtitle.copyWith(
                          fontSize: 11.5,
                          color: activeTheme.highlightColor.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildPlayAllButton(
                  'Play all',
                  Icons.play_arrow_rounded,
                  () => _playAll(combinedSongs),
                  activeTheme,
                  filled: true,
                ),
                const SizedBox(width: 6),
                _buildPlayAllButton(
                  'Shuffle',
                  Icons.shuffle_rounded,
                  () => _playAll(combinedSongs, shuffle: true),
                  activeTheme,
                ),
              ],
            ),
          );
        }

        if (index == combinedSongs.length + 1) {
          if (state.isLoadingMore) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: activeTheme.primaryAccent,
                  ),
                ),
              ),
            );
          }
          if (state.hasMoreOnline) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: _buildPlayAllButton(
                  'Load more songs',
                  Icons.expand_more_rounded,
                  () => ref.read(searchProvider.notifier).loadMoreResults(),
                  activeTheme,
                ),
              ),
            );
          }
          return const SizedBox(height: 12);
        }

        final song = combinedSongs[index - 1];
        return _buildSearchResultTile(song, combinedSongs, activeTheme);
      },
    );
  }

  Widget _buildSearchResultTile(
    SongModel song,
    List<SongModel> queue,
    AppThemeType activeTheme,
  ) {
    final playerState = ref.watch(playerProvider);
    final libState = ref.watch(libraryProvider);
    final downloadState = ref.watch(downloadProvider);

    final isCurrent = playerState.currentSong?.id == song.id;
    final isPlaying = isCurrent && playerState.isPlaying;
    final isOnline = song.id.startsWith('online_') || !song.isLocal;
    final downloadedSong =
        libState.downloadedSongs.where((s) => s.id == song.id).firstOrNull;
    final isDownloaded = downloadedSong != null;
    final downloadedArtwork = (downloadedSong?.artworkPath?.isNotEmpty ?? false)
        ? downloadedSong!.artworkPath
        : null;
    final isDownloading = downloadState.isDownloading(song.id);
    final downloadProgress = downloadState.getProgress(song.id);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: GlassCard(
        borderRadius: 16,
        blur: 0,
        color: isCurrent
            ? activeTheme.secondaryBackground.withValues(alpha: 0.90)
            : AppColors.glassWhiteMedium,
        borderColor: isCurrent
            ? activeTheme.primaryAccent.withValues(alpha: 0.65)
            : AppColors.glassBorderSubtle,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        onTap: () {
          HapticFeedback.selectionClick();
          ref.read(playerProvider.notifier).playTrack(song, queue: queue);
        },
        child: Row(
          children: [
            AlbumArtwork(
              size: 46,
              borderRadius: 12,
              artworkUrl: downloadedArtwork ?? song.artworkPath,
              albumId: song.albumId,
              songId: song.rawId,
              songTitle: song.title,
              songArtist: song.artist,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.songTitle.copyWith(
                            fontSize: 14,
                            color: isCurrent ? activeTheme.primaryAccent : Colors.white,
                          ),
                        ),
                      ),
                      if (isOnline) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (isDownloaded
                                    ? Colors.greenAccent
                                    : activeTheme.primaryAccent)
                                .withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isDownloaded ? 'OFFLINE' : '320K',
                            style: TextStyle(
                              color: isDownloaded
                                  ? Colors.greenAccent
                                  : activeTheme.primaryAccent,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${song.artist} • ${song.album}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.artistName.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            if (isOnline) ...[
              IconButton(
                icon: isDownloading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          value: downloadProgress > 0 ? downloadProgress : null,
                          strokeWidth: 2,
                          color: activeTheme.primaryAccent,
                        ),
                      )
                    : Icon(
                        isDownloaded
                            ? Icons.check_circle_rounded
                            : Icons.arrow_circle_down_rounded,
                        color: isDownloaded
                            ? Colors.greenAccent
                            : activeTheme.primaryAccent,
                        size: 24,
                      ),
                tooltip: isDownloaded ? 'Downloaded Offline' : 'Download 320kbps',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  showDownloadOptionsSheet(context, song);
                },
              ),
            ],
            const SizedBox(width: 4),
            GradientButton.circle(
              size: 34,
              gradient: isCurrent && isPlaying
                  ? activeTheme.accentGradient
                  : const LinearGradient(
                      colors: [Colors.white, Color(0xFFE8EEFF)],
                    ),
              glowColor: activeTheme.primaryAccent,
              onPressed: () {
                if (isCurrent) {
                  ref.read(playerProvider.notifier).togglePlayPause();
                } else {
                  ref.read(playerProvider.notifier).playTrack(song, queue: queue);
                }
              },
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: Tween<double>(begin: 0.85, end: 1.0).animate(animation),
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  key: ValueKey<bool>(isPlaying),
                  color: isCurrent && isPlaying ? Colors.white : Colors.black87,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
