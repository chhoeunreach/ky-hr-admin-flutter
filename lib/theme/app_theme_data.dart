import 'package:cnattendance/theme/app_theme_mode.dart';
import 'package:cnattendance/theme/theme_colors.dart';
import 'package:flutter/material.dart';

class AppThemeData {
  static const Duration animationDuration = Duration(milliseconds: 300);

  static final Map<AppThemeMode, AppThemeInfo> themes = {
    AppThemeMode.light: AppThemeInfo(
      id: AppThemeMode.light.id,
      name: 'Original Mode',
      icon: Icons.light_mode,
      description: 'Original clean Digital HRS experience',
      colors: const ThemeColors(
        primaryColor: Color(0xff2563eb),
        secondaryColor: Color(0xff1d4ed8),
        accentColor: Color(0xff60a5fa),
        backgroundColor: Color(0xfff8fafc),
        cardColor: Color(0xffffffff),
        textColor: Color(0xff0f172a),
        isDark: false,
        gradientColors: [
          Color(0xfff8fafc),
          Color(0xffdbeafe),
          Color(0xff60a5fa),
        ],
      ),
    ),
    AppThemeMode.dark: AppThemeInfo(
      id: AppThemeMode.dark.id,
      name: 'Dark Mode',
      icon: Icons.dark_mode,
      description: 'Original dark mode',
      colors: const ThemeColors(
        primaryColor: Color(0xff3b82f6),
        secondaryColor: Color(0xff1e3a8a),
        accentColor: Color(0xff60a5fa),
        backgroundColor: Color(0xff020617),
        cardColor: Color(0xff0f172a),
        textColor: Color(0xffffffff),
        isDark: true,
        gradientColors: [
          Color(0xff020617),
          Color(0xff0f172a),
          Color(0xff1e3a8a),
        ],
      ),
    ),
    AppThemeMode.kyEnterprise: _theme(
      AppThemeMode.kyEnterprise,
      'KY Enterprise',
      Icons.business_center,
      'Corporate navy with gold accents',
      const Color(0xff0047ab),
      const Color(0xff0a254f),
      const Color(0xfffbbf24),
      const Color(0xff041c3c),
      const Color(0xff0a254f),
      const Color(0xffffffff),
      true,
      const [Color(0xff041c3c), Color(0xff0047ab), Color(0xff0a254f)],
    ),
    AppThemeMode.neoGlass: _theme(
      AppThemeMode.neoGlass,
      'Neo Glass',
      Icons.blur_on,
      'Glass-like violet and blue finish',
      const Color(0xff7c3aed),
      const Color(0xff2563eb),
      const Color(0xff38bdf8),
      const Color(0xff120b35),
      const Color(0x1fffffff),
      const Color(0xffffffff),
      true,
      const [Color(0xff120b35), Color(0xff312e81), Color(0xff7c3aed)],
    ),
    AppThemeMode.premiumGradient: _theme(
      AppThemeMode.premiumGradient,
      'Premium Gradient',
      Icons.gradient,
      'Teal and blue premium surface',
      const Color(0xff14b8a6),
      const Color(0xff2563eb),
      const Color(0xff22d3ee),
      const Color(0xff082f49),
      const Color(0xff0f3a5c),
      const Color(0xffffffff),
      true,
      const [Color(0xff0f766e), Color(0xff2563eb), Color(0xff0891b2)],
    ),
    AppThemeMode.amoled: _theme(
      AppThemeMode.amoled,
      'AMOLED Mode',
      Icons.contrast,
      'Pure black with green highlights',
      const Color(0xff22c55e),
      const Color(0xff064e3b),
      const Color(0xff4ade80),
      const Color(0xff000000),
      const Color(0xff101010),
      const Color(0xffffffff),
      true,
      const [Color(0xff000000), Color(0xff052e16), Color(0xff000000)],
    ),
    AppThemeMode.sunset: _theme(
      AppThemeMode.sunset,
      'Sunset Mode',
      Icons.wb_twilight,
      'Warm orange daylight palette',
      const Color(0xfffb923c),
      const Color(0xfffdba74),
      const Color(0xfff97316),
      const Color(0xfffff7ed),
      const Color(0xffffedd5),
      const Color(0xff431407),
      false,
      const [Color(0xfffff7ed), Color(0xfffed7aa), Color(0xfffb923c)],
    ),
    AppThemeMode.oceanBlue: _theme(
      AppThemeMode.oceanBlue,
      'Ocean Blue',
      Icons.water,
      'Deep blue operational theme',
      const Color(0xff0284c7),
      const Color(0xff075985),
      const Color(0xff38bdf8),
      const Color(0xff082f49),
      const Color(0xff0c4a6e),
      const Color(0xffffffff),
      true,
      const [Color(0xff082f49), Color(0xff075985), Color(0xff0284c7)],
    ),
    AppThemeMode.forestGreen: _theme(
      AppThemeMode.forestGreen,
      'Forest Green',
      Icons.forest,
      'Dark green with fresh accents',
      const Color(0xff16a34a),
      const Color(0xff14532d),
      const Color(0xff4ade80),
      const Color(0xff052e16),
      const Color(0xff064e3b),
      const Color(0xffffffff),
      true,
      const [Color(0xff052e16), Color(0xff14532d), Color(0xff16a34a)],
    ),
    AppThemeMode.royalPurple: _theme(
      AppThemeMode.royalPurple,
      'Royal Purple',
      Icons.diamond,
      'Rich violet dashboard feel',
      const Color(0xff9333ea),
      const Color(0xff581c87),
      const Color(0xffc084fc),
      const Color(0xff2e1065),
      const Color(0xff4c1d95),
      const Color(0xffffffff),
      true,
      const [Color(0xff2e1065), Color(0xff581c87), Color(0xff9333ea)],
    ),
    AppThemeMode.copperBrown: _theme(
      AppThemeMode.copperBrown,
      'Copper Brown',
      Icons.local_fire_department,
      'Grounded copper and espresso tones',
      const Color(0xffc2410c),
      const Color(0xff7c2d12),
      const Color(0xfffdba74),
      const Color(0xff431407),
      const Color(0xff7c2d12),
      const Color(0xffffffff),
      true,
      const [Color(0xff431407), Color(0xff7c2d12), Color(0xffc2410c)],
    ),
    AppThemeMode.rosePink: _theme(
      AppThemeMode.rosePink,
      'Rose Pink',
      Icons.favorite,
      'Confident rose and ruby palette',
      const Color(0xffe11d48),
      const Color(0xff9f1239),
      const Color(0xfffda4af),
      const Color(0xff881337),
      const Color(0xff9f1239),
      const Color(0xffffffff),
      true,
      const [Color(0xff881337), Color(0xffbe123c), Color(0xffe11d48)],
    ),
  };

