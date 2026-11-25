import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/features/repair_price/models/repair_device.dart';
import 'package:cnattendance/features/repair_price/models/repair_brand.dart';
import 'package:cnattendance/features/repair_price/models/repair_category.dart';
import 'package:cnattendance/features/repair_price/models/repair_service.dart';
import 'package:cnattendance/features/repair_price/pages/repair_device_page.dart';
import 'package:cnattendance/features/repair_price/providers/repair_price_provider.dart';
import 'package:cnattendance/features/repair_price/repositories/repair_price_repository.dart';
import 'package:cnattendance/features/repair_price/services/repair_price_api_service.dart';
import 'package:cnattendance/features/repair_price/widgets/repair_edit_device_sheet.dart';
import 'package:cnattendance/features/repair_price/widgets/repair_search_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

class _TestPreferences extends Preferences {
  @override
  Future<String> getAppUrl({bool forceCheck = false}) async =>
      'https://example.test';

  @override
  Future<String> getToken() async => 'test-token';
}

class _RepairRepository extends RepairPriceRepository {
  final permissions = Completer<Map<String, dynamic>?>();
  var permissionChecks = 0;
  var deviceRequests = 0;

  @override
  Future<Map<String, dynamic>?> fetchPermissions() async {
    if (++permissionChecks == 1) return permissions.future;
    return null;
  }

  @override
  Future<List<RepairDevice>> fetchDevices({
    String? search,
    int? brandId,
    int? deviceTypeId,
    int? seriesId,
    int page = 1,
    int perPage = 20,
  }) async {
    deviceRequests++;
    return [];
  }
}

class _RoleRepository extends RepairPriceRepository {
  static const device = RepairDevice(id: 10, name: 'Phone');
  static const part = RepairService(
    id: 4,
    repairPriceId: 20,
    name: 'Battery',
    sellingPrice: 60,
    partCost: 20,
    serviceFee: 8,
  );
  static const alternatePart = RepairService(
    id: 4,
    repairPriceId: 21,
    name: 'Battery',
    sellingPrice: 73.25,
    partCost: 25.75,
    serviceFee: 9,
  );

  Map<String, dynamic>? permissions = {'can_view': true};
  final deviceWrites = <String>[];
  final priceWrites = <int>[];

  @override
  Future<Map<String, dynamic>?> fetchPermissions() async => permissions;

  @override
  Future<List<RepairBrand>> fetchBrands() async => [];

  @override
  Future<List<RepairDeviceType>> fetchDeviceTypes() async => [];

  @override
  Future<List<RepairDeviceSeries>> fetchSeries({
    int? brandId,
    int? deviceTypeId,
  }) async =>
      [];

  @override
  Future<List<RepairDevice>> fetchDevices({
    String? search,
    int? brandId,
    int? deviceTypeId,
    int? seriesId,
    int page = 1,
    int perPage = 20,
  }) async =>
      [device];

  @override
  Future<List<RepairCategory>> fetchCategories() async => [];

  @override
  Future<List<RepairService>> fetchDeviceServices(
    int deviceId, {
    String? search,
    int? categoryId,
  }) async =>
      [part, alternatePart];

  @override
  Future<RepairDevice> createDevice(Map<String, dynamic> data) async {
    deviceWrites.add('create');
    return device;
  }

  @override
  Future<RepairDevice> updateDevice(int id, Map<String, dynamic> data) async {
    deviceWrites.add('update');
    return device;
  }

  @override
  Future<bool> deleteDevice(int id) async {
    deviceWrites.add('delete');
    return true;
  }

  @override
  Future<RepairService> updatePrice({
    required int priceId,
    required int deviceId,
    required RepairService service,
  }) async {
    priceWrites.add(priceId);
    return RepairService(
      id: service.id,
      repairPriceId: priceId,
      name: service.name,
      sellingPrice: 81.50,
      partCost: service.partCost,
      serviceFee: service.serviceFee,
    );
  }
}

class _SearchRepository extends RepairPriceRepository {
  static const brand =
      RepairBrand(id: 2, name: 'Orchid Mobile', slug: 'orchid');
  static const series = RepairDeviceSeries(
    id: 3,
    name: 'Nova Series',
    slug: 'nova',
    brandId: 2,
    deviceTypeId: 1,
  );
  static const matchingDevice = RepairDevice(
    id: 30,
    name: 'Phone X',
    modelNumber: 'NX-500',
    brand: brand,
    series: series,
  );
  static const otherDevice = RepairDevice(
    id: 31,
    name: 'Tablet Y',
    modelNumber: 'TY-100',
  );

  final deviceSearches = <String?>[];
  final fallbackSearches = <String>[];
  var returnEmptyFromList = false;

