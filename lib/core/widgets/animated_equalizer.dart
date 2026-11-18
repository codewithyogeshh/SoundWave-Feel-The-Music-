import 'package:flutter/material.dart';
import 'package:soundwave/app/theme/app_colors.dart';

class AnimatedEqualizer extends StatefulWidget {
  final bool isPlaying;
  final Color? color;
  final double size;
  final int barCount;

  const AnimatedEqualizer({
    super.key,
    required this.isPlaying,
    this.color,
    this.size = 20.0,
    this.barCount = 4,
  });

  @override
  State<AnimatedEqualizer> createState() => _AnimatedEqualizerState();
}

class _AnimatedEqualizerState extends State<AnimatedEqualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedEqualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat();
      } else {
        _controller.animateTo(0.2, duration: const Duration(milliseconds: 300));
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
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(widget.barCount, (index) {
              final phase = (index * 0.25);
              final progress = (_controller.value + phase) % 1.0;
              // Bounce height wave
              final heightFactor = widget.isPlaying
                  ? 0.25 + 0.75 * (0.5 + 0.5 * (index % 2 == 0 ? 1 : -1) * (progress * 2 - 1).abs())
                  : 0.2;

              return Container(
                width: widget.size / (widget.barCount * 1.8),
                height: widget.size * heightFactor,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      AppColors.electricBlue,
                      widget.color ?? AppColors.magenta,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: widget.isPlaying
                      ? [
                          BoxShadow(
                            color: (widget.color ?? AppColors.magenta).withValues(alpha: 0.4),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

