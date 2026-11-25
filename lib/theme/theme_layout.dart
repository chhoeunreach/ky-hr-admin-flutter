import 'dart:convert';

import 'package:cnattendance/theme/app_theme_mode.dart';
import 'package:cnattendance/theme/theme_colors.dart';
import 'package:flutter/material.dart';
import 'package:cnattendance/core/theme/app_colors.dart';
import 'package:cnattendance/core/theme/app_palette.dart';

enum LayoutArea {
  home('Home sections'),
  tabs('Navigation menu'),
  shortcuts('Quick services');

  const LayoutArea(this.label);
  final String label;
}

enum LayoutItem {
  profile(LayoutArea.home, 'Profile header'),
  banner(LayoutArea.home, 'Banner'),
  quote(LayoutArea.home, 'Quote card', separateBannerOnly: true),
  clock(LayoutArea.home, 'Clock and week', separateBannerOnly: true),
  summary(LayoutArea.home, 'Attendance summary and bonus'),
  stories(LayoutArea.home, 'Stories and Highlights'),
  scanner(LayoutArea.home, 'Attendance scanner'),
  workingTime(LayoutArea.home, 'Working time'),
  attendanceZone(LayoutArea.home, 'Attendance map'),
  quickServices(LayoutArea.home, 'Quick services'),
  weeklyReport(LayoutArea.home, 'Weekly report'),
  team(LayoutArea.home, 'My team'),
  home(LayoutArea.tabs, 'Home', pinned: true),
  social(LayoutArea.tabs, 'Social Feed', permission: 'social-feed'),
  repair(LayoutArea.tabs, 'Repair List', permission: 'repair'),
  leave(LayoutArea.tabs, 'Leave', permission: 'leave-request'),
  attendance(LayoutArea.tabs, 'Attendance', permission: 'attendance'),
  more(LayoutArea.tabs, 'More', pinned: true),
  present(LayoutArea.shortcuts, 'Attendance', permission: 'attendance'),
  holiday(LayoutArea.shortcuts, 'Holidays', permission: 'holiday'),
  leaveRequest(LayoutArea.shortcuts, 'Leave', permission: 'leave-request'),
  events(LayoutArea.shortcuts, 'Events', permission: 'event'),
  projects(LayoutArea.shortcuts, 'Projects', permission: 'project-management'),
  tasks(LayoutArea.shortcuts, 'Tasks', permission: 'project-management'),
  awards(LayoutArea.shortcuts, 'Awards', permission: 'award'),
  training(LayoutArea.shortcuts, 'Training', permission: 'training'),
  socialPost(LayoutArea.shortcuts, 'Social Post', permission: 'social-rewards'),
  chatShortcut(LayoutArea.shortcuts, 'Chat',
      permission: 'chat', enabledByDefault: false),
  socialShortcut(LayoutArea.shortcuts, 'Social Feed',
      permission: 'social-feed', enabledByDefault: false),
  repairShortcut(LayoutArea.shortcuts, 'Repair List', permission: 'repair'),
  highlightsShortcut(LayoutArea.shortcuts, 'Highlights',
      enabledByDefault: false);

  const LayoutItem(
    this.area,
    this.label, {
    this.pinned = false,
    this.enabledByDefault = true,
    this.separateBannerOnly = false,
    this.permission,
  });

  final LayoutArea area;
  final String label;
  final bool pinned;
  final bool enabledByDefault;
  final bool separateBannerOnly;
  final String? permission;

  bool allowed(Map<String, String> features) {
    if (permission == null) return true;
    if (features.containsKey(permission)) {
      return features[permission] == '1';
    }
    return enabledByDefault;
  }
}

class ThemeLayout {
  const ThemeLayout.defaults()
      : _order = const {},
        _visibility = const {},
        primary = null,
        secondary = null,
        accent = null,
        background = null,
        card = null,
        text = null,
        menuOnRight = false,
        _splitBanner = null,
        showMenuButton = true;

  ThemeLayout._({
    required Map<LayoutArea, List<LayoutItem>> order,
    required Map<LayoutItem, bool> visibility,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.background,
    required this.card,
    required this.text,
    required this.menuOnRight,
    required this.showMenuButton,
    required bool? splitBanner,
  })  : _order = order,
        _visibility = visibility,
        _splitBanner = splitBanner;

  final Map<LayoutArea, List<LayoutItem>> _order;
  final Map<LayoutItem, bool> _visibility;
  final Color? primary;
  final Color? secondary;
  final Color? accent;
  final Color? background;
  final Color? card;
  final Color? text;
  final bool menuOnRight;
  final bool showMenuButton;
  final bool? _splitBanner;

  List<LayoutItem> items(LayoutArea area) => [
        ...{
          ...?_order[area],
          ...LayoutItem.values.where((item) => item.area == area),
        },
      ];

  bool shows(LayoutItem item) =>
      item.pinned || (_visibility[item] ?? item.enabledByDefault);

  List<LayoutItem> visible(LayoutArea area) =>
      items(area).where(shows).toList();

  List<int> visibleTabIndices(List<LayoutItem> available) =>
      visible(LayoutArea.tabs)
          .map(available.indexOf)
          .where((index) => index >= 0)
          .toList();

  ThemeLayout reorder(LayoutArea area, LayoutItem item, LayoutItem target) {
    final ordered = items(area);
    final destination = ordered.indexOf(target);
    if (destination < 0 || !ordered.remove(item)) return this;
    ordered.insert(destination, item);
    return _copy(order: {..._order, area: ordered});
  }

