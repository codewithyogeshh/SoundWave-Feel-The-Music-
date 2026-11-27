import 'package:flutter/material.dart';

enum AppThemeType {
  cyberNeon,
  midnightOled,
  royalAmethyst,
  emeraldAurora,
  crimsonEclipse;

  String get label {
    switch (this) {
      case AppThemeType.cyberNeon:
        return 'Cyber Neon';
      case AppThemeType.midnightOled:
        return 'Midnight Obsidian';
      case AppThemeType.royalAmethyst:
        return 'Royal Amethyst';
      case AppThemeType.emeraldAurora:
        return 'Emerald Aurora';
      case AppThemeType.crimsonEclipse:
        return 'Crimson Eclipse';
    }
  }

  String get description {
    switch (this) {
      case AppThemeType.cyberNeon:
        return 'Deep midnight navy with electric blue and magenta glow';
      case AppThemeType.midnightOled:
        return 'Pure 100% OLED black with luxury gold and amber glow';
      case AppThemeType.royalAmethyst:
        return 'Deep velvet purple with lilac and violet radiance';
      case AppThemeType.emeraldAurora:
        return 'Cyberpunk matrix slate with mint emerald and electric teal';
      case AppThemeType.crimsonEclipse:
        return 'Vampire dark wine with neon rose and sunset coral';
    }
  }

  Color get primaryBackground {
    switch (this) {
      case AppThemeType.cyberNeon:
        return const Color(0xFF101735);
      case AppThemeType.midnightOled:
        return const Color(0xFF050508);
      case AppThemeType.royalAmethyst:
        return const Color(0xFF130924);
      case AppThemeType.emeraldAurora:
        return const Color(0xFF061514);
      case AppThemeType.crimsonEclipse:
        return const Color(0xFF19080E);
    }
  }

  Color get secondaryBackground {
    switch (this) {
      case AppThemeType.cyberNeon:
        return const Color(0xFF172454);
      case AppThemeType.midnightOled:
        return const Color(0xFF111118);
      case AppThemeType.royalAmethyst:
        return const Color(0xFF1E1038);
      case AppThemeType.emeraldAurora:
        return const Color(0xFF0C2624);
      case AppThemeType.crimsonEclipse:
        return const Color(0xFF280C17);
    }
  }

  Color get deepBackground {
    switch (this) {
      case AppThemeType.cyberNeon:
        return const Color(0xFF090F27);
      case AppThemeType.midnightOled:
        return const Color(0xFF000000);
      case AppThemeType.royalAmethyst:
        return const Color(0xFF0C0517);
      case AppThemeType.emeraldAurora:
        return const Color(0xFF030D0C);
      case AppThemeType.crimsonEclipse:
        return const Color(0xFF100308);
    }
  }

  Color get primaryAccent {
    switch (this) {
      case AppThemeType.cyberNeon:
        return const Color(0xFF4D9EFF);
      case AppThemeType.midnightOled:
        return const Color(0xFFFFD700);
      case AppThemeType.royalAmethyst:
        return const Color(0xFF9D4EDD);
      case AppThemeType.emeraldAurora:
        return const Color(0xFF00F5A0);
      case AppThemeType.crimsonEclipse:
        return const Color(0xFFFF0055);
    }
  }

  Color get secondaryAccent {
    switch (this) {
      case AppThemeType.cyberNeon:
        return const Color(0xFFA45CFF);
      case AppThemeType.midnightOled:
        return const Color(0xFFFF9100);
      case AppThemeType.royalAmethyst:
        return const Color(0xFFC77DFF);
      case AppThemeType.emeraldAurora:
        return const Color(0xFF00D9F5);
      case AppThemeType.crimsonEclipse:
        return const Color(0xFFFF4D6D);
    }
  }

  Color get highlightColor {
    switch (this) {
      case AppThemeType.cyberNeon:
        return const Color(0xFFE66BEF);
      case AppThemeType.midnightOled:
        return const Color(0xFFFFB703);
      case AppThemeType.royalAmethyst:
        return const Color(0xFFE0AAFF);
      case AppThemeType.emeraldAurora:
        return const Color(0xFF70FFD6);
      case AppThemeType.crimsonEclipse:
        return const Color(0xFFFF758F);
    }
  }

  LinearGradient get backgroundGradient {
    switch (this) {
      case AppThemeType.cyberNeon:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF141D44),
            Color(0xFF101735),
            Color(0xFF090F27),
          ],
        );
      case AppThemeType.midnightOled:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0F0F16),
            Color(0xFF050508),
            Color(0xFF000000),
          ],
        );
      case AppThemeType.royalAmethyst:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1E0E38),
            Color(0xFF130924),
            Color(0xFF0C0517),
          ],
        );
      case AppThemeType.emeraldAurora:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0D2B28),
            Color(0xFF061514),
            Color(0xFF030D0C),
          ],
        );
      case AppThemeType.crimsonEclipse:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF2B0E1B),
            Color(0xFF19080E),
            Color(0xFF100308),
          ],
        );
    }
  }

  LinearGradient get primaryGradient {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primaryAccent, secondaryAccent],
    );
  }

  LinearGradient get accentGradient {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [secondaryAccent, highlightColor],
    );
  }

  /// Near-black ink for white/cream lettering on light fills.
  static const Color inkOnFill = Color(0xFF090D16);

  static double _contrastRatio(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final hi = la > lb ? la : lb;
    final lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  /// Picks black or white text for a filled shape, whichever stays readable
  /// across every stop of [fills]. Gold, mint and lilac fills get dark ink;
  /// deep blue, violet and crimson fills keep white, in every theme.
  static Color readableOn(List<Color> fills) {
    if (fills.isEmpty) return Colors.white;
    double worstFor(Color fg) => fills
        .map((fill) => _contrastRatio(fg, fill))
        .reduce((a, b) => a < b ? a : b);
    return worstFor(inkOnFill) >= worstFor(Colors.white)
        ? inkOnFill
        : Colors.white;
  }

  /// Foreground for anything drawn on [primaryAccent].
  Color get onPrimaryAccent => readableOn([primaryAccent]);

  /// Foreground for anything drawn on [primaryGradient].
  Color get onPrimaryGradient => readableOn(primaryGradient.colors);

  /// Foreground for anything drawn on [accentGradient].
  Color get onAccentGradient => readableOn(accentGradient.colors);

  List<Color> get swatches => [
        primaryBackground,
        primaryAccent,
        secondaryAccent,
        highlightColor,
      ];
}

