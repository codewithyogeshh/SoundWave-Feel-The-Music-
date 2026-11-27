import 'dart:ui' show FontFeature;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soundwave/app/theme/app_colors.dart';
import 'package:soundwave/app/theme/text_styles.dart';
import 'package:soundwave/app/theme/theme_model.dart';
import 'package:soundwave/core/utils/duration_formatter.dart';
import 'package:soundwave/core/widgets/album_artwork.dart';
import 'package:soundwave/core/widgets/animated_equalizer.dart';
import 'package:soundwave/core/widgets/app_background.dart';
import 'package:soundwave/core/widgets/glass_card.dart';
import 'package:soundwave/core/widgets/reveal.dart';
import 'package:soundwave/features/online/widgets/download_options_sheet.dart';
import 'package:soundwave/features/player/models/song_model.dart';
import 'package:soundwave/features/player/presentation/widgets/lyrics_viewer.dart';
import 'package:soundwave/features/player/services/queue_variety.dart';
import 'package:soundwave/features/player/services/sleep_timer_service.dart';
import 'package:soundwave/shared/providers/download_provider.dart';
import 'package:soundwave/shared/providers/library_provider.dart';
import 'package:soundwave/shared/providers/online_music_provider.dart';
import 'package:soundwave/shared/providers/player_provider.dart';
import 'package:soundwave/shared/providers/theme_provider.dart';

class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen> {
  double? _dragValue;
  bool _isUpNextExpanded = false;
  bool _showLyrics = false;

