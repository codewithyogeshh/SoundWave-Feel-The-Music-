import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundwave/app/theme/app_colors.dart';
import 'package:soundwave/core/widgets/glass_card.dart';
import 'package:soundwave/shared/providers/theme_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Compact single-row credit: small avatar, name, handle and a GitHub button.
/// Deliberately small so the profile page stays about the listener.
class DeveloperSpotlightCard extends ConsumerWidget {
  const DeveloperSpotlightCard({super.key});

  Future<void> _launchGithub(BuildContext context) async {
    const url = 'https://github.com/codewithyogeshh';
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open GitHub link: $url')),
          );
        }
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open browser for GitHub profile')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTheme = ref.watch(themeProvider);

    return GlassCard(
      borderRadius: 18,
      blur: 0,
      enableHaptics: true,
      onTap: () => _launchGithub(context),
      color: activeTheme.secondaryBackground.withValues(alpha: 0.9),
      borderColor: activeTheme.primaryAccent.withValues(alpha: 0.32),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: activeTheme.primaryGradient,
              border: Border.all(
                color: activeTheme.highlightColor.withValues(alpha: 0.8),
                width: 1.5,
              ),
            ),
            child: const Center(
              child: Text(
                'YC',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12.5,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Yogesh Chavan',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Developer · @codewithyogeshh',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.9),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.open_in_new_rounded,
              size: 14,
              color: activeTheme.primaryAccent,
            ),
          ),
        ],
      ),
    );
  }
}
