import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:soundwave/app/theme/app_colors.dart';
import 'package:soundwave/app/theme/theme_model.dart';

class GradientButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget? child;
  final String? text;
  final IconData? icon;
  final Gradient gradient;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final double? width;
  final double? height;
  final bool isCircle;
  final bool hasGlow;
  final Color? glowColor;

  const GradientButton({
    super.key,
    required this.onPressed,
    this.child,
    this.text,
    this.icon,
    this.gradient = AppColors.accentGradient,
    this.borderRadius = 30.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    this.width,
    this.height,
    this.isCircle = false,
    this.hasGlow = false,
    this.glowColor,
  });

  const GradientButton.pill({
    super.key,
    required this.onPressed,
    required this.text,
    this.icon = Icons.play_arrow_rounded,
    this.child,
    this.gradient = const LinearGradient(
      colors: [Colors.white, Color(0xFFF0F4FF)],
    ),
    this.borderRadius = 30.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
    this.width,
    this.height = 38,
    this.isCircle = false,
    this.hasGlow = true,
    this.glowColor = const Color(0x33FFFFFF),
  });

  const GradientButton.circle({
    super.key,
    required this.onPressed,
    required this.child,
    this.text,
    this.icon,
    this.gradient = AppColors.accentGradient,
    this.borderRadius = 50.0,
    this.padding = EdgeInsets.zero,
    required double size,
    this.isCircle = true,
    this.hasGlow = true,
    this.glowColor = AppColors.purple,
  })  : width = size,
        height = size;

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onPressed != null) {
      HapticFeedback.lightImpact();
      if (!MediaQuery.disableAnimationsOf(context)) {
        _controller.forward();
      }
    }
  }

  void _onTapUp(TapUpDetails _) {
    if (widget.onPressed != null) _controller.reverse();
  }

  void _onTapCancel() {
    if (widget.onPressed != null) _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveGlowColor = widget.glowColor ?? AppColors.purple;
    // Dark ink on the bright gold/mint/lilac fills, white on the deep ones, so
    // a button label never disappears in any of the five themes.
    final foreground = AppThemeType.readableOn(widget.gradient.colors);

    Widget content = widget.child ??
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.icon != null) ...[
              Icon(
                widget.icon,
                size: 18,
                color: foreground,
              ),
              const SizedBox(width: 6),
            ],
            if (widget.text != null)
              Text(
                widget.text!,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: foreground,
                  letterSpacing: -0.2,
                ),
              ),
          ],
        );
    content = IconTheme(
      data: IconThemeData(color: foreground),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: foreground),
        child: content,
      ),
    );

    return GestureDetector(
      onTap: widget.onPressed,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: widget.width,
          height: widget.height,
          padding: widget.padding,
          decoration: BoxDecoration(
            gradient: widget.gradient,
            shape: widget.isCircle ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: widget.isCircle
                ? null
                : BorderRadius.circular(widget.borderRadius),
            boxShadow: widget.hasGlow
                ? [
                    BoxShadow(
                      color: effectiveGlowColor.withValues(alpha: 0.4),
                      blurRadius: widget.isCircle ? 24 : 14,
                      spreadRadius: widget.isCircle ? 2 : 0,
                      offset: widget.isCircle
                          ? const Offset(0, 0)
                          : const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Center(child: content),
        ),
      ),
    );
  }
}

