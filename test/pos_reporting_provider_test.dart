import 'dart:async';
import 'package:cnattendance/features/pos/models/pos_report.dart';
import 'package:cnattendance/features/pos/providers/pos_reporting_provider.dart';
import 'package:cnattendance/features/pos/services/pos_reporting_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'fixtures/pos_report_fixture.dart';

class MemoryPosRepository implements PosReportingRepository {
  final List<PosFilters> calls = [];
  Object? error;
  Future<PosReport> Function(PosFilters)? respond;
  @override
  Future<PosReport> load(PosFilters filters) async {
    calls.add(filters);
    if (error != null) throw error!;
    return respond != null
        ? respond!(filters)
        : PosReport.fromJson(posFixture(filters));
  }

  @override
  Future<List<int>> export(PosFilters filters) async => [1, 2, 3];
}

void main() {
  test('defaults to today and bounded server pages of twenty', () async {
    final repo = MemoryPosRepository();
    final model = PosReportingProvider(repository: repo);
    await model.refresh();
    final now = DateTime.now();
    expect(model.filters.from, DateTime(now.year, now.month, now.day));
    expect(repo.calls.single.toQuery()['per_page'], 20);
    expect(model.report!.transactions.length, 20);
    model.page(2);
    await Future<void>.delayed(Duration.zero);
    expect(repo.calls.last.page, 2);
    expect(model.report!.transactions.single.report.invoiceNo, 'POS-21');
    expect(model.report!.metric('sales_amount'), 210);
    model.dispose();
  });
  testWidgets(
      'search is debounced and stale responses cannot replace newer filters',
      (tester) async {
    final repo = MemoryPosRepository();
    final first = Completer<PosReport>();
    repo.respond = (f) => f.search.isEmpty
        ? first.future
        : Future.value(PosReport.fromJson(posFixture(f, total: 1)));
    final model = PosReportingProvider(repository: repo);
    unawaited(model.refresh());
    model.search('P');
    model.search('POS');
    await tester.pump(const Duration(milliseconds: 349));
    expect(repo.calls.length, 1);
    await tester.pump(const Duration(milliseconds: 2));
    expect(repo.calls.length, 2);
    expect(repo.calls.last.search, 'POS');
    expect(model.report!.total, 1);
    first.complete(
        PosReport.fromJson(posFixture(PosFilters.today(), total: 99)));
    await tester.pump();
    expect(model.report!.total, 1);
    model.dispose();
  });
  test(
      'navigation preserves date and branch, resets page/search/status and respects modules',
      () async {
    final repo = MemoryPosRepository();
    final model = PosReportingProvider(repository: repo);
    await model.refresh();
    model.update(model.filters
        .copyWith(branch: 'HQ', search: 'phone', page: 2, status: 'qualified'));
    await Future<void>.delayed(Duration.zero);
    final date = model.filters.from;
    model.navigate('material');
    await Future<void>.delayed(Duration.zero);
    expect(model.destination, 'material');
    expect(model.filters.type, 'material');
    expect(model.filters.branch, 'HQ');
    expect(model.filters.from, date);
    expect(model.filters.page, 1);
    expect(model.filters.search, '');
    expect(model.filters.status, 'all');
    model.navigate('unpermitted');
    expect(model.destination, 'material');
    model.reset();
    await Future<void>.delayed(Duration.zero);
    expect(model.filters.type, 'material');
    expect(model.filters.branch, '');
    model.dispose();
  });
  test('reconciles a server-clamped page after records change', () async {
    final repo = MemoryPosRepository();
    repo.respond = (f) async =>
        PosReport.fromJson(posFixture(f.copyWith(page: 1), total: 1));
    final model = PosReportingProvider(repository: repo);
    await model.update(model.filters.copyWith(page: 999));
    expect(model.report!.page, 1);
    expect(model.filters.page, 1);
    model.dispose();
  });

  test(
      'initial reports defer to the admin default mode rather than a client default',
      () async {
    final repo = MemoryPosRepository();
    repo.respond = (f) async {
      final json = posFixture(f);
      json['commission_policy'] = {
        ...json['commission_policy'] as Map<String, dynamic>,
        'default_mode': 'without_conditions'
      };
      json['filters'] = {'commission_mode': 'without_conditions'};
      return PosReport.fromJson(json);
    };
    final model = PosReportingProvider(repository: repo);
    await model.refresh();
    expect(repo.calls.single.toQuery().containsKey('commission_mode'), isFalse);
    expect(model.filters.commissionMode, 'without_conditions');
    model.dispose();
  });

  test('period shortcuts use calendar boundaries and retain other filters',
      () async {
    final model = PosReportingProvider(repository: MemoryPosRepository());
    await model.refresh();
    final now = DateTime.now();
    model.period('last_month');
    expect(model.filters.from, DateTime(now.year, now.month - 1));
    expect(model.filters.to, DateTime(now.year, now.month, 0));
    model.period('last_7_days');
    expect(model.filters.to.difference(model.filters.from).inDays, 6);
    model.period('this_year');
    expect(model.filters.from, DateTime(now.year));
    expect(model.filters.to, DateTime(now.year, 12, 31));
    model.dispose();
  });
}
