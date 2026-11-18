import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:soundwave/app/theme/app_colors.dart';

class WaveformGlow extends StatefulWidget {
  final bool isPlaying;
  final double width;
  final double height;

  const WaveformGlow({
    super.key,
    required this.isPlaying,
    required this.width,
    required this.height,
  });

  @override
  State<WaveformGlow> createState() => _WaveformGlowState();
}

class _WaveformGlowState extends State<WaveformGlow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant WaveformGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat();
      } else {
        _controller.animateTo(0.2, duration: const Duration(milliseconds: 400));
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
            painter: _WaveformGlowPainter(
              progress: _controller.value,
              isPlaying: widget.isPlaying,
            ),
          );
        },
      ),
    );
  }
}

class _WaveformGlowPainter extends CustomPainter {
  final double progress;
  final bool isPlaying;

  _WaveformGlowPainter({required this.progress, required this.isPlaying});

  @override
  void paint(Canvas canvas, Size size) {
    final barCount = 36;
    final barWidth = size.width / (barCount * 1.6);
    final centerY = size.height * 0.52;

    for (int i = 0; i < barCount; i++) {
      // Don't draw bars directly in the center where artwork sits
      final normalizedX = (i - (barCount / 2)) / (barCount / 2);
      if (normalizedX.abs() < 0.65) continue; // Leaves space for the 300px album art

      final x = (i / barCount) * size.width;
      final wave = math.sin((i * 0.35) + (progress * 2 * math.pi));
      final dynamicFactor = isPlaying ? (0.4 + 0.6 * ((wave + 1) / 2)) : 0.2;
      final barHeight = size.height * 0.35 * dynamicFactor * (1.0 - (normalizedX.abs() - 0.65) * 0.8);

      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.magenta.withValues(alpha: 0.0),
            AppColors.violet.withValues(alpha: 0.45 * dynamicFactor),
            AppColors.neonBlue.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(x, centerY - barHeight / 2, barWidth, barHeight))
        ..style = PaintingStyle.fill;

      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, centerY - barHeight / 2, barWidth, barHeight),
        const Radius.circular(3),
      );
      canvas.drawRRect(rrect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformGlowPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.isPlaying != isPlaying;
}

