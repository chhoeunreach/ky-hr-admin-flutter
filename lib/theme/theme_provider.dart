import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/model/app_appearance_config.dart';
import 'package:cnattendance/model/app_theme_option.dart';
import 'package:cnattendance/model/remote_theme_mode.dart';
import 'package:cnattendance/theme/app_theme_data.dart';
import 'package:cnattendance/theme/app_theme_mode.dart';
import 'package:cnattendance/theme/theme_colors.dart';
import 'package:cnattendance/theme/theme_layout.dart';
import 'package:cnattendance/utils/chat_unread_store.dart';
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
    'heat': false,
    'snow': false,
    'emoji_effect': false,
  };

  static const String _dayModeCleanKey = 'day_mode_clean_background';

  AppThemeMode _mode = AppThemeMode.light;
  String _currentThemeId = AppThemeMode.light.id;
  bool _loaded = false;
  bool _animationsEnabled = true;
  bool _dayModeClean = true;
  final Map<String, bool> _effects = Map<String, bool>.from(_effectDefaults);
  final Map<String, ThemeLayout> _layouts = {};
  final Map<String, String?> _backgrounds = {};
  AppAppearanceConfig? _serverAppearance;
  List<RemoteThemeMode> _remoteThemeModes = [];

  AppThemeMode get mode => _mode;
  String get currentThemeId => _currentThemeId;
  bool get loaded => _loaded;
  bool get animationsEnabled => _animationsEnabled;
  bool get dayModeClean => _dayModeClean;
  ThemeLayout get layout => layoutForId(_currentThemeId);
  String? backgroundFor(AppThemeMode mode) => _backgrounds[mode.id];
  String? backgroundForId(String id) => _backgrounds[id];
  ThemeColors get colors => colorsForId(_currentThemeId);
  ThemeData get themeData {
    final core = AppThemeModeX.tryFromId(_currentThemeId);
    if (core != null) {
      return AppThemeData.themeData(core, overrides: colors);
    }
    final baseMode = colors.isDark ? AppThemeMode.dark : AppThemeMode.light;
    return AppThemeData.themeData(baseMode, overrides: colors);
  }
  ThemeData get lightTheme => AppThemeData.themeData(AppThemeMode.light);
  ThemeData get darkTheme => AppThemeData.themeData(AppThemeMode.dark);
  bool get isDark => colors.isDark;

  List<RemoteThemeMode> get remoteThemeModes => _remoteThemeModes;

  AppThemeOption get currentThemeOption {
    for (final opt in availableThemeOptions) {
      if (opt.id == _currentThemeId) return opt;
    }
    final core = AppThemeModeX.tryFromId(_currentThemeId) ?? _mode;
    return AppThemeOption.fromCoreMode(core, customColors: colors);
  }

  bool isSelected(AppThemeOption option) => option.id == _currentThemeId;

  /// Returns active theme options uniting both Core System themes and Custom Added themes.
  List<AppThemeOption> get availableThemeOptions {
    if (_remoteThemeModes.isEmpty) {
      return AppThemeMode.values
          .map((mode) => AppThemeOption.fromCoreMode(mode))
          .toList();
    }
    final List<AppThemeOption> options = [];
    for (final remote in _remoteThemeModes) {
      if (!remote.isActive) continue;
      options.add(AppThemeOption.fromRemote(remote));
    }
    if (options.isNotEmpty) {
      return options;
    }
    return [
      AppThemeOption.fromCoreMode(AppThemeMode.light),
      AppThemeOption.fromCoreMode(AppThemeMode.royalBlueGold),
    ];
  }

  /// Returns only active core theme modes permitted for the user's role.
  List<AppThemeMode> get availableModes {
    final modes = availableThemeOptions
        .map((opt) => opt.coreMode)
        .whereType<AppThemeMode>()
        .toList();
    return modes.isNotEmpty
        ? modes
        : [AppThemeMode.light, AppThemeMode.royalBlueGold];
  }

  /// Global admin-managed appearance (background + floating effects).
  AppAppearanceConfig? get serverAppearance => _serverAppearance;

  /// True when an admin-configured background should replace every other
  /// background layer.
  bool get hasServerBackground => _serverAppearance?.hasCustomBackground ?? false;

  /// Admin-controlled effect value; falls back to the local preference when
  /// no server config has been received yet (offline / first launch).
  bool effectEnabled(String key) {
    final server = _serverAppearance;
    if (server != null && AppAppearanceConfig.effectKeys.contains(key)) {
      return server.effectEnabled(key);
    }
    return _effects[key] ?? false;
  }

  ThemeLayout layoutFor(AppThemeMode mode) => layoutForId(mode.id);

  ThemeLayout layoutForId(String id) =>
      _layouts[id] ?? const ThemeLayout.defaults();

  ThemeColors colorsForMode(AppThemeMode mode) => colorsForId(mode.id);

  ThemeColors colorsForId(String id) {
    final remote = _remoteThemeModes.cast<RemoteThemeMode?>().firstWhere(
          (m) => m?.key == id,
          orElse: () => null,
        );
    final core = AppThemeModeX.tryFromId(id);
    final ThemeColors baseColors;
    if (remote != null) {
      baseColors = remote.toThemeColors();
    } else if (core != null) {
      baseColors = AppThemeData.info(core).colors;
    } else {
      baseColors = AppThemeData.info(AppThemeMode.light).colors;
    }
    return layoutForId(id).colorsFor(baseColors);
  }

  Future<void> load() async {
    if (ChatUnreadStore.isStorageReady) {
      try {
        _animationsEnabled = GetStorage().read(_animationKey) != false;
      } catch (_) {
        _animationsEnabled = true;
      }
    } else {
      _animationsEnabled = true;
    }
    final prefs = await SharedPreferences.getInstance();
    _dayModeClean = prefs.getBool(_dayModeCleanKey) ?? true;
    final savedMode = prefs.getString(storageKey);
    if (savedMode == null) {
      dynamic legacyLightMode;
      if (ChatUnreadStore.isStorageReady) {
        try {
          legacyLightMode = GetStorage().read('theme');
        } catch (_) {}
      }
      final isLight = legacyLightMode ?? true;
      _mode = isLight ? AppThemeMode.light : AppThemeMode.dark;
      _currentThemeId = _mode.id;
    } else {
      _currentThemeId = savedMode;
      _mode = AppThemeModeX.tryFromId(savedMode) ?? AppThemeMode.light;
    }
    for (final entry in _effectDefaults.entries) {
      _effects[entry.key] =
          prefs.getBool('rose_effect_${entry.key}') ?? entry.value;
    }
    for (final mode in AppThemeMode.values) {
      final layout = ThemeLayout.decode(prefs.getString(layoutKeyForId(mode.id)));
      _layouts[mode.id] = layout;
      _backgrounds[mode.id] = prefs.getString(backgroundKeyForId(mode.id));
      _mirrorLayout(mode.id, layout);
    }
    _serverAppearance = await Preferences().getAppAppearance();
    _remoteThemeModes = await Preferences().getThemeModes();

    for (final remote in _remoteThemeModes) {
      if (!_layouts.containsKey(remote.key)) {
        final layout = ThemeLayout.decode(prefs.getString(layoutKeyForId(remote.key)));
        _layouts[remote.key] = layout;
        _backgrounds[remote.key] = prefs.getString(backgroundKeyForId(remote.key));
      }
    }

    final validIds = availableThemeOptions.map((o) => o.id).toSet();
    if (!validIds.contains(_currentThemeId)) {
      _currentThemeId = validIds.contains(AppThemeMode.light.id)
          ? AppThemeMode.light.id
          : (validIds.contains(AppThemeMode.royalBlueGold.id)
              ? AppThemeMode.royalBlueGold.id
              : (validIds.isNotEmpty ? validIds.first : AppThemeMode.light.id));
      _mode = AppThemeModeX.tryFromId(_currentThemeId) ?? AppThemeMode.light;
    }
    _syncLegacyStorage(_mode);
    _loaded = true;
    notifyListeners();
  }

  /// Applies the admin-managed theme modes and colors, filtering visible themes
  /// by is_active and user role.
  Future<void> applyRemoteThemeModes(List<RemoteThemeMode> modes) async {
    _remoteThemeModes = modes.map((m) {
      if (m.key == 'light' || m.name.toLowerCase().contains('original')) {
        return m.copyWith(
          name: 'Day Mode',
          description: 'Crisp light with royal blue',
        );
      } else if (m.key == 'dark' || m.name.toLowerCase() == 'dark mode') {
        return m.copyWith(
          name: 'Night Mode',
          description: 'Sleek night mode',
        );
      }
      return m;
    }).toList();
    final prefs = await SharedPreferences.getInstance();
    for (final remote in modes) {
      if (!_layouts.containsKey(remote.key)) {
        _layouts[remote.key] =
            ThemeLayout.decode(prefs.getString(layoutKeyForId(remote.key)));
        _backgrounds[remote.key] =
            prefs.getString(backgroundKeyForId(remote.key));
      }
    }

    final validIds = availableThemeOptions.map((o) => o.id).toSet();
    if (!validIds.contains(_currentThemeId)) {
      final fallbackId = validIds.contains(AppThemeMode.light.id)
          ? AppThemeMode.light.id
          : (validIds.contains(AppThemeMode.royalBlueGold.id)
              ? AppThemeMode.royalBlueGold.id
              : (validIds.isNotEmpty ? validIds.first : AppThemeMode.light.id));
      await setThemeById(fallbackId);
    } else {
      notifyListeners();
    }
    try {
      await Preferences().cacheThemeModes(modes);
    } catch (error) {
      debugPrint('Unable to cache remote theme modes: $error');
    }
  }

  /// Applies the admin-managed appearance config and caches it for the next
  /// cold start so the app renders the latest known state offline.
  Future<void> applyServerAppearance(AppAppearanceConfig config) async {
    final previous = _serverAppearance;
    if (previous != null &&
        previous.backgroundType == config.backgroundType &&
        previous.backgroundUrl == config.backgroundUrl &&
        previous.heat == config.heat &&
        previous.snow == config.snow &&
        previous.floatingHearts == config.floatingHearts &&
        previous.rosePetals == config.rosePetals &&
        previous.heartGlow == config.heartGlow &&
        previous.sparkleEffects == config.sparkleEffects &&
        previous.emojiEffect == config.emojiEffect &&
        previous.emojiChar == config.emojiChar &&
        _sameCustomEffects(previous.customEffects, config.customEffects)) {
      return;
    }
    _serverAppearance = config;
    notifyListeners();
    try {
      await Preferences().cacheAppAppearance(config);
    } catch (error) {
      debugPrint('Unable to cache app appearance: $error');
    }
  }

  bool _sameCustomEffects(
    List<Map<String, dynamic>> previous,
    List<Map<String, dynamic>> next,
  ) {
    if (previous.length != next.length) return false;
    for (var index = 0; index < previous.length; index++) {
      for (final key in const ['id', 'name', 'emoji', 'enabled']) {
        if (previous[index][key] != next[index][key]) return false;
      }
    }
    return true;
  }

  Future<void> setMode(AppThemeMode mode) async {
    await setThemeById(mode.id);
  }

  Future<void> setThemeById(String id) async {
    _currentThemeId = id;
    final core = AppThemeModeX.tryFromId(id);
    if (core != null) {
      _mode = core;
    } else {
      final remote = _remoteThemeModes.cast<RemoteThemeMode?>().firstWhere(
            (m) => m?.key == id,
            orElse: () => null,
          );
      _mode = (remote?.isDark ?? true) ? AppThemeMode.dark : AppThemeMode.light;
    }
    _syncLegacyStorage(_mode);
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, id);
  }

  Future<void> setBackground(AppThemeMode mode, String? filePath) async {
    await setBackgroundForId(mode.id, filePath);
  }

  Future<void> setBackgroundForId(String id, String? filePath) async {
    if (_backgrounds[id] == filePath) return;
    final prefs = await SharedPreferences.getInstance();
    if (filePath == null) {
      await prefs.remove(backgroundKeyForId(id));
      _backgrounds.remove(id);
    } else {
      await prefs.setString(backgroundKeyForId(id), filePath);
      _backgrounds[id] = filePath;
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

  Future<void> setDayModeClean(bool clean) async {
    if (_dayModeClean == clean) return;
    _dayModeClean = clean;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dayModeCleanKey, clean);
    if (ChatUnreadStore.isStorageReady) {
      try {
        await GetStorage().write(_dayModeCleanKey, clean);
      } catch (_) {}
    }
  }

  Future<void> setAnimationsEnabled(bool enabled) async {
    if (_animationsEnabled == enabled) return;
    _animationsEnabled = enabled;
    notifyListeners();
    if (ChatUnreadStore.isStorageReady) {
      try {
        await GetStorage().write(_animationKey, enabled);
      } catch (error) {
        debugPrint('Unable to save animation preference: $error');
      }
    }
  }

  Future<bool> saveLayout(AppThemeMode mode, ThemeLayout layout) async {
    return saveLayoutForId(mode.id, layout);
  }

  Future<bool> saveLayoutForId(String id, ThemeLayout layout) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(layoutKeyForId(id), layout.encode())) return false;
    _layouts[id] = layout;
    _mirrorLayout(id, layout);
    notifyListeners();
    return true;
  }

  static void _mirrorLayout(String id, ThemeLayout layout) {
    if (!ChatUnreadStore.isStorageReady) return;
    try {
      GetStorage().write(layoutKeyForId(id), layout.encode()).catchError((error) {
        debugPrint('Unable to mirror layout storage: $error');
      });
    } catch (_) {}
  }

  static String layoutKey(AppThemeMode mode) => layoutKeyForId(mode.id);
  static String layoutKeyForId(String id) => 'theme_layout_$id';

  static String backgroundKey(AppThemeMode mode) => backgroundKeyForId(mode.id);
  static String backgroundKeyForId(String id) => 'theme_background_$id';

  Future<void> resetToSystemMode() async {
    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    await setThemeById(
      brightness == Brightness.dark
          ? AppThemeMode.dark.id
          : AppThemeMode.light.id,
    );
  }

  void _syncLegacyStorage(AppThemeMode mode) {
    if (!ChatUnreadStore.isStorageReady) return;
    try {
      GetStorage().write(storageKey, _currentThemeId);
      if (mode == AppThemeMode.light) {
        GetStorage().write('theme', true);
      } else if (mode == AppThemeMode.dark) {
        GetStorage().write('theme', false);
      }
    } catch (_) {}
  }
}
