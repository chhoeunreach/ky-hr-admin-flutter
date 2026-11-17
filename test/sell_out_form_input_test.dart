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

  for (final entry in [
    ['qty', '', 'quantity_validation'],
    ['qty', '0', 'quantity_validation'],
    ['qty', '1.5', 'quantity_validation'],
    ['unit_price', '', 'unit_price_validation'],
    ['unit_price', '-1', 'unit_price_validation'],
    ['unit_price', 'NaN', 'unit_price_validation'],
    ['unit_price', 'Infinity', 'unit_price_validation'],
  ]) {
    testWidgets('invalid ${entry[0]} "${entry[1]}" stays editable after submit',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
          home: SellOutReportCreateScreen(
        serviceType: 'Material',
        commissionPolicy: const CommissionPolicy(),
        existingReport: SellOutReport(
            serviceType: 'Material',
            sellerName: 'Seller',
            createdAt: DateTime.now().toIso8601String()),
      )));
      await tester.pumpAndSettle();
      final field = find.byWidgetPredicate((widget) =>
          widget is TextField &&
          widget.decoration?.labelText ==
              translate('sell_out_report.${entry[0]}'));
      await tester.ensureVisible(field);
      await tester.enterText(field, entry[1]);
      await tester.pumpAndSettle();
      final submit = find.widgetWithText(ElevatedButton, 'Update Report');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text(translate('sell_out_report.${entry[2]}')), findsWidgets);
      expect(tester.widget<TextField>(field).controller!.text, entry[1]);
      await tester.tap(find.descendant(
          of: find.byType(AlertDialog), matching: find.byType(TextButton)));
      await tester.pumpAndSettle();
      await tester.ensureVisible(field);
      await tester.enterText(field, entry[0] == 'qty' ? '2' : '12.50');
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).decoration!.errorText, isNull);
      expect(tester.testTextInput.isVisible, isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'removing an earlier product keeps the active number field mounted',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        home: SellOutReportCreateScreen(
      serviceType: 'Sell',
      commissionPolicy: const CommissionPolicy(),
      existingReport: SellOutReport(
          serviceType: 'Sell',
          sellerName: 'Seller',
          lines: [SellOutReportLine(), SellOutReportLine()]),
    )));
    await tester.pumpAndSettle();
    final quantities = find.byWidgetPredicate((widget) =>
        widget is TextField &&
        widget.decoration?.labelText == translate('sell_out_report.qty'));
    await tester.ensureVisible(quantities.last);
    await tester.pumpAndSettle();
    await tester.tap(quantities.last);
    await tester.pump();
    final active = tester.state<EditableTextState>(find.descendant(
        of: quantities.last, matching: find.byType(EditableText)));
    tester.testTextInput.updateEditingValue(const TextEditingValue(
        text: '42', selection: TextSelection.collapsed(offset: 2)));
    await tester.pump();
    tester
        .widget<TextButton>(find.widgetWithText(TextButton, 'Remove').first)
        .onPressed!();
    await tester.pumpAndSettle();
    expect(active.mounted, isTrue);
    expect(active.widget.focusNode.hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
    expect(tester.widget<TextField>(quantities).controller!.text, '42');
    expect(tester.takeException(), isNull);
  });

  for (final label in ['qty', 'unit_price']) {
    testWidgets('$label keeps its input connection during keyboard animation',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(MaterialApp(
          home: SellOutReportCreateScreen(
        serviceType: 'Sell',
        commissionPolicy: const CommissionPolicy(),
        existingReport: SellOutReport(
            serviceType: 'Sell',
            sellerName: 'Seller',
            lines: List.generate(3, (_) => SellOutReportLine())),
      )));
      await tester.pumpAndSettle();
      final field = find
          .byWidgetPredicate((widget) =>
              widget is TextField &&
              widget.decoration?.labelText ==
                  translate('sell_out_report.$label'))
          .last;
      expect(
          tester.widget<TextField>(field).keyboardType,
          label == 'qty'
              ? TextInputType.number
              : const TextInputType.numberWithOptions(decimal: true));
      await tester.ensureVisible(field);
      await tester.pumpAndSettle();
      await tester.tap(field);
      await tester.pump();
      final original = tester.state<EditableTextState>(
          find.descendant(of: field, matching: find.byType(EditableText)));
      for (final inset in [60.0, 120.0, 180.0, 240.0, 300.0]) {
        tester.view.viewInsets = FakeViewPadding(bottom: inset);
        await tester.pump(const Duration(milliseconds: 60));
        expect(original.mounted, isTrue);
        expect(original.widget.focusNode.hasFocus, isTrue);
        expect(tester.testTextInput.isVisible, isTrue);
      }
      await tester.pumpAndSettle();
      expect(original.widget.focusNode.hasFocus, isTrue);
      tester.testTextInput.updateEditingValue(const TextEditingValue(
          text: '12', selection: TextSelection.collapsed(offset: 2)));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller!.text, '12');
      expect(original.widget.focusNode.hasFocus, isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  for (final service in [
    'Sell',
    'Material',
    'Iron',
    'Repair',
    'Buy In',
    'SellSim',
    'iCloud Cus'
  ]) {
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      testWidgets(
          '$service on $platform preserves typing and focus when the keyboard opens',
          (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpWidget(MaterialApp(
            theme: ThemeData(platform: platform),
            home: SellOutReportCreateScreen(
              serviceType: service,
              commissionPolicy: const CommissionPolicy(),
              existingReport:
                  SellOutReport(serviceType: service, sellerName: 'Seller'),
            )));
        await tester.pumpAndSettle();

        final fields = service == 'iCloud Cus'
            ? [
                'customer_phone',
                'note',
                'account_name',
                'apple_id_email',
                'icloud_storage',
                'trusted_phone',
                'devices'
              ]
            : [
                'customer_phone',
                'note',
                'product_name',
                'color',
                'storage',
                'qty',
                'unit_price'
              ];
        for (final label in fields) {
          final field = find.byWidgetPredicate((widget) =>
              widget is TextField &&
              widget.decoration?.labelText ==
                  translate('sell_out_report.$label'));
          await tester.ensureVisible(field);
          await tester.pumpAndSettle();
          await tester.tap(field);
          await tester.pump();
          tester.view.viewInsets =
              FakeViewPadding(bottom: 300 * tester.view.devicePixelRatio);
          await tester.pumpAndSettle();
          final editable =
              find.descendant(of: field, matching: find.byType(EditableText));
          expect(
              tester.widget<EditableText>(editable).focusNode.hasFocus, isTrue,
              reason:
                  '$service / $label must keep focus as the keyboard opens');
          for (final text in ['1', '12', '123']) {
            tester.testTextInput.updateEditingValue(TextEditingValue(
                text: text,
                selection: TextSelection.collapsed(offset: text.length)));
            await tester.pump();
            expect(tester.widget<TextField>(field).controller!.text, text);
            expect(tester.widget<EditableText>(editable).focusNode.hasFocus,
                isTrue);
            expect(tester.testTextInput.isVisible, isTrue);
          }
          tester.testTextInput.updateEditingValue(const TextEditingValue());
          await tester.pump();
          expect(tester.widget<TextField>(field).controller!.text, isEmpty);
          tester.view.resetViewInsets();
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
