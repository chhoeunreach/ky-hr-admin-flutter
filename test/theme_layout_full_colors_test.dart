import 'package:cnattendance/theme/app_theme_data.dart';
import 'package:cnattendance/theme/app_theme_mode.dart';
import 'package:cnattendance/theme/theme_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ThemeLayout full color customization', () {
    test('defaults have null for all custom colors', () {
      const layout = ThemeLayout.defaults();
      expect(layout.primary, isNull);
      expect(layout.secondary, isNull);
      expect(layout.accent, isNull);
      expect(layout.background, isNull);
      expect(layout.card, isNull);
      expect(layout.text, isNull);
    });

    test('colorsFor returns base colors when no overrides are set', () {
      const layout = ThemeLayout.defaults();
      final base = AppThemeData.info(AppThemeMode.royalBlueGold).colors;
      final result = layout.colorsFor(base);

      expect(result.primaryColor, equals(base.primaryColor));
      expect(result.secondaryColor, equals(base.secondaryColor));
      expect(result.accentColor, equals(base.accentColor));
      expect(result.backgroundColor, equals(base.backgroundColor));
      expect(result.cardColor, equals(base.cardColor));
      expect(result.textColor, equals(base.textColor));
    });

    test('setColors overrides all 6 colors and serializes to JSON', () {
      const layout = ThemeLayout.defaults();
      final custom = layout.setColors(
        primary: const Color(0xFF112233),
        secondary: const Color(0xFF223344),
        accent: const Color(0xFF334455),
        background: const Color(0xFF445566),
        card: const Color(0xFF556677),
        text: const Color(0xFF667788),
      );

      expect(custom.primary, equals(const Color(0xFF112233)));
      expect(custom.secondary, equals(const Color(0xFF223344)));
      expect(custom.accent, equals(const Color(0xFF334455)));
      expect(custom.background, equals(const Color(0xFF445566)));
      expect(custom.card, equals(const Color(0xFF556677)));
      expect(custom.text, equals(const Color(0xFF667788)));

      final base = AppThemeData.info(AppThemeMode.royalBlueGold).colors;
      final resolved = custom.colorsFor(base);

      expect(resolved.primaryColor, equals(const Color(0xFF112233)));
      expect(resolved.secondaryColor, equals(const Color(0xFF223344)));
      expect(resolved.accentColor, equals(const Color(0xFF334455)));
      expect(resolved.backgroundColor, equals(const Color(0xFF445566)));
      expect(resolved.cardColor, equals(const Color(0xFF556677)));
      expect(resolved.textColor, equals(const Color(0xFF667788)));

      final encoded = custom.encode();
      final decoded = ThemeLayout.decode(encoded);

      expect(decoded.primary, equals(const Color(0xFF112233)));
      expect(decoded.secondary, equals(const Color(0xFF223344)));
      expect(decoded.accent, equals(const Color(0xFF334455)));
      expect(decoded.background, equals(const Color(0xFF445566)));
      expect(decoded.card, equals(const Color(0xFF556677)));
      expect(decoded.text, equals(const Color(0xFF667788)));
    });

    test('decode handles backwards compatibility with legacy layout json', () {
      const legacyJson = '{"background":4282664004,"accent":4294953047}';
      final decoded = ThemeLayout.decode(legacyJson);

      expect(decoded.background, isNotNull);
      expect(decoded.accent, isNotNull);
      expect(decoded.primary, isNull);
      expect(decoded.secondary, isNull);
      expect(decoded.card, isNull);
      expect(decoded.text, isNull);
    });
  });
}
