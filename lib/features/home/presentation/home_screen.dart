import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundwave/app/theme/app_colors.dart';
import 'package:soundwave/app/theme/text_styles.dart';
import 'package:soundwave/app/theme/theme_model.dart';
import 'package:soundwave/core/widgets/album_artwork.dart';
import 'package:soundwave/core/widgets/glass_card.dart';
import 'package:soundwave/core/widgets/gradient_button.dart';
import 'package:soundwave/core/widgets/loading_widget.dart';
import 'package:soundwave/core/widgets/reveal.dart';
import 'package:soundwave/core/widgets/section_header.dart';
import 'package:soundwave/features/online/widgets/download_options_sheet.dart';
import 'package:soundwave/features/online/widgets/online_song_tile.dart';
import 'package:soundwave/features/online/widgets/trending_song_card.dart';
import 'package:soundwave/features/player/models/song_model.dart';
import 'package:soundwave/shared/providers/library_provider.dart';
import 'package:soundwave/shared/providers/online_music_provider.dart';
import 'package:soundwave/shared/providers/player_provider.dart';
import 'package:soundwave/shared/providers/theme_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final VoidCallback? onNavigateToExplore;
  final VoidCallback? onNavigateToLibrary;
  final VoidCallback? onNavigateToSearch;
  final VoidCallback? onNavigateToProfile;

  const HomeScreen({
    super.key,
    this.onNavigateToExplore,
    this.onNavigateToLibrary,
    this.onNavigateToSearch,
    this.onNavigateToProfile,
  });

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _selectedGenre = 'All';

  final List<String> _genrePills = [
    'All',
    'Trending',
    'Top Hindi',
    'Marathi',
    'Romantic',
    'Party Dance',
    'Lo-Fi',
    'Punjabi',
    'Devotional',
    'Study Music',
    'Arijit Singh',
  ];

  Future<void> _refreshFeeds() async {
    HapticFeedback.lightImpact();
    ref.invalidate(onlineTrendingProvider);
    if (_selectedGenre != 'All') {
      ref.invalidate(onlineGenreSongsProvider(_selectedGenre));
    }
    try {
      await ref.read(onlineTrendingProvider.future);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final libState = ref.watch(libraryProvider);
    final activeTheme = ref.watch(themeProvider);
    final downloadedSongs = libState.downloadedSongs;
    final localSongs = libState.localSongs;

    // Fetch trending and genre songs online
    final trendingAsync = ref.watch(onlineTrendingProvider);
    final genreSongsAsync = _selectedGenre == 'All'
        ? trendingAsync
        : ref.watch(onlineGenreSongsProvider(_selectedGenre));

    final activeFeedAsync = _selectedGenre == 'All' ? trendingAsync : genreSongsAsync;
    final activeSongs = activeFeedAsync.asData?.value ?? const <SongModel>[];
    final showTrendingSection = activeFeedAsync.isLoading || activeSongs.isNotEmpty;
    final offlineFallbackHero = downloadedSongs.firstOrNull ?? localSongs.firstOrNull;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        color: activeTheme.primaryAccent,
        backgroundColor: activeTheme.secondaryBackground,
        onRefresh: _refreshFeeds,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // 1. Top Brand Header with live, functional shortcuts
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 14, bottom: 8),
                child: Reveal(
                  index: 0,
                  child: _buildTopHeader(
                    context,
                    activeTheme,
                    downloadedCount: downloadedSongs.length,
                  ),
                ),
              ),
            ),

            // 2. Hero Featured Banner (Dynamic for Selected Category or Offline Fallback)
            activeFeedAsync.when(
              data: (songs) {
                if (songs.isNotEmpty) {
                  return SliverToBoxAdapter(
                    child: _buildHeroBanner(
                      context,
                      songs.first,
                      songs,
                      activeTheme,
                      badgeText: _selectedGenre == 'All'
                          ? 'TOP TRENDING • 320 KBPS'
                          : '${_selectedGenre.toUpperCase()} • 320 KBPS',
                      isOfflineFallback: false,
                    ),
                  );
                }
                if (offlineFallbackHero != null) {
                  final offlineQueue =
                      downloadedSongs.isNotEmpty ? downloadedSongs : localSongs;
                  return SliverToBoxAdapter(
                    child: _buildHeroBanner(
                      context,
                      offlineFallbackHero,
                      offlineQueue,
                      activeTheme,
                      badgeText: 'READY OFFLINE',
                      isOfflineFallback: true,
                    ),
                  );
                }
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              },
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: ShimmerPlaceholder(height: 198, borderRadius: 26),
                ),
              ),
              error: (_, _) {
                if (offlineFallbackHero != null) {
                  final offlineQueue =
                      downloadedSongs.isNotEmpty ? downloadedSongs : localSongs;
                  return SliverToBoxAdapter(
                    child: _buildHeroBanner(
                      context,
                      offlineFallbackHero,
                      offlineQueue,
                      activeTheme,
                      badgeText: 'READY OFFLINE',
                      isOfflineFallback: true,
                    ),
                  );
                }
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              },
            ),

            // 3. Curated Mood & Genre Filter Pills
            SliverToBoxAdapter(
              child: SizedBox(
                height: 56,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _genrePills.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final genre = _genrePills[index];
                    final isSelected = genre == _selectedGenre;
                    final selectedTextColor = activeTheme.onAccentGradient;
                    return Reveal(
                      index: index,
                      duration: const Duration(milliseconds: 420),
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedGenre = genre;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: isSelected ? activeTheme.accentGradient : null,
                            color: isSelected
                                ? null
                                : activeTheme.primaryAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.45)
                                  : activeTheme.primaryAccent.withValues(alpha: 0.28),
                              width: isSelected ? 1.4 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: activeTheme.highlightColor.withValues(alpha: 0.5),
                                      blurRadius: 20,
                                      spreadRadius: 1,
                                      offset: const Offset(0, 6),
                                    ),
                                  ]
                                : [
                                    BoxShadow(
                                      color: activeTheme.primaryAccent.withValues(alpha: 0.12),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isSelected) ...[
                                Icon(
                                  Icons.bolt_rounded,
                                  size: 13,
                                  color: selectedTextColor,
                                ),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                genre,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: isSelected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: isSelected
                                      ? selectedTextColor
                                      : Colors.white.withValues(alpha: 0.82),
                                  letterSpacing: isSelected ? -0.2 : 0,
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
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // 4. Horizontal Selected Genre / Trending Online Hits Carousel
            if (showTrendingSection) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          // Accent marker that ties the rail to the active theme.
                          Container(
                            width: 3,
                            height: 18,
                            decoration: BoxDecoration(
                              gradient: activeTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 9),
                          Icon(
                            _selectedGenre == 'All'
                                ? Icons.whatshot_rounded
                                : Icons.auto_awesome_rounded,
                            color: activeTheme.highlightColor,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _selectedGenre == 'All'
                                ? 'Trending Online Hits'
                                : '$_selectedGenre Hits',
                            style: AppTextStyles.sectionTitle.copyWith(
                              fontSize: 17,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              activeTheme.primaryAccent.withValues(alpha: 0.26),
                              activeTheme.secondaryAccent.withValues(alpha: 0.18),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: activeTheme.primaryAccent.withValues(alpha: 0.45),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.hd_rounded,
                              size: 11,
                              color: activeTheme.primaryAccent,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '320 KBPS',
                              style: TextStyle(
                                color: activeTheme.primaryAccent,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 10)),
              activeFeedAsync.when(
                data: (songs) {
                  if (songs.isEmpty) {
                    return const SliverToBoxAdapter(child: SizedBox.shrink());
                  }
                  return SliverToBoxAdapter(
                    child: SizedBox(
                      height: 224,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: songs.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 14),
                        itemBuilder: (context, index) {
                          final song = songs[index];
                          return TrendingSongCard(song: song, playlist: songs);
                        },
                      ),
                    ),
                  );
                },
                loading: () => SliverToBoxAdapter(
                  child: SizedBox(
                    height: 212,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 3,
                      separatorBuilder: (_, _) => const SizedBox(width: 14),
                      itemBuilder: (_, _) => const ShimmerPlaceholder(
                        width: 156,
                        height: 210,
                        borderRadius: 20,
                      ),
                    ),
                  ),
                ),
                error: (_, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 18)),
            ],

            // 5. In-App Downloaded Songs (Offline Access Section)
            if (downloadedSongs.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: SectionHeader(
                  title: 'Downloaded for Offline (${downloadedSongs.length})',
                  actionText: 'View all',
                  onActionTap: widget.onNavigateToLibrary,
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final song = downloadedSongs[index];
                    return OnlineSongTile(
                      song: song,
                      playlist: downloadedSongs,
                    );
                  },
                  childCount: downloadedSongs.length.clamp(0, 4),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],

            // 6. Selected Genre / All Online Songs Feed
            SliverToBoxAdapter(
              child: SectionHeader(
                title: _selectedGenre == 'All' ? 'Hot Online Tracks' : '$_selectedGenre Hits',
                actionText: 'Search more',
                onActionTap: widget.onNavigateToSearch ?? widget.onNavigateToExplore,
              ),
            ),

            genreSongsAsync.when(
              data: (songs) {
                if (songs.isEmpty) {
                  return SliverToBoxAdapter(
                    child: _buildOfflineRetryCard(activeTheme),
                  );
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final song = songs[index];
                      return OnlineSongTile(
                        song: song,
                        playlist: songs,
                      );
                    },
                    childCount: songs.length,
                  ),
                );
              },
              loading: () => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Column(
                    children: List.generate(
                      4,
                      (_) => const Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: ShimmerPlaceholder(height: 70, borderRadius: 18),
                      ),
                    ),
                  ),
                ),
              ),
              error: (_, _) => SliverToBoxAdapter(
                child: _buildOfflineRetryCard(activeTheme),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // 7. Device Audio Storage Tile
            if (localSongs.isNotEmpty)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: GlassCard(
                    borderRadius: 18,
                    blur: 0,
                    color: activeTheme.secondaryBackground.withValues(alpha: 0.65),
                    borderColor: activeTheme.primaryAccent.withValues(alpha: 0.25),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    onTap: widget.onNavigateToLibrary,
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: activeTheme.primaryAccent.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.phone_android_rounded,
                            color: activeTheme.primaryAccent,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Device Storage Audio',
                                style: AppTextStyles.songTitle.copyWith(fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${localSongs.length} local audio files on your phone',
                                style: AppTextStyles.artistName.copyWith(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Open Library',
                          style: AppTextStyles.actionLink.copyWith(
                            fontSize: 12,
                            color: activeTheme.primaryAccent,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 12,
                          color: activeTheme.primaryAccent,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            const SliverToBoxAdapter(
              child: SizedBox(height: 175),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineRetryCard(AppThemeType activeTheme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: GlassCard(
        borderRadius: 20,
        blur: 0,
        color: activeTheme.secondaryBackground.withValues(alpha: 0.6),
        borderColor: activeTheme.primaryAccent.withValues(alpha: 0.25),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: activeTheme.primaryAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.wifi_off_rounded,
                color: activeTheme.primaryAccent,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Online catalog unavailable',
                    style: AppTextStyles.songTitle.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Connect to internet and retry, or play your downloaded & local music offline.',
                    style: AppTextStyles.subtitle.copyWith(
                      fontSize: 11.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            GradientButton.pill(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              gradient: activeTheme.primaryGradient,
              glowColor: activeTheme.primaryAccent,
              onPressed: _refreshFeeds,
              text: 'Retry',
              icon: Icons.refresh_rounded,
            ),
          ],
        ),
      ),
    );
  }

  /// Time-aware eyebrow line above the wordmark — a small premium touch that
  /// makes the home screen feel alive without adding another menu item.
  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 5) return 'LATE NIGHT SESSIONS';
    if (hour < 12) return 'GOOD MORNING';
    if (hour < 17) return 'GOOD AFTERNOON';
    if (hour < 21) return 'GOOD EVENING';
    return 'NIGHT OWL MODE';
  }

  Widget _buildTopHeader(
    BuildContext context,
    AppThemeType activeTheme, {
    required int downloadedCount,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left: Brand Logo & Tagline
        Expanded(
          child: Row(
          children: [
            // Brand mark: rounded gradient tile with a soft outer glow.
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: activeTheme.primaryGradient,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: activeTheme.primaryAccent.withValues(alpha: 0.42),
                    blurRadius: 18,
                    spreadRadius: 1,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                Icons.graphic_eq_rounded,
                color: activeTheme.onPrimaryGradient,
                size: 24,
              ),
            ),
            const SizedBox(width: 13),
            Flexible(
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting(),
                  style: AppTextStyles.badgeText.copyWith(
                    color: activeTheme.highlightColor,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 2),
                ShaderMask(
                  shaderCallback: (rect) =>
                      activeTheme.primaryGradient.createShader(rect),
                  blendMode: BlendMode.srcIn,
                  child: Text(
                    'SoundWave',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.cardTitle.copyWith(
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      color: Colors.white,
                    ),
                  ),
                ),
                Text(
                  'Feel the music, live the moment.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.timeLabel.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              ),
            ),
          ],
          ),
        ),

        // Right: Live Search Shortcut, Offline Library Badge, and Profile Avatar
        Row(
          children: [
            Semantics(
              button: true,
              label: 'Search music',
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  (widget.onNavigateToSearch ?? widget.onNavigateToExplore)?.call();
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.glassWhiteMedium,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: AppColors.glassBorderSubtle),
                  ),
                  child: const Icon(
                    Icons.search_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              button: true,
              label: 'Offline downloads',
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  widget.onNavigateToLibrary?.call();
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.glassWhiteMedium,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: AppColors.glassBorderSubtle),
                      ),
                      child: Icon(
                        Icons.offline_pin_rounded,
                        color: downloadedCount > 0
                            ? activeTheme.primaryAccent
                            : Colors.white,
                        size: 20,
                      ),
                    ),
                    if (downloadedCount > 0)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: activeTheme.highlightColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$downloadedCount',
                            style: const TextStyle(
                              color: Color(0xFF090D16),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              button: true,
              label: 'Profile and settings',
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  widget.onNavigateToProfile?.call();
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: activeTheme.primaryGradient,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: activeTheme.highlightColor.withValues(alpha: 0.7),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeroBanner(
    BuildContext context,
    SongModel heroSong,
    List<SongModel> playlist,
    AppThemeType activeTheme, {
    required String badgeText,
    required bool isOfflineFallback,
  }) {
    final libState = ref.watch(libraryProvider);
    final downloadedMatch =
        libState.downloadedSongs.where((s) => s.id == heroSong.id).firstOrNull;
    final effectiveArtwork = (downloadedMatch?.artworkPath?.isNotEmpty ?? false)
        ? downloadedMatch!.artworkPath
        : heroSong.artworkPath;

    return Reveal(
      index: 1,
      child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      height: 238,
      child: GlassCard(
        borderRadius: 30,
        blur: 0,
        padding: EdgeInsets.zero,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            activeTheme.secondaryBackground.withValues(alpha: 0.98),
            activeTheme.primaryBackground.withValues(alpha: 0.9),
          ],
        ),
        borderColor: activeTheme.highlightColor.withValues(alpha: 0.5),
        shadows: [
          BoxShadow(
            color: activeTheme.primaryAccent.withValues(alpha: 0.4),
            blurRadius: 28,
            spreadRadius: 2,
            offset: const Offset(0, 12),
          ),
        ],
        child: Stack(
          children: [
            // Ambient theme glow bleeding out from behind the artwork.
            Positioned(
              right: -30,
              top: -40,
              width: 230,
              height: 230,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        activeTheme.primaryAccent.withValues(alpha: 0.5),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Right-aligned Artwork with Gradient Mask
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 208,
              child: ShaderMask(
                shaderCallback: (rect) {
                  return const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.transparent,
                      Colors.black87,
                      Colors.black,
                    ],
                    stops: [0.0, 0.42, 1.0],
                  ).createShader(rect);
                },
                blendMode: BlendMode.dstIn,
                child: AlbumArtwork(
                  size: 216,
                  borderRadius: 0,
                  artworkUrl: effectiveArtwork,
                  albumId: downloadedMatch?.albumId ?? heroSong.albumId,
                  songId: downloadedMatch?.rawId ?? heroSong.rawId,
                  songTitle: heroSong.title,
                  songArtist: heroSong.artist,
                ),
              ),
            ),

            // Left Content Overlay
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.56,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: activeTheme.accentGradient,
                            borderRadius: BorderRadius.circular(9),
                            boxShadow: [
                              BoxShadow(
                                color: activeTheme.highlightColor.withValues(alpha: 0.45),
                                blurRadius: 14,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isOfflineFallback
                                    ? Icons.offline_pin_rounded
                                    : Icons.bolt_rounded,
                                color: activeTheme.onAccentGradient,
                                size: 13,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                badgeText,
                                style: TextStyle(
                                  color: activeTheme.onAccentGradient,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          heroSong.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.cardTitle.copyWith(
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                            height: 1.12,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${heroSong.artist} • ${heroSong.album}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.subtitle.copyWith(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.78),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Action Buttons: Play Now & Download
                  Row(
                    children: [
                      GradientButton.pill(
                        onPressed: () {
                          ref.read(playerProvider.notifier).playTrack(heroSong, queue: playlist);
                          ref.read(libraryProvider.notifier).recordPlayed(heroSong);
                        },
                        text: isOfflineFallback ? 'Play Offline' : 'Play Now',
                        icon: Icons.play_arrow_rounded,
                      ),
                      if (!isOfflineFallback) ...[
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            showDownloadOptionsSheet(context, heroSong);
                          },
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppColors.glassWhiteMedium,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: activeTheme.primaryAccent.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Icon(
                              downloadedMatch != null
                                  ? Icons.check_circle_rounded
                                  : Icons.arrow_circle_down_rounded,
                              color: downloadedMatch != null
                                  ? Colors.greenAccent
                                  : activeTheme.primaryAccent,
                              size: 22,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
