import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/provider/dashboardprovider.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cnattendance/models/monthly_attendance_summary.dart';
import 'package:cnattendance/theme/app_theme_data.dart';
import 'package:cnattendance/theme/app_theme_mode.dart';
import 'package:cnattendance/widget/homescreen/monthly_attendance_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_translate/flutter_translate.dart';

class _SummaryPreferences extends Preferences {
  @override
  Future<String> getToken() async => 'employee-token';
  @override
  Future<String> getAppUrl({bool forceCheck = false}) async =>
      'https://example.test/';
}

void main() {
  Map<String, dynamic> payload() => {
        'available': true,
        'month': '2026-11',
        'late_count': 3,
        'excused_late_count': 2,
        'approved_late_count': 2,
        'approved_time_leave_count': 4,
        'deduction': {'amount': 1.2, 'currency': 'USD'},
        'bonus': {'target_amount': 20, 'completed_days': 8, 'working_days': 25},
      };

  setUp(() {
    Localization.load(jsonDecode(File('assets/i18n/en.json').readAsStringSync())
        as Map<String, dynamic>);
  });

  test('refresh uses the authenticated API and clears stale values on failure',
      () async {
    var status = 200;
    final client = MockClient((request) async {
      expect(request.url.path, '/api/dashboard/attendance-summary');
      expect(request.headers['Authorization'], 'Bearer employee-token');
      return http.Response(jsonEncode({'data': payload()}), status);
    });
    final provider = DashboardProvider(
        attendanceSummaryPreferences: _SummaryPreferences(),
        attendanceSummaryClient: client);
    addTearDown(provider.dispose);
    await provider.refreshMonthlyAttendanceSummary();
    expect(provider.monthlyAttendanceSummary!.deduction, 1.2);
    status = 503;
    await provider.refreshMonthlyAttendanceSummary();
    expect(provider.monthlyAttendanceSummary, isNull);
  });

  test('an older refresh cannot replace the latest employee summary', () async {
    final first = Completer<http.Response>();
    var calls = 0;
    final started = Completer<void>();
    final client = MockClient((request) {
      if (calls++ == 0) {
        started.complete();
        return first.future;
      }
      return Future.value(http.Response(
          jsonEncode({
            'data': {...payload(), 'late_count': 7}
          }),
          200));
    });
    final provider = DashboardProvider(
        attendanceSummaryPreferences: _SummaryPreferences(),
        attendanceSummaryClient: client);
    addTearDown(provider.dispose);
    final old = provider.refreshMonthlyAttendanceSummary();
    await started.future;
    await provider.refreshMonthlyAttendanceSummary();
    first.complete(http.Response(jsonEncode({'data': payload()}), 200));
    await old;
    expect(provider.monthlyAttendanceSummary!.lateCount, 7);
  });

  test('a refresh completing after disposal is safely ignored', () async {
    final pending = Completer<http.Response>();
    final started = Completer<void>();
    final client = MockClient((request) {
      started.complete();
      return pending.future;
    });
    final provider = DashboardProvider(
        attendanceSummaryPreferences: _SummaryPreferences(),
        attendanceSummaryClient: client);
    final refresh = provider.refreshMonthlyAttendanceSummary();
    await started.future;
    provider.dispose();
    pending.complete(http.Response(jsonEncode({'data': payload()}), 200));
    await refresh;
  });

  test('parses the backend amounts and derives full-month progress', () {
    final summary = MonthlyAttendanceSummary.fromJson(payload())!;
    expect(summary.month, '2026-11');
    expect(summary.lateCount, 3);
    expect(summary.excusedLateCount, 2);
    expect(summary.totalLateCount, 5);
    expect(summary.approvedLateCount, 2);
    expect(summary.approvedTimeLeaveCount, 4);
    expect(summary.deduction, 1.2);
    expect(summary.bonusTarget, 20);
    expect(summary.progress, .32);
    final legacyData = payload()
      ..remove('approved_late_count')
      ..remove('approved_time_leave_count');
    expect(MonthlyAttendanceSummary.fromJson(legacyData)!.approvedLateCount,
        isNull);
    expect(
        MonthlyAttendanceSummary.fromJson(legacyData)!.approvedTimeLeaveCount,
        isNull);
    final data = payload();
    data['bonus']['working_days'] = 0;
    expect(MonthlyAttendanceSummary.fromJson(data)!.progress, 0);
  });

  test(
      'missing or malformed data is unavailable rather than invented zero amounts',
      () {
    for (final data in [
      null,
      {},
      {'available': false},
      {'available': true},
      {...payload(), 'month': '2026-99'},
      {...payload(), 'late_count': -1}
    ]) {
      expect(MonthlyAttendanceSummary.fromJson(data), isNull);
    }
    final data = payload();
    data['deduction']['amount'] = 'NaN';
    expect(MonthlyAttendanceSummary.fromJson(data), isNull);
  });

  for (final language in ['en', 'km']) {
    for (final width in [320.0, 390.0, 768.0]) {
      testWidgets('clock and summary fit $language at $width', (tester) async {
        Localization.load(
            jsonDecode(File('assets/i18n/$language.json').readAsStringSync())
                as Map<String, dynamic>);
        await tester.binding.setSurfaceSize(Size(width, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(MaterialApp(
            home: Scaffold(
                body: Padding(
          padding: const EdgeInsets.all(10),
          child: HomeAttendanceClockSummary(
              clock: const Text('11:43'),
              summary: MonthlyAttendanceSummary.fromJson(payload())),
        ))));
        expect(find.text('32%'), findsOneWidget);
        expect(
            tester
                .widget<Text>(find.byKey(const ValueKey('home-late-formula')))
                .data,
            translate('home_attendance.late_formula')
                .replaceAll('{total}', '5')
                .replaceAll('{excused}', '2')
                .replaceAll('{deductible}', '3'));
        expect(
            tester
                .widget<Text>(
                    find.byKey(const ValueKey('home-approved-attendance')))
                .data,
            contains(': 2 · '));
        expect(
            tester
                .widget<Text>(
                    find.byKey(const ValueKey('home-approved-attendance')))
                .data,
            endsWith(': 4'));
        expect(find.text(r'-$1.20'), findsOneWidget);
        expect(find.textContaining(r'$20.00'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const ValueKey('home-bonus-progress')));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.textContaining('2026-11'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('unavailable data shows dashes and offers a refresh explanation',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: HomeMonthlyAttendanceSummary(summary: null))));
    expect(find.text('—'), findsNWidgets(2));
    expect(find.text(r'$0.00'), findsNothing);
    await tester.tap(find.byType(HomeMonthlyAttendanceSummary));
    await tester.pumpAndSettle();
    expect(find.textContaining('unavailable'), findsOneWidget);
  });

  testWidgets('large text and a dark theme remain usable on a small phone',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final data = payload();
    data['deduction']['amount'] = 0;
    await tester.pumpWidget(MaterialApp(
      theme: AppThemeData.themeData(AppThemeMode.dark),
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.8)),
          child: child!),
      home: Scaffold(
          body: HomeAttendanceClockSummary(
              clock: const Text('11:43'),
              summary: MonthlyAttendanceSummary.fromJson(data))),
    ));
    expect(find.text(r'$0.00'), findsOneWidget);
    expect(find.text(r'-$0.00'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
