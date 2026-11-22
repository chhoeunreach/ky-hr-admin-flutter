import 'dart:convert';

import 'package:cnattendance/model/app_appearance_config.dart';
import 'package:cnattendance/theme/theme_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppAppearanceConfig', () {
    test('falls back to safe defaults on an empty payload', () {
      final config = AppAppearanceConfig.fromJson(const {});

      expect(config.backgroundType, AppAppearanceConfig.backgroundNone);
      expect(config.hasCustomBackground, isFalse);
      expect(config.heat, isFalse);
      expect(config.snow, isFalse);
      expect(config.floatingHearts, isTrue);
      expect(config.heartGlow, isTrue);
      expect(config.sparkleEffects, isTrue);
      expect(config.emojiEffect, isFalse);
      expect(config.emojiChar, '✨');
    });

    test('parses admin payload and round-trips through json', () {
      final config = AppAppearanceConfig.fromJson(const {
        'background_type': 'svg',
        'background_url': 'https://hr.example/storage/bg.svg',
        'heat': true,
        'snow': '1',
        'floating_hearts': false,
        'rose_petals': true,
        'heart_glow': false,
        'sparkle_effects': true,
        'emoji_effect': true,
        'emoji_char': '🎄',
      });

      expect(config.backgroundType, AppAppearanceConfig.backgroundSvg);
      expect(config.isSvgBackground, isTrue);
      expect(config.hasCustomBackground, isTrue);
      expect(config.heat, isTrue);
      expect(config.snow, isTrue);
      expect(config.floatingHearts, isFalse);
      expect(config.rosePetals, isTrue);
      expect(config.heartGlow, isFalse);
      expect(config.emojiEffect, isTrue);
      expect(config.emojiChar, '🎄');
      expect(config.effectEnabled('heat'), isTrue);
      expect(config.effectEnabled('unknown'), isFalse);

      final restored = AppAppearanceConfig.fromJson(config.toJson());
      expect(restored.backgroundUrl, config.backgroundUrl);
      expect(restored.snow, isTrue);
      expect(restored.floatingHearts, isFalse);
      expect(restored.emojiChar, '🎄');
    });

    test('treats a missing url or type none as no custom background', () {
      final withoutUrl = AppAppearanceConfig.fromJson(const {
        'background_type': 'image',
        'background_url': '  ',
      });
      expect(withoutUrl.hasCustomBackground, isFalse);

      final typeNone = AppAppearanceConfig.fromJson(const {
        'background_type': 'none',
        'background_url': 'https://hr.example/storage/bg.jpg',
      });
      expect(typeNone.hasCustomBackground, isFalse);

      final badType = AppAppearanceConfig.fromJson(const {
        'background_type': 'video',
        'background_url': 'https://hr.example/v.mp4',
      });
      expect(badType.backgroundType, AppAppearanceConfig.backgroundNone);
    });
  });

  group('ThemeProvider server appearance', () {
    test('server config overrides local effect preferences', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = ThemeProvider();

      expect(provider.serverAppearance, isNull);
      expect(provider.hasServerBackground, isFalse);
      expect(provider.effectEnabled('heat'), isFalse);

      await provider.applyServerAppearance(const AppAppearanceConfig(
        backgroundType: AppAppearanceConfig.backgroundImage,
        backgroundUrl: 'https://hr.example/storage/bg.jpg',
        heat: true,
        snow: true,
        floatingHearts: false,
      ));

      expect(provider.serverAppearance, isNotNull);
      expect(provider.hasServerBackground, isTrue);
      expect(provider.effectEnabled('heat'), isTrue);
      expect(provider.effectEnabled('snow'), isTrue);
      expect(provider.effectEnabled('floating_hearts'), isFalse);
      // Keys the admin does not manage stay local.
      expect(provider.effectEnabled('reduce_animations'), isFalse);
    });

    test('identical config does not notify listeners twice', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = ThemeProvider();
      const config = AppAppearanceConfig(heat: true);

      await provider.applyServerAppearance(config);
      var notifications = 0;
      provider.addListener(() => notifications++);
      await provider.applyServerAppearance(config);

      expect(notifications, 0);
    });

    test('caches the applied config for the next cold start', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = ThemeProvider();
      const config = AppAppearanceConfig(
        backgroundType: AppAppearanceConfig.backgroundSvg,
        backgroundUrl: 'https://hr.example/storage/bg.svg',
        snow: true,
        emojiEffect: true,
        emojiChar: '🎉',
      );

      await provider.applyServerAppearance(config);

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('app_appearance_v1');
      expect(raw, isNotNull);
      final parsed = AppAppearanceConfig.fromJson(
          jsonDecode(raw!) as Map<String, dynamic>);
      expect(parsed.backgroundType, AppAppearanceConfig.backgroundSvg);
      expect(parsed.backgroundUrl, 'https://hr.example/storage/bg.svg');
      expect(parsed.snow, isTrue);
      expect(parsed.emojiEffect, isTrue);
      expect(parsed.emojiChar, '🎉');
    });
  });
}
