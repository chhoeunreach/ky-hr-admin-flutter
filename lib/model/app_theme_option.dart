import 'package:cnattendance/model/remote_theme_mode.dart';
import 'package:cnattendance/theme/app_theme_data.dart';
import 'package:cnattendance/theme/app_theme_mode.dart';
import 'package:cnattendance/theme/theme_colors.dart';
import 'package:flutter/material.dart';

/// Represents an available theme choice for the mobile user, uniting both
/// immutable Core System themes and dynamic Admin-added Custom themes.
class AppThemeOption {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final ThemeColors colors;
  final bool isDark;
  final bool isSystem;
  final AppThemeMode? coreMode;

  const AppThemeOption({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.colors,
    required this.isDark,
    required this.isSystem,
    this.coreMode,
  });

  bool get isCoreSystem => isSystem && coreMode != null;

  factory AppThemeOption.fromCoreMode(AppThemeMode mode, {ThemeColors? customColors}) {
    final info = AppThemeData.info(mode);
    final themeColors = customColors ?? info.colors;
    return AppThemeOption(
      id: mode.id,
      name: info.name,
      description: info.description,
      icon: info.icon,
      colors: themeColors,
      isDark: themeColors.isDark,
      isSystem: true,
      coreMode: mode,
    );
  }

  factory AppThemeOption.fromRemote(RemoteThemeMode remote) {
    final core = AppThemeModeX.tryFromId(remote.key);
    final IconData iconData = core != null
        ? AppThemeData.info(core).icon
        : iconFromString(remote.icon);
    return AppThemeOption(
      id: remote.key,
      name: remote.name,
      description: remote.description,
      icon: iconData,
      colors: remote.toThemeColors(),
      isDark: remote.isDark,
      isSystem: remote.isSystem || core != null,
      coreMode: core,
    );
  }

  static IconData iconFromString(String iconName) {
    switch (iconName.toLowerCase().replaceAll('-', '_')) {
      case 'account_balance':
      case 'account_balance_rounded':
      case 'account_balance_outlined':
      case 'crown':
        return Icons.account_balance_rounded;
      case 'wb_sunny':
      case 'wb_sunny_outlined':
      case 'light_mode':
        return Icons.wb_sunny_outlined;
      case 'nightlight':
      case 'dark_mode':
        return Icons.dark_mode;
      case 'business_center':
        return Icons.business_center;
      case 'blur_on':
        return Icons.blur_on;
      case 'gradient':
        return Icons.gradient;
      case 'contrast':
        return Icons.contrast;
      case 'water_drop':
      case 'waves':
        return Icons.water_drop;
      case 'park':
      case 'forest':
        return Icons.park;
      case 'diamond':
        return Icons.diamond;
      case 'coffee':
        return Icons.coffee;
      case 'favorite':
      case 'favorite_border':
        return Icons.favorite;
      case 'shield':
        return Icons.shield;
      case 'palette':
      default:
        return Icons.palette;
    }
  }
}
