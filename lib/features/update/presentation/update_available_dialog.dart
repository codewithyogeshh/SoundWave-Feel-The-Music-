import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:soundwave/app/theme/text_styles.dart';
import 'package:soundwave/features/update/services/apk_installer.dart';
import 'package:soundwave/features/update/services/update_service.dart';
import 'package:soundwave/shared/providers/theme_provider.dart';

/// Shown when a newer release than the installed APK exists.
///
/// "Update now" downloads the new APK inside the app and opens the Android
/// installer, which upgrades SoundWave in place — nothing to uninstall.
class UpdateAvailableDialog extends ConsumerStatefulWidget {
  const UpdateAvailableDialog({super.key, required this.info});

  final UpdateInfo info;

  static Future<void> show(BuildContext context, UpdateInfo info) {
    return showDialog<void>(
      context: context,
      builder: (_) => UpdateAvailableDialog(info: info),
    );
  }

  @override
  ConsumerState<UpdateAvailableDialog> createState() =>
      _UpdateAvailableDialogState();
}

class _UpdateAvailableDialogState extends ConsumerState<UpdateAvailableDialog> {
  bool _downloading = false;
  double _progress = 0;
  String? _message;

  Future<void> _startUpdate() async {
    if (_downloading) return;

    setState(() {
      _downloading = true;
      _progress = 0;
      _message = null;
    });

    try {
      final apk = await ApkInstaller.download(
        widget.info.downloadUrl,
        widget.info.version,
        onProgress: (value) {
          if (mounted) setState(() => _progress = value);
        },
      );

      final opened = await ApkInstaller.install(apk);
      if (!mounted) return;

      if (opened) {
        Navigator.pop(context);
        return;
      }

      setState(() {
        _downloading = false;
        _message =
            'Allow "Install unknown apps" for SoundWave, then tap Update now '
            'again.';
      });
    } catch (error) {
      debugPrint('UpdateAvailableDialog: $error');
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _message =
            'Could not download the update. Check your internet connection and '
            'try again.';
      });
    }
  }

  Future<void> _openInBrowser() async {
    try {
      final opened = await launchUrl(
        Uri.parse(widget.info.downloadUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('Could not open the download link.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Could not open the download link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
            'SoundWave v${widget.info.version} is out. You are on '
            'v${widget.info.currentVersion}.',
            style: AppTextStyles.subtitle.copyWith(height: 1.4),
          ),
          const SizedBox(height: 12),
          if (_downloading) ...[
            LinearProgressIndicator(
              value: _progress > 0 ? _progress : null,
              color: activeTheme.primaryAccent,
              backgroundColor: Colors.white24,
            ),
            const SizedBox(height: 10),
            Text(
              'Downloading update… ${(_progress * 100).round()}%',
              style: AppTextStyles.subtitle.copyWith(fontSize: 12),
            ),
          ] else ...[
            Text(
              'Tap Update now and SoundWave installs the new version by itself '
              '— your songs, playlists and settings stay exactly as they are.',
              style: AppTextStyles.subtitle.copyWith(
                fontSize: 12,
                height: 1.45,
              ),
            ),
            if (_message != null) ...[
              const SizedBox(height: 10),
              Text(
                _message!,
                style: AppTextStyles.subtitle.copyWith(
                  fontSize: 12,
                  height: 1.45,
                  color: activeTheme.primaryAccent,
                ),
              ),
            ],
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _downloading ? null : _openInBrowser,
          child: const Text(
            'Open in browser',
            style: TextStyle(color: Colors.white70),
          ),
        ),
        TextButton(
          onPressed: _downloading ? null : () => Navigator.pop(context),
          child: const Text('Later', style: TextStyle(color: Colors.white)),
        ),
        TextButton(
          onPressed: _downloading ? null : _startUpdate,
          child: Text(
            'Update now',
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
