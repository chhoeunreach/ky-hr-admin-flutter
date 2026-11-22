import 'package:cnattendance/model/remote_theme_mode.dart';
import 'package:cnattendance/theme/app_theme_mode.dart';
import 'package:cnattendance/theme/theme_layout.dart';
import 'package:cnattendance/theme/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RemoteThemeMode and ThemeProvider role filtering', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('RemoteThemeMode parses JSON and produces ThemeColors', () {
      final json = {
        'key': 'royal_blue_gold',
        'name': 'Royal Blue & Gold Luxury',
        'description': 'Luxury Angkorean palette',
        'icon': 'crown',
        'primary_color': '#0756C8',
        'secondary_color': '#082D68',
        'accent_color': '#FFC857',
        'background_color': '#061A40',
        'card_color': '#0B3975',
        'text_color': '#FFFFFF',
        'is_dark': true,
        'is_active': true,
        'allowed_roles': ['admin', 'manager'],
        'gradient_colors': ['#061A40', '#0756C8', '#082D68'],
        'is_system': true,
      };

      final mode = RemoteThemeMode.fromJson(json);
      expect(mode.key, equals('royal_blue_gold'));
      expect(mode.name, equals('Royal Blue & Gold Luxury'));
      expect(mode.primaryColor, equals(const Color(0xFF0756C8)));
      expect(mode.accentColor, equals(const Color(0xFFFFC857)));
      expect(mode.backgroundColor, equals(const Color(0xFF061A40)));
      expect(mode.allowedRoles, contains('manager'));

      final themeColors = mode.toThemeColors();
      expect(themeColors.primaryColor, equals(const Color(0xFF0756C8)));
      expect(themeColors.accentColor, equals(const Color(0xFFFFC857)));
      expect(themeColors.isDark, isTrue);
    });

    test('ThemeProvider availableModes filters inactive themes and respects remote permissions', () async {
      final provider = ThemeProvider();
      await provider.load();

      // Initially with no remote modes loaded, availableModes contains all AppThemeMode values
      expect(provider.availableModes.length, equals(AppThemeMode.values.length));

      // Simulate receiving remote theme modes where only royal_blue_gold and light are active
      final remoteModes = [
        const RemoteThemeMode(
          key: 'royal_blue_gold',
          name: 'Royal Blue & Gold',
          description: '',
          icon: 'palette',
          primaryColor: Color(0xFF0756C8),
          secondaryColor: Color(0xFF082D68),
          accentColor: Color(0xFFFFC857),
          backgroundColor: Color(0xFF061A40),
          cardColor: Color(0xFF0B3975),
          textColor: Color(0xFFFFFFFF),
          isDark: true,
          isActive: true,
          allowedRoles: [],
          gradientColors: [],
          isSystem: true,
        ),
        const RemoteThemeMode(
          key: 'light',
          name: 'Original Mode',
          description: '',
          icon: 'palette',
          primaryColor: Color(0xFF0B5FFF),
          secondaryColor: Color(0xFF0A1F44),
          accentColor: Color(0xFF0284C7),
          backgroundColor: Color(0xFFF5F7FB),
          cardColor: Color(0xFFFFFFFF),
          textColor: Color(0xFF0F172A),
          isDark: false,
          isActive: true,
          allowedRoles: [],
          gradientColors: [],
          isSystem: true,
        ),
        const RemoteThemeMode(
          key: 'forest_green',
          name: 'Forest Green',
          description: '',
          icon: 'forest',
          primaryColor: Color(0xFF16A34A),
          secondaryColor: Color(0xFF14532D),
          accentColor: Color(0xFF4ADE80),
          backgroundColor: Color(0xFF052E16),
          cardColor: Color(0xFF064E3B),
          textColor: Color(0xFFFFFFFF),
          isDark: true,
          isActive: false, // Inactive / hidden by admin
          allowedRoles: [],
          gradientColors: [],
          isSystem: true,
        ),
      ];

      await provider.applyRemoteThemeModes(remoteModes);

      expect(provider.availableModes, contains(AppThemeMode.royalBlueGold));
      expect(provider.availableModes, contains(AppThemeMode.light));
      expect(provider.availableModes, isNot(contains(AppThemeMode.forestGreen)));
      expect(provider.availableModes, isNot(contains(AppThemeMode.sunset)));
    });

    test('ThemeProvider switches to available mode when current mode is hidden by admin', () async {
      final provider = ThemeProvider();
      await provider.load();
      await provider.setMode(AppThemeMode.forestGreen);
      expect(provider.mode, equals(AppThemeMode.forestGreen));

      // Admin hides forest_green, leaving only royal_blue_gold
      final remoteModes = [
        const RemoteThemeMode(
          key: 'royal_blue_gold',
          name: 'Royal Blue & Gold',
          description: '',
          icon: 'palette',
          primaryColor: Color(0xFF0756C8),
          secondaryColor: Color(0xFF082D68),
          accentColor: Color(0xFFFFC857),
          backgroundColor: Color(0xFF061A40),
          cardColor: Color(0xFF0B3975),
          textColor: Color(0xFFFFFFFF),
          isDark: true,
          isActive: true,
          allowedRoles: [],
          gradientColors: [],
          isSystem: true,
        ),
      ];

      await provider.applyRemoteThemeModes(remoteModes);

      // Automatically switched to available mode
      expect(provider.mode, equals(AppThemeMode.royalBlueGold));
    });

    test('Custom dynamic theme appears in availableThemeOptions and can be selected', () async {
      final provider = ThemeProvider();
      await provider.load();

      final remoteModes = [
        const RemoteThemeMode(
          key: 'royal_blue_gold',
          name: 'Royal Blue & Gold',
          description: 'Angkor Wat Luxury',
          icon: 'account_balance',
          primaryColor: Color(0xFF0756C8),
          secondaryColor: Color(0xFF082D68),
          accentColor: Color(0xFFFFC857),
          backgroundColor: Color(0xFF061A40),
          cardColor: Color(0xFF0B3975),
          textColor: Color(0xFFFFFFFF),
          isDark: true,
          isActive: true,
          allowedRoles: [],
          gradientColors: [],
          isSystem: true,
        ),
        const RemoteThemeMode(
          key: 'sunset_orange',
          name: 'Sunset Orange',
          description: 'Warm evening theme',
          icon: 'wb_sunny',
          primaryColor: Color(0xFFEA580C),
          secondaryColor: Color(0xFF9A3412),
          accentColor: Color(0xFFFDBA74),
          backgroundColor: Color(0xFFFFF7ED),
          cardColor: Color(0xFFFFEDD5),
          textColor: Color(0xFF431407),
          isDark: false,
          isActive: true,
          allowedRoles: [],
          gradientColors: [Color(0xFFEA580C), Color(0xFFFDBA74)],
          isSystem: false, // Custom admin-added theme!
        ),
      ];

      await provider.applyRemoteThemeModes(remoteModes);

      // Verify custom theme is exposed in availableThemeOptions
      expect(provider.availableThemeOptions.length, equals(2));
      final customOption = provider.availableThemeOptions
          .firstWhere((opt) => opt.id == 'sunset_orange');
      expect(customOption.name, equals('Sunset Orange'));
      expect(customOption.isSystem, isFalse);
      expect(customOption.isCoreSystem, isFalse);
      expect(customOption.coreMode, isNull);

      // Select custom theme
      await provider.setThemeById('sunset_orange');
      expect(provider.currentThemeId, equals('sunset_orange'));
      expect(provider.colors.primaryColor, equals(const Color(0xFFEA580C)));
      expect(provider.colors.secondaryColor, equals(const Color(0xFF9A3412)));
      expect(provider.colors.accentColor, equals(const Color(0xFFFDBA74)));
      expect(provider.colors.backgroundColor, equals(const Color(0xFFFFF7ED)));
      expect(provider.colors.cardColor, equals(const Color(0xFFFFEDD5)));
      expect(provider.colors.textColor, equals(const Color(0xFF431407)));

      // ThemeData reflects custom colors
      expect(provider.themeData.colorScheme.primary, equals(const Color(0xFFEA580C)));
      expect(provider.themeData.scaffoldBackgroundColor, equals(const Color(0xFFFFF7ED)));
    });

    test('Custom layout can be saved and retrieved for custom theme id', () async {
      final provider = ThemeProvider();
      await provider.load();

      final customLayout = const ThemeLayout.defaults().setColors(
        primary: const Color(0xFF10B981),
        accent: const Color(0xFF34D399),
      );

      final success = await provider.saveLayoutForId('custom_green', customLayout);
      expect(success, isTrue);

      final loadedLayout = provider.layoutForId('custom_green');
      expect(loadedLayout.primary, equals(const Color(0xFF10B981)));
      expect(loadedLayout.accent, equals(const Color(0xFF34D399)));
    });

    test('Gracefully falls back to Royal Blue & Gold when selected custom theme is deleted by admin', () async {
      final provider = ThemeProvider();
      await provider.load();

      // Initially active with royal_blue_gold and custom_summer
      final initialModes = [
        const RemoteThemeMode(
          key: 'royal_blue_gold',
          name: 'Royal Blue & Gold',
          description: '',
          icon: 'palette',
          primaryColor: Color(0xFF0756C8),
          secondaryColor: Color(0xFF082D68),
          accentColor: Color(0xFFFFC857),
          backgroundColor: Color(0xFF061A40),
          cardColor: Color(0xFF0B3975),
          textColor: Color(0xFFFFFFFF),
          isDark: true,
          isActive: true,
          allowedRoles: [],
          gradientColors: [],
          isSystem: true,
        ),
        const RemoteThemeMode(
          key: 'custom_summer',
          name: 'Summer Splash',
          description: '',
          icon: 'palette',
          primaryColor: Color(0xFF06B6D4),
          secondaryColor: Color(0xFF0891B2),
          accentColor: Color(0xFF67E8F9),
          backgroundColor: Color(0xFFECFEFF),
          cardColor: Color(0xFFCFFAFE),
          textColor: Color(0xFF164E63),
          isDark: false,
          isActive: true,
          allowedRoles: [],
          gradientColors: [],
          isSystem: false,
        ),
      ];

      await provider.applyRemoteThemeModes(initialModes);
      await provider.setThemeById('custom_summer');
      expect(provider.currentThemeId, equals('custom_summer'));

      // Admin deletes custom_summer, leaving only royal_blue_gold
      final updatedModes = [
        const RemoteThemeMode(
          key: 'royal_blue_gold',
          name: 'Royal Blue & Gold',
          description: '',
          icon: 'palette',
          primaryColor: Color(0xFF0756C8),
          secondaryColor: Color(0xFF082D68),
          accentColor: Color(0xFFFFC857),
          backgroundColor: Color(0xFF061A40),
          cardColor: Color(0xFF0B3975),
          textColor: Color(0xFFFFFFFF),
          isDark: true,
          isActive: true,
          allowedRoles: [],
          gradientColors: [],
          isSystem: true,
        ),
      ];

      await provider.applyRemoteThemeModes(updatedModes);

      // Verify automatic fallback to Royal Blue & Gold
      expect(provider.currentThemeId, equals(AppThemeMode.royalBlueGold.id));
      expect(provider.mode, equals(AppThemeMode.royalBlueGold));
    });
  });
}
