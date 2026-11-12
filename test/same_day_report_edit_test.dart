import 'dart:convert';
import 'dart:io';

import 'package:cnattendance/models/commission_policy.dart';
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

  for (final service in [
    'Sell',
    'Material',
    'Iron',
    'Repair',
    'Buy In',
    'iCloud Cus'
  ]) {
    test('$service can edit only on its creation date', () {
      final report = SellOutReport(
          serviceType: service,
          createdAt: DateTime(2026, 11, 10, 0, 1).toIso8601String());
      expect(report.isCreatedToday(now: DateTime(2026, 11, 10, 23, 59, 59)),
          isTrue);
      expect(report.isCreatedToday(now: DateTime(2026, 11, 11)), isFalse);
      expect(report.isCreatedToday(now: DateTime(2026, 11, 9)), isFalse);
      report.createdAt = '';
      expect(report.isCreatedToday(now: DateTime(2026, 11, 10)), isFalse);
    });

    testWidgets('$service blocks submitting an expired edit form',
        (tester) async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      await tester.pumpWidget(MaterialApp(
          home: SellOutReportCreateScreen(
        serviceType: service,
        commissionPolicy: const CommissionPolicy(),
        existingReport: SellOutReport(
            id: 1,
            serviceType: service,
            createdAt: yesterday.toIso8601String(),
            sellerName: 'Employee',
            lines: [
              SellOutReportLine(
                  productName: 'Saved item',
                  serialNumber: 'SERIAL123',
                  qty: 1,
                  unitPrice: 10)
            ]),
      )));
      await tester.pumpAndSettle();
      final button = find.widgetWithText(ElevatedButton, 'Update Report');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('Only reports created today can be edited.'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'iCloud editing restores saved fields and separates the generated note',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: SellOutReportCreateScreen(
      serviceType: 'iCloud Cus',
      commissionPolicy: const CommissionPolicy(),
      existingReport: SellOutReport(
          id: 1,
          serviceType: 'iCloud Cus',
          createdAt: DateTime.now().toIso8601String(),
          sellerName: 'Employee',
          customerPhone: '012345678',
          note:
              'Keep this note\n\niCloud Info\nAccount Name: Saved Account\nApple ID: saved@example.test\niCloud Storage: 200 GB\nTrusted Phone: 099123456\nDevices: iPhone\niPad',
          extractedText: 'Original OCR content',
          lines: [
            SellOutReportLine(
                productName: 'iCloud Cus - Old account',
                sku: 'old@example.test',
                storage: '50 GB')
          ]),
    )));
    await tester.pumpAndSettle();
    for (final entry in {
      'account_name': 'Saved Account',
      'apple_id_email': 'saved@example.test',
      'icloud_storage': '200 GB',
      'trusted_phone': '099123456',
      'devices': 'iPhone\niPad',
      'note': 'Keep this note'
    }.entries) {
      final field = find.byWidgetPredicate((w) =>
          w is TextField &&
          w.decoration?.labelText == translate('sell_out_report.${entry.key}'), skipOffstage: false);
      expect(field, findsOneWidget);
      expect(tester.widget<TextField>(field).controller!.text, entry.value);
    }
    expect(tester.takeException(), isNull);
  });
}
