import 'package:flutter/material.dart';
import 'package:cnattendance/core/theme/app_colors.dart';
import 'package:cnattendance/core/theme/app_palette.dart';

@immutable
class AppGradients {
  const AppGradients(this.colors);

  final AppColors colors;

  LinearGradient get primaryGradient => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppPalette.emerald400,
          AppPalette.emerald700,
          AppPalette.emerald800,
        ],
      );

  LinearGradient get goldGradient => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppPalette.goldLight, AppPalette.gold, AppPalette.goldDeep],
      );

  LinearGradient get bannerScrim => LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [AppPalette.black45, colors.overlayScrim.withValues(alpha: 0)],
      );

  LinearGradient get progressGradient => LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [colors.accent, colors.success],
      );

  LinearGradient get navGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [colors.primaryAlt, colors.primary],
      );

  LinearGradient get storyRing => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppPalette.customFF7C3AED,
          AppPalette.customFFC026D3,
          AppPalette.gold,
        ],
      );
}
