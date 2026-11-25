import 'package:cnattendance/core/theme/app_colors.dart';
import 'package:cnattendance/core/theme/app_palette.dart';
import 'package:cnattendance/theme/app_theme_data.dart';
import 'package:cnattendance/theme/app_theme_mode.dart';
import 'package:cnattendance/theme/theme_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color foreground, Color background) {
  final values = [foreground.computeLuminance(), background.computeLuminance()]
    ..sort((a, b) => b.compareTo(a));
  return (values[0] + 0.05) / (values[1] + 0.05);
}

void main() {
  test('Original Mode semantic colors resolve from the central palette', () {
    expect(AppColors.light.primary, AppPalette.emerald800);
    expect(AppColors.light.primaryAlt, AppPalette.emerald600);
    expect(AppColors.light.primaryLight, AppPalette.emerald400);
    expect(AppColors.light.surface, AppPalette.emerald100);
    expect(AppColors.light.background, AppPalette.emerald50);
    expect(AppColors.light.accent, AppPalette.gold);
    expect(AppColors.light.success, AppPalette.success);
    expect(AppColors.light.danger, AppPalette.danger);
  });

  test('day palette text and icons meet WCAG contrast targets', () {
    const colors = AppColors.light;
    final resolvedCard = Color.alphaBlend(colors.card, colors.background);

    expect(
        _contrast(colors.onPrimary, colors.primary), greaterThanOrEqualTo(4.5));
    expect(
        _contrast(colors.onAccent, colors.accent), greaterThanOrEqualTo(4.5));
    expect(_contrast(colors.textSecondary, resolvedCard),
        greaterThanOrEqualTo(4.5));
  });

  test('Original Mode ThemeData installs the semantic color extension', () {
    final theme = AppThemeData.themeData(AppThemeMode.light);
    final defaults = AppThemeData.info(AppThemeMode.light).colors;
    final colors = theme.extension<AppColors>();

    expect(colors, isNotNull);
    expect(colors!.primary, defaults.primaryColor);
    expect(colors.background, defaults.backgroundColor);
    expect(theme.scaffoldBackgroundColor, defaults.backgroundColor);
  });

  test('local theme color overrides keep their selected background and accent',
      () {
    const customBackground = AppPalette.customFF0D1F41;
    const customAccent = AppPalette.goldDeep;
    const overrides = ThemeColors(
      primaryColor: AppPalette.emerald800,
      secondaryColor: AppPalette.emerald600,
      accentColor: customAccent,
      backgroundColor: customBackground,
      cardColor: AppPalette.white,
      textColor: AppPalette.ink900,
      isDark: false,
      gradientColors: [customBackground, AppPalette.white],
    );

    final theme =
        AppThemeData.themeData(AppThemeMode.light, overrides: overrides);
    final colors = theme.extension<AppColors>()!;

    expect(colors.background, customBackground);
    expect(colors.accent, customAccent);
  });
}
