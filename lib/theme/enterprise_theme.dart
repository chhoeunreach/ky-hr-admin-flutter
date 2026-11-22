import 'dart:ui';

import 'package:cnattendance/theme/app_theme_data.dart';
import 'package:cnattendance/theme/app_theme_mode.dart';
import 'package:cnattendance/theme/theme_colors.dart';
import 'package:cnattendance/theme/theme_provider.dart';
import 'package:cnattendance/theme/theme_layout.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

class EnterpriseTheme {
  final AppThemeMode mode;
  final ThemeColors colors;

  EnterpriseTheme._(this.mode, this.colors,
      [this.layout = const ThemeLayout.defaults()]);

  final ThemeLayout layout;

  factory EnterpriseTheme.of(BuildContext context) {
    try {
      final provider = Provider.of<ThemeProvider>(context);
      return EnterpriseTheme._(
        provider.mode,
        provider.colors,
        provider.layout,
      );
    } catch (_) {}

    final theme = Theme.of(context);
    final match = AppThemeData.themes.entries.where((entry) {
      final info = entry.value;
      return info.colors.primaryColor == theme.colorScheme.primary &&
          info.colors.secondaryColor == theme.colorScheme.secondary;
    });
    if (match.isEmpty) {
      final isDark = theme.brightness == Brightness.dark;
      final fallbackMode = isDark ? AppThemeMode.dark : AppThemeMode.light;
      return EnterpriseTheme._(
        fallbackMode,
        AppThemeData.info(fallbackMode).colors,
      );
    }
    return EnterpriseTheme._(match.first.key, match.first.value.colors);
  }

  bool get isDark => colors.isDark;
  bool get isRoyalDay => mode == AppThemeMode.royalBlueDay || isRoyalLuxuryDay;
  bool get isRoyalLuxuryDay => mode == AppThemeMode.royalBlueGoldKhmerDay;
  bool get isRoyalBlueGold => mode == AppThemeMode.royalBlueGold || isRoyalDay;
  bool get isKhmerHeritage => mode == AppThemeMode.khmerHeritage;
  Color get primary => colors.primaryColor;
  Color get secondary => colors.secondaryColor;
  Color get accent => colors.accentColor;
  Color get text => colors.textColor;
  Color get surface => colors.cardColor;

  Color get contentSurface =>
      mode == AppThemeMode.light && layout.background == null
          ? AppColors.white
          : Color.alphaBlend(surface, colors.backgroundColor);

  Color get cardBackground => isKhmerHeritage || layout.background != null
      ? surface
      : mode == AppThemeMode.rosePink
          ? AppColors.customFF9D124D.withValues(alpha: 0.96)
          : isDark
              ? AppColors.customFF1E293B.withValues(alpha: 0.90)
              : AppColors.white;
  Color get cardBorder => isKhmerHeritage || layout.background != null
      ? accent.withValues(alpha: .5)
      : mode == AppThemeMode.rosePink
          ? AppColors.customFFFF80AB.withValues(alpha: 0.52)
          : isDark
              ? AppColors.customFF334155
              : AppColors.customFFE2E8F0;

  Color get mutedText => text.withValues(alpha: isDark ? 0.74 : 0.68);
  Color get glassFill => AppColors.white.withValues(
        alpha: mode == AppThemeMode.rosePink ? 0.14 : (isDark ? 0.12 : 0.58),
      );
  Color get glassStroke => isKhmerHeritage
      ? cardBorder
      : AppColors.white.withValues(
          alpha: mode == AppThemeMode.rosePink ? 0.34 : (isDark ? 0.18 : 0.74),
        );
  Color get glow => accent.withValues(alpha: isDark ? 0.34 : 0.28);

  /// Electric-blue edge used for glowing card borders.
  Color get glowEdge => accent.withValues(alpha: isDark ? 0.55 : 0.45);

  LinearGradient get pageGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors.gradientColors,
      );

  LinearGradient get cardGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isKhmerHeritage
            ? [surface, secondary]
            : [
                AppColors.white.withValues(alpha: isDark ? 0.17 : 0.76),
                primary.withValues(alpha: isDark ? 0.14 : 0.10),
                secondary.withValues(alpha: isDark ? 0.16 : 0.08),
              ],
      );

  BoxDecoration glassDecoration({
    double radius = 24,
    Color? glowColor,
    double glowOpacity = 0.16,
    bool glowingBorder = false,
  }) {
    return BoxDecoration(
      gradient: cardGradient,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: glowingBorder ? glowEdge : glassStroke,
        width: glowingBorder ? 1.2 : 1,
      ),
      boxShadow: [
        if (glowingBorder)
          BoxShadow(
            color: (glowColor ?? primary).withValues(alpha: 0.30),
            blurRadius: 16,
            spreadRadius: 0.5,
            offset: const Offset(0, 0),
          ),
        BoxShadow(
          color: (glowColor ?? accent).withValues(alpha: glowOpacity),
          blurRadius: 28,
          spreadRadius: 1,
          offset: const Offset(0, 14),
        ),
        BoxShadow(
          color: AppColors.black.withValues(alpha: isDark ? 0.24 : 0.10),
          blurRadius: 22,
          offset: const Offset(0, 12),
        ),
      ],
    );
  }
}

class EnterpriseGlass extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? glowColor;
  final double glowOpacity;
  final bool glowingBorder;

  const EnterpriseGlass({
    Key? key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 24,
    this.glowColor,
    this.glowOpacity = 0.14,
    this.glowingBorder = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final enterprise = EnterpriseTheme.of(context);
    if (HomeSurfaceStyle.isClean(context)) {
      final card = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: AppColors.customFFB8DEFF),
            boxShadow: const [
              BoxShadow(
                color: AppColors.custom1A1683E6,
                blurRadius: 18,
                offset: Offset(0, 7),
              ),
              BoxShadow(
                color: AppColors.custom55FFFFFF,
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: child,
        ),
      );
      if (MediaQuery.disableAnimationsOf(context)) return card;

      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 340),
        curve: Curves.easeOutCubic,
        child: card,
        builder: (context, progress, child) => Transform.translate(
          offset: Offset(0, 10 * (1 - progress)),
          child: child,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: enterprise.glassDecoration(
            radius: radius,
            glowColor: glowColor,
            glowOpacity: glowOpacity,
            glowingBorder: glowingBorder,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Limits the simplified surface treatment to the Original Mode home screen.
class HomeSurfaceStyle extends InheritedWidget {
  final bool clean;

  const HomeSurfaceStyle({
    Key? key,
    required this.clean,
    required Widget child,
  }) : super(key: key, child: child);

  static bool isClean(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HomeSurfaceStyle>()?.clean ??
      false;

  @override
  bool updateShouldNotify(HomeSurfaceStyle oldWidget) =>
      clean != oldWidget.clean;
}
