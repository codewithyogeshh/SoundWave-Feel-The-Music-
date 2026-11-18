import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:soundwave/app/theme/app_colors.dart';

/// Interactive & fluid visualizer suite featuring:
/// 1. BeatRipples: Expanding concentric neon glow rings behind artwork
/// 2. ArtworkBeatBounce: Physical bounce on album art with the music rhythm
/// 3. EqualizerSpectrumBars: Real-feeling audio spectrum with gravity peak dots
class BeatRipples extends StatefulWidget {
  final bool isPlaying;
  final double size;
  final Widget child;

  const BeatRipples({
    super.key,
    required this.isPlaying,
    required this.size,
    required this.child,
  });

  @override
  State<BeatRipples> createState() => _BeatRipplesState();
}

class _BeatRipplesState extends State<BeatRipples>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant BeatRipples oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat();
      } else {
        _controller.stop();
        _controller.animateTo(0.0, duration: const Duration(milliseconds: 300));
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size * 1.35,
      height: widget.size * 1.35,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final progress = _controller.value;
          // Beat pulse for the artwork scale
          final beatCycle = math.sin(progress * 2 * math.pi);
          final beatScale = widget.isPlaying
              ? 1.0 + (0.032 * math.max(0.0, beatCycle))
              : 1.0;

          return Stack(
            alignment: Alignment.center,
            children: [
              // Ripple 1 (Neon Magenta to Violet)
              if (widget.isPlaying)
                CustomPaint(
                  size: Size(widget.size * 1.35, widget.size * 1.35),
                  painter: _PulseRingPainter(
                    progress: progress,
                    innerRadius: widget.size * 0.48,
                    maxRadius: widget.size * 0.65,
                    color: AppColors.magenta,
                  ),
                ),

              // Ripple 2 (Violet to Electric Blue, phase offset)
              if (widget.isPlaying)
                CustomPaint(
                  size: Size(widget.size * 1.35, widget.size * 1.35),
                  painter: _PulseRingPainter(
                    progress: (progress + 0.5) % 1.0,
                    innerRadius: widget.size * 0.48,
                    maxRadius: widget.size * 0.65,
                    color: AppColors.electricBlue,
                  ),
                ),

              // Center Child with Rhythmic Scale Bounce
              Transform.scale(
                scale: beatScale,
                child: widget.child,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PulseRingPainter extends CustomPainter {
  final double progress;
  final double innerRadius;
  final double maxRadius;
  final Color color;

  _PulseRingPainter({
    required this.progress,
    required this.innerRadius,
    required this.maxRadius,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final currentRadius = innerRadius + (maxRadius - innerRadius) * progress;
    final alpha = (1.0 - progress).clamp(0.0, 1.0) * 0.45;

    final paint = Paint()
      ..color = color.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5 * (1.0 - progress * 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawCircle(center, currentRadius, paint);
  }

  @override
  bool shouldRepaint(covariant _PulseRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Dynamic animated beat spectrum bars with peak particles
class BeatSpectrumVisualizer extends StatefulWidget {
  final bool isPlaying;
  final double width;
  final double height;
  final int barCount;

  const BeatSpectrumVisualizer({
    super.key,
    required this.isPlaying,
    required this.width,
    this.height = 70.0,
    this.barCount = 32,
  });

  @override
  State<BeatSpectrumVisualizer> createState() => _BeatSpectrumVisualizerState();
}

class _BeatSpectrumVisualizerState extends State<BeatSpectrumVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant BeatSpectrumVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat();
      } else {
        _controller.animateTo(0.1, duration: const Duration(milliseconds: 400));
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _SpectrumPainter(
              progress: _controller.value,
              isPlaying: widget.isPlaying,
              barCount: widget.barCount,
            ),
          );
        },
      ),
    );
  }
}

class _SpectrumPainter extends CustomPainter {
  final double progress;
  final bool isPlaying;
  final int barCount;

  _SpectrumPainter({
    required this.progress,
    required this.isPlaying,
    required this.barCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final totalSpacing = size.width * 0.25;
    final barWidth = (size.width - totalSpacing) / barCount;
    final spacing = totalSpacing / (barCount - 1);
    final centerY = size.height;

    for (int i = 0; i < barCount; i++) {
      final x = i * (barWidth + spacing);

      // Create organic multi-harmonic frequency wave
      final harmonic1 = math.sin((i * 0.35) + (progress * 2 * math.pi));
      final harmonic2 = math.cos((i * 0.6) - (progress * 4 * math.pi));
      final harmonic3 = math.sin((i * 0.15) + (progress * 1.5 * math.pi));
      final combined = (harmonic1 * 0.5 + harmonic2 * 0.3 + harmonic3 * 0.2).abs();

      // Bass boost on lower and middle frequencies
      final centerDist = 1.0 - ((i - (barCount / 2)) / (barCount / 2)).abs() * 0.4;
      final rawFactor = isPlaying ? (combined * centerDist) : 0.08;
      final heightFactor = rawFactor.clamp(0.06, 0.95);
      final barHeight = size.height * heightFactor;

      final rect = Rect.fromLTWH(x, centerY - barHeight, barWidth, barHeight);

      // Gradient shader for each bar (Neon Cyan -> Violet -> Magenta)
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            AppColors.electricBlue,
            AppColors.violet,
            AppColors.magenta,
          ],
        ).createShader(rect)
        ..style = PaintingStyle.fill;

      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(3));
      canvas.drawRRect(rrect, paint);

      // Peak dot floating above the bar
      if (isPlaying && heightFactor > 0.3) {
        final dotPaint = Paint()
          ..color = AppColors.magenta.withValues(alpha: 0.9)
          ..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);

        final dotY = (centerY - barHeight - 4).clamp(0.0, size.height);
        canvas.drawCircle(Offset(x + barWidth / 2, dotY), barWidth * 0.45, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SpectrumPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.isPlaying != isPlaying;
}

