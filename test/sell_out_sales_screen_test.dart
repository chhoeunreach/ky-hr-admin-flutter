import 'dart:convert';
import 'package:cnattendance/models/commission_policy.dart';
import 'dart:io';

import 'package:cnattendance/models/sell_out_report.dart';
import 'package:cnattendance/models/sell_out_report_line.dart';
import 'package:cnattendance/screen/sell_out_report_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime.now();
  final records = [
    SellOutReport(
        invoiceNo: 'INV-TODAY',
        serviceType: 'Sell',
        customerName: 'Sok Chea',
        customerPhone: '012345678',
        createdAt: today.toIso8601String(),
        lines: [
          SellOutReportLine(
              productName: 'iPhone sample', qty: 100, unitPrice: 2)
        ]),
    SellOutReport(
        invoiceNo: 'INV-FAILED',
        serviceType: 'Sell',
        customerName: 'Dara',
        createdAt: today.toIso8601String(),
        lines: [SellOutReportLine(qty: 1, unitPrice: 30)]),
    SellOutReport(
        invoiceNo: 'INV-OLD',
        serviceType: 'Sell',
        createdAt: DateTime(today.year, today.month - 1, 15).toIso8601String()),
    SellOutReport(
        invoiceNo: 'INV-MATERIAL',
        serviceType: 'Material',
        createdAt: today.toIso8601String()),
  ];

  Widget screen({List<SellOutReport>? data}) => MaterialApp(
          home: SellOutReportScreen(
        serviceType: 'Sell',
        reportLoader: () async => data ?? records,
      ));

  setUp(() {
    Localization.load(jsonDecode(File('assets/i18n/en.json').readAsStringSync())
        as Map<String, dynamic>);
  });

  testWidgets(
      'a hidden server policy removes module commission and qualification controls',
      (tester) async {
    await tester.pumpWidget(screen(data: [
      SellOutReport(
          serviceType: 'Sell',
          invoiceNo: 'HIDDEN-1',
          createdAt: today.toIso8601String(),
          commissionPolicy: const CommissionPolicy(),
          serverCommission: 999,
          lines: [SellOutReportLine(qty: 100, unitPrice: 1)])
    ]));
    await tester.pumpAndSettle();
    expect(find.text('Commission'), findsNothing);
    expect(find.text('Qualified'), findsNothing);
    expect(find.text('Failed'), findsNothing);
    expect(find.byKey(const ValueKey('commission-mode')), findsNothing);
    expect(find.byKey(const ValueKey('invoice-commission-HIDDEN-1')),
        findsNothing);
    await tester.tap(find.byKey(const ValueKey('pos-nav-more')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Commission Rules'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search and section navigation use the loaded reports',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Sales Reports (2)'), findsOneWidget);
    expect(find.text('INV-OLD'), findsNothing);
    expect(find.text('INV-MATERIAL'), findsNothing);
    await tester.enterText(find.byType(TextField), 'iPhone');
    await tester.pumpAndSettle();
    expect(find.text('Sales Reports (1)'), findsOneWidget);
    expect(find.text('INV-TODAY'), findsOneWidget);
    expect(find.text('INV-FAILED'), findsNothing);
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    expect(find.text('INV-FAILED'), findsOneWidget);
    expect(find.text('INV-TODAY'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pos-nav-sell')));
    await tester.pumpAndSettle();
    expect(find.byType(TextField).hitTestable(), findsOneWidget);
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Commission Rules'));
    await tester.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byType(BottomSheet),
            matching: find.text('Commission Rules')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'monthly and yearly report scopes recalculate commission with selectable conditions',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(850, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final periodRecords = [
      SellOutReport(
          invoiceNo: 'PERIOD-A',
          sellerName: 'Seller',
          serviceType: 'Sell',
          customerPhone: '012345678',
          createdAt: today.toIso8601String(),
          serverCommission: 0,
          lines: [SellOutReportLine(qty: 60, unitPrice: 1)]),
      SellOutReport(
          invoiceNo: 'PERIOD-B',
          sellerName: 'Seller',
          serviceType: 'Sell',
          customerPhone: '012345678',
          createdAt:
              DateTime(today.year, today.month == 1 ? 2 : today.month - 1, 15)
                  .toIso8601String(),
          serverCommission: 0,
          lines: [SellOutReportLine(qty: 40, unitPrice: 1)]),
    ];
    await tester.pumpWidget(screen(data: periodRecords));
    await tester.pumpAndSettle();
    expect(find.text('Sales Reports (1)'), findsOneWidget);
    expect(
        tester
            .widget<Text>(
                find.byKey(const ValueKey('invoice-commission-PERIOD-A')))
            .data,
        '\$0.00');
    await tester.tap(find.text('This Year'));
    await tester.pumpAndSettle();
    expect(find.text('Sales Reports (2)'), findsOneWidget);
    expect(
        tester
            .widget<Text>(
                find.byKey(const ValueKey('invoice-commission-PERIOD-A')))
            .data,
        '\$15.00');
    expect(
        tester
            .widget<Text>(
                find.byKey(const ValueKey('invoice-commission-PERIOD-B')))
            .data,
        '\$10.00');
    await tester.pumpAndSettle();
    expect(find.text('Sales Reports (2)'), findsOneWidget);
    await tester.tap(find.text('This Month'));
    await tester.pumpAndSettle();
    expect(find.text('Sales Reports (1)'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('commission-mode')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(
        CheckedPopupMenuItem<String>, 'Without conditions'));
    await tester.pumpAndSettle();
    expect(find.text('Sales Reports (1)'), findsOneWidget);
    expect(
        tester
            .widget<Text>(
                find.byKey(const ValueKey('invoice-commission-PERIOD-A')))
            .data,
        '\$15.00');
    await tester.tap(find.byKey(const ValueKey('commission-mode')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Commission Rules'));
    await tester.pumpAndSettle();
    expect(find.text('Commission rules are managed by your administrator.'),
        findsOneWidget);
    expect(find.text('Full-time minimum quantity: 100'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'date field opens the range picker and shortcuts use current calendar periods',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(850, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sales-date-range')));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<DateRangePickerDialog>(find.byType(DateRangePickerDialog))
            .initialDateRange,
        DateTimeRange(
            start: DateUtils.dateOnly(today), end: DateUtils.dateOnly(today)));
    Navigator.of(tester.element(find.byType(DateRangePickerDialog))).pop();
    await tester.pumpAndSettle();
    final expected = <String, DateTimeRange>{
      'Last Month': DateTimeRange(
          start: DateTime(today.year, today.month - 1),
          end: DateTime(today.year, today.month, 0)),
      'This Year': DateTimeRange(
          start: DateTime(today.year), end: DateTime(today.year, 12, 31)),
      'This Month': DateTimeRange(
          start: DateTime(today.year, today.month),
          end: DateTime(today.year, today.month + 1, 0)),
    };
    for (final entry in expected.entries) {
      await tester.tap(find.text(entry.key));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sales-date-range')));
      await tester.pumpAndSettle();
      final dialog = tester
          .widget<DateRangePickerDialog>(find.byType(DateRangePickerDialog));
      expect(dialog.initialDateRange, entry.value);
      Navigator.of(tester.element(find.byType(DateRangePickerDialog))).pop();
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const ValueKey('sales-date-range')));
    await tester.pumpAndSettle();
    final custom = DateTimeRange(
        start: DateTime(today.year, today.month, 2),
        end: DateTime(today.year, today.month, 5));
    Navigator.of(tester.element(find.byType(DateRangePickerDialog)))
        .pop(custom);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sales-date-range')));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<DateRangePickerDialog>(find.byType(DateRangePickerDialog))
            .initialDateRange,
        custom);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Khmer report options fit a narrow phone', (tester) async {
    Localization.load(jsonDecode(File('assets/i18n/km.json').readAsStringSync())
        as Map<String, dynamic>);
    await tester.binding.setSurfaceSize(const Size(320, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('commission-mode')), findsOneWidget);
  });

  for (final service in ['Material', 'Iron', 'Repair', 'Buy In']) {
    for (final language in ['en', 'km']) {
      testWidgets(
          '$service shares the Sell layout and keeps its rules in $language',
          (tester) async {
        final labels =
            jsonDecode(File('assets/i18n/$language.json').readAsStringSync())
                as Map<String, dynamic>;
        Localization.load(labels);
        await tester.binding.setSurfaceSize(const Size(320, 1250));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final serviceRecords = [
          SellOutReport(
              invoiceNo: 'SERVICE-OK',
              serviceType: service,
              customerPhone: '012345678',
              createdAt: today.toIso8601String(),
              lines: [SellOutReportLine(qty: 1, unitPrice: 10)]),
          SellOutReport(
              invoiceNo: 'SERVICE-NO-PHONE',
              serviceType: service,
              createdAt: today.toIso8601String(),
              lines: [SellOutReportLine(qty: 1, unitPrice: 10)]),
          ...records.where((r) =>
              SellOutReport.canonicalServiceType(r.serviceType) !=
              SellOutReport.canonicalServiceType(service)),
        ];
        final canonical = SellOutReport.canonicalServiceType(service);
        final display = (labels['home_screen']
            as Map<String, dynamic>)['service_$canonical'] as String;
        final reportLabels = labels['sell_out_report'] as Map<String, dynamic>;
        await tester.pumpWidget(MaterialApp(
            home: SellOutReportScreen(
          serviceType: display,
          reportLoader: () async => serviceRecords,
        )));
        await tester.pumpAndSettle();
        expect(
            find.text(
                '${(reportLabels['service_reports'] as String).replaceAll('{service}', display)} (2)'),
            findsOneWidget);
        expect(
            find.text((reportLabels['new_service'] as String)
                .replaceAll('{service}', display)),
            findsOneWidget);
        expect(find.text('INV-TODAY'), findsNothing);
        final rate = service == 'Material'
            ? '\$0.25'
            : service == 'Buy In'
                ? '\$0.00'
                : '\$0.20';
        expect(
            tester
                .widget<Text>(
                    find.byKey(const ValueKey('invoice-commission-SERVICE-OK')))
                .data,
            rate);
        expect(
            tester
                .widget<Text>(find.byKey(
                    const ValueKey('invoice-commission-SERVICE-NO-PHONE')))
                .data,
            '\$0.00');
        expect(find.byKey(const ValueKey('sales-page-size')), findsOneWidget);
        expect(find.byKey(const ValueKey('commission-mode')), findsOneWidget);
        expect(find.byKey(const ValueKey('sales-date-range')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final width in [320.0, 768.0]) {
    testWidgets('full screen fits width $width', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('New Sale'), findsOneWidget);
      expect(
          tester.getCenter(find.byKey(const ValueKey('sales-date-range'))).dy,
          closeTo(
              tester
                  .getCenter(
                      find.byKey(const ValueKey('date-preset-this_month')))
                  .dy,
              1));
    });
  }
}