  @override
  Future<Map<String, dynamic>?> fetchPermissions() async => {'can_view': true};

  @override
  Future<List<RepairBrand>> fetchBrands() async => [_SearchRepository.brand];

  @override
  Future<List<RepairDeviceType>> fetchDeviceTypes() async => [];

  @override
  Future<List<RepairDeviceSeries>> fetchSeries({
    int? brandId,
    int? deviceTypeId,
  }) async =>
      [_SearchRepository.series];

  @override
  Future<List<RepairDevice>> fetchDevices({
    String? search,
    int? brandId,
    int? deviceTypeId,
    int? seriesId,
    int page = 1,
    int perPage = 20,
  }) async {
    deviceSearches.add(search);
    return returnEmptyFromList ? [] : [matchingDevice, otherDevice];
  }

  @override
  Future<List<RepairDevice>> searchDevices(String query) async {
    fallbackSearches.add(query);
    return [matchingDevice, otherDevice];
  }
}

class _DevicesDownRepository extends _SearchRepository {
  var devicesDown = false;

  @override
  Future<List<RepairDevice>> fetchDevices({
    String? search,
    int? brandId,
    int? deviceTypeId,
    int? seriesId,
    int page = 1,
    int perPage = 20,
  }) async {
    if (devicesDown) {
      deviceSearches.add(search);
      throw const RepairApiException('device list unavailable',
          statusCode: 503);
    }
    return super.fetchDevices(
      search: search,
      brandId: brandId,
      deviceTypeId: deviceTypeId,
      seriesId: seriesId,
      page: page,
      perPage: perPage,
    );
  }

  @override
  Future<List<RepairDevice>> searchDevices(String query) async {
    if (devicesDown) {
      fallbackSearches.add(query);
      throw const RepairApiException('search unavailable', statusCode: 404);
    }
    return super.searchDevices(query);
  }
}

class _GatedSearchRepository extends RepairPriceRepository {
  static const device = RepairDevice(id: 10, name: 'Phone');
  var deviceFetches = 0;
  final gate = Completer<void>();

  @override
  Future<Map<String, dynamic>?> fetchPermissions() async => {'can_view': true};

  @override
  Future<List<RepairBrand>> fetchBrands() async => [];

  @override
  Future<List<RepairDeviceType>> fetchDeviceTypes() async => [];

  @override
  Future<List<RepairDeviceSeries>> fetchSeries({
    int? brandId,
    int? deviceTypeId,
  }) async =>
      [];

  @override
  Future<List<RepairDevice>> fetchDevices({
    String? search,
    int? brandId,
    int? deviceTypeId,
    int? seriesId,
    int page = 1,
    int perPage = 20,
  }) async {
    deviceFetches++;
    if (deviceFetches > 1) await gate.future;
    return [device];
  }
}

