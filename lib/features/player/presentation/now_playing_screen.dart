import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundwave/app/theme/app_colors.dart';
import 'package:soundwave/app/theme/text_styles.dart';
import 'package:soundwave/app/theme/theme_model.dart';
import 'package:soundwave/core/utils/duration_formatter.dart';
import 'package:soundwave/core/widgets/album_artwork.dart';
import 'package:soundwave/core/widgets/animated_equalizer.dart';
import 'package:soundwave/core/widgets/app_background.dart';
import 'package:soundwave/core/widgets/glass_card.dart';
import 'package:soundwave/core/widgets/gradient_button.dart';
import 'package:soundwave/features/online/widgets/download_options_sheet.dart';
import 'package:soundwave/features/player/models/song_model.dart';
import 'package:soundwave/features/player/services/sleep_timer_service.dart';
import 'package:soundwave/shared/providers/download_provider.dart';
import 'package:soundwave/shared/providers/library_provider.dart';
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
    // Responsive album art clamped gracefully by both width and height to prevent vertical scrolling/overflow
    final artSize = (screenWidth * 0.70).clamp(200.0, (screenHeight * 0.32).clamp(200.0, 280.0));

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
                // Top Bar with live Sleep Timer pill
                _buildTopBar(context, song, activeTheme, sleepTimer),
                const SizedBox(height: 10),

                // Center Album Art with Calm Ambient Glow
                SizedBox(
                  width: screenWidth,
                  height: artSize + 12,
                  child: Center(
                    child: Hero(
                      tag: 'album_art_${song.id}',
                      child: AlbumArtwork(
                        size: artSize,
                        borderRadius: 24,
                        artworkUrl: song.artworkPath,
                        albumId: song.albumId,
                        songId: song.rawId,
                        songTitle: song.title,
                        songArtist: song.artist,
                        hasGlow: true,
                        glowColor: activeTheme.primaryAccent,
                        overlay: Positioned(
                          top: 12,
                          right: 12,
                          child: _buildHeartOverlayButton(isFav, song, activeTheme),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Song Title, Artist & HD/Offline Badge
                _buildSongInfo(song, activeTheme, isDownloaded: libState.isDownloaded(song.id)),

                const SizedBox(height: 12),

                // Seek Slider & Duration Labels
                _buildProgressBar(posMs, maxMs, position, duration, activeTheme),

                const SizedBox(height: 10),

                // Main Player Controls (Shuffle, Prev, Play/Pause, Next, Repeat)
                _buildPlayerControls(playerState, activeTheme),

                const SizedBox(height: 12),

                // Action Bar (Share, Favorite, Download, Playlist, Queue)
                _buildActionsRow(context, song, isFav, activeTheme),

                const SizedBox(height: 16),

                // "Up Next" Section
                _buildUpNextSection(context, playerState, activeTheme),

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
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          tooltip: 'Minimize player',
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.white,
            size: 32,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Now Playing',
              style: AppTextStyles.sectionTitle.copyWith(fontSize: 16),
            ),
            if (sleepTimer.isActive) ...[
              const SizedBox(height: 2),
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
                        DurationFormatter.format(sleepTimer.remaining),
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
            ],
          ],
        ),
        IconButton(
          tooltip: 'More options',
          icon: const Icon(
            Icons.more_vert_rounded,
            color: Colors.white,
            size: 24,
          ),
          onPressed: () => _showMoreOptionsSheet(context, song, activeTheme),
        ),
      ],
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.songTitleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                song.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.artistNameLarge,
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
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3.5,
            activeTrackColor: activeTheme.highlightColor,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
            thumbColor: Colors.white,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            min: 0.0,
            max: maxMs > 0 ? maxMs : 1.0,
            value: posMs.clamp(0.0, maxMs > 0 ? maxMs : 1.0),
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DurationFormatter.format(position),
                style: AppTextStyles.timeLabel,
              ),
              Text(
                DurationFormatter.format(duration),
                style: AppTextStyles.timeLabel,
              ),
            ],
          ),
        ),
      ],
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
        IconButton(
          tooltip: 'Previous track',
          icon: const Icon(
            Icons.skip_previous_rounded,
            size: 34,
            color: Colors.white,
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            ref.read(playerProvider.notifier).skipToPrevious();
          },
        ),
        // Main Glow Play / Pause
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: activeTheme.highlightColor.withValues(alpha: 0.42),
                blurRadius: 26,
                spreadRadius: 2,
              ),
            ],
          ),
          child: GradientButton.circle(
            size: 72,
            gradient: activeTheme.accentGradient,
            glowColor: activeTheme.highlightColor,
            hasGlow: true,
            onPressed: () {
              ref.read(playerProvider.notifier).togglePlayPause();
            },
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: Tween<double>(begin: 0.85, end: 1.0).animate(animation),
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: Icon(
                playerState.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                key: ValueKey<bool>(playerState.isPlaying),
                color: Colors.white,
                size: 38,
              ),
            ),
          ),
        ),
        // Next
        IconButton(
          tooltip: 'Next track',
          icon: const Icon(
            Icons.skip_next_rounded,
            size: 34,
            color: Colors.white,
          ),
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

  Widget _buildUpNextSection(
    BuildContext context,
    PlayerState playerState,
    AppThemeType activeTheme,
  ) {
    final queue = playerState.queue;
    final currentIndex = playerState.currentIndex;
    final upcomingSongs = <SongModel>[];

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
                  style: AppTextStyles.sectionTitle.copyWith(fontSize: 16),
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
              'Upcoming List',
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
        final queue = ref.watch(playerProvider).queue;
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Playback Queue', style: AppTextStyles.sectionTitle),
                      Text('${queue.length} Tracks', style: AppTextStyles.timeLabel),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    itemCount: queue.length,
                    itemBuilder: (_, index) {
                      final item = queue[index];
                      final isCurrent =
                          ref.watch(playerProvider).currentSong?.id == item.id;
                      return ListTile(
                        leading: AlbumArtwork(
                          size: 42,
                          borderRadius: 10,
                          artworkUrl: item.artworkPath,
                          albumId: item.albumId,
                          songId: item.rawId,
                          songTitle: item.title,
                          songArtist: item.artist,
                        ),
                        title: Text(
                          item.title,
                          style: AppTextStyles.songTitle.copyWith(
                            color: isCurrent ? activeTheme.primaryAccent : Colors.white,
                          ),
                        ),
                        subtitle: Text(item.artist, style: AppTextStyles.artistName),
                        trailing: isCurrent
                            ? AnimatedEqualizer(
                                isPlaying: true,
                                size: 16,
                                color: activeTheme.primaryAccent,
                              )
                            : null,
                        onTap: () {
                          ref.read(playerProvider.notifier).playTrack(item, queue: queue);
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
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
                  leading: Icon(Icons.equalizer_rounded, color: activeTheme.primaryAccent),
                  title: Text('Equalizer Preset', style: AppTextStyles.songTitle.copyWith(fontSize: 15)),
                  subtitle: Text(eqPreset, style: AppTextStyles.subtitle.copyWith(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showEqualizerSheet(context, activeTheme, eqPreset);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.timer_outlined, color: activeTheme.secondaryAccent),
                  title: Text('Sleep Timer', style: AppTextStyles.songTitle.copyWith(fontSize: 15)),
                  subtitle: Text(
                    sleepTimer.isActive
                        ? 'Pausing in ${DurationFormatter.format(sleepTimer.remaining)}'
                        : 'Automatically pause playback after a timer',
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

  void _showSleepTimerSheet(BuildContext context, AppThemeType activeTheme) {
    const presets = [5, 15, 30, 45, 60];
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
                    Text('Sleep Timer', style: AppTextStyles.cardTitle.copyWith(fontSize: 18)),
                    if (timerState.isActive)
                      Text(
                        DurationFormatter.format(timerState.remaining),
                        style: TextStyle(
                          color: activeTheme.primaryAccent,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Music will gently pause when the countdown ends.',
                  style: AppTextStyles.subtitle.copyWith(fontSize: 12),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: presets.map((mins) {
                    final isSelected =
                        timerState.isActive && timerState.totalMinutes == mins;
                    return ChoiceChip(
                      selected: isSelected,
                      label: Text('$mins min'),
                      selectedColor: activeTheme.primaryAccent,
                      backgroundColor: AppColors.glassWhiteMedium,
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
                            content: Text('Sleep timer set for $mins minutes'),
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),
                if (timerState.isActive) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.timer_off_rounded, size: 18),
                      label: const Text('Cancel Sleep Timer'),
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
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEqualizerSheet(
    BuildContext context,
    AppThemeType activeTheme,
    String currentPreset,
  ) {
    const presets = [
      'Flat / Neutral',
      'Vibrant Bass Boost',
      'Vocal Clarity',
      'Treble Booster',
      'Electronic & Club',
      'Acoustic Warmth',
      'Rock & Metal',
    ];
    final storage = ref.read(storageServiceProvider);
    final profile = storage.getUserProfile();

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
                Text('Equalizer Presets', style: AppTextStyles.cardTitle.copyWith(fontSize: 18)),
                const SizedBox(height: 10),
                ...presets.map((preset) {
                  final isSelected = preset == currentPreset;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      preset,
                      style: TextStyle(
                        color: isSelected ? activeTheme.primaryAccent : Colors.white,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check_circle_rounded, color: activeTheme.primaryAccent)
                        : null,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      final updated = Map<String, dynamic>.from(profile);
                      updated['equalizerPreset'] = preset;
                      updated['eqPreset'] = preset;
                      storage.saveUserProfile(updated);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Equalizer preset applied: $preset')),
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

