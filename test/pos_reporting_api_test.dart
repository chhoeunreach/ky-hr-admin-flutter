import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/features/pos/models/pos_report.dart';
import 'package:cnattendance/services/sell_out_api_service.dart';
import 'package:dio/dio.dart';
import 'package:cnattendance/models/sell_out_report.dart';
import 'package:cnattendance/models/sell_out_report_line.dart';
import 'package:flutter_test/flutter_test.dart';
import 'fixtures/pos_report_fixture.dart';

class _Preferences extends Preferences {
  @override
  Future<String> getToken() async => 'test-token';
  @override
  Future<String> getAppUrl({bool forceCheck = false}) async =>
      'https://example.test/';
}

class _Adapter implements HttpClientAdapter {
  RequestOptions? request;
  dynamic response;
  int status = 200;
  String contentType = 'application/json';
  dynamic body;
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    request = options;
    return ResponseBody.fromString(
        body?.toString() ?? jsonEncode(response), status,
        headers: {
          'content-type': [contentType]
        });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
      'uses existing auth and URL with bounded query filters and server totals',
      () async {
    final adapter = _Adapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final api = SellOutApiService(dio: dio, preferences: _Preferences());
    final filters = PosFilters.today()
        .copyWith(branch: 'HQ', employee: 'Employee', search: 'SKU-1', page: 2);
    adapter.response = posFixture(filters);
    final report = await api.fetchReporting(filters);
    expect(adapter.request!.uri.path, '/api/sell-out-reports');
    expect(adapter.request!.headers['Authorization'], 'Bearer test-token');
    expect(adapter.request!.queryParameters['paginated'], 1);
    expect(adapter.request!.queryParameters['branch_name'], 'HQ');
    expect(adapter.request!.queryParameters['per_page'], 20);
    expect(report.page, 2);
    expect(report.transactions.single.report.invoiceNo, 'POS-21');
    expect(report.metric('sales_amount'), 210);
    dio.close();
  });
  test(
      'CSV export uses the same filters and preserves API authentication errors',
      () async {
    final adapter = _Adapter()
      ..contentType = 'text/csv; charset=UTF-8'
      ..body = 'Reference,Amount\nINV-1,12.00';
    final dio = Dio()..httpClientAdapter = adapter;
    final api = SellOutApiService(dio: dio, preferences: _Preferences());
    final filters = PosFilters.today()
        .copyWith(type: 'repair', search: 'Phone', branch: 'HQ');
    expect(utf8.decode(await api.exportReporting(filters)),
        contains('INV-1,12.00'));
    expect(adapter.request!.headers['Accept'], 'application/json');
    expect(adapter.request!.queryParameters['export'], 'csv');
    expect(adapter.request!.queryParameters['type'], 'repair');
    expect(adapter.request!.queryParameters['search'], 'Phone');
    adapter
      ..status = 401
      ..contentType = 'application/json'
      ..body = '{"message":"Unauthenticated"}';
    await expectLater(
        api.exportReporting(filters),
        throwsA(isA<DioException>()
            .having((e) => e.response?.statusCode, 'status', 401)));
    dio.close();
  });

  test('create and edit requests preserve the original invoice reference',
      () async {
    final adapter = _Adapter()..response = {'status': true};
    final dio = Dio()..httpClientAdapter = adapter;
    final api = SellOutApiService(dio: dio, preferences: _Preferences());
    final report = SellOutReport(
        id: 1,
        serviceType: 'Iron',
        originalInvoiceNo: 'ORIGINAL-123',
        lines: [SellOutReportLine(productName: 'Iron', qty: 1, unitPrice: 10)]);
    await api.submitReport(report);
    expect(
        Map.fromEntries(
            (adapter.request!.data as FormData).fields)['original_invoice_no'],
        'ORIGINAL-123');
    await api.updateReport(report);
    expect(
        Map.fromEntries((adapter.request!.data as FormData).fields)['_method'],
        'PUT');
    expect(
        Map.fromEntries(
            (adapter.request!.data as FormData).fields)['original_invoice_no'],
        'ORIGINAL-123');
    dio.close();
  });

  test('parses the real Laravel dashboard response without losing totals',
      () async {
    // Generated from MobilePosReportingTest's isolated backend fixture through
    // Laravel's HTTP kernel, rather than a hand-written Dart response.
    final adapter = _Adapter()
      ..response = jsonDecode(
          File('test/fixtures/pos_backend_contract.json').readAsStringSync());
    final dio = Dio()..httpClientAdapter = adapter;
    final api = SellOutApiService(dio: dio, preferences: _Preferences());
    final report = await api.fetchReporting(
        PosFilters(from: DateTime(2026, 11, 9), to: DateTime(2026, 11, 9)));
    expect(report.transactions.length, 6);
    expect(report.total, 6);
    expect(report.metric('sales_amount'), 222);
    expect(report.metric('buy_in_amount'), 500);
    expect(report.metric('commission'), 25.65);
    expect(
        report.categories.singleWhere((c) => c.type == 'sell').commission, 25);
    expect(
        report.categories.singleWhere((c) => c.type == 'buy_in').commission, 0);
    expect(report.summary['gross_profit'], isNull);
    expect(report.currency, r'$');
    expect(report.businessName, 'HQ');
    expect(report.modules, posModules);
    expect(report.points.single.amount, 222);
    expect(report.points.single.purchases, 500);
    expect(report.points.single.quantity, 100);
    final purchases =
        report.transactions.singleWhere((r) => r.type == 'buy_in');
    expect(purchases.report.totalAmount, 500);
    expect(purchases.commission, 0);
    expect(purchases.status, 'not_applicable');
    final sales = report.transactions.where((r) => r.type == 'sell');
    expect(sales.fold<int>(0, (sum, row) => sum + row.quantity), 100);
    expect(sales.every((r) => r.canEdit), isTrue);
    dio.close();
  });

  test(
      'rejects legacy responses rather than downloading all reports as a fallback',
      () async {
    final adapter = _Adapter()..response = {'status': true, 'data': []};
    final dio = Dio()..httpClientAdapter = adapter;
    final api = SellOutApiService(dio: dio, preferences: _Preferences());
    await expectLater(
        api.fetchReporting(PosFilters.today()), throwsFormatException);
    dio.close();
  });
}
