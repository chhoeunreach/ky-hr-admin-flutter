enum AppThemeMode {
  light,
  dark,
  kyEnterprise,
  neoGlass,
  premiumGradient,
  amoled,
  sunset,
  oceanBlue,
  forestGreen,
  royalPurple,
  copperBrown,
  rosePink,
}

extension AppThemeModeX on AppThemeMode {
  String get id {
    switch (this) {
      case AppThemeMode.light:
        return 'light';
      case AppThemeMode.dark:
        return 'dark';
      case AppThemeMode.kyEnterprise:
        return 'ky_enterprise';
      case AppThemeMode.neoGlass:
        return 'neo_glass';
      case AppThemeMode.premiumGradient:
        return 'premium_gradient';
      case AppThemeMode.amoled:
        return 'amoled';
      case AppThemeMode.sunset:
        return 'sunset';
      case AppThemeMode.oceanBlue:
        return 'ocean_blue';
      case AppThemeMode.forestGreen:
        return 'forest_green';
      case AppThemeMode.royalPurple:
        return 'royal_purple';
      case AppThemeMode.copperBrown:
        return 'copper_brown';
      case AppThemeMode.rosePink:
        return 'rose_pink';
    }
  }

  static AppThemeMode fromId(String? id) {
    for (final mode in AppThemeMode.values) {
      if (mode.id == id) return mode;
    }
    return AppThemeMode.light;
  }
}
