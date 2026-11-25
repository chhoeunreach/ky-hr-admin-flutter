import 'dart:convert';
import 'dart:io';

import 'package:cnattendance/model/app_theme_option.dart';
import 'package:cnattendance/model/remote_theme_mode.dart';
import 'package:cnattendance/provider/dashboardprovider.dart';
import 'package:cnattendance/provider/morescreenprovider.dart';
import 'package:cnattendance/provider/prefprovider.dart';
import 'package:cnattendance/screen/dashboard/morescreen.dart';
import 'package:cnattendance/theme/app_theme_data.dart';
import 'package:cnattendance/theme/app_theme_mode.dart';
import 'package:cnattendance/theme/theme_layout.dart';
import 'package:cnattendance/theme/theme_provider.dart';
import 'package:cnattendance/widget/dashboard_drawer.dart';
import 'package:cnattendance/widget/morescreen/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  void loadLanguage(String code) {
    Localization.load(
      jsonDecode(File('assets/i18n/$code.json').readAsStringSync())
          as Map<String, dynamic>,
    );
  }

  Widget createTestWidget({
    required Widget child,
    Map<String, String> features = const {},
    String languageCode = 'en',
  }) {
    loadLanguage(languageCode);

    final dashboardProvider = DashboardProvider()..features = Map.of(features);
    final prefProvider = PrefProvider();
    final moreScreenProvider = MoreScreenProvider()..features = Map.of(features);
    final themeProvider = ThemeProvider();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<DashboardProvider>.value(value: dashboardProvider),
        ChangeNotifierProvider<PrefProvider>.value(value: prefProvider),
        ChangeNotifierProvider<MoreScreenProvider>.value(value: moreScreenProvider),
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
      ],
      child: MaterialApp(
        home: Scaffold(body: child),
      ),
    );
  }

  group('Default Menus and Repair Navigation', () {
    test('ThemeLayout includes Repair in tabs by default', () {
      const layout = ThemeLayout.defaults();
      final tabs = layout.visible(LayoutArea.tabs);
      expect(tabs, contains(LayoutItem.repair));
      expect(tabs, contains(LayoutItem.home));
      expect(tabs, contains(LayoutItem.leave));
      expect(tabs, contains(LayoutItem.attendance));
      expect(tabs, contains(LayoutItem.social));
      expect(tabs, contains(LayoutItem.more));
    });

    test('LayoutItem.repair allows by default unless explicitly disabled with 0', () {
      expect(LayoutItem.repair.allowed({}), isTrue);
      expect(LayoutItem.repair.allowed({'repair': '1'}), isTrue);
      expect(LayoutItem.repair.allowed({'repair': '0'}), isFalse);
    });

    test('LayoutItem.leave and attendance allow by default unless explicitly disabled with 0', () {
      expect(LayoutItem.leave.allowed({}), isTrue);
      expect(LayoutItem.leave.allowed({'leave-request': '1'}), isTrue);
      expect(LayoutItem.leave.allowed({'leave-request': '0'}), isFalse);

      expect(LayoutItem.attendance.allowed({}), isTrue);
      expect(LayoutItem.attendance.allowed({'attendance': '1'}), isTrue);
      expect(LayoutItem.attendance.allowed({'attendance': '0'}), isFalse);
    });

    testWidgets('MoreScreen shows Repair List by default in English and Khmer', (tester) async {
      // English
      await tester.pumpWidget(createTestWidget(
        child: MoreScreen(),
        languageCode: 'en',
      ));
      await tester.pumpAndSettle();

      final repairFinderEn = find.widgetWithText(Services, 'Repair List');
      await tester.scrollUntilVisible(repairFinderEn, 200,
          scrollable: find.byType(Scrollable).first);
      expect(repairFinderEn, findsOneWidget);

      // Khmer
      await tester.pumpWidget(createTestWidget(
        child: MoreScreen(),
        languageCode: 'km',
      ));
      await tester.pumpAndSettle();

      final repairFinderKm = find.widgetWithText(Services, 'បញ្ជីជួសជុល');
      await tester.scrollUntilVisible(repairFinderKm, 200,
          scrollable: find.byType(Scrollable).first);
      expect(repairFinderKm, findsOneWidget);
    });

    testWidgets('MoreScreen hides Repair List when repair feature is explicitly 0', (tester) async {
      await tester.pumpWidget(createTestWidget(
        child: MoreScreen(),
        features: {'repair': '0'},
        languageCode: 'en',
      ));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(Services, 'Repair List'), findsNothing);
    });

    testWidgets('DashboardDrawer shows Repair List by default and hides when 0', (tester) async {
      // Shown by default
      await tester.pumpWidget(createTestWidget(
        child: const DashboardDrawer(),
        languageCode: 'en',
      ));
      await tester.pumpAndSettle();

      final repairDrawerFinder = find.text('Repair List');
      await tester.scrollUntilVisible(repairDrawerFinder, 200,
          scrollable: find.byType(Scrollable).first);
      expect(repairDrawerFinder, findsOneWidget);

      // Hidden when repair is '0'
      await tester.pumpWidget(createTestWidget(
        child: const DashboardDrawer(),
        features: {'repair': '0'},
        languageCode: 'en',
      ));
      await tester.pumpAndSettle();

      expect(find.text('Repair List'), findsNothing);
    });

    test('AppThemeData displays Day Mode and Night Mode', () {
      expect(AppThemeData.themes[AppThemeMode.light]?.name, 'Day Mode');
      expect(AppThemeData.themes[AppThemeMode.dark]?.name, 'Night Mode');
      expect(AppThemeOption.fromCoreMode(AppThemeMode.light).name, 'Day Mode');
      expect(AppThemeOption.fromCoreMode(AppThemeMode.dark).name, 'Night Mode');

      // Remote mode with legacy names maps to Day Mode and Night Mode
      final remoteLight = RemoteThemeMode.fromJson(const {
        'key': 'light',
        'name': 'Original Mode',
        'description': 'Original light',
      });
      expect(remoteLight.name, 'Day Mode');
      expect(AppThemeOption.fromRemote(remoteLight).name, 'Day Mode');

      final remoteDark = RemoteThemeMode.fromJson(const {
        'key': 'dark',
        'name': 'Dark Mode',
        'description': 'Original dark',
      });
      expect(remoteDark.name, 'Night Mode');
      expect(AppThemeOption.fromRemote(remoteDark).name, 'Night Mode');
    });

    testWidgets('MoreScreen shows Night Mode toggle in English and Khmer', (tester) async {
      // English
      await tester.pumpWidget(createTestWidget(
        child: MoreScreen(),
        languageCode: 'en',
      ));
      await tester.pumpAndSettle();

      final nightModeEn = find.text('Night Mode').first;
      await tester.scrollUntilVisible(nightModeEn, 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Night Mode'), findsWidgets);

      // Khmer
      await tester.pumpWidget(createTestWidget(
        child: MoreScreen(),
        languageCode: 'km',
      ));
      await tester.pumpAndSettle();

      final nightModeKm = find.text('ម៉ូដពេលយប់ (Night Mode)').first;
      await tester.scrollUntilVisible(nightModeKm, 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('ម៉ូដពេលយប់ (Night Mode)'), findsWidgets);
    });
  });
}
