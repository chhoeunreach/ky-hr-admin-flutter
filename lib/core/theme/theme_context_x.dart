import 'package:flutter/material.dart';
import 'package:cnattendance/core/theme/app_colors.dart';
import 'package:cnattendance/core/theme/app_gradients.dart';

extension ThemeX on BuildContext {
  AppColors get colors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.light;

  AppGradients get gradients => AppGradients(colors);
}