  ThemeLayout setVisible(LayoutItem item, bool visible) =>
      item.pinned ? this : _copy(visibility: {..._visibility, item: visible});

  ThemeLayout setMenuOnRight(bool value) => _copy(menuOnRight: value);

  ThemeLayout setShowMenuButton(bool value) => _copy(showMenuButton: value);

  bool separatesBanner(AppThemeMode mode) =>
      mode != AppThemeMode.royalBlueDay &&
      mode != AppThemeMode.royalBlueGoldKhmerDay &&
      (mode == AppThemeMode.royalBlueGold ||
          (_splitBanner ?? mode == AppThemeMode.khmerHeritage));

  ThemeLayout setSeparateBanner(bool value) => _copy(splitBanner: value);

  ThemeLayout setColors({
    Color? primary,
    Color? secondary,
    Color? accent,
    Color? background,
    Color? card,
    Color? text,
  }) =>
      ThemeLayout._(
        order: _order,
        visibility: _visibility,
        primary: primary,
        secondary: secondary,
        accent: accent,
        background: background,
        card: card,
        text: text,
        menuOnRight: menuOnRight,
        showMenuButton: showMenuButton,
        splitBanner: _splitBanner,
      );

  ThemeLayout _copy({
    Map<LayoutArea, List<LayoutItem>>? order,
    Map<LayoutItem, bool>? visibility,
    Color? primary,
    Color? secondary,
    Color? accent,
    Color? background,
    Color? card,
    Color? text,
    bool? menuOnRight,
    bool? showMenuButton,
    bool? splitBanner,
  }) =>
      ThemeLayout._(
        order: order ?? _order,
        visibility: visibility ?? _visibility,
        primary: primary ?? this.primary,
        secondary: secondary ?? this.secondary,
        accent: accent ?? this.accent,
        background: background ?? this.background,
        card: card ?? this.card,
        text: text ?? this.text,
        menuOnRight: menuOnRight ?? this.menuOnRight,
        showMenuButton: showMenuButton ?? this.showMenuButton,
        splitBanner: splitBanner ?? _splitBanner,
      );

  ThemeColors colorsFor(ThemeColors base) {
    if (primary == null &&
        secondary == null &&
        accent == null &&
        background == null &&
        card == null &&
        text == null) {
      return base;
    }
    final surface = background;
    final dark = surface == null
        ? base.isDark
        : ThemeData.estimateBrightnessForColor(surface) == Brightness.dark;
    final effBackground = background ?? base.backgroundColor;
    final effAccent = accent ?? base.accentColor;
    final effPrimary = primary ?? (accent ?? base.primaryColor);
    final effSecondary = secondary ?? (surface ?? base.secondaryColor);
    final effCard = card ??
        (surface == null
            ? base.cardColor
            : Color.lerp(surface, dark ? AppColors.white : AppColors.black, .09)!);
    final effText = text ??
        (surface == null
            ? base.textColor
            : dark
                ? AppColors.white
                : AppColors.customFF211720);

    return ThemeColors(
      primaryColor: effPrimary,
      secondaryColor: effSecondary,
      accentColor: effAccent,
      backgroundColor: effBackground,
      cardColor: effCard,
      textColor: effText,
      isDark: dark,
      gradientColors: surface == null && primary == null && secondary == null
          ? base.gradientColors
          : [
              Color.lerp(effBackground, effAccent, .18)!,
              effBackground,
              Color.lerp(effBackground, base.backgroundColor, .38)!,
            ],
    );
  }

  String encode() => jsonEncode({
        'order': _order.map((area, entries) =>
            MapEntry(area.name, entries.map((item) => item.name).toList())),
        'visibility':
            _visibility.map((item, visible) => MapEntry(item.name, visible)),
        'primary': primary?.toARGB32(),
        'secondary': secondary?.toARGB32(),
        'accent': accent?.toARGB32(),
        'background': background?.toARGB32(),
        'card': card?.toARGB32(),
        'text': text?.toARGB32(),
        'menuOnRight': menuOnRight,
        'showMenuButton': showMenuButton,
        'splitBanner': _splitBanner,
      });

  factory ThemeLayout.decode(String? value) {
    if (value == null) return const ThemeLayout.defaults();
    final Object? data;
    try {
      data = jsonDecode(value);
    } on FormatException {
      return const ThemeLayout.defaults();
    }
    if (data is! Map) return const ThemeLayout.defaults();
    final order = data['order'];
    final visibility = data['visibility'];
    Color? color(Object? value) => value is int && AppPalette.isArgbValue(value)
        ? AppPalette.fromArgb(value)
        : null;
    final itemNames = {for (final item in LayoutItem.values) item.name: item};
    return ThemeLayout._(
      order: {
        if (order is Map)
          for (final area in LayoutArea.values)
            if (order[area.name] case final List entries)
              area: [
                for (final entry in entries)
                  if (itemNames[entry] case final LayoutItem item
                      when item.area == area)
                    item,
              ],
      },
      visibility: {
        if (visibility is Map)
          for (final item in LayoutItem.values)
            if (visibility[item.name] case final bool visible) item: visible,
      },
      primary: color(data['primary']),
      secondary: color(data['secondary']),
      accent: color(data['accent']),
      background: color(data['background']),
      card: color(data['card']),
      text: color(data['text']),
      menuOnRight: data['menuOnRight'] == true,
      showMenuButton: data['showMenuButton'] != false,
      splitBanner:
          data['splitBanner'] is bool ? data['splitBanner'] as bool : null,
    );
  }
}
