import 'package:cnattendance/theme/app_theme_data.dart';
import 'package:cnattendance/theme/app_theme_mode.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String storageKey = 'app_theme_mode';

  AppThemeMode _mode = AppThemeMode.light;
  bool _loaded = false;

  AppThemeMode get mode => _mode;
  bool get loaded => _loaded;
  ThemeData get themeData => AppThemeData.themeData(_mode);
  ThemeData get lightTheme => AppThemeData.themeData(AppThemeMode.light);
  ThemeData get darkTheme => AppThemeData.themeData(AppThemeMode.dark);
  bool get isDark => AppThemeData.info(_mode).colors.isDark;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString(storageKey);
    if (savedMode == null) {
      final legacyLightMode = GetStorage().read('theme') ?? true;
      _mode = legacyLightMode ? AppThemeMode.light : AppThemeMode.dark;
    } else {
      _mode = AppThemeModeX.fromId(savedMode);
    }
    _syncLegacyStorage(_mode);
    _loaded = true;
    notifyListeners();
  }

  Future<void> setMode(AppThemeMode mode) async {
    _mode = mode;
    _syncLegacyStorage(mode);
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, mode.id);
  }

  Future<void> resetToSystemMode() async {
    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    await setMode(
      brightness == Brightness.dark ? AppThemeMode.dark : AppThemeMode.light,
    );
  }

  void _syncLegacyStorage(AppThemeMode mode) {
    GetStorage().write(storageKey, mode.id);
    if (mode == AppThemeMode.light) {
      GetStorage().write('theme', true);
    } else if (mode == AppThemeMode.dark) {
      GetStorage().write('theme', false);
    }
  }
}
