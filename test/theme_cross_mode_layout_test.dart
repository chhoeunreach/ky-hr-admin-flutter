import 'dart:convert';
import 'dart:io';

import 'package:cnattendance/features/repair_price/providers/repair_price_provider.dart';
import 'package:cnattendance/provider/dashboardprovider.dart';
import 'package:cnattendance/provider/prefprovider.dart';
import 'package:cnattendance/theme/app_theme_data.dart';
import 'package:cnattendance/theme/app_theme_mode.dart';
import 'package:cnattendance/theme/theme_layout.dart';
import 'package:cnattendance/theme/theme_provider.dart';
import 'package:cnattendance/widget/homescreen/home_model_view.dart';
import 'package:cnattendance/widget/homescreen/royal_dashboard_widgets.dart';
import 'package:cnattendance/widgets/theme_layout_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/chat_storage_test_env.dart';

const _background = Color(0xff750f2b);
const _accent = Color(0xffe6b857);

ThemeLayout _customLayout() => const ThemeLayout.defaults()
    .reorder(LayoutArea.home, LayoutItem.banner, LayoutItem.scanner)
    .setVisible(LayoutItem.stories, false)
    .setColors(background: _background, accent: _accent);

void _loadLanguage(String code) {
  Localization.load(
    jsonDecode(File('assets/i18n/$code.json').readAsStringSync())
        as Map<String, dynamic>,
  );
}

