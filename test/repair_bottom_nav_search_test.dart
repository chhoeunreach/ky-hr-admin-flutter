import 'dart:convert';
import 'dart:io';

import 'package:cnattendance/features/repair_price/models/repair_brand.dart';
import 'package:cnattendance/features/repair_price/models/repair_device.dart';
import 'package:cnattendance/features/repair_price/pages/repair_device_page.dart';
import 'package:cnattendance/features/repair_price/providers/repair_price_provider.dart';
import 'package:cnattendance/features/repair_price/repositories/repair_price_repository.dart';
import 'package:cnattendance/provider/dashboardprovider.dart';

import 'package:cnattendance/theme/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:persistent_bottom_nav_bar_v2/persistent_bottom_nav_bar_v2.dart';
import 'package:provider/provider.dart';

class _MockRepo extends RepairPriceRepository {
  final List<String?> searches = [];

  @override
  Future<Map<String, dynamic>?> fetchPermissions() async => {
        'can_view': true,
        'can_view_cost': false,
        'can_manage_prices': false,
        'can_manage_devices': false,
        'can_manage_services': false,
      };

  @override
  Future<List<RepairBrand>> fetchBrands() async => [];

  @override
  Future<List<RepairDeviceType>> fetchDeviceTypes() async => [];

  @override
  Future<List<RepairDeviceSeries>> fetchSeries({int? brandId, int? deviceTypeId}) async => [];

  @override
  Future<List<RepairDevice>> fetchDevices({
    String? search,
    int? brandId,
    int? deviceTypeId,
    int? seriesId,
    int page = 1,
    int perPage = 20,
  }) async {
    searches.add(search);
    final all = [
      const RepairDevice(id: 1, name: 'iPhone 13', modelNumber: 'A2633'),
      const RepairDevice(id: 2, name: 'Samsung S22', modelNumber: 'SM-S901B'),
    ];
    if (search == null || search.isEmpty) return all;
    return all.where((d) => d.name.toLowerCase().contains(search.toLowerCase())).toList();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    Localization.load(
      jsonDecode(File('assets/i18n/en.json').readAsStringSync()) as Map<String, dynamic>,
    );
  });

  testWidgets('RepairDevicePage search works when placed in bottom navigation tab', (tester) async {
    final repo = _MockRepo();
    final provider = RepairPriceProvider(repository: repo);
    final tabController = PersistentTabController(initialIndex: 0);

    final tabs = [
      PersistentTabConfig(
        screen: const Scaffold(body: Text('Home Screen')),
        item: ItemConfig(icon: const Icon(Icons.home), title: 'Home'),
      ),
      PersistentTabConfig(
        screen: const RepairDevicePage(showBackButton: false),
        item: ItemConfig(icon: const Icon(Icons.build), title: 'Repair List'),
      ),
    ];

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<RepairPriceProvider>.value(value: provider),
          ChangeNotifierProvider<DashboardProvider>(create: (_) => DashboardProvider()),
          ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: PersistentTabView(
              controller: tabController,
              tabs: tabs,
              navBarBuilder: (navBarConfig) => const SizedBox(height: 56),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Initial tab is Home
    expect(find.text('Home Screen'), findsOneWidget);

    // 2. Switch to Tab 1 (Repair List)
    tabController.jumpToTab(1);
    await tester.pumpAndSettle();

    expect(find.text('iPhone 13'), findsOneWidget);
    expect(find.text('Samsung S22'), findsOneWidget);

    // 3. Find search input and enter text
    final searchField = find.byType(TextField);
    expect(searchField, findsOneWidget);

    await tester.tap(searchField);
    await tester.pumpAndSettle();

    final editable = tester.state<EditableTextState>(find.byType(EditableText));
    expect(editable.widget.focusNode.hasFocus, isTrue, reason: 'Search field must be focused');

    await tester.enterText(searchField, 'Samsung');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    // 4. Verify search results
    expect(repo.searches, contains('Samsung'));
    expect(find.text('Samsung S22'), findsOneWidget);
    expect(find.text('iPhone 13'), findsNothing);
  });
}
