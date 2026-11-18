import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<bool> requestAudioPermission() async {
    if (kIsWeb) return true;

    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        // Request audio permission (Android 13+ SDK 33+)
        var status = await Permission.audio.status;
        if (!status.isGranted) {
          status = await Permission.audio.request();
        }
        if (status.isGranted) return true;

        // Also check/request storage permission for Android <= 12
        var storageStatus = await Permission.storage.status;
        if (!storageStatus.isGranted) {
          storageStatus = await Permission.storage.request();
        }
        if (storageStatus.isGranted) return true;

        // If both failed, check if audio is granted regardless
        return await isAudioPermissionGranted();
      } catch (e) {
        debugPrint('Error requesting audio permissions: $e');
        return false;
      }
    }

    return true;
  }

  static Future<bool> isAudioPermissionGranted() async {
    if (kIsWeb) return true;

    if (defaultTargetPlatform == TargetPlatform.android) {
      final audioGranted = await Permission.audio.isGranted;
      if (audioGranted) return true;
      return await Permission.storage.isGranted;
    }

    return true;
  }

  static Future<bool> openSettings() async {
    return await openAppSettings();
  }
}

