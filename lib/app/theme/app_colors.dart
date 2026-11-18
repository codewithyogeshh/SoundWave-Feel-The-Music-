import 'package:flutter/material.dart';

/// SoundWave Visual Identity & Realtime Colors Token System (60-30-10)
class AppColors {
  // Backgrounds (60% Dominant Base)
  static const Color primaryBackground = Color(0xFF101735);
  static const Color secondaryBackground = Color(0xFF172454);
  static const Color deepBackground = Color(0xFF090F27);
  static const Color cardSurface = Color(0x1A1F2C61); // translucent surface

  // Accents & Actions (10% High-Impact Accent)
  static const Color electricBlue = Color(0xFF3478F6);
  static const Color neonBlue = Color(0xFF4D9EFF);
  static const Color violet = Color(0xFF8557F6);
  static const Color purple = Color(0xFFA45CFF);
  static const Color magenta = Color(0xFFE66BEF);
  static const Color hotPink = Color(0xFFFF529A);

  // Text Hierarchy
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFC8D2F2);
  static const Color textMuted = Color(0xFF8996BD);

  // Glassmorphic Surfaces (30% Structural Hierarchy)
  static const Color glassWhite = Color(0x14FFFFFF); // ~8% opacity
  static const Color glassWhiteMedium = Color(0x1FFFFFFF); // ~12% opacity
  static const Color glassWhiteHeavy = Color(0x2EFFFFFF); // ~18% opacity
  static const Color glassBorder = Color(0x29FFFFFF); // ~16% opacity
  static const Color glassBorderSubtle = Color(0x1AFFFFFF); // ~10% opacity

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [electricBlue, purple],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [violet, magenta],
  );

  static const LinearGradient magentaGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [hotPink, magenta],
  );

  static const LinearGradient cyanGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [neonBlue, electricBlue],
  );

  static const LinearGradient activeNavGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [purple, electricBlue],
  );

  static const LinearGradient glassOverlayGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x28FFFFFF),
      Color(0x05FFFFFF),
    ],
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF141D44),
      Color(0xFF101735),
      Color(0xFF090F27),
    ],
  );

  static const RadialGradient heroGlow = RadialGradient(
    center: Alignment(0.0, -0.2),
    radius: 1.2,
    colors: [
      Color(0x3D8557F6),
      Color(0x00101735),
    ],
  );
}

