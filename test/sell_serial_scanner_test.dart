import 'dart:convert';
import 'package:cnattendance/models/commission_policy.dart';
import 'dart:io';

import 'package:cnattendance/models/sell_out_report.dart';
import 'package:cnattendance/models/sell_out_report_line.dart';
import 'package:cnattendance/screen/sell_out_report_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_translate/flutter_translate.dart';

void main() {
  setUp(() {
    Localization.load(jsonDecode(File('assets/i18n/en.json').readAsStringSync())
        as Map<String, dynamic>);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('google_mlkit_text_recognizer'),
            (_) async => null);
  });

  Widget form(Future<String?> Function(BuildContext) scanner,
          {int lines = 1, String serviceType = 'Sell'}) =>
      MaterialApp(
          home: SellOutReportCreateScreen(
        serviceType: serviceType,
        existingReport: SellOutReport(
            serviceType: serviceType,
            sellerName: 'Employee',
            lines: List.generate(
                lines,
                (i) => SellOutReportLine(
                    productName: 'Phone $i', serialNumber: 'ORIGINAL$i'))),
        serialNumberScanner: scanner,
      ));

  Finder serial(int index) => find
      .byWidgetPredicate((w) =>
          w is TextField &&
          w.decoration?.labelText == translate('sell_out_report.serial_number'))
      .at(index);

  Future<void> tapScan(WidgetTester tester, int index) async {
    final button = find.byKey(ValueKey('sell-serial-scan-$index'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets(
      'scan fills only the selected Sell product serial and allows editing',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(form((_) async => '  ABC123456  ', lines: 2));
    await tester.pumpAndSettle();
    await tapScan(tester, 1);
    expect(tester.widget<TextField>(serial(0)).controller!.text, 'ORIGINAL0');
    expect(tester.widget<TextField>(serial(1)).controller!.text, 'ABC123456');
    await tester.enterText(serial(1), 'EDIT1234');
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(serial(1)).controller!.text, 'EDIT1234');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Material scan fills the selected row and preserves its serial rules',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(form((_) async => '  MAT-123456789012345678  ',
        lines: 2, serviceType: 'Material'));
    await tester.pumpAndSettle();
    await tapScan(tester, 1);
    expect(tester.widget<TextField>(serial(0)).controller!.text, 'ORIGINAL0');
    expect(tester.widget<TextField>(serial(1)).controller!.text,
        'MAT-123456789012345678');
    await tester.enterText(serial(1), 'MANUAL-123');
    expect(tester.widget<TextField>(serial(1)).controller!.text, 'MANUAL-123');
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelled Material scan preserves its serial', (tester) async {
    await tester.pumpWidget(form((_) async => null, serviceType: 'Material'));
    await tester.pumpAndSettle();
    await tapScan(tester, 0);
    expect(tester.widget<TextField>(serial(0)).controller!.text, 'ORIGINAL0');
    expect(tester.takeException(), isNull);
  });

  for (final value in <String?>[
    null,
    '',
    '123',
    'https://example.test/ABC123',
    'ABC123456789012345'
  ]) {
    testWidgets(
        'cancelled or invalid scan preserves the existing serial: $value',
        (tester) async {
      await tester.pumpWidget(form((_) async => value));
      await tester.pumpAndSettle();
      await tapScan(tester, 0);
      expect(tester.widget<TextField>(serial(0)).controller!.text, 'ORIGINAL0');
      if (value != null && value.isNotEmpty)
        expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final service in ['', 'លក់', 'Material', 'សម្ភារ']) {
    testWidgets(
        'scanner supports Sell and Material forms including localized types: $service',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      Localization.load(
          jsonDecode(File('assets/i18n/km.json').readAsStringSync())
              as Map<String, dynamic>);
      await tester
          .pumpWidget(form((_) async => 'SCAN123456', serviceType: service));
      await tester.pumpAndSettle();
      await tapScan(tester, 0);
      expect(
          tester.widget<TextField>(serial(0)).controller!.text, 'SCAN123456');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('scanner errors preserve manual input and show a useful message',
      (tester) async {
    await tester.pumpWidget(
        form((_) async => throw PlatformException(code: 'camera_denied')));
    await tester.pumpAndSettle();
    await tapScan(tester, 0);
    expect(tester.widget<TextField>(serial(0)).controller!.text, 'ORIGINAL0');
    expect(
        find.text(
            'Unable to open the scanner. Check camera permission and try again.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'hidden commission policy keeps the form usable without commission previews',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: SellOutReportCreateScreen(
            serviceType: 'Sell',
            commissionPolicy: const CommissionPolicy(),
            existingReport: SellOutReport(
                serviceType: 'Sell',
                sellerName: 'Employee',
                serverCommission: 999,
                lines: [
                  SellOutReportLine(
                      serialNumber: 'VALID123', qty: 100, unitPrice: 1)
                ]))));
    await tester.pumpAndSettle();
    expect(find.text('Commission'), findsNothing);
    expect(find.byTooltip('View Commission Rules'), findsNothing);
    expect(find.byKey(const ValueKey('sell-serial-scan-0')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'edited totals apply the admin minimum amount and rate to the preview',
      (tester) async {
    const rule = CommissionRule(
        enabled: true,
        rate: 3,
        perItem: false,
        requirePhone: false,
        minimumAmount: 10,
        partTimeQuantity: 0,
        fullTimeQuantity: 0);
    const p = CommissionPolicy(
        visible: true,
        enabled: true,
        canCalculate: true,
        rules: {'material': rule});
    await tester.pumpWidget(MaterialApp(
        home: SellOutReportCreateScreen(
            serviceType: 'Material',
            commissionPolicy: p,
            existingReport: SellOutReport(
                serviceType: 'Material',
                sellerName: 'Employee',
                serverTotalAmount: 5,
                lines: [SellOutReportLine(qty: 1, unitPrice: 5)]))));
    await tester.pumpAndSettle();
    final price = find.byWidgetPredicate((w) =>
        w is TextField &&
        w.decoration?.labelText == translate('sell_out_report.unit_price'));
    await tester.ensureVisible(price);
    await tester.enterText(price, '20');
    await tester.pumpAndSettle();
    expect(find.text(r'$20.00'), findsWidgets);
    expect(find.text(r'$3.00'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
