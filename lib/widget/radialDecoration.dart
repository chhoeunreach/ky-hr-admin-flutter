import 'package:cnattendance/utils/constant.dart';
import 'package:cnattendance/theme/app_theme_data.dart';
import 'package:cnattendance/theme/app_theme_mode.dart';
import 'package:flutter/cupertino.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hexcolor/hexcolor.dart';

BoxDecoration RadialDecoration() {
  final colors = themedRadialColors();
  return BoxDecoration(
      image: DecorationImage(
          image: AssetImage("assets/images/back.png"),
          fit: BoxFit.fitHeight,
          opacity: .7,
          alignment: Alignment.center),
      gradient: RadialGradient(colors: colors));
}

List<Color> themedRadialColors() {
  final mode = AppThemeModeX.fromId(GetStorage().read('app_theme_mode'));
  if (mode == AppThemeMode.light) {
    return [
      HexColor(getAppTheme() ? appTheme : "#000000"),
      HexColor(getAppTheme() ? appAlternateTheme : "#000000"),
    ];
  }
  if (mode == AppThemeMode.dark) {
    return const [Color(0xff000000), Color(0xff000000)];
  }
  return AppThemeData.info(mode).colors.gradientColors;
}

Color themedChromeColor() {
  final mode = AppThemeModeX.fromId(GetStorage().read('app_theme_mode'));
  if (mode == AppThemeMode.light || mode == AppThemeMode.dark) {
    return HexColor(getAppTheme() ? radialBoxTheme : "#000000");
  }
  return AppThemeData.info(mode).colors.cardColor;
}
