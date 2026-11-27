import 'dart:async';
import 'dart:ui' show FontFeature, lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundwave/app/theme/app_colors.dart';
import 'package:soundwave/app/theme/text_styles.dart';
import 'package:soundwave/core/widgets/premium_transitions.dart';
import 'package:soundwave/features/player/presentation/lyrics_full_screen.dart';
import 'package:soundwave/features/player/services/lyrics_service.dart';
import 'package:soundwave/shared/providers/player_provider.dart';
import 'package:soundwave/shared/providers/theme_provider.dart';

/// Every lyric line is laid out at exactly this height. A fixed extent lets the
/// viewer centre the active line with arithmetic (index * extent) instead of
/// guessing heights, which is what used to make the lyrics drift away from the
/// centre as the song progressed.
const double _lineExtent = 94;

class LyricsViewer extends ConsumerStatefulWidget {
  /// Fixed height for the inline card. Ignored in full-screen mode.
  final double? height;

  /// Full-screen mode uses larger type and hides the "card" decoration.
  final bool fullScreen;

  final VoidCallback? onClose;

  const LyricsViewer({
    super.key,
    this.height,
    this.fullScreen = false,
    this.onClose,
  });

  @override
  ConsumerState<LyricsViewer> createState() => _LyricsViewerState();
}

class _LyricsViewerState extends ConsumerState<LyricsViewer> {
  final ScrollController _scrollController = ScrollController();

  int _activeIndex = -1;
  int _lastScrolledIndex = -1;
  String? _songId;

  bool _userDragging = false;
  Timer? _resumeFollowTimer;

