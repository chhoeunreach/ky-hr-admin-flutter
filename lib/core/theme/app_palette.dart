import 'package:flutter/material.dart';

/// Raw colors live here so the app can be re-skinned from one source.
abstract final class AppPalette {
  AppPalette._();
  static const hexPrefix = '\u0023';

  /// Parses a user-selected hex color while keeping Color construction here.
  static Color parseOpaqueHex(String value) {
    final digits =
        value.startsWith(hexPrefix) ? value.substring(hexPrefix.length) : value;
    final normalized = digits.length == 6 ? 'FF$digits' : digits;
    return Color(int.parse(normalized, radix: 16));
  }

  static bool isArgbValue(int value) =>
      value >= argbPrefix && value <= argbMask;

  static Color fromArgb(int value) => Color(value);

  static Color fromRgba(int red, int green, int blue, double opacity) =>
      Color.fromRGBO(red, green, blue, opacity);

  static const int argbMask = 0xFFFFFFFF;
  static const int argbPrefix = 0xFF000000;
  static const int rgbMask = 0x00FFFFFF;

  /// Emits an RGB value for embedded HTML/CSS without scattering hex literals.
  static String cssRgb(Color color) {
    final value = color.toARGB32();
    final red = (value >> 16) & 0xff;
    final green = (value >> 8) & 0xff;
    final blue = value & 0xff;
    return 'rgb($red, $green, $blue)';
  }

  // Emerald brand palette.
  static const emerald900 = Color(0xFF064E3B);
  static const emerald800 = Color(0xFF065F46);
  static const emerald700 = Color(0xFF047857);
  static const emerald600 = Color(0xFF059669);
  static const emerald400 = Color(0xFF34D399);
  static const emerald300 = Color(0xFF6EE7B7);
  static const emerald200 = Color(0xFFA7F3D0);
  static const emerald100 = Color(0xFFD1FAE5);
  static const emerald50 = Color(0xFFF4FDF8);

  // Gold and status palette.
  static const goldLight = Color(0xFFFFF0A8);
  static const gold = Color(0xFFFFC107);
  static const goldDark = Color(0xFFFFB300);
  static const goldDeep = Color(0xFFE08A00);
  static const success = Color(0xFF22C55E);
  static const danger = Color(0xFFEF4444);
  static const warning = Color(0xFFFFC107);
  static const info = Color(0xFF059669);
  static const successSwatch = MaterialColor(0xFF22C55E, {
    50: Color(0xFFE8F5E9),
    100: Color(0xFFC8E6C9),
    200: Color(0xFFA5D6A7),
    300: Color(0xFF81C784),
    400: Color(0xFF66BB6A),
    500: Color(0xFF22C55E),
    600: Color(0xFF43A047),
    700: Color(0xFF388E3C),
    800: Color(0xFF2E7D32),
    900: Color(0xFF1B5E20),
  });
  static const dangerSwatch = MaterialColor(0xFFEF4444, {
    50: Color(0xFFFFEBEE),
    100: Color(0xFFFFCDD2),
    200: Color(0xFFEF9A9A),
    300: Color(0xFFE57373),
    400: Color(0xFFEF5350),
    500: Color(0xFFEF4444),
    600: Color(0xFFE53935),
    700: Color(0xFFD32F2F),
    800: Color(0xFFC62828),
    900: Color(0xFFB71C1C),
  });
  static const goldSwatch = MaterialColor(0xFFFFB300, {
    50: Color(0xFFFFF8E1),
    100: Color(0xFFFFECB3),
    200: Color(0xFFFFE082),
    300: Color(0xFFFFD54F),
    400: Color(0xFFFFCA28),
    500: Color(0xFFFFB300),
    600: Color(0xFFFFA000),
    700: Color(0xFFFF8F00),
    800: Color(0xFFFF6F00),
    900: Color(0xFFE65100),
  });
  static const greySwatch = MaterialColor(0xFF9AA5B1, {
    50: Color(0xFFFAFAFA),
    100: Color(0xFFF5F5F5),
    200: Color(0xFFEEEEEE),
    300: Color(0xFFE0E0E0),
    400: Color(0xFFBDBDBD),
    500: Color(0xFF9AA5B1),
    600: Color(0xFF757575),
    700: Color(0xFF616161),
    800: Color(0xFF424242),
    900: Color(0xFF212121),
  });

