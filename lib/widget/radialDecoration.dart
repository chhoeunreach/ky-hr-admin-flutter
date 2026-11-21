import 'package:cnattendance/theme/app_theme_data.dart';
import 'package:cnattendance/theme/app_theme_mode.dart';
import 'package:cnattendance/theme/theme_provider.dart';
import 'package:cnattendance/theme/theme_layout.dart';
import 'package:flutter/cupertino.dart';
import 'package:get_storage/get_storage.dart';

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

ThemeLayout _themedLayout(AppThemeMode mode) => ThemeLayout.decode(
    GetStorage().read<String>(ThemeProvider.layoutKey(mode)));

List<Color> themedRadialColors() {
  final mode = AppThemeModeX.fromId(GetStorage().read('app_theme_mode'));
  final layout = _themedLayout(mode);
  if (layout.background != null) {
    return layout.colorsFor(AppThemeData.info(mode).colors).gradientColors;
  }
  if (mode == AppThemeMode.dark) {
    return const [Color(0xff000000), Color(0xff000000)];
  }
  return AppThemeData.info(mode).colors.gradientColors;
}

Color themedChromeColor() {
  final mode = AppThemeModeX.fromId(GetStorage().read('app_theme_mode'));
  final layout = _themedLayout(mode);
  if (layout.background != null) {
    return layout.colorsFor(AppThemeData.info(mode).colors).cardColor;
  }
  return AppThemeData.info(mode).colors.cardColor;
}
