import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/features/banner_slideshow/banner_border_animation.dart';
import 'package:cnattendance/features/banner_slideshow/banner_slide_switcher.dart';
import 'package:cnattendance/model/banner_slideshow_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BannerSlideshowConfig', () {
    test('json round-trips slides and slideshow behaviour', () {
      final config = BannerSlideshowConfig(
        slides: const [
          BannerSlide(
            id: 'a',
            imageUrl: 'https://example.com/a.jpg',
            linkUrl: 'https://example.com',
            title: 'News',
          ),
          BannerSlide(id: 'b', imageUrl: '', enabled: false),
        ],
        intervalSeconds: 7,
        autoplay: false,
        showIndicators: false,
        animateBorder: true,
        pauseOnTouch: false,
        loop: false,
        transition: BannerSlideshowConfig.transitionSlide,
      );

      final restored = BannerSlideshowConfig.fromJson(config.toJson());

      expect(restored.slides.length, 2);
      expect(restored.slides.first.title, 'News');
      expect(restored.slides.first.isNetworkImage, isTrue);
      expect(restored.slides.last.enabled, isFalse);
      expect(restored.intervalSeconds, 7);
      expect(restored.autoplay, isFalse);
      expect(restored.showIndicators, isFalse);
      expect(restored.animateBorder, isTrue);
      expect(restored.copyWith(autoplay: true).animateBorder, isTrue);
      expect(restored.copyWith(animateBorder: false).animateBorder, isFalse);
      expect(restored.pauseOnTouch, isFalse);
      expect(restored.loop, isFalse);
      expect(restored.transition, BannerSlideshowConfig.transitionSlide);
      expect(restored.enabledSlides.length, 1);
    });

    test('interval is clamped to the supported range', () {
      expect(
        BannerSlideshowConfig.fromJson({'intervalSeconds': 1})
            .effectiveIntervalSeconds,
        BannerSlideshowConfig.minIntervalSeconds,
      );
      expect(
        BannerSlideshowConfig.fromJson({'intervalSeconds': 999})
            .effectiveIntervalSeconds,
        BannerSlideshowConfig.maxIntervalSeconds,
      );
      expect(
        BannerSlideshowConfig.fromJson({'intervalSeconds': 'abc'})
            .effectiveIntervalSeconds,
        BannerSlideshowConfig.defaultIntervalSeconds,
      );
    });

    test('unknown transition falls back to fade', () {
      expect(
        BannerSlideshowConfig.fromJson({'transition': 'unsupported'})
            .transition,
        BannerSlideshowConfig.transitionFade,
      );
    });

    test('older settings leave the border animation off', () {
      expect(BannerSlideshowConfig.fromJson({}).animateBorder, isFalse);
    });

    test('all admin transition values survive a JSON round trip', () {
      for (final value in BannerSlideshowConfig.transitionLabels.keys) {
        final config = BannerSlideshowConfig.fromJson({'transition': value});
        expect(config.transition, value);
        expect(config.toJson()['transition'], value);
      }
    });
  });

  testWidgets('banner border pulses and respects reduced motion',
      (tester) async {
    Future<void> show({required bool reducedMotion}) =>
        tester.pumpWidget(MediaQuery(
          data: MediaQueryData(disableAnimations: reducedMotion),
          child: const SizedBox.expand(child: BannerBorderAnimation()),
        ));

    final decoration = find.byType(DecoratedBox);
    double opacity() {
      final box = tester.widget<DecoratedBox>(decoration);
      final border = (box.decoration as BoxDecoration).border! as Border;
      return border.top.color.a;
    }

    await show(reducedMotion: false);
    expect(opacity(), closeTo(.18, .01));
    await tester.pump(const Duration(milliseconds: 600));
    expect(opacity(), greaterThan(.18));
    await show(reducedMotion: true);
    expect(decoration, findsNothing);
  });

  for (final mode in BannerSlideshowConfig.transitionLabels.keys) {
    testWidgets('banner plays the configured $mode transition', (tester) async {
      Future<void> show(String slide) => tester.pumpWidget(MaterialApp(
            home: BannerSlideSwitcher(
              transition: mode,
              child: SizedBox(key: ValueKey(slide)),
            ),
          ));

      await show('first');
      await show('second');
      final first = find.byKey(const ValueKey('first'));
      final second = find.byKey(const ValueKey('second'));
      final switcher = find.byType(BannerSlideSwitcher);
      Finder effect<T extends Widget>() => find.descendant(
            of: switcher,
            matching: find.byType(T),
          );

      expect(second, findsOneWidget);
      if (mode == BannerSlideshowConfig.transitionInstant) {
        expect(first, findsNothing);
        expect(effect<FadeTransition>(), findsNothing);
      } else {
        expect(first, findsOneWidget);
        expect(effect<FadeTransition>(), findsNWidgets(2));
        if (mode == BannerSlideshowConfig.transitionSlide ||
            mode == BannerSlideshowConfig.transitionSlideUp) {
          final incoming = tester.widget<SlideTransition>(
            find.ancestor(of: second, matching: effect<SlideTransition>()),
          );
          expect(
            incoming.position.value,
            mode == BannerSlideshowConfig.transitionSlide
                ? const Offset(.08, 0)
                : const Offset(0, .08),
          );
        } else if (mode == BannerSlideshowConfig.transitionZoom) {
          final incoming = tester.widget<ScaleTransition>(
            find.ancestor(of: second, matching: effect<ScaleTransition>()),
          );
          expect(incoming.scale.value, .92);
        }
        await tester.pumpAndSettle();
        expect(first, findsNothing);
      }
    });
  }

  group('Preferences slideshow storage', () {
    test('legacy single banner keys migrate into a one-slide slideshow',
        () async {
      SharedPreferences.setMockInitialValues({
        'home_banner_image_url': 'https://example.com/legacy.jpg',
        'home_banner_link_url': 'https://example.com/promo',
        'home_banner_title': 'Legacy',
      });

      final config = await Preferences().getHomeSlideshow();
      expect(config.slides.length, 1);
      expect(config.slides.first.imageUrl, 'https://example.com/legacy.jpg');
      expect(config.slides.first.linkUrl, 'https://example.com/promo');
      expect(config.slides.first.title, 'Legacy');
    });

    test('empty legacy keys produce the default (Angkor Wat) slideshow',
        () async {
      SharedPreferences.setMockInitialValues({});

      final config = await Preferences().getHomeSlideshow();
      expect(config.enabledSlides, isEmpty);
    });

    test('saved slideshow wins over legacy keys and survives reload', () async {
      SharedPreferences.setMockInitialValues({
        'home_banner_image_url': 'https://example.com/legacy.jpg',
      });

      final preferences = Preferences();
      await preferences.saveHomeSlideshow(const BannerSlideshowConfig(
        slides: [
          BannerSlide(id: 'one', imageUrl: 'https://example.com/one.jpg'),
          BannerSlide(id: 'two', imageUrl: 'https://example.com/two.jpg'),
        ],
        intervalSeconds: 3,
      ));

      final reloaded = await Preferences().getHomeSlideshow();
      expect(reloaded.slides.length, 2);
      expect(reloaded.intervalSeconds, 3);

      await preferences.resetHomeSlideshow();
      final reset = await Preferences().getHomeSlideshow();
      expect(reset.enabledSlides, isEmpty);
    });
  });
}