  static const emeraldSwatch = MaterialColor(0xFF065F46, {
    50: emerald50,
    100: emerald100,
    200: emerald200,
    300: emerald300,
    400: emerald400,
    500: emerald800,
    600: emerald600,
    700: emerald700,
    800: emerald800,
    900: emerald900,
  });
  static const purpleSwatch = MaterialColor(0xFF9C27B0, {
    50: Color(0xFFF3E5F5),
    100: Color(0xFFE1BEE7),
    200: Color(0xFFCE93D8),
    300: Color(0xFFBA68C8),
    400: Color(0xFFAB47BC),
    500: Color(0xFF9C27B0),
    600: Color(0xFF8E24AA),
    700: Color(0xFF7B1FA2),
    800: Color(0xFF6A1B9A),
    900: Color(0xFF4A148C),
  });
  static const tealSwatch = MaterialColor(0xFF009688, {
    50: Color(0xFFE0F2F1),
    100: Color(0xFFB2DFDB),
    200: Color(0xFF80CBC4),
    300: Color(0xFF4DB6AC),
    400: Color(0xFF26A69A),
    500: Color(0xFF009688),
    600: Color(0xFF00897B),
    700: Color(0xFF00796B),
    800: Color(0xFF00695C),
    900: Color(0xFF004D40),
  });
  static const pinkSwatch = MaterialColor(0xFFE91E63, {
    50: Color(0xFFFCE4EC),
    100: Color(0xFFF8BBD0),
    200: Color(0xFFF48FB1),
    300: Color(0xFFF06292),
    400: Color(0xFFEC407A),
    500: Color(0xFFE91E63),
    600: Color(0xFFD81B60),
    700: Color(0xFFC2185B),
    800: Color(0xFFAD1457),
    900: Color(0xFF880E4F),
  });
  static const cyanSwatch = MaterialColor(0xFF00BCD4, {
    50: Color(0xFFE0F7FA),
    100: Color(0xFFB2EBF2),
    200: Color(0xFF80DEEA),
    300: Color(0xFF4DD0E1),
    400: Color(0xFF26C6DA),
    500: Color(0xFF00BCD4),
    600: Color(0xFF00ACC1),
    700: Color(0xFF0097A7),
    800: Color(0xFF00838F),
    900: Color(0xFF006064),
  });
  static const amberSwatch = MaterialColor(0xFFFFC107, {
    50: Color(0xFFFFF8E1),
    100: Color(0xFFFFECB3),
    200: Color(0xFFFFE082),
    300: Color(0xFFFFD54F),
    400: Color(0xFFFFCA28),
    500: Color(0xFFFFC107),
    600: Color(0xFFFFB300),
    700: Color(0xFFFFA000),
    800: Color(0xFFFF8F00),
    900: Color(0xFFFF6F00),
  });
  static const orangeSwatch = MaterialColor(0xFFFF9800, {
    50: Color(0xFFFFF3E0),
    100: Color(0xFFFFE0B2),
    200: Color(0xFFFFCC80),
    300: Color(0xFFFFB74D),
    400: Color(0xFFFFA726),
    500: Color(0xFFFF9800),
    600: Color(0xFFFB8C00),
    700: Color(0xFFF57C00),
    800: Color(0xFFEF6C00),
    900: Color(0xFFE65100),
  });
  // Neutral and opacity tokens.
  static const white = Color(0xFFFFFFFF);
  static const black = Color(0xFF000000);
  static const ink900 = Color(0xFF0F172A);
  static const ink600 = Color(0xFF475569);
  static const ink300 = Color(0xFFCBD5E1);
  static const grey = Color(0xFF9AA5B1);
  static const white85 = Color(0xD9FFFFFF);
  static const overlayScrim = Color(0x59000000);
  static const emeraldShadow = Color(0x2E065F46);
  static const emeraldShadowSoft = Color(0x1F065F46);
  static const black18 = Color(0x2E000000);
  static const white70 = Color(0xB3FFFFFF);
  static const white60 = Color(0x99FFFFFF);
  static const white54 = Color(0x8AFFFFFF);
  static const white38 = Color(0x61FFFFFF);
  static const white30 = Color(0x4DFFFFFF);
  static const white24 = Color(0x3DFFFFFF);
  static const white12 = Color(0x1FFFFFFF);
  static const white10 = Color(0x1AFFFFFF);
  static const black87 = Color(0xDD000000);
  static const black54 = Color(0x8A000000);
  static const black45 = Color(0x73000000);
  static const black38 = Color(0x61000000);
  static const black26 = Color(0x42000000);
  static const black12 = Color(0x1F000000);
  static const materialPurple = Color(0xFF9C27B0);
  static const materialPink = Color(0xFFE91E63);
  static const materialBlueGrey = Color(0xFF607D8B);
  static const materialTeal = Color(0xFF009688);
  static const materialCyan = Color(0xFF00BCD4);