  static AppThemeInfo info(AppThemeMode mode) => themes[mode]!;

  static ThemeData themeData(AppThemeMode mode) {
    final theme = info(mode);
    final colors = theme.colors;
    final scheme = ColorScheme.fromSeed(
      seedColor: colors.primaryColor,
      brightness: colors.isDark ? Brightness.dark : Brightness.light,
      primary: colors.primaryColor,
      secondary: colors.secondaryColor,
      surface: colors.cardColor,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'GoogleSans',
      brightness: colors.isDark ? Brightness.dark : Brightness.light,
      colorScheme: scheme.copyWith(
        primary: colors.primaryColor,
        secondary: colors.secondaryColor,
        tertiary: colors.accentColor,
        surface: colors.cardColor,
        onSurface: colors.textColor,
      ),
      scaffoldBackgroundColor: colors.backgroundColor,
      canvasColor: colors.backgroundColor,
      cardColor: colors.cardColor,
      dividerColor: colors.textColor.withValues(alpha: 0.14),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontFamily: 'GoogleSans',
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: colors.cardColor,
        surfaceTintColor: Colors.transparent,
        elevation: mode == AppThemeMode.neoGlass ? 0 : 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        shadowColor:
            Colors.black.withValues(alpha: colors.isDark ? 0.36 : 0.12),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colors.cardColor,
        selectedItemColor: colors.accentColor,
        unselectedItemColor: colors.textColor.withValues(alpha: 0.62),
        type: BottomNavigationBarType.fixed,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.cardColor,
        indicatorColor: colors.primaryColor.withValues(alpha: 0.22),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(color: colors.textColor, fontFamily: 'GoogleSans'),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        titleTextStyle: TextStyle(
          color: colors.textColor,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          fontFamily: 'GoogleSans',
        ),
        contentTextStyle: TextStyle(
          color: colors.textColor.withValues(alpha: 0.78),
          fontSize: 14,
          fontFamily: 'GoogleSans',
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: const TextStyle(
            fontFamily: 'GoogleSans',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.primaryColor,
          side: BorderSide(color: colors.primaryColor.withValues(alpha: 0.55)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? colors.accentColor
              : colors.textColor.withValues(alpha: 0.5);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? colors.primaryColor.withValues(alpha: 0.45)
              : colors.textColor.withValues(alpha: 0.18);
        }),
      ),
      textTheme: ThemeData(
        brightness: colors.isDark ? Brightness.dark : Brightness.light,
        fontFamily: 'GoogleSans',
      ).textTheme.apply(
            bodyColor: colors.textColor,
            displayColor: colors.textColor,
            fontFamily: 'GoogleSans',
          ),
    );
  }

  static AppThemeInfo _theme(
    AppThemeMode mode,
    String name,
    IconData icon,
    String description,
    Color primary,
    Color secondary,
    Color accent,
    Color background,
    Color card,
    Color text,
    bool isDark,
    List<Color> gradient,
  ) {
    return AppThemeInfo(
      id: mode.id,
      name: name,
      icon: icon,
      description: description,
      colors: ThemeColors(
        primaryColor: primary,
        secondaryColor: secondary,
        accentColor: accent,
        backgroundColor: background,
        cardColor: card,
        textColor: text,
        isDark: isDark,
        gradientColors: gradient,
      ),
    );
  }
}
