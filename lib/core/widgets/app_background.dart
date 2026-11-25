import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundwave/shared/providers/playback_prefs_provider.dart';
import 'package:soundwave/shared/providers/theme_provider.dart';

class AppBackground extends ConsumerWidget {
  final Widget child;
  final bool showGlow;

  const AppBackground({
    super.key,
    required this.child,
    this.showGlow = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    final batterySaver = ref.watch(batterySaverProvider);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: theme.deepBackground,
        gradient: theme.backgroundGradient,
      ),
      child: Stack(
        children: [
          if (showGlow && !batterySaver) ...[
            // Top-center Theme Glow
            Positioned(
              top: -80,
              left: 0,
              right: 0,
              height: 340,
              child: IgnorePointer(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        theme.primaryAccent.withValues(alpha: 0.24),
                        theme.secondaryAccent.withValues(alpha: 0.09),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            // Bottom-right Secondary Accent Ambient Glow
            Positioned(
              bottom: 60,
              right: -100,
              width: 300,
              height: 300,
              child: IgnorePointer(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        theme.highlightColor.withValues(alpha: 0.18),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Subtle ambient particles/light points
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _SubtleStardustPainter(),
                ),
              ),
            ),
          ],
          SafeArea(child: child),
        ],
      ),
    );
  }
}

class _SubtleStardustPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;

    // Deterministic subtle micro-stars
    final points = [
      Offset(size.width * 0.15, size.height * 0.12),
      Offset(size.width * 0.82, size.height * 0.08),
      Offset(size.width * 0.45, size.height * 0.22),
      Offset(size.width * 0.88, size.height * 0.35),
      Offset(size.width * 0.12, size.height * 0.48),
      Offset(size.width * 0.70, size.height * 0.65),
      Offset(size.width * 0.28, size.height * 0.78),
      Offset(size.width * 0.85, size.height * 0.85),
    ];

    for (final pt in points) {
      canvas.drawCircle(pt, 1.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
