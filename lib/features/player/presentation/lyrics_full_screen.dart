import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundwave/app/theme/text_styles.dart';
import 'package:soundwave/core/utils/duration_formatter.dart';
import 'package:soundwave/core/widgets/app_background.dart';
import 'package:soundwave/core/widgets/premium_sheet.dart';
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
    final fromCache = ref.watch(lyricsFromCacheProvider);
    final loadedLyrics = ref.watch(currentSongLyricsProvider).asData?.value;
    final plainOnly =
        loadedLyrics != null && loadedLyrics.isNotEmpty && !loadedLyrics.isSynced;
    final activeTheme = ref.watch(themeProvider);
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
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              gradient: activeTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(11),
                              boxShadow: [
                                BoxShadow(
                                  color: activeTheme.primaryAccent.withValues(
                                    alpha: 0.38,
                                  ),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.lyrics_rounded,
                              color: activeTheme.onPrimaryGradient,
                              size: 17,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ShaderMask(
                                  shaderCallback: (rect) => activeTheme
                                      .primaryGradient
                                      .createShader(rect),
                                  blendMode: BlendMode.srcIn,
                                  child: Text(
                                    song.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.songTitle.copyWith(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.3,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                Text(
                                  song.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.artistName.copyWith(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: activeTheme.highlightColor
                                        .withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    PremiumSheetPill(
                      label: plainOnly
                          ? 'NO TIMING'
                          : fromCache
                          ? 'SAVED'
                          : 'LYRICS',
                      icon: fromCache
                          ? Icons.offline_pin_rounded
                          : Icons.graphic_eq_rounded,
                      color: activeTheme.highlightColor,
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
                        activeTrackColor: activeTheme.primaryAccent,
                        inactiveTrackColor: Colors.white.withValues(alpha: 0.16),
                        thumbColor: activeTheme.highlightColor,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
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
                            DurationFormatter.format(
                              Duration(milliseconds: posMs.toInt()),
                            ),
                            style: AppTextStyles.timeLabel.copyWith(
                              color: activeTheme.highlightColor.withValues(
                                alpha: 0.8,
                              ),
                            ),
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
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: activeTheme.primaryGradient,
                            boxShadow: [
                              BoxShadow(
                                color: activeTheme.primaryAccent.withValues(
                                  alpha: 0.45,
                                ),
                                blurRadius: 22,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: IconButton(
                            tooltip: playerState.isPlaying ? 'Pause' : 'Play',
                            iconSize: 30,
                            color: activeTheme.onPrimaryGradient,
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
