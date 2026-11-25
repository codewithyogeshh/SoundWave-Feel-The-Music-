import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundwave/app/theme/text_styles.dart';
import 'package:soundwave/core/utils/duration_formatter.dart';
import 'package:soundwave/core/widgets/app_background.dart';
import 'package:soundwave/features/player/presentation/widgets/lyrics_viewer.dart';
import 'package:soundwave/features/player/services/lyrics_service.dart';
import 'package:soundwave/shared/providers/player_provider.dart';
import 'package:soundwave/shared/providers/theme_provider.dart';

/// Immersive, edge-to-edge lyrics screen: the active line sits in the exact
/// middle of the screen and playback controls live at the bottom.
class LyricsFullScreen extends ConsumerStatefulWidget {
  const LyricsFullScreen({super.key});

  @override
  ConsumerState<LyricsFullScreen> createState() => _LyricsFullScreenState();
}

class _LyricsFullScreenState extends ConsumerState<LyricsFullScreen> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final activeTheme = ref.watch(themeProvider);
    final fromCache = ref.watch(lyricsFromCacheProvider);
    final loadedLyrics = ref.watch(currentSongLyricsProvider).asData?.value;
    final plainOnly =
        loadedLyrics != null && loadedLyrics.isNotEmpty && !loadedLyrics.isSynced;
    final song = playerState.currentSong;

    if (song == null) {
      return const SizedBox.shrink();
    }

    final duration = playerState.duration;
    final maxMs = duration.inMilliseconds.toDouble();
    final posMs = (_dragValue ?? playerState.position.inMilliseconds.toDouble())
        .clamp(0.0, maxMs > 0 ? maxMs : 1.0);

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 14, 0),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Close lyrics',
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        Navigator.of(context).maybePop();
                      },
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.songTitle.copyWith(fontSize: 15),
                          ),
                          Text(
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.artistName.copyWith(fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: activeTheme.primaryAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (fromCache) ...[
                            Icon(
                              Icons.offline_pin_rounded,
                              size: 10,
                              color: activeTheme.primaryAccent,
                            ),
                            const SizedBox(width: 3),
                          ],
                          Text(
                            plainOnly
                                ? 'LYRICS • NO TIMING'
                                : fromCache
                                ? 'LYRICS • SAVED'
                                : 'LYRICS',
                            style: TextStyle(
                              color: activeTheme.primaryAccent,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Lyrics: active line pinned to the centre, auto-following the song.
              const Expanded(
                child: LyricsViewer(
                  key: ValueKey('fullscreen_lyrics'),
                  fullScreen: true,
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Fine-tune karaoke timing without leaving the lyrics.
                    const LyricsSyncControls(),
                    const SizedBox(height: 2),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        activeTrackColor: activeTheme.highlightColor,
                        inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
                        thumbColor: Colors.white,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.5),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 13),
                      ),
                      child: Slider(
                        min: 0.0,
                        max: maxMs > 0 ? maxMs : 1.0,
                        value: posMs,
                        onChanged: (val) => setState(() => _dragValue = val),
                        onChangeEnd: (val) {
                          HapticFeedback.selectionClick();
                          ref
                              .read(playerProvider.notifier)
                              .seek(Duration(milliseconds: val.toInt()));
                          setState(() => _dragValue = null);
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DurationFormatter.format(Duration(milliseconds: posMs.toInt())),
                            style: AppTextStyles.timeLabel,
                          ),
                          Text(
                            DurationFormatter.format(duration),
                            style: AppTextStyles.timeLabel,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          tooltip: 'Previous track',
                          icon: const Icon(
                            Icons.skip_previous_rounded,
                            size: 30,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            ref.read(playerProvider.notifier).skipToPrevious();
                          },
                        ),
                        const SizedBox(width: 20),
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: activeTheme.accentGradient,
                            boxShadow: [
                              BoxShadow(
                                color: activeTheme.highlightColor.withValues(alpha: 0.35),
                                blurRadius: 18,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: IconButton(
                            tooltip: playerState.isPlaying ? 'Pause' : 'Play',
                            iconSize: 30,
                            color: Colors.white,
                            icon: Icon(
                              playerState.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                            ),
                            onPressed: () {
                              ref.read(playerProvider.notifier).togglePlayPause();
                            },
                          ),
                        ),
                        const SizedBox(width: 20),
                        IconButton(
                          tooltip: 'Next track',
                          icon: const Icon(
                            Icons.skip_next_rounded,
                            size: 30,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            ref.read(playerProvider.notifier).skipToNext();
                          },
                        ),
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
