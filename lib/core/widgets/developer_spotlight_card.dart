import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundwave/app/theme/app_colors.dart';
import 'package:soundwave/app/theme/text_styles.dart';
import 'package:soundwave/core/widgets/glass_card.dart';
import 'package:soundwave/shared/providers/theme_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class DeveloperSpotlightCard extends ConsumerStatefulWidget {
  const DeveloperSpotlightCard({super.key});

  @override
  ConsumerState<DeveloperSpotlightCard> createState() =>
      _DeveloperSpotlightCardState();
}

class _DeveloperSpotlightCardState
    extends ConsumerState<DeveloperSpotlightCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _rotateAnimation = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _animController, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

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
  Widget build(BuildContext context) {
    final activeTheme = ref.watch(themeProvider);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion && _animController.isAnimating) {
      _animController.stop();
    } else if (!reduceMotion && !_animController.isAnimating) {
      _animController.repeat();
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: activeTheme.secondaryAccent.withValues(alpha: 0.22),
            blurRadius: 24,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: activeTheme.primaryAccent.withValues(alpha: 0.14),
            blurRadius: 20,
            spreadRadius: -2,
          ),
        ],
      ),
      child: GlassCard(
        borderRadius: 26,
        blur: 0,
        padding: EdgeInsets.zero,
        color: activeTheme.secondaryBackground.withValues(alpha: 0.90),
        borderColor: activeTheme.primaryAccent.withValues(alpha: 0.42),
        child: Stack(
          children: [
            // Decorative ambient glow in top-right
            Positioned(
              top: -20,
              right: -20,
              width: 140,
              height: 140,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        activeTheme.highlightColor.withValues(alpha: 0.22),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Isolated animated soundwave bars inside RepaintBoundary
            Positioned(
              bottom: 12,
              right: 18,
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _rotateAnimation,
                  builder: (context, _) {
                    return Row(
                      children: List.generate(7, (i) {
                        final h = reduceMotion
                            ? 14.0 + (i % 3) * 4.0
                            : 10.0 +
                                14.0 *
                                    math.sin(_rotateAnimation.value + (i * 0.8)).abs();
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          width: 3.5,
                          height: h,
                          decoration: BoxDecoration(
                            color: activeTheme.primaryAccent
                                .withValues(alpha: 0.35 + 0.05 * i),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ),
            ),

            // Card Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Creator Badge & GitHub Icon
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: activeTheme.accentGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.code_rounded,
                                color: Colors.white, size: 13),
                            SizedBox(width: 5),
                            Text(
                              'LEAD ARCHITECT & CREATOR',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _launchGithub(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: activeTheme.primaryAccent
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                          child: Icon(
                            Icons.open_in_new_rounded,
                            color: activeTheme.primaryAccent,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Profile Info Row
                  Row(
                    children: [
                      Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: activeTheme.primaryGradient,
                          border: Border.all(
                            color: activeTheme.highlightColor,
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: activeTheme.highlightColor
                                  .withValues(alpha: 0.35),
                              blurRadius: 14,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            'YC',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Name and Handles
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Yogesh Chavan',
                              style: AppTextStyles.cardTitle.copyWith(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Mobile Engineer & UI/UX Specialist',
                              style: AppTextStyles.subtitle.copyWith(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 6),

                            // GitHub username pill
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.glassBorderSubtle,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.terminal_rounded,
                                      size: 13,
                                      color: activeTheme.primaryAccent),
                                  const SizedBox(width: 6),
                                  Text(
                                    '@codewithyogeshh',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: activeTheme.primaryAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Interactive Button to Open GitHub
                  GlassCard(
                    borderRadius: 14,
                    blur: 0,
                    enableHaptics: true,
                    onTap: () => _launchGithub(context),
                    height: 46,
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF24292E),
                        Color(0xFF161B22),
                      ],
                    ),
                    borderColor:
                        activeTheme.primaryAccent.withValues(alpha: 0.45),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.favorite_rounded,
                            color: activeTheme.highlightColor, size: 16),
                        const SizedBox(width: 8),
                        const Text(
                          'github.com/codewithyogeshh',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded,
                            color: Colors.white70, size: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

