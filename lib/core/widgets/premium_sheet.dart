import 'package:flutter/material.dart';
import 'package:soundwave/app/theme/app_colors.dart';
import 'package:soundwave/app/theme/theme_model.dart';

/// Background used by every player bottom sheet: the theme's own colour, warmed
/// at the top with the accent so the sheet feels lit from above.
BoxDecoration premiumSheetDecoration(AppThemeType theme, {double radius = 30}) {
  return BoxDecoration(
    borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      stops: const [0.0, 0.45, 1.0],
      colors: [
        Color.lerp(theme.secondaryBackground, theme.primaryAccent, 0.12)!,
        theme.secondaryBackground,
        theme.primaryBackground,
      ],
    ),
    border: Border.all(
      color: theme.highlightColor.withValues(alpha: 0.22),
    ),
  );
}

/// The little gradient grip at the top of a sheet.
class PremiumSheetHandle extends StatelessWidget {
  final AppThemeType theme;

  const PremiumSheetHandle({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 46,
        height: 4,
        margin: const EdgeInsets.only(top: 10, bottom: 14),
        decoration: BoxDecoration(
          gradient: theme.primaryGradient,
          borderRadius: BorderRadius.circular(2),
          boxShadow: [
            BoxShadow(
              color: theme.primaryAccent.withValues(alpha: 0.55),
              blurRadius: 10,
            ),
          ],
        ),
      ),
    );
  }
}

/// Title block of a sheet: gradient badge, gradient title and one quiet line of
/// context underneath.
class PremiumSheetHeader extends StatelessWidget {
  final AppThemeType theme;
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const PremiumSheetHeader({
    super.key,
    required this.theme,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.primaryAccent,
                theme.primaryAccent.withValues(alpha: 0.6),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: theme.primaryAccent.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Icon(icon, size: 21, color: theme.onPrimaryAccent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ShaderMask(
                shaderCallback: (rect) =>
                    theme.primaryGradient.createShader(rect),
                blendMode: BlendMode.srcIn,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: Colors.white,
                  ),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 10), trailing!],
      ],
    );
  }
}

/// Small glass pill for counts, badges and inline actions inside a sheet.
class PremiumSheetPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final VoidCallback? onTap;

  const PremiumSheetPill({
    super.key,
    required this.label,
    this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: content,
    );
  }
}