  @override
  void initState() {
    super.initState();
    // Queues restored from an older build, or built from a list that was full
    // of copies of one song, are cleaned up as soon as the player opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(playerProvider.notifier).refreshQueueVariety();
    });
  }

  /// Staggered entrance helper: each section eases in slightly after the one
  /// above it, which is what gives the screen its premium, layered feel.
  Widget _stagger(int index, Widget child) => Reveal(index: index, child: child);

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final activeTheme = ref.watch(themeProvider);
    final libState = ref.watch(libraryProvider);
    final sleepTimer = ref.watch(sleepTimerProvider);
    final song = playerState.currentSong;

    if (song == null) {
      return Scaffold(
        body: AppBackground(
          child: Center(
            child: Text(
              'No music playing',
              style: AppTextStyles.screenTitle,
            ),
          ),
        ),
      );
    }

    final isFav = libState.isFavorite(song.id);
    final duration = playerState.duration;
    final position = playerState.position;
    final maxMs = duration.inMilliseconds.toDouble();
    final posMs = (_dragValue != null)
        ? _dragValue!
        : position.inMilliseconds.toDouble().clamp(0.0, maxMs > 0 ? maxMs : 1.0);

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    // A hero-sized cover: almost as wide as the phone, still capped by height
    // so the transport deck stays reachable on short screens.
    final artMaxByHeight = (screenHeight * 0.40).clamp(210.0, 340.0);
    final artSize = (screenWidth * 0.78).clamp(210.0, artMaxByHeight);

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          bottom: true,
          top: true,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 6),
                // Top Bar with live Sleep Timer pill & quick actions
                _stagger(0, _buildTopBar(context, song, activeTheme, sleepTimer, playerState.playbackSpeed)),
                const SizedBox(height: 10),

                // Center Album Art or Interactive Karaoke Lyrics
                SizedBox(
                  width: screenWidth,
                  height: artSize + 12,
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: _showLyrics
                          ? LyricsViewer(
                              key: const ValueKey('lyrics_mode'),
                              height: artSize + 12,
                              onClose: () => setState(() => _showLyrics = false),
                            )
                          : GestureDetector(
                              key: const ValueKey('artwork_mode'),
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _showLyrics = true);
                              },
                              child: Hero(
                                tag: 'album_art_${song.id}',
                                // Gradient ring + lifted glow, the same language
                                // as the round cover on the mini player.
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(36),
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        activeTheme.highlightColor.withValues(alpha: 0.95),
                                        activeTheme.primaryAccent.withValues(alpha: 0.9),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: activeTheme.primaryAccent.withValues(alpha: 0.5),
                                        blurRadius: 36,
                                        spreadRadius: 2,
                                        offset: const Offset(0, 14),
                                      ),
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.35),
                                        blurRadius: 18,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: AlbumArtwork(
                                    size: artSize,
                                    borderRadius: 33,
                                    artworkUrl: song.artworkPath,
                                    albumId: song.albumId,
                                    songId: song.rawId,
                                    songTitle: song.title,
                                    songArtist: song.artist,
                                    overlay: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        // Glass sheen so the cover catches the light.
                                        IgnorePointer(
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  Colors.white.withValues(alpha: 0.18),
                                                  Colors.transparent,
                                                  Colors.black.withValues(alpha: 0.24),
                                                ],
                                                stops: const [0.0, 0.42, 1.0],
                                              ),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          top: 12,
                                          right: 12,
                                          child: _buildHeartOverlayButton(isFav, song, activeTheme),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Artwork / Lyrics Switcher Pill
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _showLyrics = !_showLyrics);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: _showLyrics
                          ? activeTheme.primaryAccent.withValues(alpha: 0.18)
                          : Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _showLyrics
                            ? activeTheme.primaryAccent.withValues(alpha: 0.7)
                            : Colors.white.withValues(alpha: 0.15),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _showLyrics ? Icons.music_note_rounded : Icons.mic_external_on_rounded,
                          size: 15,
                          color: _showLyrics ? activeTheme.primaryAccent : Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _showLyrics ? '🎵 Show Album Artwork' : '🎤 Synced Karaoke Lyrics',
                          style: TextStyle(
                            color: _showLyrics ? activeTheme.primaryAccent : Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Song info + seek + transport deck sit on one lifted, tinted
                // card so the screen carries the mini player's colour wash.
                _stagger(
                  2,
                  GlassCard(
                    borderRadius: 28,
                    blur: 20,
                    color: activeTheme.secondaryBackground.withValues(alpha: 0.62),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        activeTheme.primaryAccent.withValues(alpha: 0.28),
                        activeTheme.highlightColor.withValues(alpha: 0.12),
                      ],
                    ),
                    borderColor: activeTheme.highlightColor.withValues(alpha: 0.36),
                    shadows: [
                      BoxShadow(
                        color: activeTheme.primaryAccent.withValues(alpha: 0.24),
                        blurRadius: 28,
                        offset: const Offset(0, 12),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.24),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
                    child: Column(
                      children: [
                        // Song Title, Artist & HD/Offline Badge
                        _buildSongInfo(
                          song,
                          activeTheme,
                          isDownloaded: libState.isDownloaded(song.id),
                        ),

                        const SizedBox(height: 10),

                        // Seek Slider & Duration Labels
                        _buildProgressBar(posMs, maxMs, position, duration, activeTheme),

                        const SizedBox(height: 6),

                        // Main Player Controls (Shuffle, Prev, Play/Pause, Next, Repeat)
                        _buildPlayerControls(playerState, activeTheme),

                        const SizedBox(height: 10),

                        // Quick jump back 10s / forward 30s
                        _buildSeekRow(playerState),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Action Bar (Share, Favorite, Download, Playlist, Queue)
                _buildActionsRow(context, song, isFav, activeTheme),

                const SizedBox(height: 16),

                // Similar & Recommended Tracks
                _stagger(7, _buildRecommendedSection(context, song, activeTheme)),

                const SizedBox(height: 16),

                // "Up Next" Section
                _stagger(8, _buildUpNextSection(context, playerState, activeTheme)),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    SongModel song,
    AppThemeType activeTheme,
    SleepTimerState sleepTimer,
    double playbackSpeed,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Tooltip(
          message: 'Minimize player',
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkResponse(
              radius: 24,
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.07),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Now Playing',
              style: AppTextStyles.sectionTitle.copyWith(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (sleepTimer.isActive) ...[
                  GestureDetector(
                    onTap: () => _showSleepTimerSheet(context, activeTheme),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: activeTheme.primaryAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: activeTheme.primaryAccent.withValues(alpha: 0.45),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.timer_rounded, size: 11, color: activeTheme.primaryAccent),
                          const SizedBox(width: 4),
                          Text(
                            sleepTimer.mode == SleepTimerMode.endOfTrack
                                ? 'End of song'
                                : DurationFormatter.format(sleepTimer.remaining),
                            style: TextStyle(
                              color: activeTheme.primaryAccent,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                // Speed indicator chip
                GestureDetector(
                  onTap: () => _showPlaybackSpeedSheet(context, activeTheme),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${playbackSpeed.toStringAsFixed(playbackSpeed % 1 == 0 ? 0 : 2)}x',
                      style: TextStyle(
                        color: (playbackSpeed - 1.0).abs() > 0.01
                            ? activeTheme.secondaryAccent
                            : AppColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
              ),
            ),
          ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
              message: _showLyrics ? 'Show Artwork' : 'Karaoke Lyrics',
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkResponse(
                  radius: 22,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _showLyrics = !_showLyrics);
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _showLyrics
                          ? activeTheme.primaryAccent.withValues(alpha: 0.22)
                          : Colors.white.withValues(alpha: 0.07),
                      border: Border.all(
                        color: _showLyrics
                            ? activeTheme.primaryAccent.withValues(alpha: 0.55)
                            : Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Icon(
                      _showLyrics
                          ? Icons.music_note_rounded
                          : Icons.mic_external_on_rounded,
                      color: _showLyrics ? activeTheme.primaryAccent : Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Tooltip(
              message: 'More options',
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkResponse(
                  radius: 22,
                  onTap: () =>
                      _showMoreOptionsSheet(context, song, activeTheme),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.07),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: const Icon(
                      Icons.more_vert_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
      ),
    );
  }

  Widget _buildHeartOverlayButton(
    bool isFav,
    SongModel song,
    AppThemeType activeTheme,
  ) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        ref.read(libraryProvider.notifier).toggleFavorite(song);
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.42),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.22),
            width: 1,
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, animation) => ScaleTransition(
            scale: Tween<double>(begin: 0.78, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            ),
            child: child,
          ),
          child: Icon(
            isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            key: ValueKey<bool>(isFav),
            color: isFav ? activeTheme.highlightColor : Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildSongInfo(
    SongModel song,
    AppThemeType activeTheme, {
    required bool isDownloaded,
  }) {
    final badgeColor = isDownloaded ? Colors.greenAccent : activeTheme.primaryAccent;
    final badgeLabel = isDownloaded ? 'OFFLINE' : 'HD';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                song.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.songTitleLarge.copyWith(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                song.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.artistNameLarge.copyWith(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.82),
                ),
              ),
            ],
          ),
        ),
        if (song.isHd || isDownloaded) ...[
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: badgeColor.withValues(alpha: 0.8),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: badgeColor.withValues(alpha: 0.2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Text(
              badgeLabel,
              style: AppTextStyles.badgeText.copyWith(
                color: badgeColor,
                fontSize: 10.5,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProgressBar(
    double posMs,
    double maxMs,
    Duration position,
    Duration duration,
    AppThemeType activeTheme,
  ) {
    final safeMax = maxMs > 0 ? maxMs : 1.0;
    final value = posMs.clamp(0.0, safeMax);

    return Column(
      children: [
        // Gradient-filled seek bar, tinted from primary to highlight so the
        // progress reads as brightly as the mini player's.
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (rect) => LinearGradient(
            colors: [
              activeTheme.primaryAccent,
              activeTheme.highlightColor,
            ],
          ).createShader(rect),
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 5,
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.22),
              thumbColor: Colors.white,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 17),
              overlayColor: activeTheme.primaryAccent.withValues(alpha: 0.16),
            ),
            child: Slider(
              min: 0.0,
              max: safeMax,
              value: value,
              onChanged: (val) {
                setState(() {
                  _dragValue = val;
                });
              },
              onChangeEnd: (val) {
                HapticFeedback.selectionClick();
                ref
                    .read(playerProvider.notifier)
                    .seek(Duration(milliseconds: val.toInt()));
                setState(() {
                  _dragValue = null;
                });
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _timeChip(DurationFormatter.format(position), dim: true),
              _timeChip(DurationFormatter.format(duration)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _timeChip(String label, {bool dim = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: AppTextStyles.timeLabel.copyWith(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: dim ? AppColors.textMuted : Colors.white.withValues(alpha: 0.92),
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  Widget _buildPlayerControls(PlayerState playerState, AppThemeType activeTheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Shuffle
        IconButton(
          tooltip: 'Toggle shuffle',
          icon: Icon(
            Icons.shuffle_rounded,
            size: 24,
            color: playerState.isShuffle
                ? activeTheme.highlightColor
                : AppColors.textMuted,
          ),
          onPressed: () {
            HapticFeedback.selectionClick();
            ref.read(playerProvider.notifier).toggleShuffle();
          },
        ),
        // Previous
        _roundControl(
          tooltip: 'Previous track',
          icon: Icons.skip_previous_rounded,
          onPressed: () {
            HapticFeedback.lightImpact();
            ref.read(playerProvider.notifier).skipToPrevious();
          },
        ),
        // Main Glow Play / Pause with a breathing halo while music plays.
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: playerState.isPlaying
                  ? activeTheme.highlightColor.withValues(alpha: 0.5)
                  : activeTheme.highlightColor.withValues(alpha: 0.2),
              width: 1.6,
            ),
          ),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 460),
              curve: Curves.easeOutCubic,
              width: playerState.isPlaying ? 84 : 78,
              height: playerState.isPlaying ? 84 : 78,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: activeTheme.accentGradient,
                boxShadow: [
                  BoxShadow(
                    color: activeTheme.highlightColor.withValues(
                      alpha: playerState.isPlaying ? 0.55 : 0.3,
                    ),
                    blurRadius: playerState.isPlaying ? 34 : 22,
                    spreadRadius: playerState.isPlaying ? 4 : 1,
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () =>
                      ref.read(playerProvider.notifier).togglePlayPause(),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, animation) => ScaleTransition(
                        scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutBack,
                          ),
                        ),
                        child: FadeTransition(opacity: animation, child: child),
                      ),
                      child: Icon(
                        playerState.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        key: ValueKey<bool>(playerState.isPlaying),
                        color: activeTheme.onAccentGradient,
                        size: 36,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Next
        _roundControl(
          tooltip: 'Next track',
          icon: Icons.skip_next_rounded,
          onPressed: () {
            HapticFeedback.lightImpact();
            ref.read(playerProvider.notifier).skipToNext();
          },
        ),
        // Repeat
        IconButton(
          tooltip: 'Cycle repeat mode',
          icon: Icon(
            playerState.repeatMode == AudioServiceRepeatMode.one
                ? Icons.repeat_one_rounded
                : Icons.repeat_rounded,
            size: 24,
            color: playerState.repeatMode != AudioServiceRepeatMode.none
                ? activeTheme.highlightColor
                : AppColors.textMuted,
          ),
          onPressed: () {
            HapticFeedback.selectionClick();
            ref.read(playerProvider.notifier).cycleRepeatMode();
          },
        ),
      ],
    );
  }

  /// Frosted circular transport button used for previous / next.
  Widget _roundControl({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
    double size = 46,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkResponse(
          radius: size * 0.62,
          onTap: onPressed,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.06),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: Icon(icon, size: 28, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildSeekRow(PlayerState playerState) {
    final position = playerState.position;
    final duration = playerState.duration;
    final canSeek = duration > Duration.zero;

    Widget jumpButton({
      required String label,
      required Duration delta,
      required String tooltip,
    }) {
      final maxMs = duration.inMilliseconds;
      final target = Duration(
        milliseconds: (position + delta).inMilliseconds.clamp(0, maxMs),
      );
      final enabled =
          canSeek &&
          (delta.isNegative ? position > Duration.zero : position < duration);

      return Tooltip(
        message: tooltip,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: enabled ? Colors.white : AppColors.textMuted,
            side: BorderSide(
              color: Colors.white.withValues(alpha: enabled ? 0.22 : 0.08),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            minimumSize: const Size(0, 34),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: const StadiumBorder(),
          ),
          onPressed: enabled
              ? () {
                  HapticFeedback.selectionClick();
                  ref.read(playerProvider.notifier).seek(target);
                }
              : null,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        jumpButton(
          label: '−10s',
          delta: const Duration(seconds: -10),
          tooltip: 'Back 10 seconds',
        ),
        const SizedBox(width: 14),
        jumpButton(
          label: '+30s',
          delta: const Duration(seconds: 30),
          tooltip: 'Forward 30 seconds',
        ),
      ],
    );
  }

  Widget _buildActionsRow(
    BuildContext context,
    SongModel song,
    bool isFav,
    AppThemeType activeTheme,
  ) {
    final isDownloaded = ref.watch(libraryProvider).isDownloaded(song.id);
    final downloadState = ref.watch(downloadProvider);
    final isDownloading = downloadState.isDownloading(song.id);
    final downloadProgress = downloadState.getProgress(song.id);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(
            tooltip: 'Share track',
            icon: const Icon(Icons.share_outlined, color: AppColors.textSecondary, size: 22),
            onPressed: () {
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Sharing "${song.title}" by ${song.artist}'),
                ),
              );
            },
          ),
          IconButton(
            tooltip: isFav ? 'Remove from favorites' : 'Add to favorites',
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: Tween<double>(begin: 0.78, end: 1.0).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
                ),
                child: child,
              ),
              child: Icon(
                isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                key: ValueKey<bool>(isFav),
                color: isFav ? activeTheme.highlightColor : AppColors.textSecondary,
                size: 24,
              ),
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              ref.read(libraryProvider.notifier).toggleFavorite(song);
            },
          ),
          IconButton(
            tooltip: isDownloaded ? 'Downloaded Offline' : 'Download 320kbps + Cover Banner',
            icon: isDownloading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      value: downloadProgress > 0 ? downloadProgress : null,
                      strokeWidth: 2.2,
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
                    size: 26,
                  ),
            onPressed: () {
              HapticFeedback.lightImpact();
              showDownloadOptionsSheet(context, song);
            },
          ),
          IconButton(
            tooltip: 'Equalizer Studio',
            icon: const Icon(Icons.equalizer_rounded, color: AppColors.textSecondary, size: 24),
            onPressed: () {
              HapticFeedback.lightImpact();
              context.push('/equalizer');
            },
          ),
          IconButton(
            tooltip: 'Add to playlist',
            icon: const Icon(Icons.playlist_add_rounded, color: AppColors.textSecondary, size: 26),
            onPressed: () => _showAddToPlaylistDialog(context, song, activeTheme),
          ),
          IconButton(
            tooltip: 'Playback queue',
            icon: const Icon(Icons.queue_music_rounded, color: AppColors.textSecondary, size: 24),
            onPressed: () => _showQueueSheet(context, activeTheme),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendedSection(
    BuildContext context,
    SongModel currentSong,
    AppThemeType activeTheme,
  ) {
    final recommendedAsync = ref.watch(recommendedSongsProvider(currentSong));
    final libState = ref.watch(libraryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 16,
                    color: activeTheme.primaryAccent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Similar & Recommended',
                    style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
                  ),
                ],
              ),
              Text(
                'Based on Artist',
                style: AppTextStyles.timeLabel.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 140,
          child: recommendedAsync.when(
            loading: () => const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator.adaptive(strokeWidth: 2),
              ),
            ),
            error: (_, _) => _buildLocalFallbackList(currentSong, libState, activeTheme),
            data: (songs) {
              final displaySongs = songs.isNotEmpty
                  ? songs
                  : libState.allSongs.where((s) => s.id != currentSong.id).take(6).toList();

              if (displaySongs.isEmpty) {
                return const SizedBox.shrink();
              }

              return ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: displaySongs.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final recSong = displaySongs[index];
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      ref.read(playerProvider.notifier).playTrack(
                        recSong,
                        queue: [recSong, ...ref.read(playerProvider).queue],
                      );
                    },
                    child: Container(
                      width: 110,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: AlbumArtwork(
                                  size: 94,
                                  artworkUrl: recSong.artworkPath,
                                  albumId: recSong.albumId,
                                  songId: recSong.rawId,
                                  songTitle: recSong.title,
                                  songArtist: recSong.artist,
                                ),
                              ),
                              Positioned(
                                bottom: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    gradient: activeTheme.primaryGradient,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.5),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            recSong.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.songTitle.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            recSong.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.subtitle.copyWith(
                              fontSize: 9.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLocalFallbackList(
    SongModel currentSong,
    LibraryState libState,
    AppThemeType activeTheme,
  ) {
    final localSongs = libState.allSongs.where((s) => s.id != currentSong.id).take(6).toList();
    if (localSongs.isEmpty) return const SizedBox.shrink();

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      itemCount: localSongs.length,
      separatorBuilder: (_, _) => const SizedBox(width: 12),
      itemBuilder: (context, index) {
        final recSong = localSongs[index];
        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            ref.read(playerProvider.notifier).playTrack(
              recSong,
              queue: [recSong, ...ref.read(playerProvider).queue],
            );
          },
          child: Container(
            width: 110,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: AlbumArtwork(
                    size: 94,
                    artworkUrl: recSong.artworkPath,
                    albumId: recSong.albumId,
                    songId: recSong.rawId,
                    songTitle: recSong.title,
                    songArtist: recSong.artist,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  recSong.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.songTitle.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  recSong.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.subtitle.copyWith(
                    fontSize: 9.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUpNextSection(
    BuildContext context,
    PlayerState playerState,
    AppThemeType activeTheme,
  ) {
    final queue = playerState.queue;
    final currentIndex = playerState.currentIndex;
    var upcomingSongs = <SongModel>[];

    if (queue.isNotEmpty) {
      for (int i = currentIndex + 1; i < queue.length; i++) {
        upcomingSongs.add(queue[i]);
      }
      if (playerState.repeatMode == AudioServiceRepeatMode.all) {
        for (int i = 0; i <= currentIndex && i < queue.length; i++) {
          if (!upcomingSongs.contains(queue[i])) {
            upcomingSongs.add(queue[i]);
          }
        }
      }
    }

    // Never list ten versions of the same song as "up next".
    upcomingSongs = QueueVariety.trimRepeats(
      upcomingSongs,
      currentId: playerState.currentSong?.id,
    );
    final upcomingTime = upcomingSongs.fold<Duration>(
      Duration.zero,
      (total, song) => total + song.duration,
    );

    if (upcomingSongs.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: 8, bottom: 20),
        child: GlassCard(
          borderRadius: 16,
          blur: 0,
          color: AppColors.glassWhiteMedium,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: activeTheme.primaryAccent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.playlist_play_rounded,
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
                      'End of Queue',
                      style: AppTextStyles.songTitle.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Search or explore songs to add more to Up Next',
                      style: AppTextStyles.artistName.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final visibleCount =
        _isUpNextExpanded ? upcomingSongs.length : upcomingSongs.length.clamp(0, 6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header with count badge and Full Queue sheet trigger
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.queue_music_rounded,
                  color: activeTheme.primaryAccent,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Up Next',
                  style: AppTextStyles.sectionTitle.copyWith(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: activeTheme.primaryAccent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: activeTheme.primaryAccent.withValues(alpha: 0.4),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    '${upcomingSongs.length} upcoming',
                    style: TextStyle(
                      color: activeTheme.primaryAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: () => _showQueueSheet(context, activeTheme),
              child: Row(
                children: [
                  Text(
                    'Full Queue',
                    style: AppTextStyles.actionLink.copyWith(
                      color: activeTheme.secondaryAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 11,
                    color: activeTheme.secondaryAccent,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Horizontal Quick Scroll Cards
        SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: upcomingSongs.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final s = upcomingSongs[index];
              final isOnline = s.id.startsWith('online_') || !s.isLocal;
              return Container(
                width: 236,
                margin: const EdgeInsets.symmetric(vertical: 2),
                child: GlassCard(
                  borderRadius: 16,
                  blur: 0,
                  color: AppColors.glassWhiteMedium,
                  padding: const EdgeInsets.all(10),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(playerProvider.notifier).playTrack(s, queue: queue);
                  },
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          AlbumArtwork(
                            size: 52,
                            borderRadius: 12,
                            artworkUrl: s.artworkPath,
                            albumId: s.albumId,
                            songId: s.rawId,
                            songTitle: s.title,
                            songArtist: s.artist,
                          ),
                          Positioned(
                            top: 3,
                            left: 3,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '#${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              s.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.songTitle.copyWith(fontSize: 13),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              s.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.artistName.copyWith(fontSize: 11),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  DurationFormatter.format(s.duration),
                                  style: AppTextStyles.timeLabel.copyWith(fontSize: 10),
                                ),
                                if (isOnline) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding:
                                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: activeTheme.primaryAccent.withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '320K',
                                      style: TextStyle(
                                        color: activeTheme.primaryAccent,
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: activeTheme.primaryAccent.withValues(alpha: 0.16),
                        ),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: activeTheme.primaryAccent,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 14),

        // Vertical List Header with View All / Show Less
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              upcomingSongs.isEmpty
                  ? 'Upcoming List'
                  : 'Upcoming List • ${DurationFormatter.formatLong(upcomingTime)} left',
              style: AppTextStyles.artistName.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            if (upcomingSongs.length > 6)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isUpNextExpanded = !_isUpNextExpanded;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                  child: Text(
                    _isUpNextExpanded ? 'Show Less' : 'Show All (${upcomingSongs.length})',
                    style: TextStyle(
                      color: activeTheme.primaryAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 8),

        // Vertical Queue Items
        ...List.generate(visibleCount, (index) {
          final s = upcomingSongs[index];
          final isOnline = s.id.startsWith('online_') || !s.isLocal;
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            child: GlassCard(
              borderRadius: 14,
              blur: 0,
              color: AppColors.glassWhiteMedium,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              onTap: () {
                HapticFeedback.selectionClick();
                ref.read(playerProvider.notifier).playTrack(s, queue: queue);
              },
              child: Row(
                children: [
                  Container(
                    width: 24,
                    alignment: Alignment.center,
                    child: Text(
                      '${index + 1}',
                      style: AppTextStyles.artistName.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AlbumArtwork(
                    size: 38,
                    borderRadius: 9,
                    artworkUrl: s.artworkPath,
                    albumId: s.albumId,
                    songId: s.rawId,
                    songTitle: s.title,
                    songArtist: s.artist,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                s.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.songTitle.copyWith(fontSize: 13),
                              ),
                            ),
                            if (isOnline) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: activeTheme.primaryAccent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '320K',
                                  style: TextStyle(
                                    color: activeTheme.primaryAccent,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.artistName.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    DurationFormatter.format(s.duration),
                    style: AppTextStyles.timeLabel.copyWith(fontSize: 11),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.play_circle_outline_rounded,
                    color: activeTheme.primaryAccent,
                    size: 20,
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  void _showQueueSheet(BuildContext context, AppThemeType activeTheme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: activeTheme.primaryBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final queue = ref.watch(playerProvider).queue;
            final currentSong = ref.watch(playerProvider).currentSong;

            Duration totalDuration = Duration.zero;
            for (final s in queue) {
              totalDuration += s.duration;
            }

            return DraggableScrollableSheet(
              initialChildSize: 0.65,
              minChildSize: 0.45,
              maxChildSize: 0.92,
              expand: false,
              builder: (_, controller) {
                return Column(
                  children: [
                    Container(
                      width: 44,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Playback Queue', style: AppTextStyles.sectionTitle),
                              const SizedBox(height: 2),
                              Text(
                                '${queue.length} Tracks • ${DurationFormatter.formatLong(totalDuration)}',
                                style: AppTextStyles.timeLabel.copyWith(color: AppColors.textMuted),
                              ),
                            ],
                          ),
                          if (queue.length > 1)
                            TextButton.icon(
                              onPressed: () {
                                HapticFeedback.mediumImpact();
                                ref.read(playerProvider.notifier).clearUpcomingQueue();
                              },
                              icon: const Icon(Icons.clear_all_rounded, size: 16, color: AppColors.textMuted),
                              label: const Text(
                                'Clear Upcoming',
                                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Colors.white10),
                    Expanded(
                      child: queue.isEmpty
                          ? Center(
                              child: Text(
                                'Queue is empty',
                                style: AppTextStyles.subtitle.copyWith(color: AppColors.textMuted),
                              ),
                            )
                          : Theme(
                              data: Theme.of(context).copyWith(
                                canvasColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                              ),
                              child: ReorderableListView.builder(
                                scrollController: controller,
                                physics: const BouncingScrollPhysics(),
                                itemCount: queue.length,
                                onReorderItem: (oldIndex, newIndex) {
                                  HapticFeedback.selectionClick();
                                  ref.read(playerProvider.notifier).reorderQueue(
                                    oldIndex,
                                    newIndex,
                                    isAdjusted: true,
                                  );
                                },
                                itemBuilder: (context, index) {
                                  final item = queue[index];
                                  final isCurrent = currentSong?.id == item.id;

                                  return Dismissible(
                                    key: ValueKey('queue_item_${item.id}_$index'),
                                    direction: queue.length > 1
                                        ? DismissDirection.endToStart
                                        : DismissDirection.none,
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 20),
                                      color: Colors.redAccent.withValues(alpha: 0.8),
                                      child: const Icon(Icons.delete_sweep_rounded, color: Colors.white),
                                    ),
                                    onDismissed: (_) {
                                      HapticFeedback.mediumImpact();
                                      ref.read(playerProvider.notifier).removeFromQueue(index);
                                    },
                                    child: ListTile(
                                      key: ValueKey('list_tile_${item.id}_$index'),
                                      leading: AlbumArtwork(
                                        size: 44,
                                        borderRadius: 10,
                                        artworkUrl: item.artworkPath,
                                        albumId: item.albumId,
                                        songId: item.rawId,
                                        songTitle: item.title,
                                        songArtist: item.artist,
                                      ),
                                      title: Text(
                                        item.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.songTitle.copyWith(
                                          color: isCurrent ? activeTheme.primaryAccent : Colors.white,
                                          fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                                        ),
                                      ),
                                      subtitle: Text(
                                        item.artist,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.artistName,
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isCurrent) ...[
                                            AnimatedEqualizer(
                                              isPlaying: true,
                                              size: 16,
                                              color: activeTheme.primaryAccent,
                                            ),
                                            const SizedBox(width: 10),
                                          ],
                                          ReorderableDragStartListener(
                                            index: index,
                                            child: const Icon(
                                              Icons.drag_handle_rounded,
                                              color: AppColors.textMuted,
                                              size: 22,
                                            ),
                                          ),
                                        ],
                                      ),
                                      onTap: () {
                                        ref.read(playerProvider.notifier).playTrack(item, queue: queue);
                                        Navigator.pop(ctx);
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showAddToPlaylistDialog(
    BuildContext context,
    SongModel song,
    AppThemeType activeTheme,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: activeTheme.secondaryBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final playlists = ref.watch(libraryProvider).playlists;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add to Playlist', style: AppTextStyles.sectionTitle),
                const SizedBox(height: 12),
                if (playlists.isEmpty)
                  Text('No playlists created yet.', style: AppTextStyles.subtitle)
                else
                  ...playlists.map((pl) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.playlist_play_rounded,
                        color: activeTheme.primaryAccent,
                      ),
                      title: Text(pl.name, style: AppTextStyles.songTitle),
                      subtitle: Text('${pl.songCount} songs', style: AppTextStyles.artistName),
                      onTap: () {
                        ref.read(libraryProvider.notifier).addSongToPlaylist(pl.id, song);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Added to ${pl.name}')),
                        );
                      },
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMoreOptionsSheet(
    BuildContext context,
    SongModel song,
    AppThemeType activeTheme,
  ) {
    final storage = ref.read(storageServiceProvider);
    final profile = storage.getUserProfile();
    final eqPreset = (profile['equalizerPreset'] as String?) ??
        (profile['eqPreset'] as String?) ??
        'Vibrant Bass Boost';
    final sleepTimer = ref.read(sleepTimerProvider);
    final currentSpeed = ref.read(playerProvider).playbackSpeed;

    showModalBottomSheet(
      context: context,
      backgroundColor: activeTheme.secondaryBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.tune_rounded, color: activeTheme.primaryAccent),
                  title: Text('Audio Equalizer Studio', style: AppTextStyles.songTitle.copyWith(fontSize: 15)),
                  subtitle: Text('Profile: $eqPreset • 5-band EQ, curve & boost', style: AppTextStyles.subtitle.copyWith(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/equalizer');
                  },
                ),
                ListTile(
                  leading: Icon(Icons.speed_rounded, color: activeTheme.secondaryAccent),
                  title: Text('Playback Speed', style: AppTextStyles.songTitle.copyWith(fontSize: 15)),
                  subtitle: Text('${currentSpeed.toStringAsFixed(currentSpeed % 1 == 0 ? 0 : 2)}x speed', style: AppTextStyles.subtitle.copyWith(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showPlaybackSpeedSheet(context, activeTheme);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.timer_outlined, color: activeTheme.primaryAccent),
                  title: Text('Sleep Timer & Fade-Out', style: AppTextStyles.songTitle.copyWith(fontSize: 15)),
                  subtitle: Text(
                    sleepTimer.isActive
                        ? (sleepTimer.mode == SleepTimerMode.endOfTrack
                            ? 'Pausing after the current song'
                            : 'Pausing in ${DurationFormatter.format(sleepTimer.remaining)}')
                        : 'Gradually duck volume before pausing',
                    style: AppTextStyles.subtitle.copyWith(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showSleepTimerSheet(context, activeTheme);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded, color: AppColors.textSecondary),
                  title: Text('Track Details & Audio Specs', style: AppTextStyles.songTitle.copyWith(fontSize: 15)),
                  subtitle: Text(
                    song.isLocal ? 'Offline file' : '320 kbps online stream',
                    style: AppTextStyles.subtitle.copyWith(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showTrackDetailsDialog(context, song, activeTheme);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPlaybackSpeedSheet(BuildContext context, AppThemeType activeTheme) {
    const speeds = [0.75, 1.0, 1.25, 1.5, 2.0];
    final currentSpeed = ref.read(playerProvider).playbackSpeed;

    showModalBottomSheet(
      context: context,
      backgroundColor: activeTheme.secondaryBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Playback Speed', style: AppTextStyles.cardTitle.copyWith(fontSize: 18)),
                    Text(
                      '${currentSpeed.toStringAsFixed(currentSpeed % 1 == 0 ? 0 : 2)}x',
                      style: TextStyle(color: activeTheme.primaryAccent, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: speeds.map((speed) {
                    final isSelected = (speed - currentSpeed).abs() < 0.05;
                    return ChoiceChip(
                      selected: isSelected,
                      label: Text('${speed}x'),
                      selectedColor: activeTheme.primaryAccent,
                      backgroundColor: Colors.white.withValues(alpha: 0.06),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                      onSelected: (_) {
                        HapticFeedback.selectionClick();
                        ref.read(playerProvider.notifier).setPlaybackSpeed(speed);
                        Navigator.pop(ctx);
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSleepTimerSheet(BuildContext context, AppThemeType activeTheme) {
    final presets = <int>[5, 10, 15, 30, 45, 60, 90];
    // Offer the length picked last time first, so a nightly routine is one tap.
    var lastMinutes = 30;
    try {
      lastMinutes = ref.read(storageServiceProvider).getSleepTimerMinutes();
    } catch (_) {}
    if (presets.remove(lastMinutes)) {
      presets.insert(0, lastMinutes);
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: activeTheme.secondaryBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final timerState = ref.watch(sleepTimerProvider);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Smart Sleep Timer', style: AppTextStyles.cardTitle.copyWith(fontSize: 18)),
                    if (timerState.isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: activeTheme.primaryAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          timerState.mode == SleepTimerMode.endOfTrack
                              ? 'End of song'
                              : DurationFormatter.format(timerState.remaining),
                          style: TextStyle(
                            color: activeTheme.primaryAccent,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Music will gently duck volume in the final 25s before cleanly pausing. '
                  'Pick "End of song" to drift off over the last 15s of the track that is '
                  'playing now. Last used: $lastMinutes min (shown first).',
                  style: AppTextStyles.subtitle.copyWith(fontSize: 12),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ChoiceChip(
                      selected:
                          timerState.isActive &&
                          timerState.mode == SleepTimerMode.endOfTrack,
                      label: const Text('End of song'),
                      selectedColor: activeTheme.primaryAccent,
                      backgroundColor: Colors.white.withValues(alpha: 0.06),
                      labelStyle: TextStyle(
                        color: timerState.mode == SleepTimerMode.endOfTrack
                            ? Colors.white
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                      onSelected: (_) {
                        HapticFeedback.selectionClick();
                        ref.read(sleepTimerProvider.notifier).startEndOfTrack();
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Sleep timer: pausing after the current song',
                            ),
                          ),
                        );
                      },
                    ),
                    ...presets.map((mins) {
                    final isSelected =
                        timerState.isActive && timerState.totalMinutes == mins;
                    final isLastUsed = mins == lastMinutes;
                    return ChoiceChip(
                      selected: isSelected,
                      label: Text(isLastUsed ? '$mins min ★' : '$mins min'),
                      selectedColor: activeTheme.primaryAccent,
                      backgroundColor: Colors.white.withValues(alpha: 0.06),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                      onSelected: (_) {
                        HapticFeedback.selectionClick();
                        ref.read(sleepTimerProvider.notifier).startTimer(mins);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Sleep timer set for $mins minutes with volume fade-out'),
                          ),
                        );
                      },
                    );
                  }),
                  ],
                ),
                if (timerState.isActive) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: activeTheme.primaryAccent,
                            side: BorderSide(color: activeTheme.primaryAccent),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('+5 Min'),
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            ref.read(sleepTimerProvider.notifier).addMinutes(5);
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Added 5 minutes to sleep timer')),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.timer_off_rounded, size: 18),
                          label: const Text('Cancel Timer'),
                          onPressed: () {
                            ref.read(sleepTimerProvider.notifier).cancelTimer();
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Sleep timer cancelled')),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showTrackDetailsDialog(
    BuildContext context,
    SongModel song,
    AppThemeType activeTheme,
  ) {
    final localBanner = AlbumArtwork.extractLocalFilePath(song.artworkPath);
    final bannerLabel = localBanner != null
        ? 'Saved Offline (Local Banner)'
        : (song.artworkPath != null && song.artworkPath!.startsWith('http'))
            ? 'Remote Artwork'
            : 'Device / Generated';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: activeTheme.secondaryBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            AlbumArtwork(
              size: 42,
              borderRadius: 10,
              artworkUrl: song.artworkPath,
              albumId: song.albumId,
              songId: song.rawId,
              songTitle: song.title,
              songArtist: song.artist,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.cardTitle.copyWith(fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Artist', song.artist),
            _buildDetailRow('Album', song.album),
            _buildDetailRow('Duration', DurationFormatter.format(song.duration)),
            _buildDetailRow('Source', song.isLocal ? 'Offline Storage' : '320 kbps Stream'),
            _buildDetailRow('Banner', bannerLabel),
            if (song.fileSizeFormatted.isNotEmpty)
              _buildDetailRow('File Size', song.fileSizeFormatted),
            if (song.audioPath.contains('.'))
              _buildDetailRow(
                'Format',
                song.audioPath.split('.').last.split('?').first.toUpperCase(),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close', style: TextStyle(color: activeTheme.primaryAccent)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

