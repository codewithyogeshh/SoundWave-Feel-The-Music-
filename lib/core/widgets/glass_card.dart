import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:soundwave/app/theme/app_colors.dart';

class GlassCard extends StatefulWidget {
  final Widget child;
  final double borderRadius;
  final double blur;
  final Color? color;
  final Color? borderColor;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final BoxBorder? border;
  final List<BoxShadow>? shadows;
  final double? width;
  final double? height;
  final bool enablePressScale;
  final bool enableHaptics;

  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = 22.0,
    this.blur = 16.0,
    this.color,
    this.borderColor,
    this.padding,
    this.margin,
    this.onTap,
    this.gradient,
    this.border,
    this.shadows,
    this.width,
    this.height,
    this.enablePressScale = true,
    this.enableHaptics = false,
  });

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(
        parent: _pressController,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    if (widget.onTap != null && widget.enablePressScale) {
      if (!MediaQuery.disableAnimationsOf(context)) {
        _pressController.forward();
      }
      if (widget.enableHaptics) {
        HapticFeedback.lightImpact();
      }
    }
  }

  void _handleTapUp(TapUpDetails _) {
    if (widget.onTap != null && widget.enablePressScale) {
      _pressController.reverse();
    }
  }

  void _handleTapCancel() {
    if (widget.onTap != null && widget.enablePressScale) {
      _pressController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final container = Container(
      width: widget.width,
      height: widget.height,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: widget.color ?? AppColors.glassWhite,
        gradient: widget.gradient ?? AppColors.glassOverlayGradient,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: widget.border ??
            Border.all(
              color: widget.borderColor ?? AppColors.glassBorder,
              width: 1.0,
            ),
        boxShadow: widget.shadows ??
            [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.20),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
      ),
      child: widget.child,
    );

    // Skip expensive BackdropFilter pass when blur == 0 (used in dense scrolling lists for 120fps)
    final Widget cardBody = widget.blur > 0
        ? ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: widget.blur,
                sigmaY: widget.blur,
              ),
              child: container,
            ),
          )
        : ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: container,
          );

    if (widget.onTap != null) {
      return Padding(
        padding: widget.margin ?? EdgeInsets.zero,
        child: GestureDetector(
          onTap: widget.onTap,
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          onTapCancel: _handleTapCancel,
          behavior: HitTestBehavior.opaque,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: cardBody,
          ),
        ),
      );
    }

    if (widget.margin != null) {
      return Padding(
        padding: widget.margin!,
        child: cardBody,
      );
    }

    return cardBody;
  }
}

