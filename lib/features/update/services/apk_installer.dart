import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Downloads a release APK and hands it to the Android package installer.
///
/// Because every release is signed with the same key, Android installs the new
/// version on top of the old one — no uninstall, no data loss.
class ApkInstaller {
  ApkInstaller._();

  static const MethodChannel _channel = MethodChannel('soundwave/installer');

  /// Downloads [url] into the app cache and returns the saved file.
  static Future<File> download(
    String url,
    String version, {
    void Function(double progress)? onProgress,
  }) async {
    final cache = await getTemporaryDirectory();
    final dir = Directory('${cache.path}/updates');
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }

    final file = File('${dir.path}/soundwave-$version.apk');
    if (await file.exists()) {
      await file.delete();
    }

    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);
      if (response.statusCode != 200) {
        throw Exception('Download failed (HTTP ${response.statusCode}).');
      }

      final total = response.contentLength ?? 0;
      var received = 0;
      final sink = file.openWrite();
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) {
            onProgress?.call((received / total).clamp(0.0, 1.0));
          }
        }
      } finally {
        await sink.close();
      }
    } finally {
      client.close();
    }

    return file;
  }

  /// Opens the system installer for [apk]. Returns `false` when Android first
  /// needs the user to allow installing from SoundWave (that settings screen is
  /// opened instead), so the caller can ask the user to try again.
  static Future<bool> install(File apk) async {
    final opened = await _channel.invokeMethod<bool>('installApk', {
      'path': apk.path,
    });
    return opened ?? false;
  }
}
