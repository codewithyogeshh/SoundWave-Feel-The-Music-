import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// A GitHub release that is newer than the build installed on the phone.
class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.currentVersion,
    required this.downloadUrl,
    required this.releaseUrl,
  });

  /// Latest release version without the leading `v`, e.g. `1.3.2`.
  final String version;

  /// Version of the running build, e.g. `1.3.1`.
  final String currentVersion;

  /// Direct `.apk` asset of the release when available, otherwise its page.
  final String downloadUrl;

  /// Human-facing release page.
  final String releaseUrl;
}

/// Best-effort check of the public GitHub releases feed, so the app can tell
/// the user about a newer APK without anyone hunting for it by hand.
class UpdateService {
  UpdateService._();

  static const String _owner = 'codewithyogeshh';
  static const String _repo = 'SoundWave-Feel-The-Music-';
  static const String _latestReleaseApi =
      'https://api.github.com/repos/$_owner/$_repo/releases/latest';

  /// Version baked in by the build workflow
  /// (`flutter build apk --dart-define=SOUNDWAVE_VERSION=1.3.1`), so the value
  /// always matches `pubspec.yaml` and can never drift.
  static const String _buildVersion = String.fromEnvironment(
    'SOUNDWAVE_VERSION',
  );

  /// The `versionName` of the running build, or `null` for builds that were not
  /// made by the release workflow (dev builds simply skip the check).
  static String? get installedVersion {
    final version = _buildVersion.trim();
    return version.isEmpty ? null : version;
  }

  /// Returns the newer release, or `null` when the app is up to date, offline,
  /// or not running as the Android APK (web builds have nothing to update).
  static Future<UpdateInfo?> check() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;

    final installed = installedVersion;
    if (installed == null) return null;

    try {
      final response = await http
          .get(
            Uri.parse(_latestReleaseApi),
            headers: const {
              'Accept': 'application/vnd.github+json',
              'User-Agent': 'SoundWave-App',
            },
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        debugPrint('UpdateService: GitHub answered ${response.statusCode}');
        return null;
      }

      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) return null;

      final tag = (body['tag_name'] as String?)?.trim() ?? '';
      if (tag.isEmpty) return null;

      final latest = tag.replaceFirst(RegExp(r'^[vV]'), '');
      if (!isNewer(latest, installed)) return null;

      final releaseUrl =
          (body['html_url'] as String?) ??
          'https://github.com/$_owner/$_repo/releases/latest';

      var downloadUrl = releaseUrl;
      final assets = body['assets'];
      if (assets is List) {
        for (final asset in assets) {
          if (asset is Map &&
              asset['name'] is String &&
              asset['browser_download_url'] is String &&
              (asset['name'] as String).toLowerCase().endsWith('.apk')) {
            downloadUrl = asset['browser_download_url'] as String;
            break;
          }
        }
      }

      return UpdateInfo(
        version: latest,
        currentVersion: installed,
        downloadUrl: downloadUrl,
        releaseUrl: releaseUrl,
      );
    } catch (e) {
      // Offline or rate-limited: this check is optional, never block the app.
      debugPrint('UpdateService: update check skipped: $e');
      return null;
    }
  }

  /// True when [candidate] is a higher release than [installed]
  /// (`1.3.2` > `1.3.1`, `1.4` > `1.3.9`).
  @visibleForTesting
  static bool isNewer(String candidate, String installed) {
    final latest = _segments(candidate);
    final current = _segments(installed);
    final length = latest.length > current.length
        ? latest.length
        : current.length;

    for (var i = 0; i < length; i++) {
      final left = i < latest.length ? latest[i] : 0;
      final right = i < current.length ? current[i] : 0;
      if (left != right) return left > right;
    }
    return false;
  }

  static List<int> _segments(String version) {
    final core = version.split('+').first.split('-').first.trim();
    return core
        .split('.')
        .map((part) => int.tryParse(part.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
  }
}
