import 'package:flutter/material.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

abstract final class AppShadows {
  static List<BoxShadow> card(AppColors colors) => [
        BoxShadow(
          color: colors.shadow,
          blurRadius: 18,
          offset: const Offset(0, 7),
        ),
      ];

  static List<BoxShadow> tile(AppColors colors) => [
        BoxShadow(
          color: colors.shadow.withValues(alpha: .75),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];
}
