import 'package:flutter/material.dart';
import 'package:soundwave/app/theme/app_colors.dart';
import 'package:soundwave/app/theme/theme_model.dart';

class AppTheme {
  static ThemeData get darkTheme => fromType(AppThemeType.midnightOled);

  static ThemeData fromType(AppThemeType theme) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: theme.primaryBackground,
      colorScheme: ColorScheme.dark(
        primary: theme.primaryAccent,
        secondary: theme.secondaryAccent,
        tertiary: theme.highlightColor,
        surface: theme.secondaryBackground,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: theme.highlightColor,
        inactiveTrackColor: const Color(0x33FFFFFF),
        thumbColor: Colors.white,
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return theme.highlightColor;
          }
          return AppColors.textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return theme.secondaryAccent.withValues(alpha: 0.45);
          }
          return Colors.white.withValues(alpha: 0.14);
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: theme.primaryAccent,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: theme.secondaryBackground,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: theme.primaryAccent.withValues(alpha: 0.28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: theme.secondaryBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: AppColors.glassBorderSubtle),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: theme.secondaryBackground,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.glassWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.glassBorder, width: 1),
        ),
      ),
    );
  }
}

