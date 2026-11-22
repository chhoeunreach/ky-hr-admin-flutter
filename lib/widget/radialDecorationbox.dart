import 'package:cnattendance/utils/constant.dart';
import 'package:cnattendance/core/theme/app_colors.dart';
import 'package:flutter/cupertino.dart';
import 'package:get_storage/get_storage.dart';

//041033
BoxDecoration RadialDecorationBox() {
  final box = GetStorage();
  return BoxDecoration(
      borderRadius: BorderRadius.circular(10),
      color: (box.read('theme') ?? true)
          ? appAlternateTheme
          : AppColors.customFF252525);
}
