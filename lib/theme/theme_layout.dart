import 'dart:convert';

import 'package:cnattendance/theme/app_theme_mode.dart';
import 'package:cnattendance/theme/theme_colors.dart';
import 'package:flutter/material.dart';

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
  repair(LayoutArea.tabs, 'Repair List'),
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
  repairShortcut(LayoutArea.shortcuts, 'Repair List', enabledByDefault: false),
  chatShortcut(LayoutArea.shortcuts, 'Chat',
      permission: 'chat', enabledByDefault: false),
  socialShortcut(LayoutArea.shortcuts, 'Social Feed',
      permission: 'social-feed', enabledByDefault: false),
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

  bool allowed(Map<String, String> features) =>
      permission == null || features[permission] == '1';
}

class ThemeLayout {
  const ThemeLayout.defaults()
      : _order = const {},
        _visibility = const {},
        background = null,
        accent = null,
        menuOnRight = false,
        _splitBanner = null,
        showMenuButton = true;

  ThemeLayout._({
    required Map<LayoutArea, List<LayoutItem>> order,
    required Map<LayoutItem, bool> visibility,
    required this.background,
    required this.accent,
    required this.menuOnRight,
    required this.showMenuButton,
    required bool? splitBanner,
  })  : _order = order,
        _visibility = visibility,
        _splitBanner = splitBanner;

  final Map<LayoutArea, List<LayoutItem>> _order;
  final Map<LayoutItem, bool> _visibility;
  final Color? background;
  final Color? accent;
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

  ThemeLayout setColors({required Color? background, required Color? accent}) =>
      ThemeLayout._(
        order: _order,
        visibility: _visibility,
        background: background,
        accent: accent,
        menuOnRight: menuOnRight,
        showMenuButton: showMenuButton,
        splitBanner: _splitBanner,
      );

  ThemeLayout _copy({
    Map<LayoutArea, List<LayoutItem>>? order,
    Map<LayoutItem, bool>? visibility,
    bool? menuOnRight,
    bool? showMenuButton,
    bool? splitBanner,
  }) =>
      ThemeLayout._(
        order: order ?? _order,
        visibility: visibility ?? _visibility,
        background: background,
        accent: accent,
        menuOnRight: menuOnRight ?? this.menuOnRight,
        showMenuButton: showMenuButton ?? this.showMenuButton,
        splitBanner: splitBanner ?? _splitBanner,
      );

  ThemeColors colorsFor(ThemeColors base) {
    if (background == null && accent == null) return base;
    final surface = background;
    final dark = surface == null
        ? base.isDark
        : ThemeData.estimateBrightnessForColor(surface) == Brightness.dark;
    return ThemeColors(
      primaryColor: accent ?? base.primaryColor,
      secondaryColor: surface ?? base.secondaryColor,
      accentColor: accent ?? base.accentColor,
      backgroundColor: surface ?? base.backgroundColor,
      cardColor: surface == null
          ? base.cardColor
          : Color.lerp(surface, dark ? Colors.white : Colors.black, .09)!,
      textColor: surface == null
          ? base.textColor
          : dark
              ? Colors.white
              : const Color(0xff211720),
      isDark: dark,
      gradientColors: surface == null
          ? base.gradientColors
          : [
              Color.lerp(surface, accent ?? base.accentColor, .18)!,
              surface,
              Color.lerp(surface, base.backgroundColor, .38)!,
            ],
    );
  }

  String encode() => jsonEncode({
        'order': _order.map((area, entries) =>
            MapEntry(area.name, entries.map((item) => item.name).toList())),
        'visibility':
            _visibility.map((item, visible) => MapEntry(item.name, visible)),
        'background': background?.toARGB32(),
        'accent': accent?.toARGB32(),
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
    Color? color(Object? value) =>
        value is int && value >= 0xff000000 && value <= 0xffffffff
            ? Color(value)
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
      background: color(data['background']),
      accent: color(data['accent']),
      menuOnRight: data['menuOnRight'] == true,
      showMenuButton: data['showMenuButton'] != false,
      splitBanner:
          data['splitBanner'] is bool ? data['splitBanner'] as bool : null,
    );
  }
}
