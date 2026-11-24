import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:soundwave/app/theme/text_styles.dart';
import 'package:soundwave/features/update/services/update_service.dart';
import 'package:soundwave/shared/providers/theme_provider.dart';

/// Shown when a newer release than the installed APK exists.
class UpdateAvailableDialog extends ConsumerWidget {
  const UpdateAvailableDialog({super.key, required this.info});

  final UpdateInfo info;

  static Future<void> show(BuildContext context, UpdateInfo info) {
    return showDialog<void>(
      context: context,
      builder: (_) => UpdateAvailableDialog(info: info),
    );
  }

  Future<void> _openDownload(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    var opened = false;

    for (final url in [info.downloadUrl, info.releaseUrl]) {
      if (opened) break;
      try {
        opened = await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        opened = false;
      }
    }

    if (!opened) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Could not open the download link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTheme = ref.watch(themeProvider);

    return AlertDialog(
      backgroundColor: activeTheme.secondaryBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Row(
        children: [
          Icon(Icons.system_update_rounded, color: activeTheme.primaryAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Update available',
              style: AppTextStyles.cardTitle.copyWith(fontSize: 18),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SoundWave v${info.version} is out. You are on v${info.currentVersion}.',
            style: AppTextStyles.subtitle.copyWith(height: 1.4),
          ),
          const SizedBox(height: 12),
          Text(
            'Download the new APK and open it to install. If Android says '
            '"App not installed", uninstall the current version first, then '
            'install the new one.',
            style: AppTextStyles.subtitle.copyWith(fontSize: 12, height: 1.45),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Later', style: TextStyle(color: Colors.white)),
        ),
        TextButton(
          onPressed: () => _openDownload(context),
          child: Text(
            'Download APK',
            style: TextStyle(
              color: activeTheme.primaryAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
