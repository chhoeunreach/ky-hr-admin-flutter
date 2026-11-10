import 'dart:async';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import 'package:cnattendance/features/pos/providers/pos_reporting_provider.dart';
import 'package:cnattendance/features/pos/widgets/pos_filters_bar.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cnattendance/screen/sell_out_report_screen.dart';
import 'package:cnattendance/models/sell_out_report.dart';
import 'package:cnattendance/features/pos/models/pos_report.dart';
import 'package:cnattendance/features/pos/pages/pos_workspace_screen.dart';
import 'package:cnattendance/features/pos/widgets/pos_components.dart';
import 'package:cnattendance/features/pos/services/pos_reporting_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'fixtures/pos_report_fixture.dart';

class WorkspaceRepository implements PosReportingRepository {
  final List<PosFilters> calls = [];
  int total = 21;
  List<String> modules = posModules;
  Object? error;
  Map<String, dynamic>? commissionPolicy;
  Completer<PosReport>? pending;
  @override
  Future<PosReport> load(PosFilters filters) async {
    calls.add(filters);
    if (error != null) throw error!;
    return pending?.future ??
        PosReport.fromJson({
          ...posFixture(filters, total: total, modules: modules),
          if (commissionPolicy != null) 'commission_policy': commissionPolicy
        });
  }

  @override
  Future<List<int>> export(PosFilters filters) async =>
      utf8.encode('Reference,Amount\nPOS-1,10');
}

