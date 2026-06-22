import 'dart:ui';

import 'package:cnattendance/theme/app_theme_data.dart';
import 'package:cnattendance/theme/app_theme_mode.dart';
import 'package:cnattendance/theme/theme_colors.dart';
import 'package:flutter/material.dart';

class EnterpriseTheme {
  final AppThemeMode mode;
  final ThemeColors colors;

  EnterpriseTheme._(this.mode, this.colors);

  factory EnterpriseTheme.of(BuildContext context) {
    final theme = Theme.of(context);
    final match = AppThemeData.themes.entries.where((entry) {
      final info = entry.value;
      return info.colors.primaryColor == theme.colorScheme.primary &&
          info.colors.secondaryColor == theme.colorScheme.secondary;
    });
    if (match.isEmpty) {
      return EnterpriseTheme._(
        AppThemeMode.light,
        AppThemeData.info(AppThemeMode.light).colors,
      );
    }
    return EnterpriseTheme._(match.first.key, match.first.value.colors);
  }

  bool get isDark => colors.isDark;
  Color get primary => colors.primaryColor;
  Color get secondary => colors.secondaryColor;
  Color get accent => colors.accentColor;
  Color get text => colors.textColor;
  Color get surface => colors.cardColor;

  Color get mutedText => text.withValues(alpha: isDark ? 0.74 : 0.68);
  Color get glassFill => Colors.white.withValues(alpha: isDark ? 0.12 : 0.58);
  Color get glassStroke => Colors.white.withValues(alpha: isDark ? 0.18 : 0.74);
  Color get glow => accent.withValues(alpha: isDark ? 0.34 : 0.28);

  LinearGradient get pageGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors.gradientColors,
      );

  LinearGradient get cardGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: isDark ? 0.17 : 0.76),
          primary.withValues(alpha: isDark ? 0.14 : 0.10),
          secondary.withValues(alpha: isDark ? 0.16 : 0.08),
        ],
      );

  BoxDecoration glassDecoration({
    double radius = 24,
    Color? glowColor,
    double glowOpacity = 0.16,
  }) {
    return BoxDecoration(
      gradient: cardGradient,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: glassStroke),
      boxShadow: [
        BoxShadow(
          color: (glowColor ?? accent).withValues(alpha: glowOpacity),
          blurRadius: 28,
          spreadRadius: 1,
          offset: const Offset(0, 14),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.08),
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

  const EnterpriseGlass({
    Key? key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 24,
    this.glowColor,
    this.glowOpacity = 0.14,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final enterprise = EnterpriseTheme.of(context);
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
          ),
          child: child,
        ),
      ),
    );
  }
}
