import 'package:flutter/services.dart';

/// Bridges the Android home screen widget to the Flutter player.
///
/// The widget itself is drawn natively (RemoteViews), so it keeps showing the
/// last song even when the app UI is closed. Dart pushes the current title,
/// artist, cover and playback position down, and receives the taps on its
/// buttons.
class HomeWidgetService {
  HomeWidgetService._();

  static const MethodChannel _channel = MethodChannel('soundwave/widget');
  static bool _listening = false;

  /// Handles taps on the widget while the app process (and its audio service)
  /// is alive. Actions: `playPause`, `next`, `prev`.
  static void listen(void Function(String action) onAction) {
    if (_listening) return;
    _listening = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'onWidgetAction') return null;
      final action = call.arguments;
      if (action is String && action.isNotEmpty) {
        onAction(action);
      }
      return null;
    });
  }

  /// A button pressed while the app was closed is stored natively; this hands
  /// it over once (and clears it) so the tap is not lost.
  static Future<String?> consumePendingAction() async {
    try {
      return await _channel.invokeMethod<String>('consumePendingAction');
    } catch (_) {
      return null;
    }
  }

  static Future<void> update({
    required String title,
    required String artist,
    required bool isPlaying,
    String? artwork,
    String? nextTitle,
    required Duration position,
    required Duration duration,
  }) async {
    try {
      await _channel.invokeMethod<void>('updateWidget', {
        'title': title,
        'artist': artist,
        'isPlaying': isPlaying,
        'artwork': artwork,
        'nextTitle': nextTitle,
        'positionMs': position.inMilliseconds,
        'durationMs': duration.inMilliseconds,
      });
    } catch (_) {
      // Widget not available (tests, web, unsupported launchers).
    }
  }

  /// A tap on the widget asks for a specific screen (`/now-playing`). It is
  /// handed over once so a cold start can open that screen directly.
  static Future<String?> consumePendingRoute() async {
    try {
      return await _channel.invokeMethod<String>('consumePendingRoute');
    } catch (_) {
      return null;
    }
  }
}
