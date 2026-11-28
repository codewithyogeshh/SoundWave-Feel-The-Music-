import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundwave/app/theme/app_colors.dart';
import 'package:soundwave/app/theme/theme_model.dart';
import 'package:soundwave/core/widgets/premium_sheet.dart';
import 'package:soundwave/features/library/models/song_filter_state.dart';
import 'package:soundwave/shared/providers/theme_provider.dart';

class SortBottomSheet extends ConsumerWidget {
  final SongSortOption currentSort;

  const SortBottomSheet({
    super.key,
    required this.currentSort,
  });

  static Future<SongSortOption?> show(
    BuildContext context, {
    required SongSortOption currentSort,
  }) {
    return showModalBottomSheet<SongSortOption>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => SortBottomSheet(currentSort: currentSort),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTheme = ref.watch(themeProvider);
    final current = SongSortOption.values
        .where((option) => option == currentSort)
        .firstOrNull;

    return Container(
      decoration: premiumSheetDecoration(activeTheme, radius: 28),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      padding: const EdgeInsets.only(bottom: 18),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PremiumSheetHandle(theme: activeTheme),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: PremiumSheetHeader(
                theme: activeTheme,
                icon: Icons.sort_rounded,
                title: 'Sort Tracks By',
                subtitle: current == null
                    ? '${SongSortOption.values.length} ways to order your library'
                    : 'Now showing • ${current.label}',
              ),
            ),
            const SizedBox(height: 14),
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 20),
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
            const SizedBox(height: 6),
            Expanded(
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                itemCount: SongSortOption.values.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final option = SongSortOption.values[index];
                  return _buildOption(
                    context,
                    activeTheme,
                    option,
                    option == currentSort,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(
    BuildContext context,
    AppThemeType activeTheme,
    SongSortOption option,
    bool isSelected,
  ) {
    final foreground =
        isSelected ? activeTheme.onPrimaryGradient : Colors.white;

    return GestureDetector(
      onTap: () => Navigator.pop(context, option),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: isSelected ? activeTheme.primaryGradient : null,
          color: isSelected ? null : AppColors.glassWhite.withValues(alpha: 0.04),
          border: Border.all(
            color: isSelected
                ? activeTheme.highlightColor.withValues(alpha: 0.55)
                : AppColors.glassBorderSubtle,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeTheme.primaryAccent.withValues(alpha: 0.32),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.18)
                    : activeTheme.primaryAccent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                _getIconForOption(option),
                size: 17,
                color: isSelected ? foreground : activeTheme.highlightColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                option.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected
                      ? foreground
                      : Colors.white.withValues(alpha: 0.88),
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: foreground,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForOption(SongSortOption option) {
    switch (option) {
      case SongSortOption.nameAsc:
        return Icons.sort_by_alpha_rounded;
      case SongSortOption.nameDesc:
        return Icons.sort_by_alpha_rounded;
      case SongSortOption.artistAsc:
      case SongSortOption.artistDesc:
        return Icons.person_rounded;
      case SongSortOption.albumAsc:
        return Icons.album_rounded;
      case SongSortOption.durationAsc:
      case SongSortOption.durationDesc:
        return Icons.timer_outlined;
      case SongSortOption.sizeDesc:
      case SongSortOption.sizeAsc:
        return Icons.data_usage_rounded;
      case SongSortOption.recentlyAdded:
      case SongSortOption.dateOldest:
        return Icons.calendar_today_rounded;
      case SongSortOption.recentlyPlayed:
        return Icons.history_rounded;
    }
  }
}