  // Legacy/component-specific colors are centralized tokens and intentionally
  // retain their values where the brief calls for preserved status/art colors.
  static const custom00061A40 = Color(0x00061A40);
  static const custom1A1683E6 = Color(0x1A1683E6);
  static const custom22FFFFFF = Color(0x22FFFFFF);
  static const custom26000000 = Color(0x26000000);
  static const custom33000000 = Color(0x33000000);
  static const custom33061A40 = Color(0x33061A40);
  static const custom36000000 = Color(0x36000000);
  static const custom3B000000 = Color(0x3B000000);
  static const custom40FFFFFF = Color(0x40FFFFFF);
  static const custom44FFFFFF = Color(0x44FFFFFF);
  static const custom551684F8 = Color(0x551684F8);
  static const custom55FFFFFF = Color(0x55FFFFFF);
  static const custom99061A40 = Color(0x99061A40);
  static const customAA000000 = Color(0xAA000000);
  static const customAA06142F = Color(0xAA06142F);
  static const customEE061A40 = Color(0xEE061A40);
  static const customFF002255 = Color(0xFF002255);
  static const customFF002A68 = Color(0xFF002A68);
  static const customFF003B91 = Color(0xFF003B91);
  static const customFF003D99 = Color(0xFF003D99);
  static const customFF0047AB = Color(0xFF0047AB);
  static const customFF0054D7 = Color(0xFF0054D7);
  static const customFF0056C7 = Color(0xFF0056C7);
  static const customFF005BEA = Color(0xFF005BEA);
  static const customFF0063DC = Color(0xFF0063DC);
  static const customFF0066FF = Color(0xFF0066FF);
  static const customFF0084FF = Color(0xFF0084FF);
  static const customFF008C98 = Color(0xFF008C98);
  static const customFF008CFF = Color(0xFF008CFF);
  static const customFF00A6B2 = Color(0xFF00A6B2);
  static const customFF00C6FF = Color(0xFF00C6FF);
  static const customFF00F5D4 = Color(0xFF00F5D4);
  static const customFF01030A = Color(0xFF01030A);
  static const customFF010704 = Color(0xFF010704);
  static const customFF010814 = Color(0xFF010814);
  static const customFF010E14 = Color(0xFF010E14);
  static const customFF011754 = Color(0xFF011754);
  static const customFF020617 = Color(0xFF020617);
  static const customFF020B25 = Color(0xFF020B25);
  static const customFF02140A = Color(0xFF02140A);
  static const customFF021526 = Color(0xFF021526);
  static const customFF021A24 = Color(0xFF021A24);
  static const customFF0284C7 = Color(0xFF0284C7);
  static const customFF03122F = Color(0xFF03122F);
  static const customFF031407 = Color(0xFF031407);
  static const customFF031926 = Color(0xFF031926);
  static const customFF031A43 = Color(0xFF031A43);
  static const customFF0369A1 = Color(0xFF0369A1);
  static const customFF0369FF = Color(0xFF0369FF);
  static const customFF036EB7 = Color(0xFF036EB7);
  static const customFF04122E = Color(0xFF04122E);
  static const customFF041C3C = Color(0xFF041C3C);
  static const customFF050615 = Color(0xFF050615);
  static const customFF051026 = Color(0xFF051026);
  static const customFF052E16 = Color(0xFF052E16);
  static const customFF0596A1 = Color(0xFF0596A1);
  static const customFF06142F = Color(0xFF06142F);
  static const customFF06143A = Color(0xFF06143A);
  static const customFF061A40 = Color(0xFF061A40);
  static const customFF062B66 = Color(0xFF062B66);
  static const customFF06B6D4 = Color(0xFF06B6D4);
  static const customFF07111F = Color(0xFF07111F);
  static const customFF071326 = Color(0xFF071326);
  static const customFF071B3B = Color(0xFF071B3B);
  static const customFF071B45 = Color(0xFF071B45);
  static const customFF0756C8 = Color(0xFF0756C8);
  static const customFF075985 = Color(0xFF075985);
  static const customFF0759C7 = Color(0xFF0759C7);
  static const customFF078BFF = Color(0xFF078BFF);
  static const customFF07952E = Color(0xFF07952E);
  static const customFF082D68 = Color(0xFF082D68);
  static const customFF082F49 = Color(0xFF082F49);
  static const customFF090018 = Color(0xFF090018);
  static const customFF090302 = Color(0xFF090302);
  static const customFF09051F = Color(0xFF09051F);
  static const customFF09234F = Color(0xFF09234F);
  static const customFF0A192F = Color(0xFF0A192F);
  static const customFF0A1E3D = Color(0xFF0A1E3D);
  static const customFF0A1F44 = Color(0xFF0A1F44);
  static const customFF0A254F = Color(0xFF0A254F);
  static const customFF0A2F6B = Color(0xFF0A2F6B);
  static const customFF0A3D91 = Color(0xFF0A3D91);
  static const customFF0A84FF = Color(0xFF0A84FF);
  static const customFF0B0F14 = Color(0xFF0B0F14);
  static const customFF0B172A = Color(0xFF0B172A);
  static const customFF0B192C = Color(0xFF0B192C);
  static const customFF0B2F6B = Color(0xFF0B2F6B);
  static const customFF0B3975 = Color(0xFF0B3975);
  static const customFF0B4B38 = Color(0xFF0B4B38);
  static const customFF0B4F2C = Color(0xFF0B4F2C);
  static const customFF0B5FFF = Color(0xFF0B5FFF);
  static const customFF0C1C3A = Color(0xFF0C1C3A);
  static const customFF0C2247 = Color(0xFF0C2247);
  static const customFF0C2B61 = Color(0xFF0C2B61);
  static const customFF0C4A6E = Color(0xFF0C4A6E);
  static const customFF0D1F41 = Color(0xFF0D1F41);
  static const customFF0E3A8C = Color(0xFF0E3A8C);
  static const customFF0E7490 = Color(0xFF0E7490);
  static const customFF0EA5E9 = Color(0xFF0EA5E9);
  static const customFF0EA5FF = Color(0xFF0EA5FF);
  static const customFF0F2027 = Color(0xFF0F2027);
  static const customFF101010 = Color(0xFF101010);
  static const customFF10182E = Color(0xFF10182E);
  static const customFF102246 = Color(0xFF102246);
  static const customFF102416 = Color(0xFF102416);
  static const customFF102A56 = Color(0xFF102A56);
  static const customFF11146C = Color(0xFF11146C);
  static const customFF111827 = Color(0xFF111827);
  static const customFF111936 = Color(0xFF111936);
  static const customFF120B35 = Color(0xFF120B35);
  static const customFF121423 = Color(0xFF121423);
  static const customFF12C878 = Color(0xFF12C878);
  static const customFF13243A = Color(0xFF13243A);
  static const customFF13264D = Color(0xFF13264D);
  static const customFF142233 = Color(0xFF142233);
  static const customFF14233B = Color(0xFF14233B);
  static const customFF14264C = Color(0xFF14264C);
  static const customFF14532D = Color(0xFF14532D);
  static const customFF151725 = Color(0xFF151725);
  static const customFF160A3A = Color(0xFF160A3A);
  static const customFF161D27 = Color(0xFF161D27);
  static const customFF1677FF = Color(0xFF1677FF);
  static const customFF1684F8 = Color(0xFF1684F8);
  static const customFF16885F = Color(0xFF16885F);
  static const customFF1689F9 = Color(0xFF1689F9);
  static const customFF16A34A = Color(0xFF16A34A);
  static const customFF170703 = Color(0xFF170703);
  static const customFF172033 = Color(0xFF172033);
  static const customFF172A46 = Color(0xFF172A46);
  static const customFF1769E8 = Color(0xFF1769E8);
  static const customFF17A7E7 = Color(0xFF17A7E7);
  static const customFF180733 = Color(0xFF180733);
  static const customFF1877F2 = Color(0xFF1877F2);
  static const customFF193260 = Color(0xFF193260);
  static const customFF1A2B52 = Color(0xFF1A2B52);
  static const customFF1A3A6B = Color(0xFF1A3A6B);
  static const customFF1A5ED4 = Color(0xFF1A5ED4);
  static const customFF1B2446 = Color(0xFF1B2446);
  static const customFF1D2939 = Color(0xFF1D2939);
  static const customFF1D4ED8 = Color(0xFF1D4ED8);
  static const customFF1D7A46 = Color(0xFF1D7A46);
  static const customFF1E1B4B = Color(0xFF1E1B4B);
  static const customFF1E293B = Color(0xFF1E293B);
  static const customFF1E3A8A = Color(0xFF1E3A8A);
  static const customFF1E3E62 = Color(0xFF1E3E62);
  static const customFF1E5BB8 = Color(0xFF1E5BB8);
  static const customFF20183E = Color(0xFF20183E);
  static const customFF210814 = Color(0xFF210814);
  static const customFF211720 = Color(0xFF211720);
  static const customFF22D3EE = Color(0xFF22D3EE);
  static const customFF234067 = Color(0xFF234067);
  static const customFF24406F = Color(0xFF24406F);
  static const customFF24466F = Color(0xFF24466F);
  static const customFF246BFE = Color(0xFF246BFE);
  static const customFF24A1DE = Color(0xFF24A1DE);
  static const customFF250B17 = Color(0xFF250B17);
  static const customFF253858 = Color(0xFF253858);
  static const customFF2563EB = Color(0xFF2563EB);
  static const customFF26111B = Color(0xFF26111B);
  static const customFF262839 = Color(0xFF262839);
  static const customFF263247 = Color(0xFF263247);
  static const customFF290C1A = Color(0xFF290C1A);
  static const customFF2C0A1A = Color(0xFF2C0A1A);
  static const customFF2C5364 = Color(0xFF2C5364);
  static const customFF2D1830 = Color(0xFF2D1830);
  static const customFF2E1065 = Color(0xFF2E1065);
  static const customFF2F6FED = Color(0xFF2F6FED);
  static const customFF312E81 = Color(0xFF312E81);
  static const customFF31C65B = Color(0xFF31C65B);
  static const customFF320E20 = Color(0xFF320E20);
  static const customFF332059 = Color(0xFF332059);
  static const customFF334155 = Color(0xFF334155);
  static const customFF344054 = Color(0xFF344054);
  static const customFF367CF6 = Color(0xFF367CF6);
  static const customFF36B9FF = Color(0xFF36B9FF);
  static const customFF38BDF8 = Color(0xFF38BDF8);
  static const customFF390F24 = Color(0xFF390F24);
  static const customFF3B168F = Color(0xFF3B168F);
  static const customFF3B82F6 = Color(0xFF3B82F6);
  static const customFF3D8BFF = Color(0xFF3D8BFF);
  static const customFF421226 = Color(0xFF421226);
  static const customFF431407 = Color(0xFF431407);
  static const customFF45BD62 = Color(0xFF45BD62);
  static const customFF48A7FF = Color(0xFF48A7FF);
  static const customFF496080 = Color(0xFF496080);
  static const customFF4A148C = Color(0xFF4A148C);
  static const customFF4A192E = Color(0xFF4A192E);
  static const customFF4ADE80 = Color(0xFF4ADE80);
  static const customFF4C1D95 = Color(0xFF4C1D95);
  static const customFF5068A0 = Color(0xFF5068A0);
  static const customFF52607A = Color(0xFF52607A);
  static const customFF581C87 = Color(0xFF581C87);
  static const customFF5D6785 = Color(0xFF5D6785);
  static const customFF5EB1FF = Color(0xFF5EB1FF);
  static const customFF5F6F82 = Color(0xFF5F6F82);
  static const customFF60A5FA = Color(0xFF60A5FA);
  static const customFF611B35 = Color(0xFF611B35);
  static const customFF61A7F5 = Color(0xFF61A7F5);
  static const customFF6246D9 = Color(0xFF6246D9);
  static const customFF6366F1 = Color(0xFF6366F1);
  static const customFF63758E = Color(0xFF63758E);
  static const customFF641D37 = Color(0xFF641D37);
  static const customFF64748B = Color(0xFF64748B);
  static const customFF67E8F9 = Color(0xFF67E8F9);
  static const customFF697386 = Color(0xFF697386);
  static const customFF6B7280 = Color(0xFF6B7280);
  static const customFF70C2FF = Color(0xFF70C2FF);
  static const customFF70F2B8 = Color(0xFF70F2B8);
  static const customFF718096 = Color(0xFF718096);
  static const customFF73A3FF = Color(0xFF73A3FF);
  static const customFF750F2B = Color(0xFF750F2B);
  static const customFF7536DE = Color(0xFF7536DE);
  static const customFF758094 = Color(0xFF758094);
  static const customFF7952CC = Color(0xFF7952CC);
  static const customFF7B2D8E = Color(0xFF7B2D8E);
  static const customFF7B2FF7 = Color(0xFF7B2FF7);
  static const customFF7C2D12 = Color(0xFF7C2D12);
  static const customFF7C3AED = Color(0xFF7C3AED);
  static const customFF7D88A5 = Color(0xFF7D88A5);
  static const customFF7DD3FC = Color(0xFF7DD3FC);
  static const customFF7DD3FF = Color(0xFF7DD3FF);
  static const customFF80C8FF = Color(0xFF80C8FF);
  static const customFF818CF8 = Color(0xFF818CF8);
  static const customFF831843 = Color(0xFF831843);
  static const customFF862B48 = Color(0xFF862B48);
  static const customFF880E4F = Color(0xFF880E4F);
  static const customFF8A0E68 = Color(0xFF8A0E68);
  static const customFF8A2844 = Color(0xFF8A2844);
  static const customFF8AB4FF = Color(0xFF8AB4FF);
  static const customFF8B5CF6 = Color(0xFF8B5CF6);
  static const customFF9333EA = Color(0xFF9333EA);
  static const customFF93A1B3 = Color(0xFF93A1B3);
  static const customFF943F58 = Color(0xFF943F58);
  static const customFF9CCFF8 = Color(0xFF9CCFF8);
  static const customFF9D124D = Color(0xFF9D124D);
  static const customFF9D174D = Color(0xFF9D174D);
  static const customFF9D50DD = Color(0xFF9D50DD);
  static const customFFA31250 = Color(0xFFA31250);
  static const customFFA66BFF = Color(0xFFA66BFF);
  static const customFFA66CFF = Color(0xFFA66CFF);
  static const customFFA78BFA = Color(0xFFA78BFA);
  static const customFFA855F7 = Color(0xFFA855F7);
  static const customFFA8C8F0 = Color(0xFFA8C8F0);
  static const customFFAD1457 = Color(0xFFAD1457);
  static const customFFAECBF0 = Color(0xFFAECBF0);
  static const customFFB4235A = Color(0xFFB4235A);
  static const customFFB77900 = Color(0xFFB77900);
  static const customFFB87908 = Color(0xFFB87908);
  static const customFFB8860B = Color(0xFFB8860B);
  static const customFFB8DEFF = Color(0xFFB8DEFF);
  static const customFFB8F5D0 = Color(0xFFB8F5D0);
  static const customFFB9D8F2 = Color(0xFFB9D8F2);
  static const customFFBFDDF0 = Color(0xFFBFDDF0);
  static const customFFC084FC = Color(0xFFC084FC);
  static const customFFC2185B = Color(0xFFC2185B);
  static const customFFC2410C = Color(0xFFC2410C);
  static const customFFC4B5FD = Color(0xFFC4B5FD);
  static const customFFC53030 = Color(0xFFC53030);
  static const customFFC59B27 = Color(0xFFC59B27);
  static const customFFC6D9F5 = Color(0xFFC6D9F5);
  static const customFFC81D77 = Color(0xFFC81D77);
  static const customFFCD201F = Color(0xFFCD201F);
  static const customFFCDDDF6 = Color(0xFFCDDDF6);
  static const customFFCF4353 = Color(0xFFCF4353);
  static const customFFCFE8CC = Color(0xFFCFE8CC);
  static const customFFD38115 = Color(0xFFD38115);
  static const customFFD5B6FF = Color(0xFFD5B6FF);
  static const customFFD6AA27 = Color(0xFFD6AA27);
  static const customFFD6ECFF = Color(0xFFD6ECFF);
  static const customFFD8B4FE = Color(0xFFD8B4FE);
  static const customFFD8E0EC = Color(0xFFD8E0EC);
  static const customFFD8E7FF = Color(0xFFD8E7FF);
  static const customFFD8E9FF = Color(0xFFD8E9FF);
  static const customFFD8ECFF = Color(0xFFD8ECFF);
  static const customFFD92232 = Color(0xFFD92232);
  static const customFFD946EF = Color(0xFFD946EF);
  static const customFFDAEAFF = Color(0xFFDAEAFF);
  static const customFFDBE8FA = Color(0xFFDBE8FA);
  static const customFFDC253B = Color(0xFFDC253B);
  static const customFFDC2626 = Color(0xFFDC2626);
  static const customFFDCE6F5 = Color(0xFFDCE6F5);
  static const customFFDDE6F2 = Color(0xFFDDE6F2);
  static const customFFDDEEFF = Color(0xFFDDEEFF);
  static const customFFE0E8F2 = Color(0xFFE0E8F2);
  static const customFFE11D48 = Color(0xFFE11D48);
  static const customFFE15A2B = Color(0xFFE15A2B);
  static const customFFE2E8F0 = Color(0xFFE2E8F0);
  static const customFFE2EBFA = Color(0xFFE2EBFA);
  static const customFFE3B877 = Color(0xFFE3B877);
  static const customFFE4405F = Color(0xFFE4405F);
  static const customFFE4D59C = Color(0xFFE4D59C);
  static const customFFE5E7EB = Color(0xFFE5E7EB);
  static const customFFE5EDF8 = Color(0xFFE5EDF8);
  static const customFFE6B857 = Color(0xFFE6B857);
  static const customFFE6ECF4 = Color(0xFFE6ECF4);
  static const customFFE79700 = Color(0xFFE79700);
  static const customFFE83E8C = Color(0xFFE83E8C);
  static const customFFE8EAEF = Color(0xFFE8EAEF);
  static const customFFE8EEF6 = Color(0xFFE8EEF6);
  static const customFFE8EFF9 = Color(0xFFE8EFF9);
  static const customFFE8F1FD = Color(0xFFE8F1FD);
  static const customFFEA580C = Color(0xFFEA580C);
  static const customFFEAF1FB = Color(0xFFEAF1FB);
  static const customFFEAF1FF = Color(0xFFEAF1FF);
  static const customFFEAF2FF = Color(0xFFEAF2FF);
  static const customFFEAF3F6 = Color(0xFFEAF3F6);
  static const customFFEAF3FF = Color(0xFFEAF3FF);
  static const customFFEAF6FF = Color(0xFFEAF6FF);
  static const customFFEC4899 = Color(0xFFEC4899);
  static const customFFEDC478 = Color(0xFFEDC478);
  static const customFFEDF2F7 = Color(0xFFEDF2F7);
  static const customFFEDF4FF = Color(0xFFEDF4FF);
  static const customFFEE1D52 = Color(0xFFEE1D52);
  static const customFFEEE7DB = Color(0xFFEEE7DB);
  static const customFFEEF3F7 = Color(0xFFEEF3F7);
  static const customFFEEF4FC = Color(0xFFEEF4FC);
  static const customFFEEF4FF = Color(0xFFEEF4FF);
  static const customFFEF3D58 = Color(0xFFEF3D58);
  static const customFFF06292 = Color(0xFFF06292);
  static const customFFF107A3 = Color(0xFFF107A3);
  static const customFFF1F5F9 = Color(0xFFF1F5F9);
  static const customFFF33E58 = Color(0xFFF33E58);
  static const customFFF3425F = Color(0xFFF3425F);
  static const customFFF3D36B = Color(0xFFF3D36B);
  static const customFFF3F6FA = Color(0xFFF3F6FA);
  static const customFFF3F7FD = Color(0xFFF3F7FD);
  static const customFFF472B6 = Color(0xFFF472B6);
  static const customFFF4F1EC = Color(0xFFF4F1EC);
  static const customFFF4F6FA = Color(0xFFF4F6FA);
  static const customFFF5533D = Color(0xFFF5533D);
  static const customFFF59E0B = Color(0xFFF59E0B);
  static const customFFF5E8B7 = Color(0xFFF5E8B7);
  static const customFFF5F7FB = Color(0xFFF5F7FB);
  static const customFFF5F8FD = Color(0xFFF5F8FD);
  static const customFFF5FAFF = Color(0xFFF5FAFF);
  static const customFFF7B928 = Color(0xFFF7B928);
  static const customFFF7F7F8 = Color(0xFFF7F7F8);
  static const customFFF7F9FC = Color(0xFFF7F9FC);
  static const customFFF7FAFF = Color(0xFFF7FAFF);
  static const customFFF87171 = Color(0xFFF87171);
  static const customFFF8BBD0 = Color(0xFFF8BBD0);
  static const customFFF8FAFC = Color(0xFFF8FAFC);
  static const customFFF953C6 = Color(0xFFF953C6);
  static const customFFF97316 = Color(0xFFF97316);
  static const customFFFAF8F5 = Color(0xFFFAF8F5);
  static const customFFFB7185 = Color(0xFFFB7185);
  static const customFFFB7CA5 = Color(0xFFFB7CA5);
  static const customFFFB923C = Color(0xFFFB923C);
  static const customFFFBBF24 = Color(0xFFFBBF24);
  static const customFFFDBA74 = Color(0xFFFDBA74);
  static const customFFFED7AA = Color(0xFFFED7AA);
  static const customFFFF6098 = Color(0xFFFF6098);
  static const customFFFF6B6B = Color(0xFFFF6B6B);
  static const customFFFF7A18 = Color(0xFFFF7A18);
  static const customFFFF80AB = Color(0xFFFF80AB);
  static const customFFFF8A1C = Color(0xFFFF8A1C);
  static const customFFFF8DB8 = Color(0xFFFF8DB8);
  static const customFFFF94BA = Color(0xFFFF94BA);
  static const customFFFF97BC = Color(0xFFFF97BC);
  static const customFFFF9DAE = Color(0xFFFF9DAE);
  static const customFFFFA726 = Color(0xFFFFA726);
  static const customFFFFC83D = Color(0xFFFFC83D);
  static const customFFFFC857 = Color(0xFFFFC857);
  static const customFFFFD29F = Color(0xFFFFD29F);
  static const customFFFFD54F = Color(0xFFFFD54F);
  static const customFFFFE17A = Color(0xFFFFE17A);
  static const customFFFFEDD5 = Color(0xFFFFEDD5);
  static const customFFFFF1B6 = Color(0xFFFFF1B6);
  static const customFFFFF1B8 = Color(0xFFFFF1B8);
  static const customFFFFF1D6 = Color(0xFFFFF1D6);
  static const customFFFFF2DC = Color(0xFFFFF2DC);
  static const customFFFFF7ED = Color(0xFFFFF7ED);
  static const customFFFFFBEB = Color(0xFFFFFBEB);
  static const customFF101826 = Color(0xFF101826);
  static const customFF252525 = Color(0xFF252525);
  static const customFFEEF3F6 = Color(0xFFEEF3F6);
  static const custom24065F46 = Color(0x24065F46);
  static const custom20FFFFFF = Color(0x20FFFFFF);
  static const customFFC1E1C1 = Color(0xFFC1E1C1);
  static const customFFC9CC3F = Color(0xFFC9CC3F);
  static const customFF93C572 = Color(0xFF93C572);
  static const customFF3CB116 = Color(0xFF3CB116);
  static const customFFC026D3 = Color(0xFFC026D3);
}