void main() {
  void labels(String language) => Localization.load(
      jsonDecode(File('assets/i18n/$language.json').readAsStringSync())
          as Map<String, dynamic>);
  Widget app(WorkspaceRepository repository, {String initial = 'dashboard'}) {
    Widget module(String type) => SellOutReportScreen(
          serviceType: posServiceLabel(type),
          reportLoader: () async => [...posModules, 'icloud_cus']
              .map((service) => SellOutReport(
                    id: [...posModules, 'icloud_cus'].indexOf(service) + 1,
                    invoiceNo: 'ORIGINAL-$service',
                    serviceType: service,
                    customerPhone: '012345678',
                    createdAt: DateTime.now().toIso8601String(),
                  ))
              .toList(),
        );
    Widget dashboard() => PosWorkspaceScreen(
        repository: repository, initialModule: initial, moduleBuilder: module);
    return MaterialApp(
        home: dashboard(), routes: {posDashboardRoute: (_) => dashboard()});
  }

  setUp(() => labels('en'));
  Future<void> scrollTo(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(target, 300,
        scrollable: find.byType(Scrollable).first, maxScrolls: 40);
    await tester.pumpAndSettle();
  }

  for (final language in ['en', 'km']) {
    for (final width in [320.0, 390.0, 768.0]) {
      testWidgets('$language POS dashboard fits $width with backend figures',
          (tester) async {
        labels(language);
        await tester.binding.setSurfaceSize(Size(width, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final repository = WorkspaceRepository();
        await tester.pumpWidget(app(repository));
        await tester.pumpAndSettle();
        expect(find.byType(PosKpiCard), findsNWidgets(6));
        expect(find.text('\$210.00'), findsWidgets);
        expect(find.byKey(const ValueKey('pos-nav-material')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await scrollTo(tester, find.byKey(const ValueKey('pos-next-page')));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
      'dashboard buttons open the approved module screens and return to Dashboard',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = WorkspaceRepository()..total = 1;
    await tester.pumpWidget(app(repository));
    await tester.pumpAndSettle();
    for (final module in ['sell', 'material', 'iron']) {
      await tester.tap(find.byKey(ValueKey('pos-nav-$module')));
      await tester.pumpAndSettle();
      final screen =
          tester.widget<SellOutReportScreen>(find.byType(SellOutReportScreen));
      expect(SellOutReport.canonicalServiceType(screen.serviceType), module);
      expect(find.byKey(const ValueKey('sales-page-size')), findsOneWidget);
      expect(find.byType(PosKpiCard), findsNothing);
      await tester.tap(find.byKey(const ValueKey('pos-nav-dashboard')));
      await tester.pumpAndSettle();
      expect(find.byType(PosWorkspaceScreen), findsOneWidget);
    }
    await scrollTo(tester, find.byKey(const ValueKey('pos-quick-repair')));
    await tester.tap(find.byKey(const ValueKey('pos-quick-repair')));
    await tester.pumpAndSettle();
    expect(
        SellOutReport.canonicalServiceType(tester
            .widget<SellOutReportScreen>(find.byType(SellOutReportScreen))
            .serviceType),
        'repair');
    await tester.tap(find.byKey(const ValueKey('pos-nav-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Buy In'));
    await tester.pumpAndSettle();
    expect(
        SellOutReport.canonicalServiceType(tester
            .widget<SellOutReportScreen>(find.byType(SellOutReportScreen))
            .serviceType),
        'buy_in');
    expect(find.byKey(const ValueKey('sales-page-size')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final language in ['en', 'km']) {
    for (final width in [390.0, 768.0]) {
      testWidgets(
          '$language all six dashboard shortcuts and module navigation work at $width',
          (tester) async {
        labels(language);
        await tester.binding.setSurfaceSize(Size(width, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(app(WorkspaceRepository()..total = 1));
        await tester.pumpAndSettle();
        void expectModule(String module) {
          final screen = tester
              .widget<SellOutReportScreen>(find.byType(SellOutReportScreen));
          expect(
              SellOutReport.canonicalServiceType(screen.serviceType), module);
          expect(find.byKey(const ValueKey('sales-page-size')), findsOneWidget);
          expect(tester.takeException(), isNull);
        }

        for (final module in [...posModules, 'icloud_cus']) {
          final shortcut = find.byKey(ValueKey('pos-quick-$module'));
          await scrollTo(tester, shortcut);
          await tester.tap(shortcut);
          await tester.pumpAndSettle();
          expectModule(module);
          if (module == 'icloud_cus') {
            final more = tester.widget<Semantics>(find
                .ancestor(
                    of: find.byKey(const ValueKey('pos-nav-more')),
                    matching: find.byType(Semantics))
                .first);
            expect(more.properties.selected, isTrue);
          }
          // Every module must support the complete bottom-navigation loop.
          for (final destination in posModules) {
            if (width < 650 && ['repair', 'buy_in'].contains(destination)) {
              await tester.tap(find.byKey(const ValueKey('pos-nav-more')));
              await tester.pumpAndSettle();
              await tester.tap(
                  find.widgetWithText(ListTile, posServiceLabel(destination)));
            } else {
              await tester.tap(find.byKey(ValueKey('pos-nav-$destination')));
            }
            await tester.pumpAndSettle();
            expectModule(destination);
          }
          await tester.tap(find.byKey(const ValueKey('pos-nav-more')));
          await tester.pumpAndSettle();
          await tester.tap(
              find.widgetWithText(ListTile, posServiceLabel('icloud_cus')));
          await tester.pumpAndSettle();
          expectModule('icloud_cus');
          await tester.tap(find.byKey(const ValueKey('pos-nav-dashboard')));
          await tester.pumpAndSettle();
          expect(find.byType(PosWorkspaceScreen), findsOneWidget);
        }
        // The Dashboard More menu uses the same module route as its shortcut.
        await tester.tap(find.byKey(const ValueKey('pos-nav-more')));
        await tester.pumpAndSettle();
        await tester
            .tap(find.widgetWithText(ListTile, posServiceLabel('icloud_cus')));
        await tester.pumpAndSettle();
        expectModule('icloud_cus');
      });
    }
  }

  for (final language in ['en', 'km']) {
    testWidgets(
        '$language visible date shortcuts update the API range and keep custom dates',
        (tester) async {
      labels(language);
      await tester.binding.setSurfaceSize(const Size(320, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = WorkspaceRepository()..total = 1;
      await tester.pumpWidget(app(repository));
      await tester.pumpAndSettle();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final ranges = <String, DateTimeRange>{
        'this_month': DateTimeRange(
            start: DateTime(now.year, now.month),
            end: DateTime(now.year, now.month + 1, 0)),
        'last_month': DateTimeRange(
            start: DateTime(now.year, now.month - 1),
            end: DateTime(now.year, now.month, 0)),
        'this_year': DateTimeRange(
            start: DateTime(now.year), end: DateTime(now.year, 12, 31)),
        'today': DateTimeRange(start: today, end: today),
      };
      expect(
          tester
              .widget<ChoiceChip>(
                  find.byKey(const ValueKey('pos-period-today')))
              .selected,
          isTrue);
      for (final entry in ranges.entries) {
        final shortcut = find.byKey(ValueKey('pos-period-${entry.key}'));
        expect(shortcut.hitTestable(), findsOneWidget);
        await tester.tap(shortcut);
        await tester.pumpAndSettle();
        expect(repository.calls.last.range, entry.value);
        expect(repository.calls.last.page, 1);
        expect(tester.widget<ChoiceChip>(shortcut).selected, isTrue);
        expect(tester.takeException(), isNull);
      }
      await tester.tap(find.byKey(const ValueKey('pos-date')));
      await tester.pumpAndSettle();
      expect(find.byType(DateRangePickerDialog), findsOneWidget);
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'server-hidden commission removes metrics, controls, status and rule actions',
      (tester) async {
    final repository = WorkspaceRepository()
      ..total = 1
      ..commissionPolicy = {
        'visible': false,
        'enabled': true,
        'can_calculate': false,
        'can_change_mode': false,
        'rules': {}
      };
    await tester.pumpWidget(app(repository));
    await tester.pumpAndSettle();
    expect(find.byType(PosKpiCard), findsNWidgets(3));
    expect(find.byKey(const ValueKey('pos-commission-mode')), findsNothing);
    expect(find.byType(PosStatusBadge), findsNothing);
    expect(find.textContaining('Commission:'), findsNothing);
    await scrollTo(tester, find.text(posTr('business_overview')));
    await tester.tap(find.text(posTr('business_overview')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pos-category-sell')), findsOneWidget);
    expect(find.byKey(const ValueKey('pos-breakdown-commission-header')),
        findsNothing);
    expect(find.byKey(const ValueKey('pos-category-commission-sell')),
        findsNothing);

    await tester.tap(find.byKey(const ValueKey('pos-nav-more')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Commission Rules'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'server next page loads only the next records and keeps aggregate totals',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = WorkspaceRepository();
    await tester.pumpWidget(app(repository));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.byKey(const ValueKey('pos-next-page')));
    await tester.tap(find.byKey(const ValueKey('pos-next-page')));
    await tester.pumpAndSettle();
    expect(repository.calls.last.page, 2);
    expect(find.text('POS-21').hitTestable(), findsOneWidget);
    expect(find.text('POS-1'), findsNothing);
    expect(repository.calls.last.perPage, 20);
    await tester.tap(find.byKey(const ValueKey('pos-page-size')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('100').last);
    await tester.pumpAndSettle();
    expect(repository.calls.last.perPage, 100);
    expect(repository.calls.last.page, 1);
    expect(find.byKey(const ValueKey('pos-page-size')).hitTestable(),
        findsOneWidget);
    expect(find.text('POS-1').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'search, branch and reset filters compose rather than replace each other',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = WorkspaceRepository()..total = 1;
    await tester.pumpWidget(app(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pos-branch-')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('HQ').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('pos-search')), 'SKU-1');
    await tester.pump(const Duration(milliseconds: 360));
    await tester.pumpAndSettle();
    expect(repository.calls.last.branch, 'HQ');
    expect(repository.calls.last.search, 'SKU-1');
    await tester.tap(find.byKey(const ValueKey('pos-filter-toggle')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Reset filters'));
    await tester.tap(find.text('Reset filters'));
    await tester.pumpAndSettle();
    expect(repository.calls.last.branch, '');
    expect(repository.calls.last.search, '');
    expect(repository.calls.last.page, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Buy In filtering displays purchase spending without treating it as revenue',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = WorkspaceRepository();
    await tester.pumpWidget(app(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pos-filter-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pos-type-all')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buy In').last);
    await tester.pumpAndSettle();
    expect(repository.calls.last.type, 'buy_in');
    await scrollTo(tester, find.byType(PosKpiCard).first);
    final card = tester
        .widgetList<PosKpiCard>(find.byType(PosKpiCard))
        .firstWhere((c) => c.title == posTr('purchase_amount'));
    expect(card.value, '\$210.00');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'loading, retry and empty states are functional and unauthorized modules are hidden',
      (tester) async {
    final repository = WorkspaceRepository()..pending = Completer<PosReport>();
    await tester.pumpWidget(app(repository));
    await tester.pump();
    expect(find.byType(PosLoadingSkeleton), findsOneWidget);
    repository.pending!.completeError(Exception('offline'));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Could not load reports. Check your connection and try again.'),
        findsOneWidget);
    repository.pending = null;
    repository.total = 0;
    repository.modules = ['sell'];
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pos-nav-material')), findsNothing);
    await scrollTo(tester, find.text('No transactions found'));
    expect(find.text('No transactions found'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'all permitted create actions open existing localized transaction forms',
      (tester) async {
    labels('km');
    SharedPreferences.setMockInitialValues(
        {'user_fullname': 'Employee', 'user_branch': 'HQ'});
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('google_mlkit_text_recognizer'), (_) async => null);
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('google_mlkit_text_recognizer'), null));
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app(WorkspaceRepository()));
    await tester.pumpAndSettle();
    for (final type in posModules) {
      await tester.tap(find.byKey(const ValueKey('pos-create')));
      await tester.pumpAndSettle();
      await tester.tap(
          find.text(posTr('new_module', {'module': posModuleName(type)})).last);
      await tester.pumpAndSettle();
      final form = tester.widget<SellOutReportCreateScreen>(
          find.byType(SellOutReportCreateScreen));
      expect(SellOutReport.canonicalServiceType(form.serviceType), type);
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('commission rules remain readable on a small phone',
      (tester) async {
    labels('km');
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app(WorkspaceRepository()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pos-commission-mode')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(posTr('commission_rules')).last);
    await tester.pumpAndSettle();
    expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'an open rules menu tolerates session expiry during a report request',
      (tester) async {
    final repository = WorkspaceRepository()..total = 1;
    await tester.pumpWidget(app(repository));
    await tester.pumpAndSettle();
    final onSelected = tester
        .widget<PopupMenuButton<String>>(
            find.byKey(const ValueKey('pos-commission-mode')))
        .onSelected!;
    await tester.tap(find.byKey(const ValueKey('pos-commission-mode')));
    await tester.pumpAndSettle();
    final request = RequestOptions(path: '/api/sell-out-reports');
    repository.error = DioException(
        requestOptions: request,
        response: Response(requestOptions: request, statusCode: 401));
    final model = Provider.of<PosReportingProvider>(
        tester.element(find.byType(PosFiltersBar)),
        listen: false);
    await model.refresh();
    await tester.pumpAndSettle();
    // A queued selection may finish after the report clears on expiry.
    onSelected('rules');
    await tester.pumpAndSettle();
    expect(model.report, isNull);
    expect(tester.takeException(), isNull);
  });
  for (final language in ['en', 'km']) {
    for (final width in [320.0, 768.0]) {
      testWidgets(
          '$language business breakdown includes Sales and commission columns at $width',
          (tester) async {
        labels(language);
        await tester.binding.setSurfaceSize(Size(width, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(app(WorkspaceRepository()..total = 1));
        await tester.pumpAndSettle();
        await scrollTo(tester, find.text(posTr('business_overview')));
        await tester.tap(find.text(posTr('business_overview')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('pos-breakdown-commission-header')),
            findsOneWidget);
        for (final type in posModules) {
          expect(find.byKey(ValueKey('pos-category-$type')), findsOneWidget);
          expect(find.byKey(ValueKey('pos-category-commission-$type')),
              findsOneWidget);
        }
        expect(
            tester
                .widget<Text>(
                    find.byKey(const ValueKey('pos-category-commission-sell')))
                .data,
            r'$0.50');
        expect(
            tester
                .widget<Text>(find
                    .byKey(const ValueKey('pos-category-commission-buy_in')))
                .data,
            r'$0.00');
        expect(tester.takeException(), isNull);
        final salesRow = find.byKey(const ValueKey('pos-category-sell'));
        await tester.ensureVisible(salesRow);
        await tester.tap(salesRow);
        await tester.pumpAndSettle();
        expect(
            SellOutReport.canonicalServiceType(tester
                .widget<SellOutReportScreen>(find.byType(SellOutReportScreen))
                .serviceType),
            'sell');
        expect(tester.takeException(), isNull);
      });
    }
  }
}
