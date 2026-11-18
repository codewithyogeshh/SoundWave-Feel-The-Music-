import 'package:flutter/material.dart';
import 'package:soundwave/app/theme/app_colors.dart';
import 'package:soundwave/app/theme/text_styles.dart';
import 'package:soundwave/features/library/models/song_filter_state.dart';

class SortBottomSheet extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: AppColors.glassBorder.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      padding: const EdgeInsets.only(top: 20, bottom: 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle Bar
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.sort_rounded, color: scheme.primary, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Sort Tracks By',
                    style: AppTextStyles.cardTitle.copyWith(fontSize: 18),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(color: AppColors.glassBorderSubtle, height: 1),

            // Sort Options List
            Expanded(
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                itemCount: SongSortOption.values.length,
                separatorBuilder: (_, _) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final option = SongSortOption.values[index];
                  final isSelected = option == currentSort;

                  return Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? scheme.secondary.withValues(alpha: 0.25)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      border: isSelected
                          ? Border.all(color: scheme.tertiary.withValues(alpha: 0.5), width: 1)
                          : null,
                    ),
                    child: ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      leading: Icon(
                        _getIconForOption(option),
                        color: isSelected ? scheme.tertiary : AppColors.textSecondary,
                        size: 20,
                      ),
                      title: Text(
                        option.label,
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check_circle_rounded, color: scheme.tertiary, size: 20)
                          : null,
                      onTap: () {
                        Navigator.pop(context, option);
                      },
                    ),
                  );
                },
              ),
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