  @override
  void dispose() {
    _resumeFollowTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  /// Brings [index] to the exact vertical centre of the list.
  ///
  /// The list is padded by `(viewport - lineExtent) / 2` on both sides, so the
  /// centre of row `i` sits at offset `i * lineExtent`. That makes this exact,
  /// with no accumulated error for long songs.
  void _scrollToLine(int index, {bool animate = true}) {
    if (index < 0 || !_scrollController.hasClients) return;
    final maxExtent = _scrollController.position.maxScrollExtent;
    final target = (index * _lineExtent).clamp(0.0, maxExtent).toDouble();
    _lastScrolledIndex = index;

    if (!animate) {
      _scrollController.jumpTo(target);
      return;
    }

    // Longer jumps glide for longer, so a chorus jump never snaps: the whole
    // list eases in and out instead of starting and stopping abruptly.
    final distance = (target - _scrollController.offset).abs();
    final duration = Duration(
      milliseconds: (260 + distance * 0.4).clamp(260.0, 620.0).round(),
    );
    _scrollController.animateTo(
      target,
      duration: duration,
      curve: Curves.easeInOutCubic,
    );
  }

  void _scheduleFollow(int index) {
    if (_userDragging) return;
    if (index == _lastScrolledIndex) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _userDragging) return;
      _scrollToLine(index);
    });
  }

  /// After the listener scrolls by hand, follow the song again shortly after.
  void _onUserInteractionEnd() {
    _resumeFollowTimer?.cancel();
    _resumeFollowTimer = Timer(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      _userDragging = false;
      _scrollToLine(_activeIndex);
    });
  }

  /// Opens the immersive full-screen lyrics screen from the inline card.
  void _openFullScreen() {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 360),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, _, _) => const LyricsFullScreen(),
        // Same fade-through settle as every other page, so the immersive
        // screen grows out of the card instead of blinking on.
        transitionsBuilder: (_, animation, secondaryAnimation, child) =>
            premiumPageTransition(
              animation,
              secondaryAnimation,
              child,
              begin: const Offset(0, 0.02),
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeTheme = ref.watch(themeProvider);
    final lyricsAsync = ref.watch(currentSongLyricsProvider);
    final fromCache = ref.watch(lyricsFromCacheProvider);
    final playerState = ref.watch(playerProvider);
    final currentPos = playerState.position;
    final loadedLyrics = lyricsAsync.asData?.value;
    final plainOnly =
        loadedLyrics != null && loadedLyrics.isNotEmpty && !loadedLyrics.isSynced;

    final body = lyricsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator.adaptive(),
      ),
      error: (_, _) => LyricsUnavailable(fullScreen: widget.fullScreen),
      data: (lyrics) {
        if (lyrics.isEmpty) {
          return LyricsUnavailable(fullScreen: widget.fullScreen);
        }

        // New song / new lyrics: start again from the top without animation.
        if (_songId != lyrics.songId) {
          _songId = lyrics.songId;
          _activeIndex = -1;
          _lastScrolledIndex = -1;
          _userDragging = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _scrollToLine(0, animate: false);
          });
        }

        final activeIndex = lyrics.getActiveLineIndex(currentPos);
        if (activeIndex != _activeIndex) {
          _activeIndex = activeIndex;
          _scheduleFollow(activeIndex);
        }

        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollStartNotification &&
                notification.dragDetails != null) {
              _userDragging = true;
              _resumeFollowTimer?.cancel();
            } else if (notification is ScrollEndNotification && _userDragging) {
              _onUserInteractionEnd();
            }
            return false;
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              final viewportHeight = constraints.maxHeight;
              final verticalPadding = ((viewportHeight - _lineExtent) / 2)
                  .clamp(0.0, viewportHeight)
                  .toDouble();

              return ListView.builder(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(20, verticalPadding, 20, verticalPadding),
                itemExtent: _lineExtent,
                itemCount: lyrics.lines.length,
                itemBuilder: (context, index) {
                  final line = lyrics.lines[index];
                  final isActive = index == activeIndex;
                  final isPast = index < activeIndex;

                  // Bigger type throughout: the sung line now carries the
                  // screen, and the rest still stay readable at arm's length.
                  final baseSize = widget.fullScreen ? 22.5 : 20.0;
                  final activeSize = widget.fullScreen ? 32.0 : 28.5;

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref.read(playerProvider.notifier).seek(line.timestamp);
                    },
                    child: Center(
                      child: TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 380),
                        curve: Curves.easeOutCubic,
                        tween: Tween<double>(end: isActive ? 1.0 : 0.0),
                        builder: (context, t, _) {
                          final baseColor = isPast
                              ? Colors.white.withValues(alpha: 0.74)
                              : Colors.white.withValues(alpha: 0.48);
                          // The sung line lights up in the theme's brightest
                          // accent, inside a glowing gradient pill.
                          // Push the sung line all the way to the theme's
                          // brightest colour so it pops off the dim lines.
                          final activeColor = Color.lerp(
                            activeTheme.highlightColor,
                            Colors.white,
                            0.35,
                          )!;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: t <= 0.01
                                  ? null
                                  : LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        activeTheme.primaryAccent.withValues(alpha: 0.46 * t),
                                        activeTheme.highlightColor.withValues(alpha: 0.32 * t),
                                      ],
                                    ),
                              border: Border.all(
                                color: activeTheme.highlightColor.withValues(alpha: 0.78 * t),
                                width: 1,
                              ),
                              boxShadow: t <= 0.01
                                  ? null
                                  : [
                                      BoxShadow(
                                        color: activeTheme.primaryAccent.withValues(alpha: 0.55 * t),
                                        blurRadius: 26,
                                        spreadRadius: 1,
                                      ),
                                    ],
                            ),
                            child: Text(
                              line.text,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: lerpDouble(baseSize, activeSize, t),
                                // One weight throughout: flipping w600 → w800
                                // mid-tween made the line give a visible jolt.
                                fontWeight: FontWeight.w700,
                                height: 1.22,
                                letterSpacing: -0.3,
                                color: Color.lerp(baseColor, activeColor, t),
                                shadows: t <= 0.01
                                    ? null
                                    : [
                                        Shadow(
                                          color: activeTheme.highlightColor.withValues(alpha: 0.8 * t),
                                          blurRadius: 22,
                                        ),
                                      ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );

    if (widget.fullScreen) {
      return body;
    }

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: activeTheme.secondaryBackground.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(28),
        // Same lifted, colour-washed card as the mini player and Now Playing.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            activeTheme.primaryAccent.withValues(alpha: 0.30),
            activeTheme.highlightColor.withValues(alpha: 0.16),
          ],
        ),
        border: Border.all(
          color: activeTheme.highlightColor.withValues(alpha: 0.38),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: activeTheme.primaryAccent.withValues(alpha: 0.26),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.only(left: 10, right: 8, top: 9, bottom: 9),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: activeTheme.accentGradient,
                    boxShadow: [
                      BoxShadow(
                        color: activeTheme.primaryAccent.withValues(alpha: 0.5),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.mic_external_on_rounded,
                    color: activeTheme.onAccentGradient,
                    size: 17,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Live Karaoke Lyrics',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.cardTitle.copyWith(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      if (fromCache) ...[
                        const SizedBox(width: 6),
                        Tooltip(
                          message: 'Lyrics saved on this device',
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: activeTheme.primaryAccent.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.offline_pin_rounded,
                                  size: 10,
                                  color: activeTheme.primaryAccent,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  'SAVED',
                                  style: TextStyle(
                                    color: activeTheme.primaryAccent,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (plainOnly) ...[
                        const SizedBox(width: 6),
                        Tooltip(
                          message: 'Plain lyrics — no timestamps to follow',
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'PLAIN',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const LyricsSyncControls(compact: true),
                const SizedBox(width: 4),
                Tooltip(
                  message: 'Full screen lyrics',
                  child: GestureDetector(
                    onTap: _openFullScreen,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            activeTheme.primaryAccent.withValues(alpha: 0.34),
                            activeTheme.highlightColor.withValues(alpha: 0.22),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: activeTheme.highlightColor.withValues(alpha: 0.55),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.open_in_full_rounded,
                            size: 13,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Full screen',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  activeTheme.highlightColor.withValues(alpha: 0.45),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// Honest empty state for a track with no published lyrics.
///
/// Nothing is invented in its place; retry refetches from LRCLIB (and the
/// JioSaavn fallback) without touching the rest of the player.
class LyricsUnavailable extends ConsumerWidget {
  /// Full-screen mode uses larger type and spacing.
  final bool fullScreen;

  const LyricsUnavailable({super.key, this.fullScreen = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTheme = ref.watch(themeProvider);
    final isLoading = ref.watch(currentSongLyricsProvider).isLoading;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lyrics_outlined,
              size: fullScreen ? 42 : 26,
              color: AppColors.textMuted,
            ),
            SizedBox(height: fullScreen ? 14 : 8),
            Text(
              'No lyrics available for this song',
              textAlign: TextAlign.center,
              style: AppTextStyles.subtitle.copyWith(
                color: Colors.white70,
                fontSize: fullScreen ? 16 : 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: fullScreen ? 6 : 3),
            Text(
              'LRCLIB has no synced or plain lyrics for this track yet.',
              textAlign: TextAlign.center,
              style: AppTextStyles.subtitle.copyWith(
                color: AppColors.textMuted,
                fontSize: fullScreen ? 12.5 : 10.5,
              ),
            ),
            SizedBox(height: fullScreen ? 18 : 9),
            OutlinedButton.icon(
              onPressed: isLoading
                  ? null
                  : () {
                      HapticFeedback.selectionClick();
                      ref.invalidate(currentSongLyricsProvider);
                    },
              style: OutlinedButton.styleFrom(
                foregroundColor: activeTheme.primaryAccent,
                side: BorderSide(
                  color: activeTheme.primaryAccent.withValues(alpha: 0.5),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: fullScreen ? 18 : 12,
                  vertical: fullScreen ? 10 : 4,
                ),
                minimumSize: Size(0, fullScreen ? 40 : 30),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: isLoading
                  ? const SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.refresh_rounded, size: fullScreen ? 17 : 14),
              label: Text(
                isLoading ? 'Searching…' : 'Retry',
                style: TextStyle(fontSize: fullScreen ? 13 : 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Karaoke sync nudge: pulls the lyrics earlier (−) or pushes them later (+).
/// The value in the middle resets the per-song offset back to zero.
class LyricsSyncControls extends ConsumerWidget {
  /// Compact renders the pill used in the inline lyrics card header.
  final bool compact;

  const LyricsSyncControls({super.key, this.compact = false});

  String _label(int offsetMs) {
    if (offsetMs == 0) return '0.0s';
    final sign = offsetMs > 0 ? '+' : '−';
    return '$sign${(offsetMs.abs() / 1000).toStringAsFixed(2)}s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTheme = ref.watch(themeProvider);
    final offsetMs = ref.watch(lyricsOffsetProvider);
    final notifier = ref.read(lyricsOffsetProvider.notifier);
    final textSize = compact ? 9.5 : 11.5;
    final buttonSize = compact ? 20.0 : 28.0;

    Widget button({required IconData icon, required VoidCallback onTap}) {
      return InkResponse(
        radius: buttonSize / 2 + 4,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: SizedBox(
          width: buttonSize,
          height: buttonSize,
          child: Icon(icon, size: compact ? 13 : 17, color: activeTheme.primaryAccent),
        ),
      );
    }

    return Tooltip(
      message: 'Lyrics sync — tap the value to reset',
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 2 : 4, vertical: compact ? 1 : 3),
        decoration: BoxDecoration(
          color: activeTheme.primaryAccent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(compact ? 7 : 10),
          border: Border.all(
            color: activeTheme.primaryAccent.withValues(alpha: 0.32),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            button(
              icon: Icons.remove_rounded,
              onTap: () => notifier.nudge(-LyricsOffsetNotifier.stepMs),
            ),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                notifier.reset();
              },
              child: Container(
                constraints: BoxConstraints(minWidth: compact ? 34 : 44),
                alignment: Alignment.center,
                child: Text(
                  _label(offsetMs),
                  style: TextStyle(
                    color: offsetMs == 0
                        ? AppColors.textMuted
                        : activeTheme.primaryAccent,
                    fontSize: textSize,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
            button(
              icon: Icons.add_rounded,
              onTap: () => notifier.nudge(LyricsOffsetNotifier.stepMs),
            ),
          ],
        ),
      ),
    );
  }
}
