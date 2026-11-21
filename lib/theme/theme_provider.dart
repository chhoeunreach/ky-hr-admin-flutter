import 'package:cnattendance/theme/app_theme_data.dart';
import 'package:cnattendance/theme/app_theme_mode.dart';
import 'package:cnattendance/theme/theme_colors.dart';
import 'package:cnattendance/theme/theme_layout.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String storageKey = 'app_theme_mode';
  static const String _animationKey = 'animation';
  static const Map<String, bool> _effectDefaults = {
    'floating_hearts': true,
    'rose_petals': false,
    'heart_glow': true,
    'sparkle_effects': true,
    'qr_pulse': true,
    'reduce_animations': false,
  };

  AppThemeMode _mode = AppThemeMode.light;
  bool _loaded = false;
  bool _animationsEnabled = true;
  final Map<String, bool> _effects = Map<String, bool>.from(_effectDefaults);
  final Map<AppThemeMode, ThemeLayout> _layouts = {};
  final Map<AppThemeMode, String?> _backgrounds = {};

  AppThemeMode get mode => _mode;
  bool get loaded => _loaded;
  bool get animationsEnabled => _animationsEnabled;
  ThemeLayout get layout => layoutFor(_mode);
  String? backgroundFor(AppThemeMode mode) => _backgrounds[mode];
  ThemeColors get colors => colorsForMode(_mode);
  ThemeData get themeData => AppThemeData.themeData(_mode, overrides: colors);
  ThemeData get lightTheme => AppThemeData.themeData(AppThemeMode.light);
  ThemeData get darkTheme => AppThemeData.themeData(AppThemeMode.dark);
  bool get isDark => colors.isDark;
  bool effectEnabled(String key) => _effects[key] ?? false;

  ThemeLayout layoutFor(AppThemeMode mode) =>
      _layouts[mode] ?? const ThemeLayout.defaults();

  ThemeColors colorsForMode(AppThemeMode mode) =>
      layoutFor(mode).colorsFor(AppThemeData.info(mode).colors);

  Future<void> load() async {
    _animationsEnabled = GetStorage().read(_animationKey) != false;
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString(storageKey);
    if (savedMode == null) {
      final legacyLightMode = GetStorage().read('theme') ?? true;
      _mode = legacyLightMode ? AppThemeMode.light : AppThemeMode.dark;
    } else {
      _mode = AppThemeModeX.fromId(savedMode);
    }
    for (final entry in _effectDefaults.entries) {
      _effects[entry.key] =
          prefs.getBool('rose_effect_${entry.key}') ?? entry.value;
    }
    for (final mode in AppThemeMode.values) {
      final layout = ThemeLayout.decode(prefs.getString(layoutKey(mode)));
      _layouts[mode] = layout;
      _backgrounds[mode] = prefs.getString(backgroundKey(mode));
      _mirrorLayout(mode, layout);
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

  Future<void> setBackground(AppThemeMode mode, String? filePath) async {
    if (_backgrounds[mode] == filePath) return;
    final prefs = await SharedPreferences.getInstance();
    if (filePath == null) {
      await prefs.remove(backgroundKey(mode));
      _backgrounds.remove(mode);
    } else {
      await prefs.setString(backgroundKey(mode), filePath);
      _backgrounds[mode] = filePath;
    }
    notifyListeners();
  }

  Future<void> setEffect(String key, bool enabled) async {
    if (!_effectDefaults.containsKey(key) || _effects[key] == enabled) return;
    _effects[key] = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('rose_effect_$key', enabled);
  }

  Future<void> setAnimationsEnabled(bool enabled) async {
    if (_animationsEnabled == enabled) return;
    _animationsEnabled = enabled;
    notifyListeners();
    try {
      await GetStorage().write(_animationKey, enabled);
    } catch (error) {
      debugPrint('Unable to save animation preference: $error');
    }
  }

  Future<bool> saveLayout(AppThemeMode mode, ThemeLayout layout) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(layoutKey(mode), layout.encode())) return false;
    _layouts[mode] = layout;
    _mirrorLayout(mode, layout);
    notifyListeners();
    return true;
  }

  static void _mirrorLayout(AppThemeMode mode, ThemeLayout layout) {
    GetStorage().write(layoutKey(mode), layout.encode()).catchError((error) {
      debugPrint('Unable to mirror layout storage: $error');
    });
  }

  static String layoutKey(AppThemeMode mode) => 'theme_layout_${mode.id}';

  static String backgroundKey(AppThemeMode mode) =>
      'theme_background_${mode.id}';

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
