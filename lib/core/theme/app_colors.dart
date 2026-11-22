import 'package:flutter/material.dart';
import 'package:cnattendance/core/theme/app_palette.dart';
import 'package:cnattendance/theme/theme_colors.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color primary;
  final Color primaryAlt;
  final Color primaryLight;
  final Color surface;
  final Color background;
  final Color card;
  final Color accent;
  final Color accentDark;
  final Color onPrimary;
  final Color onAccent;
  final Color textPrimary;
  final Color textSecondary;
  final Color divider;
  final Color success;
  final Color danger;
  final Color warning;
  final Color info;
  final Color late;
  final Color bonus;
  final Color overlayScrim;
  final Color shadow;

  const AppColors(
      {required this.primary,
      required this.primaryAlt,
      required this.primaryLight,
      required this.surface,
      required this.background,
      required this.card,
      required this.accent,
      required this.accentDark,
      required this.onPrimary,
      required this.onAccent,
      required this.textPrimary,
      required this.textSecondary,
      required this.divider,
      required this.success,
      required this.danger,
      required this.warning,
      required this.info,
      required this.late,
      required this.bonus,
      required this.overlayScrim,
      required this.shadow});

  static const AppColors light = AppColors(
      primary: AppPalette.emerald800,
      primaryAlt: AppPalette.emerald600,
      primaryLight: AppPalette.emerald400,
      surface: AppPalette.emerald100,
      background: AppPalette.emerald50,
      card: AppPalette.white85,
      accent: AppPalette.gold,
      accentDark: AppPalette.goldDark,
      onPrimary: AppPalette.white,
      onAccent: AppPalette.emerald900,
      textPrimary: AppPalette.ink900,
      textSecondary: AppPalette.ink600,
      divider: AppPalette.ink300,
      success: AppPalette.success,
      danger: AppPalette.danger,
      warning: AppPalette.warning,
      info: AppPalette.info,
      late: AppPalette.danger,
      bonus: AppPalette.success,
      overlayScrim: AppPalette.overlayScrim,
      shadow: AppPalette.emeraldShadow);
  static const AppColors dark = light; // TODO: define a dedicated dark palette.

  factory AppColors.fromThemeColors(ThemeColors colors,
      {bool emeraldDay = false}) {
    final onPrimary =
        ThemeData.estimateBrightnessForColor(colors.primaryColor) ==
                Brightness.dark
            ? AppPalette.white
            : AppPalette.ink900;
    final onAccent = emeraldDay
        ? AppPalette.emerald900
        : ThemeData.estimateBrightnessForColor(colors.accentColor) ==
                Brightness.dark
            ? AppPalette.white
            : AppPalette.ink900;
    return AppColors(
        primary: colors.primaryColor,
        primaryAlt: colors.secondaryColor,
        primaryLight: emeraldDay ? AppPalette.emerald400 : colors.accentColor,
        surface: emeraldDay ? AppPalette.emerald100 : colors.cardColor,
        background: colors.backgroundColor,
        card: emeraldDay
            ? colors.cardColor.withValues(alpha: .85)
            : colors.cardColor,
        accent: colors.accentColor,
        accentDark: emeraldDay ? AppPalette.goldDark : colors.accentColor,
        onPrimary: onPrimary,
        onAccent: onAccent,
        textPrimary: emeraldDay ? AppPalette.ink900 : colors.textColor,
        textSecondary: emeraldDay
            ? AppPalette.ink600
            : colors.textColor.withValues(alpha: .72),
        divider: emeraldDay
            ? AppPalette.ink300
            : colors.textColor.withValues(alpha: .2),
        success: AppPalette.success,
        danger: AppPalette.danger,
        warning: AppPalette.warning,
        info: emeraldDay ? AppPalette.info : colors.accentColor,
        late: AppPalette.danger,
        bonus: AppPalette.success,
        overlayScrim: AppPalette.overlayScrim,
        shadow: emeraldDay
            ? AppPalette.emeraldShadow
            : colors.primaryColor.withValues(alpha: .18));
  }

  AppColors copyWith(
          {Color? primary,
          Color? primaryAlt,
          Color? primaryLight,
          Color? surface,
          Color? background,
          Color? card,
          Color? accent,
          Color? accentDark,
          Color? onPrimary,
          Color? onAccent,
          Color? textPrimary,
          Color? textSecondary,
          Color? divider,
          Color? success,
          Color? danger,
          Color? warning,
          Color? info,
          Color? late,
          Color? bonus,
          Color? overlayScrim,
          Color? shadow}) =>
      AppColors(
          primary: primary ?? this.primary,
          primaryAlt: primaryAlt ?? this.primaryAlt,
          primaryLight: primaryLight ?? this.primaryLight,
          surface: surface ?? this.surface,
          background: background ?? this.background,
          card: card ?? this.card,
          accent: accent ?? this.accent,
          accentDark: accentDark ?? this.accentDark,
          onPrimary: onPrimary ?? this.onPrimary,
          onAccent: onAccent ?? this.onAccent,
          textPrimary: textPrimary ?? this.textPrimary,
          textSecondary: textSecondary ?? this.textSecondary,
          divider: divider ?? this.divider,
          success: success ?? this.success,
          danger: danger ?? this.danger,
          warning: warning ?? this.warning,
          info: info ?? this.info,
          late: late ?? this.late,
          bonus: bonus ?? this.bonus,
          overlayScrim: overlayScrim ?? this.overlayScrim,
          shadow: shadow ?? this.shadow);

  @override
  AppColors lerp(covariant AppColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
        primary: l(primary, other.primary),
        primaryAlt: l(primaryAlt, other.primaryAlt),
        primaryLight: l(primaryLight, other.primaryLight),
        surface: l(surface, other.surface),
        background: l(background, other.background),
        card: l(card, other.card),
        accent: l(accent, other.accent),
        accentDark: l(accentDark, other.accentDark),
        onPrimary: l(onPrimary, other.onPrimary),
        onAccent: l(onAccent, other.onAccent),
        textPrimary: l(textPrimary, other.textPrimary),
        textSecondary: l(textSecondary, other.textSecondary),
        divider: l(divider, other.divider),
        success: l(success, other.success),
        danger: l(danger, other.danger),
        warning: l(warning, other.warning),
        info: l(info, other.info),
        late: l(late, other.late),
        bonus: l(bonus, other.bonus),
        overlayScrim: l(overlayScrim, other.overlayScrim),
        shadow: l(shadow, other.shadow));
  }

  // Semantic aliases for legacy component colors; raw values remain in AppPalette.
  static const amber = AppPalette.amberSwatch;
  static const accentToken = AppPalette.gold;
  static const emerald50 = AppPalette.emerald50;
  static const emerald100 = AppPalette.emerald100;
  static const emerald200 = AppPalette.emerald200;
  static const emerald300 = AppPalette.emerald300;
  static const emerald600 = AppPalette.emerald600;
  static const emerald800 = AppPalette.emerald800;
  static const goldLight = AppPalette.goldLight;
  static const goldDeep = AppPalette.goldDeep;
  static const black = AppPalette.black;
  static const black12 = AppPalette.black12;
  static const black26 = AppPalette.black26;
  static const black38 = AppPalette.black38;
  static const black45 = AppPalette.black45;
  static const black54 = AppPalette.black54;
  static const black87 = AppPalette.black87;
  static const blue = AppPalette.emeraldSwatch;
  static const blueAccent = AppPalette.emerald400;
  static const blueGrey = AppPalette.materialBlueGrey;
  static const custom00061A40 = AppPalette.custom00061A40;
  static const custom1A1683E6 = AppPalette.custom1A1683E6;
  static const custom22FFFFFF = AppPalette.custom22FFFFFF;
  static const custom24065F46 = AppPalette.custom24065F46;
  static const custom26000000 = AppPalette.custom26000000;
  static const custom33000000 = AppPalette.custom33000000;
  static const custom33061A40 = AppPalette.custom33061A40;
  static const custom36000000 = AppPalette.custom36000000;
  static const custom3B000000 = AppPalette.custom3B000000;
  static const custom40FFFFFF = AppPalette.custom40FFFFFF;
  static const custom44FFFFFF = AppPalette.custom44FFFFFF;
  static const custom551684F8 = AppPalette.custom551684F8;
  static const custom55FFFFFF = AppPalette.custom55FFFFFF;
  static const custom99061A40 = AppPalette.custom99061A40;
  static const customAA000000 = AppPalette.customAA000000;
  static const customAA06142F = AppPalette.customAA06142F;
  static const customEE061A40 = AppPalette.customEE061A40;
  static const customFF002255 = AppPalette.customFF002255;
  static const customFF002A68 = AppPalette.customFF002A68;
  static const customFF003B91 = AppPalette.customFF003B91;
  static const customFF003D99 = AppPalette.customFF003D99;
  static const customFF0047AB = AppPalette.customFF0047AB;
  static const customFF0054D7 = AppPalette.customFF0054D7;
  static const customFF0056C7 = AppPalette.customFF0056C7;
  static const customFF005BEA = AppPalette.customFF005BEA;
  static const customFF0063DC = AppPalette.customFF0063DC;
  static const customFF0066FF = AppPalette.customFF0066FF;
  static const customFF0084FF = AppPalette.customFF0084FF;
  static const customFF008C98 = AppPalette.customFF008C98;
  static const customFF008CFF = AppPalette.customFF008CFF;
  static const customFF00A6B2 = AppPalette.customFF00A6B2;
  static const customFF00C6FF = AppPalette.customFF00C6FF;
  static const customFF00F5D4 = AppPalette.customFF00F5D4;
  static const customFF01030A = AppPalette.customFF01030A;
  static const customFF010704 = AppPalette.customFF010704;
  static const customFF010814 = AppPalette.customFF010814;
  static const customFF010E14 = AppPalette.customFF010E14;
  static const customFF011754 = AppPalette.customFF011754;
  static const customFF020617 = AppPalette.customFF020617;
  static const customFF020B25 = AppPalette.customFF020B25;
  static const customFF02140A = AppPalette.customFF02140A;
  static const customFF021526 = AppPalette.customFF021526;
  static const customFF021A24 = AppPalette.customFF021A24;
  static const customFF0284C7 = AppPalette.customFF0284C7;
  static const customFF03122F = AppPalette.customFF03122F;
  static const customFF031407 = AppPalette.customFF031407;
  static const customFF031926 = AppPalette.customFF031926;
  static const customFF031A43 = AppPalette.customFF031A43;
  static const customFF0369A1 = AppPalette.customFF0369A1;
  static const customFF0369FF = AppPalette.customFF0369FF;
  static const customFF036EB7 = AppPalette.customFF036EB7;
  static const customFF04122E = AppPalette.customFF04122E;
  static const customFF041C3C = AppPalette.customFF041C3C;
  static const customFF050615 = AppPalette.customFF050615;
  static const customFF051026 = AppPalette.customFF051026;
  static const customFF052E16 = AppPalette.customFF052E16;
  static const customFF0596A1 = AppPalette.customFF0596A1;
  static const customFF06142F = AppPalette.customFF06142F;
  static const customFF06143A = AppPalette.customFF06143A;
  static const customFF061A40 = AppPalette.customFF061A40;
  static const customFF062B66 = AppPalette.customFF062B66;
  static const customFF06B6D4 = AppPalette.customFF06B6D4;
  static const customFF07111F = AppPalette.customFF07111F;
  static const customFF071326 = AppPalette.customFF071326;
  static const customFF071B3B = AppPalette.customFF071B3B;
  static const customFF071B45 = AppPalette.customFF071B45;
  static const customFF0756C8 = AppPalette.customFF0756C8;
  static const customFF075985 = AppPalette.customFF075985;
  static const customFF0759C7 = AppPalette.customFF0759C7;
  static const customFF078BFF = AppPalette.customFF078BFF;
  static const customFF07952E = AppPalette.customFF07952E;
  static const customFF082D68 = AppPalette.customFF082D68;
  static const customFF082F49 = AppPalette.customFF082F49;
  static const customFF090018 = AppPalette.customFF090018;
  static const customFF090302 = AppPalette.customFF090302;
  static const customFF09051F = AppPalette.customFF09051F;
  static const customFF09234F = AppPalette.customFF09234F;
  static const customFF0A192F = AppPalette.customFF0A192F;
  static const customFF0A1E3D = AppPalette.customFF0A1E3D;
  static const customFF0A1F44 = AppPalette.customFF0A1F44;
  static const customFF0A254F = AppPalette.customFF0A254F;
  static const customFF0A2F6B = AppPalette.customFF0A2F6B;
  static const customFF0A3D91 = AppPalette.customFF0A3D91;
  static const customFF0A84FF = AppPalette.customFF0A84FF;
  static const customFF0B0F14 = AppPalette.customFF0B0F14;
  static const customFF0B172A = AppPalette.customFF0B172A;
  static const customFF0B192C = AppPalette.customFF0B192C;
  static const customFF0B2F6B = AppPalette.customFF0B2F6B;
  static const customFF0B3975 = AppPalette.customFF0B3975;
  static const customFF0B4B38 = AppPalette.customFF0B4B38;
  static const customFF0B4F2C = AppPalette.customFF0B4F2C;
  static const customFF0B5FFF = AppPalette.customFF0B5FFF;
  static const customFF0C1C3A = AppPalette.customFF0C1C3A;
  static const customFF0C2247 = AppPalette.customFF0C2247;
  static const customFF0C2B61 = AppPalette.customFF0C2B61;
  static const customFF0C4A6E = AppPalette.customFF0C4A6E;
  static const customFF0D1F41 = AppPalette.customFF0D1F41;
  static const customFF0E3A8C = AppPalette.customFF0E3A8C;
  static const customFF0E7490 = AppPalette.customFF0E7490;
  static const customFF0EA5E9 = AppPalette.customFF0EA5E9;
  static const customFF0EA5FF = AppPalette.customFF0EA5FF;
  static const customFF0F2027 = AppPalette.customFF0F2027;
  static const customFF101010 = AppPalette.customFF101010;
  static const customFF10182E = AppPalette.customFF10182E;
  static const customFF102246 = AppPalette.customFF102246;
  static const customFF102416 = AppPalette.customFF102416;
  static const customFF102A56 = AppPalette.customFF102A56;
  static const customFF11146C = AppPalette.customFF11146C;
  static const customFF111827 = AppPalette.customFF111827;
  static const customFF111936 = AppPalette.customFF111936;
  static const customFF120B35 = AppPalette.customFF120B35;
  static const customFF121423 = AppPalette.customFF121423;
  static const customFF12C878 = AppPalette.customFF12C878;
  static const customFF13243A = AppPalette.customFF13243A;
  static const customFF13264D = AppPalette.customFF13264D;
  static const customFF142233 = AppPalette.customFF142233;
  static const customFF14233B = AppPalette.customFF14233B;
  static const customFF14264C = AppPalette.customFF14264C;
  static const customFF14532D = AppPalette.customFF14532D;
  static const customFF151725 = AppPalette.customFF151725;
  static const customFF160A3A = AppPalette.customFF160A3A;
  static const customFF161D27 = AppPalette.customFF161D27;
  static const customFF1677FF = AppPalette.customFF1677FF;
  static const customFF1684F8 = AppPalette.customFF1684F8;
  static const customFF16885F = AppPalette.customFF16885F;
  static const customFF1689F9 = AppPalette.customFF1689F9;
  static const customFF16A34A = AppPalette.customFF16A34A;
  static const customFF170703 = AppPalette.customFF170703;
  static const customFF172033 = AppPalette.customFF172033;
  static const customFF172A46 = AppPalette.customFF172A46;
  static const customFF1769E8 = AppPalette.customFF1769E8;
  static const customFF17A7E7 = AppPalette.customFF17A7E7;
  static const customFF180733 = AppPalette.customFF180733;
  static const customFF1877F2 = AppPalette.customFF1877F2;
  static const customFF193260 = AppPalette.customFF193260;
  static const customFF1A2B52 = AppPalette.customFF1A2B52;
  static const customFF1A3A6B = AppPalette.customFF1A3A6B;
  static const customFF1A5ED4 = AppPalette.customFF1A5ED4;
  static const customFF1B2446 = AppPalette.customFF1B2446;
  static const customFF1D2939 = AppPalette.customFF1D2939;
  static const customFF1D4ED8 = AppPalette.customFF1D4ED8;
  static const customFF1D7A46 = AppPalette.customFF1D7A46;
  static const customFF1E1B4B = AppPalette.customFF1E1B4B;
  static const customFF1E293B = AppPalette.customFF1E293B;
  static const customFF1E3A8A = AppPalette.customFF1E3A8A;
  static const customFF1E3E62 = AppPalette.customFF1E3E62;
  static const customFF1E5BB8 = AppPalette.customFF1E5BB8;
  static const customFF20183E = AppPalette.customFF20183E;
  static const customFF210814 = AppPalette.customFF210814;
  static const customFF211720 = AppPalette.customFF211720;
  static const customFF22D3EE = AppPalette.customFF22D3EE;
  static const customFF234067 = AppPalette.customFF234067;
  static const customFF24406F = AppPalette.customFF24406F;
  static const customFF24466F = AppPalette.customFF24466F;
  static const customFF246BFE = AppPalette.customFF246BFE;
  static const customFF24A1DE = AppPalette.customFF24A1DE;
  static const customFF250B17 = AppPalette.customFF250B17;
  static const customFF253858 = AppPalette.customFF253858;
  static const customFF2563EB = AppPalette.customFF2563EB;
  static const customFF26111B = AppPalette.customFF26111B;
  static const customFF262839 = AppPalette.customFF262839;
  static const customFF263247 = AppPalette.customFF263247;
  static const customFF290C1A = AppPalette.customFF290C1A;
  static const customFF2C0A1A = AppPalette.customFF2C0A1A;
  static const customFF2C5364 = AppPalette.customFF2C5364;
  static const customFF2D1830 = AppPalette.customFF2D1830;
  static const customFF2E1065 = AppPalette.customFF2E1065;
  static const customFF2F6FED = AppPalette.customFF2F6FED;
  static const customFF312E81 = AppPalette.customFF312E81;
  static const customFF31C65B = AppPalette.customFF31C65B;
  static const customFF320E20 = AppPalette.customFF320E20;
  static const customFF332059 = AppPalette.customFF332059;
  static const customFF334155 = AppPalette.customFF334155;
  static const customFF344054 = AppPalette.customFF344054;
  static const customFF367CF6 = AppPalette.customFF367CF6;
  static const customFF36B9FF = AppPalette.customFF36B9FF;
  static const customFF38BDF8 = AppPalette.customFF38BDF8;
  static const customFF390F24 = AppPalette.customFF390F24;
  static const customFF3B168F = AppPalette.customFF3B168F;
  static const customFF3B82F6 = AppPalette.customFF3B82F6;
  static const customFF3D8BFF = AppPalette.customFF3D8BFF;
  static const customFF421226 = AppPalette.customFF421226;
  static const customFF431407 = AppPalette.customFF431407;
  static const customFF45BD62 = AppPalette.customFF45BD62;
  static const customFF48A7FF = AppPalette.customFF48A7FF;
  static const customFF496080 = AppPalette.customFF496080;
  static const customFF4A148C = AppPalette.customFF4A148C;
  static const customFF4A192E = AppPalette.customFF4A192E;
  static const customFF4ADE80 = AppPalette.customFF4ADE80;
  static const customFF4C1D95 = AppPalette.customFF4C1D95;
  static const customFF5068A0 = AppPalette.customFF5068A0;
  static const customFF52607A = AppPalette.customFF52607A;
  static const customFF581C87 = AppPalette.customFF581C87;
  static const customFF5D6785 = AppPalette.customFF5D6785;
  static const customFF5EB1FF = AppPalette.customFF5EB1FF;
  static const customFF5F6F82 = AppPalette.customFF5F6F82;
  static const customFF60A5FA = AppPalette.customFF60A5FA;
  static const customFF611B35 = AppPalette.customFF611B35;
  static const customFF61A7F5 = AppPalette.customFF61A7F5;
  static const customFF6246D9 = AppPalette.customFF6246D9;
  static const customFF6366F1 = AppPalette.customFF6366F1;
  static const customFF63758E = AppPalette.customFF63758E;
  static const customFF641D37 = AppPalette.customFF641D37;
  static const customFF64748B = AppPalette.customFF64748B;
  static const customFF67E8F9 = AppPalette.customFF67E8F9;
  static const customFF697386 = AppPalette.customFF697386;
  static const customFF6B7280 = AppPalette.customFF6B7280;
  static const customFF70C2FF = AppPalette.customFF70C2FF;
  static const customFF70F2B8 = AppPalette.customFF70F2B8;
  static const customFF718096 = AppPalette.customFF718096;
  static const customFF73A3FF = AppPalette.customFF73A3FF;
  static const customFF750F2B = AppPalette.customFF750F2B;
  static const customFF7536DE = AppPalette.customFF7536DE;
  static const customFF758094 = AppPalette.customFF758094;
  static const customFF7952CC = AppPalette.customFF7952CC;
  static const customFF7B2D8E = AppPalette.customFF7B2D8E;
  static const customFF7B2FF7 = AppPalette.customFF7B2FF7;
  static const customFF7C2D12 = AppPalette.customFF7C2D12;
  static const customFF7C3AED = AppPalette.customFF7C3AED;
  static const customFF7D88A5 = AppPalette.customFF7D88A5;
  static const customFF7DD3FC = AppPalette.customFF7DD3FC;
  static const customFF7DD3FF = AppPalette.customFF7DD3FF;
  static const customFF80C8FF = AppPalette.customFF80C8FF;
  static const customFF818CF8 = AppPalette.customFF818CF8;
  static const customFF831843 = AppPalette.customFF831843;
  static const customFF862B48 = AppPalette.customFF862B48;
  static const customFF880E4F = AppPalette.customFF880E4F;
  static const customFF8A0E68 = AppPalette.customFF8A0E68;
  static const customFF8A2844 = AppPalette.customFF8A2844;
  static const customFF8AB4FF = AppPalette.customFF8AB4FF;
  static const customFF8B5CF6 = AppPalette.customFF8B5CF6;
  static const customFF9333EA = AppPalette.customFF9333EA;
  static const customFF93A1B3 = AppPalette.customFF93A1B3;
  static const customFF943F58 = AppPalette.customFF943F58;
  static const customFF9CCFF8 = AppPalette.customFF9CCFF8;
  static const customFF9D124D = AppPalette.customFF9D124D;
  static const customFF9D174D = AppPalette.customFF9D174D;
  static const customFF9D50DD = AppPalette.customFF9D50DD;
  static const customFFA31250 = AppPalette.customFFA31250;
  static const customFFA66BFF = AppPalette.customFFA66BFF;
  static const customFFA66CFF = AppPalette.customFFA66CFF;
  static const customFFA78BFA = AppPalette.customFFA78BFA;
  static const customFFA855F7 = AppPalette.customFFA855F7;
  static const customFFA8C8F0 = AppPalette.customFFA8C8F0;
  static const customFFAD1457 = AppPalette.customFFAD1457;
  static const customFFAECBF0 = AppPalette.customFFAECBF0;
  static const customFFB4235A = AppPalette.customFFB4235A;
  static const customFFB77900 = AppPalette.customFFB77900;
  static const customFFB87908 = AppPalette.customFFB87908;
  static const customFFB8860B = AppPalette.customFFB8860B;
  static const customFFB8DEFF = AppPalette.customFFB8DEFF;
  static const customFFB8F5D0 = AppPalette.customFFB8F5D0;
  static const customFFB9D8F2 = AppPalette.customFFB9D8F2;
  static const customFFBFDDF0 = AppPalette.customFFBFDDF0;
  static const customFFC084FC = AppPalette.customFFC084FC;
  static const customFFC2185B = AppPalette.customFFC2185B;
  static const customFFC2410C = AppPalette.customFFC2410C;
  static const customFFC4B5FD = AppPalette.customFFC4B5FD;
  static const customFFC53030 = AppPalette.customFFC53030;
  static const customFFC59B27 = AppPalette.customFFC59B27;
  static const customFFC6D9F5 = AppPalette.customFFC6D9F5;
  static const customFFC81D77 = AppPalette.customFFC81D77;
  static const customFFCD201F = AppPalette.customFFCD201F;
  static const customFFCDDDF6 = AppPalette.customFFCDDDF6;
  static const customFFCF4353 = AppPalette.customFFCF4353;
  static const customFFCFE8CC = AppPalette.customFFCFE8CC;
  static const customFFD38115 = AppPalette.customFFD38115;
  static const customFFD5B6FF = AppPalette.customFFD5B6FF;
  static const customFFD6AA27 = AppPalette.customFFD6AA27;
  static const customFFD6ECFF = AppPalette.customFFD6ECFF;
  static const customFFD8B4FE = AppPalette.customFFD8B4FE;
  static const customFFD8E0EC = AppPalette.customFFD8E0EC;
  static const customFFD8E7FF = AppPalette.customFFD8E7FF;
  static const customFFD8E9FF = AppPalette.customFFD8E9FF;
  static const customFFD8ECFF = AppPalette.customFFD8ECFF;
  static const customFFD92232 = AppPalette.customFFD92232;
  static const customFFD946EF = AppPalette.customFFD946EF;
  static const customFFDAEAFF = AppPalette.customFFDAEAFF;
  static const customFFDBE8FA = AppPalette.customFFDBE8FA;
  static const customFFDC253B = AppPalette.customFFDC253B;
  static const customFFDC2626 = AppPalette.customFFDC2626;
  static const customFFDCE6F5 = AppPalette.customFFDCE6F5;
  static const customFFDDE6F2 = AppPalette.customFFDDE6F2;
  static const customFFDDEEFF = AppPalette.customFFDDEEFF;
  static const customFFE0E8F2 = AppPalette.customFFE0E8F2;
  static const customFFE11D48 = AppPalette.customFFE11D48;
  static const customFFE15A2B = AppPalette.customFFE15A2B;
  static const customFFE2E8F0 = AppPalette.customFFE2E8F0;
  static const customFFE2EBFA = AppPalette.customFFE2EBFA;
  static const customFFE3B877 = AppPalette.customFFE3B877;
  static const customFFE4405F = AppPalette.customFFE4405F;
  static const customFFE4D59C = AppPalette.customFFE4D59C;
  static const customFFE5E7EB = AppPalette.customFFE5E7EB;
  static const customFFE5EDF8 = AppPalette.customFFE5EDF8;
  static const customFFE6B857 = AppPalette.customFFE6B857;
  static const customFFE6ECF4 = AppPalette.customFFE6ECF4;
  static const customFFE79700 = AppPalette.customFFE79700;
  static const customFFE83E8C = AppPalette.customFFE83E8C;
  static const customFFE8EAEF = AppPalette.customFFE8EAEF;
  static const customFFE8EEF6 = AppPalette.customFFE8EEF6;
  static const customFFE8EFF9 = AppPalette.customFFE8EFF9;
  static const customFFE8F1FD = AppPalette.customFFE8F1FD;
  static const customFFEA580C = AppPalette.customFFEA580C;
  static const customFFEAF1FB = AppPalette.customFFEAF1FB;
  static const customFFEAF1FF = AppPalette.customFFEAF1FF;
  static const customFFEAF2FF = AppPalette.customFFEAF2FF;
  static const customFFEAF3F6 = AppPalette.customFFEAF3F6;
  static const customFFEAF3FF = AppPalette.customFFEAF3FF;
  static const customFFEAF6FF = AppPalette.customFFEAF6FF;
  static const customFFEC4899 = AppPalette.customFFEC4899;
  static const customFFEDC478 = AppPalette.customFFEDC478;
  static const customFFEDF2F7 = AppPalette.customFFEDF2F7;
  static const customFFEDF4FF = AppPalette.customFFEDF4FF;
  static const customFFEE1D52 = AppPalette.customFFEE1D52;
  static const customFFEEE7DB = AppPalette.customFFEEE7DB;
  static const customFFEEF3F7 = AppPalette.customFFEEF3F7;
  static const customFFEEF4FC = AppPalette.customFFEEF4FC;
  static const customFFEEF4FF = AppPalette.customFFEEF4FF;
  static const customFFEF3D58 = AppPalette.customFFEF3D58;
  static const customFFF06292 = AppPalette.customFFF06292;
  static const customFFF107A3 = AppPalette.customFFF107A3;
  static const customFFF1F5F9 = AppPalette.customFFF1F5F9;
  static const customFFF33E58 = AppPalette.customFFF33E58;
  static const customFFF3425F = AppPalette.customFFF3425F;
  static const customFFF3D36B = AppPalette.customFFF3D36B;
  static const customFFF3F6FA = AppPalette.customFFF3F6FA;
  static const customFFF3F7FD = AppPalette.customFFF3F7FD;
  static const customFFF472B6 = AppPalette.customFFF472B6;
  static const customFFF4F1EC = AppPalette.customFFF4F1EC;
  static const customFFF4F6FA = AppPalette.customFFF4F6FA;
  static const customFFF5533D = AppPalette.customFFF5533D;
  static const customFFF59E0B = AppPalette.customFFF59E0B;
  static const customFFF5E8B7 = AppPalette.customFFF5E8B7;
  static const customFFF5F7FB = AppPalette.customFFF5F7FB;
  static const customFFF5F8FD = AppPalette.customFFF5F8FD;
  static const customFFF5FAFF = AppPalette.customFFF5FAFF;
  static const customFFF7B928 = AppPalette.customFFF7B928;
  static const customFFF7F7F8 = AppPalette.customFFF7F7F8;
  static const customFFF7F9FC = AppPalette.customFFF7F9FC;
  static const customFFF7FAFF = AppPalette.customFFF7FAFF;
  static const customFFF87171 = AppPalette.customFFF87171;
  static const customFFF8BBD0 = AppPalette.customFFF8BBD0;
  static const customFFF8FAFC = AppPalette.customFFF8FAFC;
  static const customFFF953C6 = AppPalette.customFFF953C6;
  static const customFFF97316 = AppPalette.customFFF97316;
  static const customFFFAF8F5 = AppPalette.customFFFAF8F5;
  static const customFFFB7185 = AppPalette.customFFFB7185;
  static const customFFFB7CA5 = AppPalette.customFFFB7CA5;
  static const customFFFB923C = AppPalette.customFFFB923C;
  static const customFFFBBF24 = AppPalette.customFFFBBF24;
  static const customFFFDBA74 = AppPalette.customFFFDBA74;
  static const customFFFED7AA = AppPalette.customFFFED7AA;
  static const customFFFF6098 = AppPalette.customFFFF6098;
  static const customFFFF6B6B = AppPalette.customFFFF6B6B;
  static const customFFFF7A18 = AppPalette.customFFFF7A18;
  static const customFFFF80AB = AppPalette.customFFFF80AB;
  static const customFFFF8A1C = AppPalette.customFFFF8A1C;
  static const customFFFF8DB8 = AppPalette.customFFFF8DB8;
  static const customFFFF94BA = AppPalette.customFFFF94BA;
  static const customFFFF97BC = AppPalette.customFFFF97BC;
  static const customFFFF9DAE = AppPalette.customFFFF9DAE;
  static const customFFFFA726 = AppPalette.customFFFFA726;
  static const customFFFFC83D = AppPalette.customFFFFC83D;
  static const customFFFFC857 = AppPalette.customFFFFC857;
  static const customFFFFD29F = AppPalette.customFFFFD29F;
  static const customFFFFD54F = AppPalette.customFFFFD54F;
  static const customFFFFE17A = AppPalette.customFFFFE17A;
  static const customFFFFEDD5 = AppPalette.customFFFFEDD5;
  static const customFFFFF1B6 = AppPalette.customFFFFF1B6;
  static const customFFFFF1B8 = AppPalette.customFFFFF1B8;
  static const customFFFFF1D6 = AppPalette.customFFFFF1D6;
  static const customFFFFF2DC = AppPalette.customFFFFF2DC;
  static const customFFFFF7ED = AppPalette.customFFFFF7ED;
  static const customFFFFFBEB = AppPalette.customFFFFFBEB;
  static const cyan = AppPalette.cyanSwatch;
  static const dangerToken = AppPalette.danger;
  static const deepOrange = AppPalette.danger;
  static const emerald200Token = AppPalette.emerald200;
  static const emerald300Token = AppPalette.emerald300;
  static const emerald400 = AppPalette.emerald400;
  static const emerald700 = AppPalette.emerald700;
  static const emerald700Token = AppPalette.emerald700;
  static const emerald900 = AppPalette.emerald900;
  static const goldDark = AppPalette.goldDark;
  static const green = AppPalette.successSwatch;
  static const greenAccent = AppPalette.emerald300;
  static const grey = AppPalette.greySwatch;
  static const infoToken = AppPalette.info;
  static const ink900 = AppPalette.ink900;
  static const lightBlue = AppPalette.emerald400;
  static const materialPink = AppPalette.materialPink;
  static const orange = AppPalette.orangeSwatch;
  static const orangeAccent = AppPalette.goldDeep;
  static const pink = AppPalette.pinkSwatch;
  static const primaryAltToken = AppPalette.emerald600;
  static const primaryLightToken = AppPalette.emerald400;
  static const primaryToken = AppPalette.emerald800;
  static const purple = AppPalette.purpleSwatch;
  static const red = AppPalette.dangerSwatch;
  static const redAccent = AppPalette.danger;
  static const successToken = AppPalette.success;
  static const surfaceToken = AppPalette.emerald100;
  static const teal = AppPalette.tealSwatch;
  static const warningToken = AppPalette.warning;
  static const white = AppPalette.white;
  static const white10 = AppPalette.white10;
  static const white12 = AppPalette.white12;
  static const white24 = AppPalette.white24;
  static const white30 = AppPalette.white30;
  static const white38 = AppPalette.white38;
  static const white54 = AppPalette.white54;
  static const white60 = AppPalette.white60;
  static const white70 = AppPalette.white70;
  static const customFF101826 = AppPalette.customFF101826;
  static const customFF252525 = AppPalette.customFF252525;
  static const customFFEEF3F6 = AppPalette.customFFEEF3F6;
  static const custom20FFFFFF = AppPalette.custom20FFFFFF;
  static const customFFC1E1C1 = AppPalette.customFFC1E1C1;
  static const customFFC9CC3F = AppPalette.customFFC9CC3F;
  static const customFF93C572 = AppPalette.customFF93C572;
  static const customFF3CB116 = AppPalette.customFF3CB116;
  static const customFFC026D3 = AppPalette.customFFC026D3;
  static const emeraldShadowSoft = AppPalette.emeraldShadowSoft;
  static const black18 = AppPalette.black18;
}
