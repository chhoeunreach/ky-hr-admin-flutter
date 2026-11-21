import 'dart:convert';
import 'dart:io';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/features/banner_slideshow/banner_border_animation.dart';
import 'package:cnattendance/features/quotes/mobile_quote_api.dart';
import 'package:cnattendance/model/home_banner_config.dart';
import 'package:cnattendance/provider/dashboardprovider.dart';
import 'package:cnattendance/provider/prefprovider.dart';
import 'package:cnattendance/theme/app_theme_data.dart';
import 'package:cnattendance/theme/app_theme_mode.dart';
import 'package:cnattendance/theme/theme_layout.dart';
import 'package:cnattendance/theme/theme_provider.dart';
import 'package:cnattendance/widget/homescreen/home_model_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/chat_storage_test_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(ChatStorageTestEnv.install);
  tearDownAll(ChatStorageTestEnv.uninstall);

  for (final width in [320.0, 390.0]) {
    testWidgets(
        'Khmer Heritage keeps the live Home sections at ${width.toInt()}px',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      var attendanceTaps = 0;
      await pumpHome(
        tester,
        width: width,
        mode: AppThemeMode.khmerHeritage,
        onAttendanceTap: () => attendanceTaps++,
        bannerConfig: const HomeBannerConfig(
          quote: 'Teamwork',
          quoteAuthor: 'Digital HR',
          quoteStyle: QuoteStyle(bannerOverlay: 0),
        ),
      );
      expect(find.text('KNEAYERNG HRMS'), findsOneWidget);
      expect(find.text('“ Teamwork ”'), findsOneWidget);
      expect(find.text('08:30:00'), findsOneWidget);
      expect(find.text('November 2026'), findsOneWidget);
      expect(find.text('Highlights'), findsWidgets);
      expect(overlayColor(tester).a, 0);
      final attendanceButton =
          find.byKey(const ValueKey('home-attendance-action'));
      await tester.ensureVisible(attendanceButton);
      await tester.tap(attendanceButton);
      expect(attendanceTaps, 1);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('Home uses the web canvas geometry and saved quote position',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpHome(tester,
        bannerConfig: const HomeBannerConfig(
          quote: 'Teamwork',
          quoteAuthor: 'Digital HR',
          quoteStyle: QuoteStyle(
            posX: 65,
            posY: 30,
            fontSize: 14,
            bannerImage: 'gradient:emerald',
            bannerOverlay: .35,
          ),
        ));
    final canvas =
        tester.getRect(find.byKey(const ValueKey('home-banner-canvas')));
    final quote = find.byKey(const ValueKey('home-banner-positioned-quote'));
    final anchor = tester.getTopLeft(quote);
    expect(canvas.width / canvas.height, closeTo(3, .01));
    expect(anchor.dx - canvas.left, closeTo(canvas.width * .65, .01));
    expect(anchor.dy - canvas.top, closeTo(canvas.height * .30, .01));
    expect(tester.widget<Text>(find.text('Teamwork ”')).style!.fontSize, 14);
    expect(find.text('— Digital HR'), findsOneWidget);
    expect(overlayColor(tester).a, .35);
    expect(find.byType(BannerBorderAnimation), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Home renders the saved layout order and visibility',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final theme = ThemeProvider();
    addTearDown(theme.dispose);
    await theme.saveLayout(
      AppThemeMode.light,
      const ThemeLayout.defaults()
          .reorder(LayoutArea.home, LayoutItem.workingTime, LayoutItem.banner)
          .setVisible(LayoutItem.banner, false),
    );
    await pumpHome(tester, themeProvider: theme);
    final workingTime = find.byKey(const ValueKey(LayoutItem.workingTime));
    final summary = find.byKey(const ValueKey(LayoutItem.summary));
    expect(find.byKey(const ValueKey(LayoutItem.banner)), findsNothing);
    expect(tester.getTopLeft(workingTime).dy,
        lessThan(tester.getTopLeft(summary).dy));
    await tester.pumpWidget(const SizedBox());
  });

  for (final mode in [AppThemeMode.light, AppThemeMode.khmerHeritage]) {
    testWidgets(
        '${mode.name} rotates quotes with the saved transition and stops without looping',
        (tester) async {
      String quote(String text) =>
          mode == AppThemeMode.khmerHeritage ? '“ $text ”' : '$text ”';
      SharedPreferences.setMockInitialValues({'app_url': '/test/'});
      final client = MockClient((request) async {
        final data = request.url.path.endsWith('/quotes')
            ? {
                'quotes': [
                  {
                    'id': 'first',
                    'text': 'First quote',
                    'style': {'bannerOverlay': 0},
                  },
                  {
                    'id': 'second',
                    'text': 'Second quote',
                    'style': {'bannerOverlay': .8},
                  },
                ],
                'playback': {
                  'autoplay': true,
                  'intervalSeconds': 2,
                  'transition': 'slide-up',
                  'loop': false,
                  'pauseOnTouch': true,
                },
              }
            : {
                'animateBorder': true,
                'slides': [
                  {
                    'id': 'banner',
                    'imageUrl': 'assets/images/home_bg.jpg',
                  },
                ],
              };
        return http.Response(jsonEncode({'data': data}), 200);
      });
      await http.runWithClient(() async {
        await pumpHome(tester,
            mode: mode, width: mode == AppThemeMode.khmerHeritage ? 390 : 560);
        await tester.pump();
        expect(find.text(quote('First quote')), findsOneWidget);
        expect(
          find.image(const AssetImage('assets/images/home_bg.jpg')),
          findsOneWidget,
        );
        expect(overlayColor(tester).a, 0);
        expect(find.byType(BannerBorderAnimation), findsOneWidget);
        final canvas = find.byKey(const ValueKey('home-banner-canvas'));
        final gesture = await tester.startGesture(tester.getCenter(canvas));
        await tester.pump(const Duration(seconds: 3));
        expect(find.text(quote('Second quote')), findsNothing);
        await gesture.up();
        await tester.pump(const Duration(seconds: 2));
        expect(find.text(quote('First quote')), findsOneWidget);
        final incoming = find.ancestor(
          of: find.text(quote('Second quote')),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is SlideTransition && widget.position.value.dy > 0,
          ),
        );
        expect(incoming, findsOneWidget);
        expect(tester.widget<SlideTransition>(incoming).position.value.dy,
            closeTo(.08, .001));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text(quote('First quote')), findsNothing);
        expect(overlayColor(tester).a, .8);
        await tester.pump(const Duration(seconds: 4));
        expect(find.text(quote('Second quote')), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      }, () => client);
    });
  }

  group('QuoteStyle & HomeBannerConfig Customization', () {
    test('QuoteStyle serializes and deserializes all customization properties',
        () {
      const style = QuoteStyle(
        fontFamily: 'Battambang',
        fontSize: 16.0,
        fontWeight: FontWeight.w700,
        fontStyle: FontStyle.italic,
        textAlign: TextAlign.center,
        color: Color(0xFFFFD54F),
        opacity: 0.9,
        rotation: -8.0,
        posX: 62.0,
        posY: 35.0,
        strokeWidth: 1.5,
        strokeColor: Color(0xFF000000),
        gradientEnabled: true,
        gradientStart: Color(0xFFFFE082),
        gradientEnd: Color(0xFFFF8F00),
        gradientAngle: 45.0,
        shadowBlur: 8.0,
        shadowColor: Color(0xCC000000),
        shadowX: 0.0,
        shadowY: 2.0,
        bannerImage: '/assets/images/angkor_wat_banner.jpg',
        bannerOverlay: 0.35,
      );

      final json = style.toJson();
      expect(json['fontFamily'], 'Battambang');
      expect(json['fontSize'], 16.0);
      expect(json['fontStyle'], 'italic');
      expect(json['textAlign'], 'center');
      expect(json['rotation'], -8.0);
      expect(json['posX'], 62.0);
      expect(json['posY'], 35.0);
      expect(json['strokeWidth'], 1.5);
      expect(json['gradientEnabled'], true);

      final restored = QuoteStyle.fromJson(json);
      expect(restored.fontFamily, 'Battambang');
      expect(restored.fontSize, 16.0);
      expect(restored.fontWeight, FontWeight.w700);
      expect(restored.fontStyle, FontStyle.italic);
      expect(restored.textAlign, TextAlign.center);
      expect(restored.color, const Color(0xFFFFD54F));
      expect(restored.rotation, -8.0);
      expect(restored.posX, 62.0);
      expect(restored.posY, 35.0);
      expect(restored.strokeWidth, 1.5);
      expect(restored.strokeColor, const Color(0xFF000000));
      expect(restored.gradientEnabled, isTrue);
      expect(restored.hasCustomPosition, isTrue);
    });

    test('HomeBannerConfig round-trips quote, author, and quoteStyle', () {
      const config = HomeBannerConfig(
        quote: 'Inspiring Quote',
        quoteAuthor: 'Leader',
        quoteStyle: QuoteStyle(
          fontFamily: 'Kantumruy Pro',
          fontSize: 14.0,
          color: Color(0xFF00E5FF),
          rotation: 5.0,
        ),
      );

      final json = config.toJson();
      expect(json['quote'], 'Inspiring Quote');
      expect(json['quoteAuthor'], 'Leader');
      expect(json['quoteStyle'], isNotNull);

      final restored = HomeBannerConfig.fromJson(json);
      expect(restored.quote, 'Inspiring Quote');
      expect(restored.quoteAuthor, 'Leader');
      expect(restored.quoteStyle?.fontFamily, 'Kantumruy Pro');
      expect(restored.quoteStyle?.fontSize, 14.0);
      expect(restored.quoteStyle?.rotation, 5.0);
      expect(restored.quoteStyle?.color, const Color(0xFF00E5FF));
    });

    test('MobileQuoteItem parses API response containing full custom style',
        () {
      final apiResponse = {
        'id': 'quote_test123',
        'text': 'United We Stand',
        'author': 'Digital HR',
        'style': {
          'fontFamily': 'Moul',
          'fontSize': 15,
          'fontWeight': '800',
          'color': '#FFF7ED',
          'rotation': -5,
          'posX': 65.5,
          'posY': 28.0,
          'strokeWidth': 1.0,
          'strokeColor': '#000000',
          'gradientEnabled': true,
          'gradientStart': '#FFE082',
          'gradientEnd': '#FF8F00',
          'gradientAngle': 90,
          'shadowBlur': 6,
          'shadowColor': 'rgba(0,0,0,0.8)',
        },
      };

      final item = MobileQuoteItem.fromJson(apiResponse);
      expect(item.id, 'quote_test123');
      expect(item.text, 'United We Stand');
      expect(item.author, 'Digital HR');
      expect(item.style, isNotNull);
      expect(item.style!.fontFamily, 'Moul');
      expect(item.style!.fontSize, 15.0);
      expect(item.style!.rotation, -5.0);
      expect(item.style!.posX, 65.5);
      expect(item.style!.posY, 28.0);
      expect(item.style!.gradientEnabled, isTrue);
      expect(item.style!.strokeWidth, 1.0);
    });

    test('Preferences stores and retrieves home quote author and custom style',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = Preferences();

      expect(await prefs.getHomeQuoteAuthor(), isNull);
      expect(await prefs.getHomeQuoteStyle(), isNull);

      await prefs.saveHomeQuote('Custom quote text');
      await prefs.saveHomeQuoteAuthor('Custom author');
      const testStyle = QuoteStyle(
        fontFamily: 'Inter',
        fontSize: 12.0,
        rotation: 3.0,
        posX: 70.0,
        posY: 40.0,
      );
      await prefs.saveHomeQuoteStyle(testStyle);

      expect(await prefs.getHomeQuote(), 'Custom quote text');
      expect(await prefs.getHomeQuoteAuthor(), 'Custom author');
      final loadedStyle = await prefs.getHomeQuoteStyle();
      expect(loadedStyle, isNotNull);
      expect(loadedStyle!.fontFamily, 'Inter');
      expect(loadedStyle.fontSize, 12.0);
      expect(loadedStyle.rotation, 3.0);
      expect(loadedStyle.posX, 70.0);
      expect(loadedStyle.posY, 40.0);

      await prefs.resetHomeQuote();
      expect(await prefs.getHomeQuote(), HomeBannerConfig.defaultQuote);
      expect(await prefs.getHomeQuoteAuthor(), isNull);
      expect(await prefs.getHomeQuoteStyle(), isNull);
    });
  });
}

