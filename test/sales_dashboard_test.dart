import 'dart:convert';
import 'dart:io';

import 'package:cnattendance/models/sell_out_report.dart';
import 'package:cnattendance/models/sell_out_report_line.dart';
import 'package:cnattendance/widget/sell_out/sales_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final translations =
      (jsonDecode(File('assets/i18n/en.json').readAsStringSync())
          as Map<String, dynamic>)['sell_out_report'] as Map<String, dynamic>;
  final date = DateTime(2026, 11, 9);
  final records = List.generate(
      8,
      (i) => SellOutReport(
            invoiceNo: 'INV-${i + 1}',
            customerName: 'Customer ${i + 1}',
            customerPhone: i == 1 ? '' : '012345678',
            serviceType: i == 2 ? 'Buy In' : 'Material',
            createdAt: date.toIso8601String(),
            lines: [SellOutReportLine(qty: 2, unitPrice: 25)],
          ));
  final reportsKey = GlobalKey();
  SellOutReport? opened;
  SellOutReport? edited;
  var exports = 0;

  Widget dashboard(List<SellOutReport> reports, {String language = 'en'}) {
    final labels = language == 'en'
        ? translations
        : (jsonDecode(File('assets/i18n/km.json').readAsStringSync())
            as Map<String, dynamic>)['sell_out_report'] as Map<String, dynamic>;
    return MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
      child: Padding(
          padding: const EdgeInsets.all(12),
          child: SalesDashboard(
            reports: reports,
            translate: (key) => labels[key] as String,
            onOpen: (report) => opened = report,
            onEdit: (report) => edited = report,
            canEdit: (_) => true,
            onExport: () => exports++,
            onFilter: () {},
            emptyState: const Text('No reports'),
            reportsKey: reportsKey,
          )),
    )));
  }

  testWidgets('sales totals and report actions work', (tester) async {
    await tester.binding.setSurfaceSize(const Size(850, 1250));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(dashboard(records));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Sales Reports (8)'), findsOneWidget);
    expect(find.text('\$400.00'), findsOneWidget);
    expect(find.text('Sales Summary'), findsNothing);
    expect(find.text('Failed'), findsNWidgets(2));
    expect(find.text('Other'), findsOneWidget);
    await tester.tap(find.text('INV-1'));
    expect(opened, same(records.first));
    await tester.tap(find.byTooltip('Edit Report').first);
    expect(edited, same(records.first));
    await tester.tap(find.byTooltip('Export reports'));
    expect(exports, 1);
  });

  testWidgets(
      'commission appears per invoice with calculation and failure reasons',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1250));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(dashboard(records));
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('invoice-commission-INV-1')), findsOneWidget);
    expect(
        tester
            .widget<Text>(
                find.byKey(const ValueKey('invoice-commission-INV-1')))
            .data,
        '\$0.25');
    expect(
        tester
            .widget<Text>(
                find.byKey(const ValueKey('invoice-commission-INV-2')))
            .data,
        '\$0.00');
    await tester.tap(find.byKey(const ValueKey('commission-summary')));
    await tester.pumpAndSettle();
    expect(find.text('Commission Calculation'), findsOneWidget);
    expect(find.text('Total Commission'), findsOneWidget);
    expect(find.text('1 × \$0.25 = \$0.25'), findsWidgets);
    expect(find.text('Phone number required'), findsOneWidget);
    expect(find.text('No commission condition'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pagination resets when filtered records change', (tester) async {
    await tester.binding.setSurfaceSize(const Size(850, 1250));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final pagedRecords = List.generate(
        31,
        (i) => SellOutReport(
              invoiceNo: 'INV-${i + 1}',
              createdAt: date.toIso8601String(),
            ));
    await tester.pumpWidget(dashboard(pagedRecords));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Next page'));
    await tester.tap(find.byTooltip('Next page'));
    await tester.pumpAndSettle();
    expect(find.text('Showing 26–31 of 31'), findsOneWidget);
    expect(find.text('INV-1'), findsNothing);
    expect(find.text('INV-26'), findsOneWidget);
    await tester.pumpWidget(dashboard(records.take(2).toList()));
    await tester.pumpAndSettle();
    expect(find.text('Showing 1–2 of 2'), findsOneWidget);
    expect(find.text('INV-1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'numbered pages and page size browse all data without changing totals',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(850, 1250));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final manyReports = List.generate(
        131,
        (i) => SellOutReport(
              invoiceNo: 'PAGE-INV-${i + 1}',
              serviceType: 'Material',
              customerPhone: '012345678',
              createdAt: date.toIso8601String(),
              lines: [SellOutReportLine(qty: 2, unitPrice: 25)],
            ));
    await tester.pumpWidget(dashboard(manyReports));
    await tester.pumpAndSettle();
    expect(find.text('Page 1 of 6'), findsOneWidget);
    expect(find.text('\$6,550.00'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('sales-page-3')));
    await tester.tap(find.byKey(const ValueKey('sales-page-3')));
    await tester.pumpAndSettle();
    expect(find.text('Showing 51–75 of 131'), findsOneWidget);
    expect(find.text('PAGE-INV-51'), findsOneWidget);
    expect(find.text('PAGE-INV-1'), findsNothing);
    await tester.ensureVisible(find.byTooltip('Last page'));
    await tester.tap(find.byTooltip('Last page'));
    await tester.pumpAndSettle();
    expect(find.text('PAGE-INV-131'), findsOneWidget);
    expect(find.text('Page 6 of 6'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('sales-page-size')));
    await tester.tap(find.byKey(const ValueKey('sales-page-size')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('100').last);
    await tester.pumpAndSettle();
    expect(find.text('Showing 1–100 of 131'), findsOneWidget);
    expect(find.text('Page 1 of 2'), findsOneWidget);
    expect(find.text('PAGE-INV-1'), findsOneWidget);
    expect(find.text('PAGE-INV-100'), findsOneWidget);
    expect(find.text('PAGE-INV-101'), findsNothing);
    expect(find.text('\$6,550.00'), findsOneWidget);
    for (final option in ['250', '500', 'All']) {
      await tester.tap(find.byKey(const ValueKey('sales-page-size')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(option).last);
      await tester.pumpAndSettle();
      expect(find.text('Showing 1–131 of 131'), findsOneWidget);
      expect(find.text('Page 1 of 1'), findsOneWidget);
      expect(find.text('PAGE-INV-131'), findsOneWidget);
    }
    expect(find.text('Show All'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sales-page-size')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('25').last);
    await tester.pumpAndSettle();
    expect(find.text('Showing 1–25 of 131'), findsOneWidget);
    expect(find.text('Page 1 of 6'), findsOneWidget);
    expect(find.text('PAGE-INV-26'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0, 768.0]) {
    for (final language in ['en', 'km']) {
      testWidgets('$language layout fits width $width and empty state',
          (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 1100));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(dashboard(records, language: language));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(dashboard([], language: language));
        await tester.pumpAndSettle();
        expect(find.text('No reports'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
