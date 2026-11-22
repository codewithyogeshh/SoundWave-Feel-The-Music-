import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundwave/app/theme/app_colors.dart';
import 'package:soundwave/app/theme/text_styles.dart';
import 'package:soundwave/features/player/services/lyrics_service.dart';
import 'package:soundwave/shared/providers/player_provider.dart';
import 'package:soundwave/shared/providers/theme_provider.dart';

class LyricsViewer extends ConsumerStatefulWidget {
  final double height;
  final VoidCallback? onClose;

  const LyricsViewer({
    super.key,
    required this.height,
    this.onClose,
  });

  @override
  ConsumerState<LyricsViewer> createState() => _LyricsViewerState();
}

class _LyricsViewerState extends ConsumerState<LyricsViewer> {
  final ScrollController _scrollController = ScrollController();
  int _lastActiveIndex = -1;
  bool _isUserScrolling = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToActiveLine(int activeIndex) {
    if (_isUserScrolling || !_scrollController.hasClients || activeIndex < 0) return;

    // Approximate line height ~ 54px
    final targetOffset = (activeIndex * 56.0) - (widget.height * 0.35);
    final clampedOffset = targetOffset.clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    _scrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeTheme = ref.watch(themeProvider);
    final lyricsAsync = ref.watch(currentSongLyricsProvider);
    final playerState = ref.watch(playerProvider);
    final currentPos = playerState.position;

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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.mic_external_on_rounded, color: activeTheme.primaryAccent, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Live Karaoke Lyrics',
                      style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: activeTheme.primaryAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Tap line to seek',
                    style: TextStyle(
                      color: activeTheme.primaryAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),

          // Lyrics Body
          Expanded(
            child: lyricsAsync.when(
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

                final activeIndex = lyrics.getActiveLineIndex(currentPos);
                if (activeIndex != _lastActiveIndex) {
                  _lastActiveIndex = activeIndex;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _scrollToActiveLine(activeIndex);
                  });
                }

                return NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification is ScrollStartNotification &&
                        notification.dragDetails != null) {
                      _isUserScrolling = true;
                    } else if (notification is ScrollEndNotification) {
                      Future.delayed(const Duration(seconds: 3), () {
                        if (mounted) {
                          _isUserScrolling = false;
                        }
                      });
                    }
                    return false;
                  },
                  child: ListView.builder(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    itemCount: lyrics.lines.length,
                    itemBuilder: (context, index) {
                      final line = lyrics.lines[index];
                      final isActive = index == activeIndex;
                      final isPast = index < activeIndex;

                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          ref.read(playerProvider.notifier).seek(line.timestamp);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            line.text,
                            style: TextStyle(
                              fontSize: isActive ? 20 : 15,
                              fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                              height: 1.4,
                              color: isActive
                                  ? activeTheme.primaryAccent
                                  : isPast
                                      ? Colors.white.withValues(alpha: 0.6)
                                      : Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
