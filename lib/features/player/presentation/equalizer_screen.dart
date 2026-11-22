import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundwave/app/theme/app_colors.dart';
import 'package:soundwave/app/theme/text_styles.dart';
import 'package:soundwave/app/theme/theme_model.dart';
import 'package:soundwave/core/widgets/app_background.dart';
import 'package:soundwave/core/widgets/glass_card.dart';
import 'package:soundwave/features/player/models/equalizer_model.dart';
import 'package:soundwave/features/player/services/equalizer_service.dart';
import 'package:soundwave/shared/providers/theme_provider.dart';

class EqualizerScreen extends ConsumerWidget {
  const EqualizerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTheme = ref.watch(themeProvider);
    final eq = ref.watch(equalizerProvider);
    final eqNotifier = ref.read(equalizerProvider.notifier);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Equalizer Studio',
          style: AppTextStyles.cardTitle.copyWith(fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          // Master Power Switch
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  eq.isEnabled ? 'ON' : 'BYPASS',
                  style: TextStyle(
                    color: eq.isEnabled ? activeTheme.primaryAccent : AppColors.textMuted,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(width: 6),
                Switch.adaptive(
                  value: eq.isEnabled,
                  activeThumbColor: activeTheme.primaryAccent,
                  activeTrackColor: activeTheme.primaryAccent.withValues(alpha: 0.35),
                  inactiveThumbColor: AppColors.textMuted,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                  onChanged: (_) => eqNotifier.toggleEnabled(),
                ),
              ],
            ),
          ),
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Presets Carousel
                _buildPresetChips(context, eq, eqNotifier, activeTheme),
                const SizedBox(height: 16),

                // Dynamic Frequency Spectrum Curve Card
                _buildCurveVisualizer(context, eq, activeTheme),
                const SizedBox(height: 18),

                // 5-Band Vertical Slider Console
                _buildSlidersConsole(context, eq, eqNotifier, activeTheme),
                const SizedBox(height: 18),

                // Bass Boost & 3D Spatial Virtualizer Effects
                _buildAcousticEnhancers(context, eq, eqNotifier, activeTheme),
                const SizedBox(height: 20),

                // Reset Action
                Center(
                  child: TextButton.icon(
                    onPressed: eq.isEnabled ? () => eqNotifier.resetToFlat() : null,
                    icon: Icon(
                      Icons.refresh_rounded,
                      size: 18,
                      color: eq.isEnabled ? activeTheme.secondaryAccent : AppColors.textMuted,
                    ),
                    label: Text(
                      'Reset to Studio Flat (0 dB)',
                      style: TextStyle(
                        color: eq.isEnabled ? activeTheme.secondaryAccent : AppColors.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPresetChips(
    BuildContext context,
    EqualizerModel eq,
    EqualizerNotifier notifier,
    AppThemeType activeTheme,
  ) {
    final presets = EqualizerModel.standardPresets.keys.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ACOUSTIC PROFILES',
                style: AppTextStyles.subtitle.copyWith(
                  letterSpacing: 1.2,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
              Text(
                eq.presetName,
                style: TextStyle(
                  color: activeTheme.primaryAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: presets.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final preset = presets[index];
              final isSelected = eq.presetName == preset;

              return GestureDetector(
                onTap: eq.isEnabled ? () => notifier.applyPreset(preset) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: isSelected ? activeTheme.primaryGradient : null,
                    color: isSelected ? null : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? activeTheme.primaryAccent.withValues(alpha: 0.8)
                          : Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSelected) ...[
                        const Icon(Icons.check_rounded, color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        preset,
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCurveVisualizer(
    BuildContext context,
    EqualizerModel eq,
    AppThemeType activeTheme,
  ) {
    return GlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Frequency Response Curve',
                style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (eq.isEnabled ? activeTheme.primaryAccent : AppColors.textMuted)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  eq.isEnabled ? 'Active dB Spectrum' : 'Bypassed',
                  style: TextStyle(
                    color: eq.isEnabled ? activeTheme.primaryAccent : AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          RepaintBoundary(
            child: SizedBox(
              height: 110,
              width: double.infinity,
              child: CustomPaint(
                painter: _FrequencyCurvePainter(
                  gains: eq.isEnabled ? eq.bandGains : const [0, 0, 0, 0, 0],
                  primaryColor: activeTheme.primaryAccent,
                  secondaryColor: activeTheme.secondaryAccent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlidersConsole(
    BuildContext context,
    EqualizerModel eq,
    EqualizerNotifier notifier,
    AppThemeType activeTheme,
  ) {
    return GlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(5, (index) {
              final gain = eq.isEnabled ? eq.bandGains[index] : 0.0;
              final label = EqualizerModel.bandLabels[index];
              final desc = EqualizerModel.bandDescriptions[index];

              return Column(
                children: [
                  // dB Readout Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${gain > 0 ? '+' : ''}${gain.toStringAsFixed(1)}',
                      style: TextStyle(
                        color: gain.abs() > 0.1 && eq.isEnabled
                            ? activeTheme.primaryAccent
                            : AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Vertical Slider
                  SizedBox(
                    height: 170,
                    width: 44,
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 4,
                          activeTrackColor: activeTheme.primaryAccent,
                          inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
                          thumbColor: Colors.white,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                          overlayColor: activeTheme.primaryAccent.withValues(alpha: 0.2),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                        ),
                        child: Slider(
                          value: eq.isEnabled ? eq.bandGains[index] : 0.0,
                          min: -12.0,
                          max: 12.0,
                          onChanged: eq.isEnabled
                              ? (val) {
                                  HapticFeedback.selectionClick();
                                  notifier.updateBandGain(index, val);
                                }
                              : null,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Frequency Label
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildAcousticEnhancers(
    BuildContext context,
    EqualizerModel eq,
    EqualizerNotifier notifier,
    AppThemeType activeTheme,
  ) {
    return Column(
      children: [
        // Bass Boost
        GlassCard(
          borderRadius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.speaker_group_rounded, color: activeTheme.primaryAccent, size: 20),
                      const SizedBox(width: 8),
                      Text('Dynamic Bass Boost', style: AppTextStyles.cardTitle.copyWith(fontSize: 14)),
                    ],
                  ),
                  Text(
                    '${(eq.bassBoost * 100).toInt()}%',
                    style: TextStyle(
                      color: activeTheme.primaryAccent,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 4,
                  activeTrackColor: activeTheme.primaryAccent,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                  thumbColor: Colors.white,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                ),
                child: Slider(
                  value: eq.isEnabled ? eq.bassBoost : 0.0,
                  min: 0.0,
                  max: 1.0,
                  onChanged: eq.isEnabled
                      ? (v) {
                          HapticFeedback.selectionClick();
                          notifier.updateBassBoost(v);
                        }
                      : null,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 3D Spatial Virtualizer
        GlassCard(
          borderRadius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.surround_sound_rounded, color: activeTheme.secondaryAccent, size: 20),
                      const SizedBox(width: 8),
                      Text('3D Spatial Virtualizer', style: AppTextStyles.cardTitle.copyWith(fontSize: 14)),
                    ],
                  ),
                  Text(
                    '${(eq.virtualizer * 100).toInt()}%',
                    style: TextStyle(
                      color: activeTheme.secondaryAccent,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 4,
                  activeTrackColor: activeTheme.secondaryAccent,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                  thumbColor: Colors.white,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                ),
                child: Slider(
                  value: eq.isEnabled ? eq.virtualizer : 0.0,
                  min: 0.0,
                  max: 1.0,
                  onChanged: eq.isEnabled
                      ? (v) {
                          HapticFeedback.selectionClick();
                          notifier.updateVirtualizer(v);
                        }
                      : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FrequencyCurvePainter extends CustomPainter {
  final List<double> gains;
  final Color primaryColor;
  final Color secondaryColor;

  _FrequencyCurvePainter({
    required this.gains,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final zeroY = h * 0.5;

    // Grid guide lines (+12, 0, -12 dB)
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final zeroLinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawLine(Offset(0, h * 0.1), Offset(w, h * 0.1), gridPaint);
    canvas.drawLine(Offset(0, zeroY), Offset(w, zeroY), zeroLinePaint);
    canvas.drawLine(Offset(0, h * 0.9), Offset(w, h * 0.9), gridPaint);

    if (gains.length != 5) return;

    // Map 5 bands to points along X and Y
    final points = <Offset>[];
    for (int i = 0; i < 5; i++) {
      final x = w * (0.1 + (i * 0.2));
      // Gain is -12 to +12 dB. Map to Y: +12 -> h * 0.1, 0 -> zeroY, -12 -> h * 0.9
      final normalizedGain = gains[i].clamp(-12.0, 12.0) / 12.0; // -1.0 to 1.0
      final y = zeroY - (normalizedGain * (h * 0.4));
      points.add(Offset(x, y));
    }

    // Build smooth cubic bezier path
    final path = Path();
    path.moveTo(0, zeroY + (points[0].dy - zeroY) * 0.7);
    path.cubicTo(
      points[0].dx * 0.5,
      points[0].dy,
      points[0].dx * 0.8,
      points[0].dy,
      points[0].dx,
      points[0].dy,
    );

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final cx = (p0.dx + p1.dx) / 2;
      path.cubicTo(cx, p0.dy, cx, p1.dy, p1.dx, p1.dy);
    }

    final last = points.last;
    path.cubicTo(
      last.dx + (w - last.dx) * 0.5,
      last.dy,
      w * 0.95,
      zeroY + (last.dy - zeroY) * 0.7,
      w,
      zeroY + (last.dy - zeroY) * 0.7,
    );

    // Gradient Fill under Curve
    final fillPath = Path.from(path)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          primaryColor.withValues(alpha: 0.25),
          secondaryColor.withValues(alpha: 0.05),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(fillPath, fillPaint);

    // Glowing Curve Stroke
    final strokePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [primaryColor, secondaryColor],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, strokePaint);

    // Draw point dots
    final dotPaint = Paint()..color = Colors.white;
    final dotGlowPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    for (final p in points) {
      canvas.drawCircle(p, 5, dotGlowPaint);
      canvas.drawCircle(p, 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FrequencyCurvePainter oldDelegate) {
    return oldDelegate.gains != gains ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor;
  }
}