MockClient _api() => MockClient((request) async {
      final path = request.url.path;
      final Object data;
      if (path.contains('banner-slideshow')) {
        data = {
          'slides': [
            {'id': 'first', 'title': 'First banner', 'enabled': true},
          ],
          'intervalSeconds': 2,
        };
      } else if (path.endsWith('/quotes')) {
        data = {
          'quotes': [
            {'id': 'quote', 'text': 'Shared quote'},
          ],
        };
      } else if (path.endsWith('/social-stories')) {
        data = [
          {
            'author': {'name': 'Story author'},
            'stories': [
              {'media_type': 'text', 'caption': 'Story caption'}
            ],
          },
        ];
      } else if (path.endsWith('/home-highlights')) {
        data = [
          {'id': 1, 'title': 'Company highlight'},
        ];
      } else {
        return http.Response('{}', 404);
      }
      return http.Response.bytes(utf8.encode(jsonEncode({'data': data})), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });

Widget _editorApp(ThemeProvider theme, DashboardProvider dashboard,
        AppThemeMode mode) =>
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: theme),
        ChangeNotifierProvider<DashboardProvider>.value(value: dashboard),
      ],
      child: MaterialApp(
        theme: AppThemeData.themeData(mode),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const ThemeLayoutEditor(),
              )),
              child: const Text('Open editor'),
            ),
          ),
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(ChatStorageTestEnv.install);
  tearDownAll(ChatStorageTestEnv.uninstall);
  setUp(() => SharedPreferences.setMockInitialValues({'app_url': '/test/'}));

  for (final mode in AppThemeMode.values) {
    test('layout round-trips and recolors for ${mode.id}', () {
      final restored = ThemeLayout.decode(_customLayout().encode());
      final home = restored.visible(LayoutArea.home);
      expect(home.indexOf(LayoutItem.banner),
          greaterThan(home.indexOf(LayoutItem.scanner)),
          reason: '${mode.id}: saved order survives encode/decode');
      expect(home, isNot(contains(LayoutItem.stories)),
          reason: '${mode.id}: hidden items stay hidden');
      expect(restored.background, _background);
      expect(restored.accent, _accent);

      final base = AppThemeData.info(mode).colors;
      final colors = restored.colorsFor(base);
      expect(colors.backgroundColor, _background, reason: mode.id);
      expect(colors.accentColor, _accent, reason: mode.id);
      expect(
        ThemeData.estimateBrightnessForColor(colors.backgroundColor),
        isNot(ThemeData.estimateBrightnessForColor(colors.textColor)),
        reason: '${mode.id}: text contrasts the saved background',
      );
      final themed = AppThemeData.themeData(mode, overrides: colors);
      expect(themed.scaffoldBackgroundColor, _background, reason: mode.id);
    });
  }

  test('ThemeProvider persists every mode and mirrors layouts to GetStorage',
      () async {
    final provider = ThemeProvider();
    addTearDown(provider.dispose);
    await provider.load();
    for (final mode in AppThemeMode.values) {
      expect(await provider.saveLayout(mode, _customLayout()), isTrue,
          reason: mode.id);
      expect(provider.layoutFor(mode).shows(LayoutItem.stories), isFalse,
          reason: mode.id);
      expect(provider.colorsForMode(mode).backgroundColor, _background,
          reason: mode.id);
      final mirrored = ThemeLayout.decode(
          GetStorage().read<String>(ThemeProvider.layoutKey(mode)));
      expect(mirrored.background, _background,
          reason: '${mode.id}: mirrored to GetStorage');
      expect(mirrored.shows(LayoutItem.stories), isFalse, reason: mode.id);
    }

    final reloaded = ThemeProvider();
    addTearDown(reloaded.dispose);
    await reloaded.load();
    for (final mode in AppThemeMode.values) {
      expect(reloaded.layoutFor(mode).shows(LayoutItem.stories), isFalse,
          reason: mode.id);
      expect(reloaded.colorsForMode(mode).backgroundColor, _background,
          reason: mode.id);
    }

    const defaults = ThemeLayout.defaults();
    expect(defaults.colorsFor(AppThemeData.info(AppThemeMode.light).colors),
        AppThemeData.info(AppThemeMode.light).colors);
  });

  for (final mode in AppThemeMode.values) {
    testWidgets('editor honors the saved layout for ${mode.id}',
        (tester) async {
      final theme = ThemeProvider();
      final dashboard = DashboardProvider();
      addTearDown(theme.dispose);
      addTearDown(dashboard.dispose);
      await theme.setMode(mode);
      await theme.saveLayout(mode, _customLayout());
      await tester.binding.setSurfaceSize(const Size(390, 820));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_editorApp(theme, dashboard, mode));
      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: mode.id);

      final scanner = find.byKey(const ValueKey(LayoutItem.scanner));
      final banner = find.byKey(const ValueKey(LayoutItem.banner));
      expect(tester.getTopLeft(banner).dy,
          greaterThan(tester.getTopLeft(scanner).dy),
          reason: '${mode.id}: banner renders after the scanner');
      final stories = find.byKey(const ValueKey(LayoutItem.stories));
      final storiesSwitch = tester.widget<SwitchListTile>(
          find.descendant(of: stories, matching: find.byType(SwitchListTile)));
      expect(storiesSwitch.value, isFalse,
          reason: '${mode.id}: hidden items keep their switch off');

      final expectedAmbient =
          ThemeData.estimateBrightnessForColor(
                  AppThemeData.themeData(mode).scaffoldBackgroundColor) ==
              Brightness.dark
          ? Colors.white
          : const Color(0xFF211720);
      expect(
        tester.widget<Text>(find.text(AppThemeData.info(mode).name)).style?.color,
        expectedAmbient,
        reason: '${mode.id}: editor text contrasts the scaffold',
      );

      final appearance = find.text('Colors & placement');
      await tester.ensureVisible(appearance);
      await tester.tap(appearance);
      await tester.pumpAndSettle();
      final backgroundTile = find.ancestor(
          of: find.text('Background color'), matching: find.byType(ListTile));
      final avatar = tester.widget<CircleAvatar>(
          find.descendant(of: backgroundTile, matching: find.byType(CircleAvatar)));
      expect(avatar.backgroundColor, _background,
          reason: '${mode.id}: color preview shows the saved background');
      expect(tester.takeException(), isNull, reason: mode.id);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('royal dashboard renders home sections in the saved order',
      (tester) async {
    _loadLanguage('en');
    final theme = ThemeProvider();
    final dashboard = DashboardProvider()
      ..attendanceMethods = ['QR']
      ..features = {
        'attendance': '1',
        'quote.view': '1',
        'home_highlight.view': '1',
      };
    final clock = ValueNotifier(DateTime.utc(2026, 11, 18, 1, 30));
    final pulse = AnimationController(vsync: tester);
    addTearDown(theme.dispose);
    addTearDown(dashboard.dispose);
    addTearDown(clock.dispose);
    addTearDown(pulse.dispose);
    await theme.setMode(AppThemeMode.royalBlueGold);
    await theme.saveLayout(
      AppThemeMode.royalBlueGold,
      const ThemeLayout.defaults()
          .reorder(LayoutArea.home, LayoutItem.scanner, LayoutItem.banner),
    );
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final client = _api();
    addTearDown(client.close);
    await http.runWithClient(() async {
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeProvider>.value(value: theme),
          ChangeNotifierProvider<DashboardProvider>.value(value: dashboard),
          ChangeNotifierProvider(create: (_) => PrefProvider()),
          ChangeNotifierProvider(create: (_) => RepairPriceProvider()),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: const [Locale('en'), Locale('km')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: AppThemeData.themeData(AppThemeMode.royalBlueGold),
          home: Scaffold(
            body: SingleChildScrollView(
              child: HomeModelView(
                clockNow: clock,
                summary: null,
                pulseController: pulse,
                animated: false,
                onAttendanceTap: () {},
                onRefreshZone: () {},
                allowedDistanceMeters: 50,
                distanceMeters: null,
                isInZone: false,
                isRefreshingZone: false,
                attendanceList: const {},
              ),
            ),
          ),
        ),
      ));
      await tester.pump();

      expect(find.byType(RoyalAttendanceScanner), findsOneWidget);
      expect(tester.takeException(), isNull);
      final scanner = find.byKey(const ValueKey(LayoutItem.scanner));
      final banner = find.byKey(const ValueKey(LayoutItem.banner));
      expect(tester.getTopLeft(scanner).dy,
          lessThan(tester.getTopLeft(banner).dy),
          reason: 'scanner renders before the banner when reordered');
      final today = find.byKey(const ValueKey(LayoutItem.workingTime));
      final calendar = find.byKey(const ValueKey('royal-calendar'));
      expect(tester.getTopLeft(today).dy,
          lessThan(tester.getTopLeft(calendar).dy),
          reason: 'calendar follows the working-time section');
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
  });
}
