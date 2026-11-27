import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundwave/app/theme/app_colors.dart';
import 'package:soundwave/app/theme/theme_model.dart';
import 'package:soundwave/core/widgets/glass_card.dart';
import 'package:soundwave/shared/providers/theme_provider.dart';

class FloatingBottomNavBar extends ConsumerWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const FloatingBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTheme = ref.watch(themeProvider);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GlassCard(
        borderRadius: 30,
        blur: 24,
        color: activeTheme.secondaryBackground.withValues(alpha: 0.86),
        borderColor: activeTheme.primaryAccent.withValues(alpha: 0.25),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, Icons.home_rounded, 'Home', activeTheme, reduceMotion),
            _buildNavItem(1, Icons.explore_rounded, 'Explore', activeTheme, reduceMotion),
            _buildNavItem(2, Icons.library_music_rounded, 'Library', activeTheme, reduceMotion),
            _buildNavItem(3, Icons.search_rounded, 'Search', activeTheme, reduceMotion),
            _buildNavItem(4, Icons.person_rounded, 'Profile', activeTheme, reduceMotion),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    String label,
    AppThemeType activeTheme,
    bool reduceMotion,
  ) {
    final isSelected = index == currentIndex;
    final selectedForeground = activeTheme.onPrimaryGradient;

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: GestureDetector(
        onTap: () {
          if (!isSelected) {
            HapticFeedback.selectionClick();
            onTabSelected(index);
          }
        },
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          child: Center(
            child: AnimatedContainer(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: isSelected
                  ? const EdgeInsets.symmetric(horizontal: 14, vertical: 9)
                  : const EdgeInsets.all(9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: isSelected ? activeTheme.primaryGradient : null,
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: activeTheme.primaryAccent.withValues(alpha: 0.42),
                          blurRadius: 16,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 22,
                    color: isSelected ? selectedForeground : AppColors.textMuted,
                  ),
                  if (isSelected) ...[
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: selectedForeground,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

