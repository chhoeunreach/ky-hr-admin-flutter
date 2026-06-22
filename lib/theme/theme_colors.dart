import 'package:flutter/material.dart';

class ThemeColors {
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;
  final Color backgroundColor;
  final Color cardColor;
  final Color textColor;
  final bool isDark;
  final List<Color> gradientColors;

  const ThemeColors({
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.backgroundColor,
    required this.cardColor,
    required this.textColor,
    required this.isDark,
    required this.gradientColors,
  });
}

class AppThemeInfo {
  final String id;
  final String name;
  final IconData icon;
  final String description;
  final ThemeColors colors;

  const AppThemeInfo({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    required this.colors,
  });
}
