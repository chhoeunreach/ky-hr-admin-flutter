import 'dart:convert';
import 'dart:io';

import 'package:cnattendance/data/source/network/model/asssetlistresponse/assetlistresponse.dart';
import 'package:cnattendance/model/admin_asset.dart';
import 'package:cnattendance/provider/dashboardprovider.dart';
import 'package:cnattendance/provider/morescreenprovider.dart';
import 'package:cnattendance/provider/prefprovider.dart';
import 'package:cnattendance/screen/assetscreen/admin_asset_form_screen.dart';
import 'package:cnattendance/screen/assetscreen/admin_asset_list_controller.dart';
import 'package:cnattendance/screen/assetscreen/assetscontroller.dart';
import 'package:cnattendance/screen/dashboard/morescreen.dart';
import 'package:cnattendance/theme/app_theme_mode.dart';
import 'package:cnattendance/theme/theme_provider.dart';
import 'package:cnattendance/utils/asset_image_compressor.dart';
import 'package:cnattendance/widget/dashboard_drawer.dart';
import 'package:cnattendance/widget/morescreen/services.dart';
import 'package:cnattendance/widget/profile/asset_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';
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

  Widget createMoreScreenTestWidget({
    required Map<String, String> features,
    String languageCode = 'en',
  }) {
    loadLanguage(languageCode);

    final dashboardProvider = DashboardProvider()..features = features;
    final prefProvider = PrefProvider();
    final moreScreenProvider = MoreScreenProvider()..features = features;
    final themeProvider = ThemeProvider();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<DashboardProvider>.value(value: dashboardProvider),
        ChangeNotifierProvider<PrefProvider>.value(value: prefProvider),
        ChangeNotifierProvider<MoreScreenProvider>.value(value: moreScreenProvider),
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
      ],
      child: GetMaterialApp(
        locale: Locale(languageCode),
        home: MoreScreen(),
      ),
    );
  }

  Widget createDrawerTestWidget({
    required Map<String, String> features,
    String languageCode = 'en',
  }) {
    loadLanguage(languageCode);

    final dashboardProvider = DashboardProvider()..features = features;
    final prefProvider = PrefProvider();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<DashboardProvider>.value(value: dashboardProvider),
        ChangeNotifierProvider<PrefProvider>.value(value: prefProvider),
      ],
      child: GetMaterialApp(
        locale: Locale(languageCode),
        home: const Scaffold(
          drawer: DashboardDrawer(),
          body: Center(child: Text('Home')),
        ),
      ),
    );
  }

  group('Asset Management in More Menu and Drawer', () {
    testWidgets('renders Asset Management in MoreScreen in English', (tester) async {
      await tester.pumpWidget(createMoreScreenTestWidget(
        features: {},
        languageCode: 'en',
      ));
      await tester.pumpAndSettle();

      final assetFinder = find.widgetWithText(Services, 'Asset Management');
      expect(assetFinder, findsOneWidget);
    });

    testWidgets('renders Asset Management in MoreScreen in Khmer', (tester) async {
      await tester.pumpWidget(createMoreScreenTestWidget(
        features: {},
        languageCode: 'km',
      ));
      await tester.pumpAndSettle();

      final assetFinder = find.widgetWithText(
        Services,
        'គ្រប់គ្រងទ្រព្យសម្បត្តិ',
      );
      expect(assetFinder, findsOneWidget);
    });

    testWidgets('renders Asset Management in DashboardDrawer in English', (tester) async {
      await tester.pumpWidget(createDrawerTestWidget(
        features: {},
        languageCode: 'en',
      ));
      await tester.pumpAndSettle();

      // Open Drawer
      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      final assetFinder = find.text('Asset Management');
      await tester.scrollUntilVisible(assetFinder, 200,
          scrollable: find.byType(Scrollable).last);
      expect(assetFinder, findsOneWidget);
    });

    testWidgets('renders Asset Management in DashboardDrawer in Khmer', (tester) async {
      await tester.pumpWidget(createDrawerTestWidget(
        features: {},
        languageCode: 'km',
      ));
      await tester.pumpAndSettle();

      // Open Drawer
      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      final assetFinder =
          find.text('គ្រប់គ្រងទ្រព្យសម្បត្តិ');
      await tester.scrollUntilVisible(assetFinder, 200,
          scrollable: find.byType(Scrollable).last);
      expect(assetFinder, findsOneWidget);
    });

    test('AdminAssetListController permissions default gracefully', () async {
      final controller = AdminAssetListController();
      expect(controller.canCreate.value, isTrue);
      expect(controller.canEdit.value, isTrue);
      expect(controller.canDelete.value, isTrue);
    });

    testWidgets('AdminAssetFormScreen renders in Original Mode with dark text and enterprise styling', (tester) async {
      loadLanguage('en');
      final themeProvider = ThemeProvider()..setMode(AppThemeMode.light);
      await tester.pumpWidget(
        ChangeNotifierProvider<ThemeProvider>.value(
          value: themeProvider,
          child: GetMaterialApp(
            locale: const Locale('en'),
            home: AdminAssetFormScreen(
              types: [AssetDropdownItem(id: 1, name: 'Laptop')],
              branches: [AssetDropdownItem(id: 1, name: 'Phnom Penh')],
              employees: [AssetEmployeeItem(id: 1, name: 'Sokha')],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('General Info'), findsOneWidget);

      final textField = tester.widget<TextField>(
        find.byType(TextField).first,
      );
      expect(textField.style?.color, const Color(0xff0f172a));

      await tester.scrollUntilVisible(
        find.text('Create Asset'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Create Asset'), findsOneWidget);
    });

    testWidgets('AssetBottomSheet renders in Original Mode with solid white sheet and dark text', (tester) async {
      final themeProvider = ThemeProvider()..setMode(AppThemeMode.light);
      Get.put(AssetController());

      await tester.pumpWidget(
        ChangeNotifierProvider<ThemeProvider>.value(
          value: themeProvider,
          child: GetMaterialApp(
            home: Scaffold(
              body: AssetBottomSheet(
                AssetData(
                  id: 101,
                  asset: 'MacBook Pro M3',
                  assignedDate: '2026-01-01',
                  returnedDate: null,
                  status: 'assigned',
                  returnCondition: null,
                  notes: null,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('MacBook Pro M3'), findsOneWidget);
      expect(find.text('Is Working Condition'), findsOneWidget);
      expect(find.text('Submit Return'), findsOneWidget);

      final assetNameText = tester.widget<Text>(find.text('MacBook Pro M3'));
      expect(assetNameText.style?.color, const Color(0xff0f172a));
    });

    test('AssetImageCompressor stats and formatting work correctly', () async {
      final photo = CompressedAssetPhoto(
        file: File('/tmp/test.jpg'),
        originalPath: '/tmp/test.jpg',
        originalSizeBytes: 1024 * 500, // 500 KB
        compressedSizeBytes: 1024 * 125, // 125 KB
      );

      expect(photo.readableSize, '125.0 KB');
      expect(photo.readableOriginalSize, '500.0 KB');
      expect(photo.savingsPercentage, 75);
    });

    test('AssetImageCompressor compressFile gracefully handles fallback on temp file', () async {
      final tempFile = File('${Directory.systemTemp.path}/asset_test_dummy.jpg');
      await tempFile.writeAsBytes(List.filled(1024, 0));

      final result = await AssetImageCompressor.compressFile(tempFile.path);
      expect(result.file.path, isNotEmpty);
      expect(result.originalSizeBytes, 1024);

      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    });

    testWidgets('AdminAssetFormScreen renders multi-upload and camera buttons in Asset Photos section', (tester) async {
      loadLanguage('en');
      final themeProvider = ThemeProvider()..setMode(AppThemeMode.light);
      await tester.pumpWidget(
        ChangeNotifierProvider<ThemeProvider>.value(
          value: themeProvider,
          child: GetMaterialApp(
            locale: const Locale('en'),
            home: AdminAssetFormScreen(
              types: [AssetDropdownItem(id: 1, name: 'Laptop')],
              branches: [AssetDropdownItem(id: 1, name: 'Phnom Penh')],
              employees: [AssetEmployeeItem(id: 1, name: 'Sokha')],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Asset Photos'), findsOneWidget);
      expect(find.text('Gallery (Multi)'), findsOneWidget);
      expect(find.text('Camera'), findsOneWidget);
    });
  });
}
