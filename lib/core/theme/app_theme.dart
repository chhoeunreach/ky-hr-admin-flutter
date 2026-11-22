import 'package:flutter/material.dart';
import 'package:cnattendance/core/theme/app_colors.dart';
import 'package:cnattendance/theme/app_theme_mode.dart';

abstract final class AppTheme {
  static ThemeData get light => build(AppColors.light);

  // TODO: replace this light-mirroring stub with a dedicated dark palette.
  static ThemeData get dark =>
      build(AppColors.dark, brightness: Brightness.dark);

  static ThemeData build(
    AppColors colors, {
    AppThemeMode mode = AppThemeMode.light,
    Brightness? brightness,
  }) {
    final resolvedBrightness = brightness ?? Brightness.light;
    final scheme = ColorScheme.fromSeed(
      seedColor: colors.primary,
      brightness: resolvedBrightness,
    ).copyWith(
      primary: colors.primary,
      onPrimary: colors.onPrimary,
      secondary: colors.accent,
      onSecondary: colors.onAccent,
      tertiary: colors.primaryAlt,
      surface: colors.card,
      onSurface: colors.textPrimary,
      error: colors.danger,
      onError: colors.onPrimary,
    );
    final emeraldDay = mode == AppThemeMode.light;

    return ThemeData(
      useMaterial3: true,
      brightness: resolvedBrightness,
      colorScheme: scheme,
      extensions: [colors],
      fontFamily: 'Roboto',
      fontFamilyFallback: const ['Noto Sans Khmer', 'Khmer OS Siemreap'],
      scaffoldBackgroundColor: colors.background,
      canvasColor: colors.background,
      cardColor: colors.card,
      dividerColor: colors.divider,
      iconTheme: emeraldDay ? IconThemeData(color: colors.primary) : null,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: colors.onPrimary),
        actionsIconTheme: IconThemeData(color: colors.onPrimary),
        titleTextStyle: const TextStyle(
          color: AppColors.white,
          fontSize: 20,
          fontFamily: 'Roboto',
          fontFamilyFallback: ['Noto Sans Khmer', 'Khmer OS Siemreap'],
          fontWeight: FontWeight.w700,
        ).copyWith(color: colors.onPrimary),
      ),
      cardTheme: CardThemeData(
        color: colors.card,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        shadowColor: colors.shadow,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colors.card,
        selectedItemColor: colors.accent,
        unselectedItemColor: colors.textSecondary,
        type: BottomNavigationBarType.fixed,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.card,
        indicatorColor: colors.accent.withValues(alpha: .2),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            color: colors.textPrimary,
            fontFamily: 'Roboto',
            fontFamilyFallback: const ['Noto Sans Khmer', 'Khmer OS Siemreap'],
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        titleTextStyle: TextStyle(
          color: colors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          fontFamily: 'Roboto',
          fontFamilyFallback: const ['Noto Sans Khmer', 'Khmer OS Siemreap'],
        ),
        contentTextStyle: TextStyle(
          color: colors.textSecondary,
          fontSize: 14,
          fontFamily: 'Roboto',
          fontFamilyFallback: const ['Noto Sans Khmer', 'Khmer OS Siemreap'],
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.card,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: colors.card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.card,
        hintStyle: TextStyle(color: colors.textSecondary),
        labelStyle: TextStyle(color: colors.textSecondary),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.danger, width: 1.6),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontFamilyFallback: ['Noto Sans Khmer', 'Khmer OS Siemreap'],
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      filledButtonTheme: emeraldDay
          ? FilledButtonThemeData(
              style: FilledButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
              ),
            )
          : null,
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: colors.primaryAlt),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.primary,
          side: BorderSide(color: colors.primary.withValues(alpha: .55)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.surface,
        selectedColor: colors.primaryLight,
        secondarySelectedColor: colors.accent,
        labelStyle: TextStyle(color: colors.textPrimary),
        side: BorderSide(color: colors.divider),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? colors.primary
                : colors.textSecondary),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? colors.primary.withValues(alpha: .4)
                : colors.divider),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? colors.primary : null),
        checkColor: WidgetStatePropertyAll(colors.onPrimary),
        side: BorderSide(color: colors.textSecondary),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primary,
        linearTrackColor: colors.surface,
        circularTrackColor: colors.surface,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.primary,
        contentTextStyle: TextStyle(color: colors.onPrimary),
        behavior: SnackBarBehavior.floating,
      ),
      textTheme: ThemeData(
        brightness: resolvedBrightness,
        fontFamily: 'Roboto',
        fontFamilyFallback: const ['Noto Sans Khmer', 'Khmer OS Siemreap'],
      ).textTheme.apply(
            bodyColor: colors.textPrimary,
            displayColor: colors.textPrimary,
            fontFamily: 'Roboto',
          ),
    );
  }
}
