import 'package:cnattendance/core/theme/app_palette.dart';
import 'package:cnattendance/theme/theme_colors.dart';
import 'package:flutter/material.dart';

class RemoteThemeMode {
  final String key;
  final String name;
  final String description;
  final String icon;
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;
  final Color backgroundColor;
  final Color cardColor;
  final Color textColor;
  final bool isDark;
  final bool isActive;
  final List<String> allowedRoles;
  final List<Color> gradientColors;
  final bool isSystem;

  const RemoteThemeMode({
    required this.key,
    required this.name,
    required this.description,
    required this.icon,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.backgroundColor,
    required this.cardColor,
    required this.textColor,
    required this.isDark,
    required this.isActive,
    required this.allowedRoles,
    required this.gradientColors,
    required this.isSystem,
  });

  static Color _parseColor(dynamic val, Color fallback) {
    if (val is String && val.trim().isNotEmpty) {
      try {
        return AppPalette.parseOpaqueHex(val.trim());
      } catch (_) {}
    }
    return fallback;
  }

  factory RemoteThemeMode.fromJson(Map<String, dynamic> json) {
    final bg = _parseColor(json['background_color'], const Color(0xFFFFFFFF));
    final prim = _parseColor(json['primary_color'], const Color(0xFF2563EB));
    final sec = _parseColor(json['secondary_color'], const Color(0xFF475569));
    final acc = _parseColor(json['accent_color'], const Color(0xFFF59E0B));
    final card = _parseColor(json['card_color'], const Color(0xFFF8FAFC));
    final txt = _parseColor(json['text_color'], const Color(0xFF0F172A));

    final rawGradients = json['gradient_colors'];
    final List<Color> grads = [];
    if (rawGradients is List && rawGradients.isNotEmpty) {
      for (final g in rawGradients) {
        grads.add(_parseColor(g, prim));
      }
    } else {
      grads.addAll([bg, prim, sec]);
    }

    final rawRoles = json['allowed_roles'];
    final List<String> roles = [];
    if (rawRoles is List) {
      for (final r in rawRoles) {
        if (r != null) roles.add(r.toString());
      }
    }

    final rawKey = (json['key'] ?? '').toString();
    var rawName = (json['name'] ?? '').toString();
    var rawDesc = (json['description'] ?? '').toString();

    if (rawKey == 'light' ||
        rawName.toLowerCase() == 'original mode' ||
        rawName.toLowerCase().contains('original')) {
      rawName = 'Day Mode';
      if (rawDesc.isEmpty || rawDesc.toLowerCase().contains('original') || rawDesc.toLowerCase().contains('electric')) {
        rawDesc = 'Crisp light with royal blue';
      }
    } else if (rawKey == 'dark' ||
        rawName.toLowerCase() == 'dark mode') {
      rawName = 'Night Mode';
      if (rawDesc.isEmpty ||
          rawDesc.toLowerCase().contains('original') ||
          rawDesc.toLowerCase().contains('dark')) {
        rawDesc = 'Sleek night mode';
      }
    }

    return RemoteThemeMode(
      key: rawKey,
      name: rawName,
      description: rawDesc,
      icon: (json['icon'] ?? 'palette').toString(),
      primaryColor: prim,
      secondaryColor: sec,
      accentColor: acc,
      backgroundColor: bg,
      cardColor: card,
      textColor: txt,
      isDark: json['is_dark'] == true || json['is_dark'] == 1 || json['is_dark'] == '1',
      isActive: json['is_active'] != false && json['is_active'] != 0 && json['is_active'] != '0',
      allowedRoles: roles,
      gradientColors: grads,
      isSystem: json['is_system'] == true || json['is_system'] == 1,
    );
  }

  RemoteThemeMode copyWith({
    String? key,
    String? name,
    String? description,
    String? icon,
    Color? primaryColor,
    Color? secondaryColor,
    Color? accentColor,
    Color? backgroundColor,
    Color? cardColor,
    Color? textColor,
    bool? isDark,
    bool? isActive,
    List<String>? allowedRoles,
    List<Color>? gradientColors,
    bool? isSystem,
  }) =>
      RemoteThemeMode(
        key: key ?? this.key,
        name: name ?? this.name,
        description: description ?? this.description,
        icon: icon ?? this.icon,
        primaryColor: primaryColor ?? this.primaryColor,
        secondaryColor: secondaryColor ?? this.secondaryColor,
        accentColor: accentColor ?? this.accentColor,
        backgroundColor: backgroundColor ?? this.backgroundColor,
        cardColor: cardColor ?? this.cardColor,
        textColor: textColor ?? this.textColor,
        isDark: isDark ?? this.isDark,
        isActive: isActive ?? this.isActive,
        allowedRoles: allowedRoles ?? this.allowedRoles,
        gradientColors: gradientColors ?? this.gradientColors,
        isSystem: isSystem ?? this.isSystem,
      );

  Map<String, dynamic> toJson() => {
        'key': key,
        'name': name,
        'description': description,
        'icon': icon,
        'primary_color': AppPalette.hexPrefix +
            (primaryColor.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0'),
        'secondary_color': AppPalette.hexPrefix +
            (secondaryColor.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0'),
        'accent_color': AppPalette.hexPrefix +
            (accentColor.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0'),
        'background_color': AppPalette.hexPrefix +
            (backgroundColor.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0'),
        'card_color': AppPalette.hexPrefix +
            (cardColor.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0'),
        'text_color': AppPalette.hexPrefix +
            (textColor.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0'),
        'is_dark': isDark,
        'is_active': isActive,
        'allowed_roles': allowedRoles,
        'gradient_colors': gradientColors
            .map((c) =>
                AppPalette.hexPrefix +
                (c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0'))
            .toList(),
        'is_system': isSystem,
      };

  ThemeColors toThemeColors() => ThemeColors(
        primaryColor: primaryColor,
        secondaryColor: secondaryColor,
        accentColor: accentColor,
        backgroundColor: backgroundColor,
        cardColor: cardColor,
        textColor: textColor,
        isDark: isDark,
        gradientColors: gradientColors,
      );
}
