import 'package:flutter/services.dart';

/// Shares the running SoundWave build through the Android share sheet.
///
/// Android keeps the installed package as `base.apk`, so sharing the app from
/// the launcher or Settings always arrives as `base.apk`. This copies the APK
/// into the app cache first, named after the app and its version, and shares
/// that copy instead.
class AppShareService {
  AppShareService._();

  static const MethodChannel _channel = MethodChannel('soundwave/installer');

  /// Opens the share sheet with the APK. Returns `true` when the file was
  /// prepared and the chooser opened.
  static Future<bool> share() async {
    final path = await _channel.invokeMethod<String>('shareApk');
    return path != null && path.isNotEmpty;
  }
}
