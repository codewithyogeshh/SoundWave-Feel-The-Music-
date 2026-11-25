import 'package:flutter/material.dart';

/// One-shot entrance animation used across the premium layouts: the child
/// fades in while lifting a few pixels and settling from 98% scale.
///
/// The stagger comes from an [Interval] on the animation clock instead of
/// timers, so nothing is left pending if a screen is disposed mid-entrance,
/// and the whole effect is skipped when the platform asks for reduced motion.
class Reveal extends StatefulWidget {
  final Widget child;

  /// Position in the entrance order. Each step starts slightly later.
  final int index;

  final Duration duration;

  /// Vertical lift (fraction of the child's height) the child animates from.
  final Offset begin;

  const Reveal({
    super.key,
    required this.child,
    this.index = 0,
    this.duration = const Duration(milliseconds: 560),
    this.begin = const Offset(0, 0.08),
  });

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  late final Animation<double> _curve;

  @override
  void initState() {
    super.initState();
    final start = (widget.index.clamp(0, 8) * 0.07).clamp(0.0, 0.5);
    _curve = CurvedAnimation(
      parent: _controller,
      curve: Interval(start, 1.0, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.isAnimating || _controller.isCompleted) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      child: widget.child,
      builder: (context, child) {
        final t = _curve.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 14) + widget.begin * (1 - t),
            child: Transform.scale(scale: 0.98 + 0.02 * t, child: child),
          ),
        );
      },
    );
  }
}
