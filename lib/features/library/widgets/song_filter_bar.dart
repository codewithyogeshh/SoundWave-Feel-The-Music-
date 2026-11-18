import 'package:flutter/material.dart';
import 'package:soundwave/app/theme/app_colors.dart';
import 'package:soundwave/app/theme/text_styles.dart';
import 'package:soundwave/features/library/models/song_filter_state.dart';
import 'package:soundwave/features/library/widgets/filter_bottom_sheet.dart';
import 'package:soundwave/features/library/widgets/sort_bottom_sheet.dart';
import 'package:soundwave/features/player/models/song_model.dart';

class SongFilterBar extends StatefulWidget {
  final SongFilterState filterState;
  final List<SongModel> allSongs;
  final int filteredCount;
  final ValueChanged<SongFilterState> onFilterChanged;
  final bool showSearchInput;

  const SongFilterBar({
    super.key,
    required this.filterState,
    required this.allSongs,
    required this.filteredCount,
    required this.onFilterChanged,
    this.showSearchInput = true,
  });

  @override
  State<SongFilterBar> createState() => _SongFilterBarState();
}

class _SongFilterBarState extends State<SongFilterBar> {
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.filterState.searchQuery);
  }

  @override
  void didUpdateWidget(covariant SongFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.filterState.searchQuery != _searchController.text) {
      _searchController.text = widget.filterState.searchQuery;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filterState = widget.filterState;
    final onFilterChanged = widget.onFilterChanged;
    final allSongs = widget.allSongs;
    final filteredCount = widget.filteredCount;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Search Bar with Instant Reactive Filtering
        if (widget.showSearchInput)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.glassWhiteMedium,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: filterState.searchQuery.isNotEmpty
                      ? scheme.primary.withValues(alpha: 0.55)
                      : AppColors.glassBorderSubtle,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) {
                        onFilterChanged(filterState.copyWith(searchQuery: val));
                      },
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'Filter tracks by title, artist, or album...',
                        hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (filterState.searchQuery.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        onFilterChanged(filterState.copyWith(searchQuery: ''));
                      },
                      child: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 18),
                    ),
                ],
              ),
            ),
          ),

        // 2. Filter Action Bar (Chips + Filter & Sort Buttons)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              // Horizontally Scrollable Filter Category Chips
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: SongCategoryFilter.values.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final cat = SongCategoryFilter.values[index];
                      final isSelected = filterState.category == cat;

                      return GestureDetector(
                        onTap: () {
                          onFilterChanged(filterState.copyWith(category: cat));
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: isSelected ? scheme.secondary : AppColors.glassWhiteMedium,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isSelected ? scheme.tertiary : AppColors.glassBorderSubtle,
                              width: 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: scheme.secondary.withValues(alpha: 0.35),
                                      blurRadius: 8,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(
                            cat.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? Colors.white : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Filter Bottom Sheet Button
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.tune_rounded, color: Colors.white, size: 20),
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                      onPressed: () async {
                        final updated = await FilterBottomSheet.show(
                          context,
                          currentState: filterState,
                          songs: allSongs,
                        );
                        if (updated != null) {
                          onFilterChanged(updated);
                        }
                      },
                    ),
                    if (filterState.activeFilterCount > 0)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: scheme.tertiary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Sort Bottom Sheet Button
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: IconButton(
                  icon: const Icon(Icons.swap_vert_rounded, color: Colors.white, size: 22),
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                  onPressed: () async {
                    final selectedSort = await SortBottomSheet.show(
                      context,
                      currentSort: filterState.sortBy,
                    );
                    if (selectedSort != null) {
                      onFilterChanged(filterState.copyWith(sortBy: selectedSort));
                    }
                  },
                ),
              ),
            ],
          ),
        ),

        // 3. Status Line: Count & Active Filters Pills
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$filteredCount ${filteredCount == 1 ? "track" : "tracks"}${filterState.hasActiveFilters ? " found" : ""}',
                style: AppTextStyles.timeLabel.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (filterState.hasActiveFilters)
                GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    onFilterChanged(filterState.reset());
                  },
                  child: Row(
                    children: [
                      Icon(Icons.refresh_rounded, size: 12, color: scheme.tertiary),
                      const SizedBox(width: 4),
                      Text(
                        'Clear Filters',
                        style: TextStyle(
                          color: scheme.tertiary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
