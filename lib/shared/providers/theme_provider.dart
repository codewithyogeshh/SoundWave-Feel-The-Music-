import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundwave/app/theme/theme_model.dart';
import 'package:soundwave/shared/providers/library_provider.dart';

final themeProvider = NotifierProvider<ThemeNotifier, AppThemeType>(ThemeNotifier.new);

class ThemeNotifier extends Notifier<AppThemeType> {
  static const String _themePrefKey = 'soundwave_app_theme';

  @override
  AppThemeType build() {
    final storage = ref.read(storageServiceProvider);
    final saved = storage.prefs.getString(_themePrefKey);
    if (saved != null) {
      try {
        return AppThemeType.values.firstWhere(
          (t) => t.name == saved,
          orElse: () => AppThemeType.cyberNeon,
        );
      } catch (_) {
        return AppThemeType.cyberNeon;
      }
    }
    return AppThemeType.cyberNeon;
  }

  Future<void> setTheme(AppThemeType theme) async {
    state = theme;
    final storage = ref.read(storageServiceProvider);
    await storage.prefs.setString(_themePrefKey, theme.name);
  }
}