void main() {
  test('repair list model search matches name, model, brand and series',
      () async {
    final repository = _SearchRepository();
    final provider = RepairPriceProvider(repository: repository);
    addTearDown(provider.dispose);

    await provider.initDevicePage();
    expect(provider.devices,
        [_SearchRepository.matchingDevice, _SearchRepository.otherDevice]);

    for (final query in ['  phone x  ', 'nx-500', 'ORCHID', 'nova series']) {
      provider.onDeviceSearchChanged(query);
      await Future<void>.delayed(const Duration(milliseconds: 350));
      await Future<void>.delayed(Duration.zero);
      expect(provider.devices, [_SearchRepository.matchingDevice],
          reason: 'query: $query');
    }
    expect(repository.deviceSearches.last, 'nova series');

    repository.returnEmptyFromList = true;
    provider.onDeviceSearchChanged('nx-500');
    await Future<void>.delayed(const Duration(milliseconds: 350));
    await Future<void>.delayed(Duration.zero);
    expect(repository.fallbackSearches, ['nx-500']);
    expect(provider.devices, [_SearchRepository.matchingDevice]);
  });

  testWidgets('Repair List checks access before fetching devices',
      (tester) async {
    Localization.load(jsonDecode(File('assets/i18n/en.json').readAsStringSync())
        as Map<String, dynamic>);
    final repository = _RepairRepository();
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => RepairPriceProvider(repository: repository),
      child: const MaterialApp(home: RepairDevicePage(showBackButton: false)),
    ));
    await tester.pump();

    expect(repository.permissionChecks, 1);
    expect(repository.deviceRequests, 0);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Access Denied'), findsNothing);

    repository.permissions.completeError(
      const RepairApiException('Connection timed out'),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Connection timed out'), findsOneWidget);
    expect(find.text('Access Denied'), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(repository.permissionChecks, 2);
    expect(repository.deviceRequests, 0);
    expect(find.text('Access Denied'), findsOneWidget);
  });

  test('device actions require the current role grant', () async {
    final repository = _RoleRepository();
    final provider = RepairPriceProvider(repository: repository);
    addTearDown(provider.dispose);
    await provider.initDevicePage();
    expect(provider.devices, [_RoleRepository.device]);
    expect(provider.canManageDevices, isFalse);
    expect(await provider.addDevice(_RoleRepository.device), isFalse);
    expect(await provider.updateDevice(_RoleRepository.device), isFalse);
    expect(await provider.deleteDevice(_RoleRepository.device.id), isFalse);
    expect(repository.deviceWrites, isEmpty);

    repository.permissions = {'can_view': true, 'can_manage_devices': true};
    await provider.initDevicePage();
    expect(await provider.updateDevice(_RoleRepository.device), isTrue);
    expect(await provider.deleteDevice(_RoleRepository.device.id), isTrue);
    expect(await provider.addDevice(_RoleRepository.device), isTrue);
    expect(repository.deviceWrites, ['update', 'delete', 'create']);

    repository.permissions = null;
    await provider.initDevicePage();
    expect(provider.canView, isFalse);
    expect(await provider.updateDevice(_RoleRepository.device), isFalse);
    expect(repository.deviceWrites, hasLength(3));
  });

  testWidgets('device editor waits for confirmation and stays open on failure',
      (tester) async {
    Localization.load(jsonDecode(File('assets/i18n/en.json').readAsStringSync())
        as Map<String, dynamic>);
    final pending = Completer<bool>();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => RepairEditDeviceSheet.show(
              context,
              brands: const [RepairBrand(id: 1, name: 'Brand', slug: 'brand')],
              deviceTypes: const [
                RepairDeviceType(id: 1, name: 'Phone', slug: 'phone'),
              ],
              onSave: (_) => pending.future,
            ),
            child: const Text('Open editor'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'New phone');
    final save = find.widgetWithText(ElevatedButton, 'Add Device');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pump();
    expect(find.byType(RepairEditDeviceSheet), findsOneWidget);
    expect(find.text('Device created successfully.'), findsNothing);
    pending.complete(false);
    await tester.pump();
    expect(find.byType(RepairEditDeviceSheet), findsOneWidget);
    expect(find.textContaining('Could not save the device'), findsOneWidget);
  });

  test('price edits require cost access and update the exact part variant',
      () async {
    final repository = _RoleRepository()
      ..permissions = {'can_view': true, 'can_update_prices': true};
    final provider = RepairPriceProvider(repository: repository);
    addTearDown(provider.dispose);
    await provider.initDevicePage();
    provider.setSelectedDevice(_RoleRepository.device);
    await Future<void>.delayed(Duration.zero);

    expect(provider.canUpdatePrices, isTrue);
    expect(
        provider.canEditServicePrice(_RoleRepository.alternatePart), isFalse);
    await expectLater(
      provider.saveServicePrice(_RoleRepository.alternatePart),
      throwsA(isA<RepairApiException>()),
    );
    expect(repository.priceWrites, isEmpty);
    const publicPrice = RepairService(id: 4, name: 'Battery', sellingPrice: 60);
    final publicJson = publicPrice.toPriceUpdateJson(deviceId: 10);
    expect(publicJson, isNot(contains('part_cost')));
    expect(publicJson, isNot(contains('service_fee')));

    repository.permissions!['can_view_cost'] = true;
    await provider.initDevicePage();
    provider.selectService(_RoleRepository.alternatePart);
    expect(provider.canEditServicePrice(_RoleRepository.alternatePart), isTrue);
    await provider.saveServicePrice(_RoleRepository.alternatePart);
    expect(repository.priceWrites, [21]);
    expect(provider.services.first.sellingPrice, 60);
    expect(provider.services.last.sellingPrice, 81.50);
    expect(provider.selectedService?.repairPriceId, 21);
  });

  test('service prices include all server pages and distinct variants',
      () async {
    final pages = <String>[];
    final client = MockClient((request) async {
      expect(request.url.path, '/api/repair-price/devices/10/services');
      expect(request.headers['authorization'], 'Bearer test-token');
      expect(request.url.queryParameters['category_id'], '7');
      final page = request.url.queryParameters['page']!;
      pages.add(page);
      return http.Response(
          jsonEncode({
            'data': [
              {
                'id': 4,
                'repair_price_id': page == '1' ? 20 : 21,
                'name': 'Battery',
                'selling_price': 60,
              }
            ],
            'pagination': {'last_page': 2},
          }),
          200);
    });
    addTearDown(client.close);
    final api = RepairPriceApiService(
      preferences: _TestPreferences(),
      client: client,
    );
    final prices = await api.getDeviceServices(10, categoryId: 7);
    expect(pages, ['1', '2']);
    expect(prices.map((price) => price.repairPriceId), [20, 21]);
  });

  testWidgets('Repair List clear button reloads the device list exactly once',
      (tester) async {
    Localization.load(
        jsonDecode(File('assets/i18n/en.json').readAsStringSync())
            as Map<String, dynamic>);
    final repository = _SearchRepository();
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => RepairPriceProvider(repository: repository),
      child: const MaterialApp(home: RepairDevicePage(showBackButton: false)),
    ));
    await tester.pumpAndSettle();
    expect(repository.deviceSearches, [null]);

    await tester.enterText(find.byType(TextField).first, 'nx');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(repository.deviceSearches, [null, 'nx']);

    final before = repository.deviceSearches.length;
    await tester.tap(find.descendant(
      of: find.byType(RepairSearchBar),
      matching: find.byIcon(Icons.close_rounded),
    ));
    await tester.pump();
    await tester.pump();
    expect(repository.deviceSearches.length, before + 1,
        reason: 'clear must trigger exactly one reload, not two');
    expect(repository.deviceSearches.last, isNull);
  });

  testWidgets('Repair List search submits immediately from the keyboard',
      (tester) async {
    Localization.load(
        jsonDecode(File('assets/i18n/en.json').readAsStringSync())
            as Map<String, dynamic>);
    final repository = _SearchRepository();
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => RepairPriceProvider(repository: repository),
      child: const MaterialApp(home: RepairDevicePage(showBackButton: false)),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'phone');
    // The 300ms debounce must not delay an explicit search submit.
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.pump();
    expect(repository.deviceSearches, [null, 'phone']);
    expect(repository.deviceSearches.last, 'phone');
  });

  testWidgets('Repair List search icon keeps a single focusable layer',
      (tester) async {
    Localization.load(
        jsonDecode(File('assets/i18n/en.json').readAsStringSync())
            as Map<String, dynamic>);
    final repository = _SearchRepository();
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => RepairPriceProvider(repository: repository),
      child: const MaterialApp(home: RepairDevicePage(showBackButton: false)),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'nova');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(repository.deviceSearches.last, 'nova');

    // The magnifier icon must not sit behind a second gesture layer:
    // tapping it focuses the field instead of swallowing the tap.
    final editable = tester.widget<EditableText>(
        find.descendant(
            of: find.byType(RepairSearchBar),
            matching: find.byType(EditableText)).first);
    editable.focusNode.unfocus();
    await tester.pump();
    expect(editable.focusNode.hasFocus, isFalse);

    await tester.tap(find.descendant(
      of: find.byType(RepairSearchBar),
      matching: find.byIcon(Icons.search_rounded),
    ));
    await tester.pump();
    expect(editable.focusNode.hasFocus, isTrue,
        reason: 'the search icon area must focus the field, not block it');
  });

  test('failed device search shows error state instead of empty', () async {
    final repository = _DevicesDownRepository();
    final provider = RepairPriceProvider(repository: repository);
    addTearDown(provider.dispose);

    await provider.initDevicePage();
    expect(provider.deviceLoadingState, RepairLoadingState.loaded);

    repository.devicesDown = true;
    provider.onDeviceSearchChanged('nx-500');
    await Future<void>.delayed(const Duration(milliseconds: 350));
    await Future<void>.delayed(Duration.zero);

    expect(provider.deviceLoadingState, RepairLoadingState.error,
        reason: 'a failing search must surface an error with retry, '
            'not the "No devices found" empty state');
    expect(provider.deviceErrorMessage, contains('device list unavailable'));
  });

  test('refresh reloads even while a device search load is in flight',
      () async {
    final repository = _GatedSearchRepository();
    final provider = RepairPriceProvider(repository: repository);
    addTearDown(provider.dispose);

    await provider.initDevicePage();
    expect(repository.deviceFetches, 1);
    expect(provider.deviceLoadingState, RepairLoadingState.loaded);

    provider.onDeviceSearchChanged('phone');
    await Future<void>.delayed(const Duration(milliseconds: 350));
    await Future<void>.delayed(Duration.zero);
    expect(repository.deviceFetches, 2,
        reason: 'the search load must be in flight');
    expect(provider.deviceLoadingState, RepairLoadingState.loading);

    final refresh = provider.initDevicePage();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(repository.deviceFetches, 3,
        reason: 'pull-to-refresh must not be skipped during a search load');

    repository.gate.complete();
    await refresh;
    await Future<void>.delayed(Duration.zero);
    expect(provider.deviceLoadingState, RepairLoadingState.loaded);
  });
}
