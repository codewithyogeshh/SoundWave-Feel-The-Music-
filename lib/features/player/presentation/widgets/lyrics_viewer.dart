import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundwave/app/theme/app_colors.dart';
import 'package:soundwave/app/theme/text_styles.dart';
import 'package:soundwave/features/player/presentation/lyrics_full_screen.dart';
import 'package:soundwave/features/player/services/lyrics_service.dart';
import 'package:soundwave/shared/providers/player_provider.dart';
import 'package:soundwave/shared/providers/theme_provider.dart';

/// Every lyric line is laid out at exactly this height. A fixed extent lets the
/// viewer centre the active line with arithmetic (index * extent) instead of
/// guessing heights, which is what used to make the lyrics drift away from the
/// centre as the song progressed.
const double _lineExtent = 68;

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

    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
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
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, _, _) => const LyricsFullScreen(),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeTheme = ref.watch(themeProvider);
    final lyricsAsync = ref.watch(currentSongLyricsProvider);
    final playerState = ref.watch(playerProvider);
    final currentPos = playerState.position;

    final body = lyricsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator.adaptive(),
      ),
      error: (_, _) => Center(
        child: Text(
          'No lyrics available for this song',
          style: AppTextStyles.subtitle.copyWith(color: AppColors.textMuted),
        ),
      ),
      data: (lyrics) {
        if (lyrics.isEmpty) {
          return Center(
            child: Text(
              'No lyrics found for this song',
              style: AppTextStyles.subtitle.copyWith(color: AppColors.textMuted),
            ),
          );
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

                  final baseSize = widget.fullScreen ? 17.0 : 15.0;
                  final activeSize = widget.fullScreen ? 24.0 : 20.0;

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref.read(playerProvider.notifier).seek(line.timestamp);
                    },
                    child: Center(
                      child: TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        tween: Tween<double>(end: isActive ? 1.0 : 0.0),
                        builder: (context, t, _) {
                          final baseColor = isPast
                              ? Colors.white.withValues(alpha: 0.55)
                              : Colors.white.withValues(alpha: 0.3);
                          return Text(
                            line.text,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: lerpDouble(baseSize, activeSize, t),
                              fontWeight: t > 0.5 ? FontWeight.w800 : FontWeight.w500,
                              height: 1.25,
                              color: Color.lerp(baseColor, activeTheme.primaryAccent, t),
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
        color: activeTheme.primaryBackground.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: activeTheme.primaryAccent.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.mic_external_on_rounded,
                      color: activeTheme.primaryAccent,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Live Karaoke Lyrics',
                      style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
                    ),
                  ],
                ),
                Tooltip(
                  message: 'Full screen lyrics',
                  child: GestureDetector(
                    onTap: _openFullScreen,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: activeTheme.primaryAccent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: activeTheme.primaryAccent.withValues(alpha: 0.45),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.open_in_full_rounded,
                            size: 13,
                            color: activeTheme.primaryAccent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Full screen',
                            style: TextStyle(
                              color: activeTheme.primaryAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
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
          const Divider(height: 1, color: Colors.white10),
          Expanded(child: body),
        ],
      ),
    );
  }
}