Color overlayColor(WidgetTester tester) {
  return tester
      .widget<ColoredBox>(
          find.byKey(const ValueKey('home-banner-darkening-overlay')))
      .color;
}

Future<void> pumpHome(WidgetTester tester,
    {HomeBannerConfig? bannerConfig,
    AppThemeMode? mode,
    VoidCallback? onAttendanceTap,
    ThemeProvider? themeProvider,
    double width = 560}) async {
  Localization.load(jsonDecode(File('assets/i18n/en.json').readAsStringSync())
      as Map<String, dynamic>);
  await tester.binding.setSurfaceSize(Size(width, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final clock = ValueNotifier(DateTime(2026, 11, 18, 8, 30));
  final pulse = AnimationController(vsync: tester);
  final preferences = PrefProvider();
  if (onAttendanceTap != null) await preferences.getAttendanceType(['QR']);
  addTearDown(clock.dispose);
  addTearDown(pulse.dispose);
  await tester.pumpWidget(MultiProvider(
    providers: [
      if (themeProvider != null)
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
      ChangeNotifierProvider(
        create: (_) => DashboardProvider()
          ..attendanceMethods = onAttendanceTap == null ? [] : ['QR']
          ..features = {'quote.view': '1'},
      ),
      ChangeNotifierProvider(create: (_) => preferences),
    ],
    child: MaterialApp(
      theme: mode == null ? null : AppThemeData.themeData(mode),
      home: Scaffold(
        body: SingleChildScrollView(
          child: HomeModelView(
            clockNow: clock,
            pulseController: pulse,
            summary: null,
            animated: false,
            onAttendanceTap: onAttendanceTap ?? () {},
            onRefreshZone: () {},
            allowedDistanceMeters: 0,
            distanceMeters: null,
            isInZone: false,
            isRefreshingZone: false,
            attendanceList: const {},
            bannerConfig: bannerConfig,
          ),
        ),
      ),
    ),
  ));
}
