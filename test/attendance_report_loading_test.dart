import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cnattendance/data/source/network/model/attendancereport/AttendanceReportResponse.dart';
import 'package:cnattendance/provider/attendancereportprovider.dart';
import 'package:cnattendance/repositories/attendancereportrepository.dart';
import 'package:cnattendance/widget/attendancescreen/attendancecardview.dart';
import 'package:cnattendance/widget/attendancescreen/attendancestatus.dart';
import 'package:cnattendance/widget/attendancescreen/reportlistview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class _Repository extends AttendanceReportRepository {
  int calendarReads = 0;
  final List<int> months = [];
  final List<Completer<AttendanceReportResponse>> requests = [];
  @override
  Future<bool> getDateInAd() async {
    calendarReads++;
    return true;
  }

  @override
  Future<AttendanceReportResponse> getAttendanceReport(int month) {
    months.add(month);
    final request = Completer<AttendanceReportResponse>();
    requests.add(request);
    return request.future;
  }
}

AttendanceReportResponse _response({
  String present = '10',
  int rows = 0,
  Map<String, dynamic>? today,
  List<Map<String, dynamic>> extraRows = const [],
}) =>
    AttendanceReportResponse.fromJson({
      'status': true,
      'message': 'OK',
      'status_code': 200,
      'data': {
        'attendance_summary': {
          'totalPresent': present,
          'totalWorkedHours': '80h'
        },
        'user_detail': {'user_id': 1, 'name': 'Employee', 'email': ''},
        'employee_today_attendance': today ??
            {
              'check_in_at': '08:00',
              'check_out_at': '-',
              'productive_time_in_min': '120',
            },
        'employee_attendance': [
          for (var i = 0; i < rows; i++)
            {
              'id': i + 1,
              'attendance_date_ad': DateFormat('yyyy-MM-dd')
                  .format(DateTime(2025, 1, 1).add(Duration(days: i))),
              'week_day': 'Monday',
              'check_in': '08:00',
              'check_out': '17:00',
            },
          ...extraRows,
        ],
      },
    });

void main() {
  test(
      'concurrent refreshes share one request and publish one completed update',
      () async {
    final repository = _Repository();
    final provider = AttendanceReportProvider()..repository = repository;
    addTearDown(provider.dispose);
    var notifications = 0;
    provider.addListener(() => notifications++);
    final first = provider.getAttendanceReport();
    final second = provider.getAttendanceReport();
    expect(identical(first, second), isTrue);
    expect(repository.requests, hasLength(1));
    expect(provider.isLoading, isTrue);
    repository.requests.single.complete(_response());
    await Future.wait([first, second]);
    expect(notifications, 2);
    expect(provider.currentMonthReport['present_days'], '10');
    expect(provider.isLoading, isFalse);
  });

  test('changing months discards a slower response from the previous selection',
      () async {
    final repository = _Repository();
    final provider = AttendanceReportProvider()..repository = repository;
    addTearDown(provider.dispose);
    provider.selectedMonth = 0;
    final old = provider.getAttendanceReport();
    provider.selectedMonth = 1;
    final recent = provider.getAttendanceReport();
    repository.requests[1].complete(_response(present: '20'));
    await recent;
    repository.requests[0].complete(_response(present: '1'));
    await old;
    expect(provider.currentMonthReport['present_days'], '20');
    expect(provider.isLoading, isFalse);
  });

  test(
      'calendar initialization coalesces startup and retains the selected month on return',
      () async {
    final repository = _Repository();
    final provider = AttendanceReportProvider()..repository = repository;
    addTearDown(provider.dispose);
    final first = provider.getDate();
    final second = provider.getDate();
    await Future<void>.delayed(Duration.zero);
    expect(repository.calendarReads, 1);
    expect(repository.months, [DateTime.now().month - 1]);
    repository.requests[0].complete(_response());
    await Future.wait([first, second]);
    provider.selectedMonth = 0;
    final returning = provider.getDate();
    await Future<void>.delayed(Duration.zero);
    expect(repository.months.last, 0);
    repository.requests[1].complete(_response());
    await returning;
    expect(provider.selectedMonth, 0);
  });

  test('a failed load clears its spinner and permits a retry', () async {
    final repository = _Repository();
    final provider = AttendanceReportProvider()..repository = repository;
    addTearDown(provider.dispose);
    final failed = provider.getAttendanceReport();
    final expectation = expectLater(failed, throwsStateError);
    repository.requests.single.completeError(StateError('Offline'));
    await expectation;
    expect(provider.isLoading, isFalse);
    final retry = provider.getAttendanceReport();
    repository.requests.last.complete(_response());
    await retry;
    expect(repository.requests, hasLength(2));
  });

  test('leaving during a request does not notify a disposed provider',
      () async {
    final repository = _Repository();
    final provider = AttendanceReportProvider()..repository = repository;
    final pending = provider.getAttendanceReport();
    provider.dispose();
    repository.requests.single.complete(_response());
    await pending;
  });

  testWidgets('attendance header displays absence after an empty report',
      (tester) async {
    Localization.load(jsonDecode(File('assets/i18n/en.json').readAsStringSync())
        as Map<String, dynamic>);
    final provider = AttendanceReportProvider();
    addTearDown(provider.dispose);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(home: Scaffold(body: AttendanceStatus())),
    ));
    expect(find.text('Absent'), findsNothing);

    provider.makeTodayReport(_response(today: {}).data.employeeTodayAttendance);
    await tester.pumpAndSettle();

    expect(find.text('Absent'), findsOneWidget);
  });

  test('leave requests and days off take precedence over missing punches', () {
    final provider = AttendanceReportProvider();
    addTearDown(provider.dispose);
    final date = DateTime.now().toIso8601String().split('T').first;
    final response = _response(today: {}, extraRows: [
      {'id': 1, 'attendance_date_ad': date, 'day_status': 'present'},
      {'id': 2, 'attendance_date_ad': date, 'leave_status': 'On Review'},
      {'id': 3, 'status_label': 'Day Off', 'check_in': '', 'check_out': '-'},
      {'id': 4, 'status_label': 'សុំច្បាប់\u200b'},
    ]);
    provider.makeTodayReport(response.data.employeeTodayAttendance);
    provider.makeAttendanceReport(response.data.employeeAttendance);

    expect(provider.todayReport['day_status'], 'leave_request');
    expect(
      provider.attendanceReport.map((row) => row.dayStatus),
      ['absent', 'leave_request', 'day_off', 'leave_request'],
    );
  });

  test('a blank history row preserves a check-in from the today report', () {
    final provider = AttendanceReportProvider();
    addTearDown(provider.dispose);
    final response = _response(extraRows: [
      {
        'id': 1,
        'attendance_date_ad': DateTime.now().toIso8601String().split('T').first,
      },
    ]);
    provider.makeTodayReport(response.data.employeeTodayAttendance);
    provider.makeAttendanceReport(response.data.employeeAttendance);

    expect(provider.todayReport['check_in_at'], '08:00');
    expect(provider.todayReport['day_status'], 'present');
  });

  testWidgets('attendance labels change when a leave request is approved',
      (tester) async {
    void loadLabels(String language) {
      Localization.load(
          jsonDecode(File('assets/i18n/$language.json').readAsStringSync())
              as Map<String, dynamic>);
    }

    loadLabels('en');
    final repository = _Repository();
    final provider = AttendanceReportProvider()..repository = repository;
    addTearDown(provider.dispose);
    final date = DateTime.now().toIso8601String().split('T').first;
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(
        home: Scaffold(
          body: CustomScrollView(slivers: [
            SliverToBoxAdapter(child: AttendanceStatus()),
            const ReportListView(asSliver: true),
          ]),
        ),
      ),
    ));

    Future<void> refresh(String leaveStatus, String dayStatus) async {
      final load = provider.getAttendanceReport();
      repository.requests.last.complete(_response(today: {}, extraRows: [
        {
          'id': 0,
          'attendance_date_nepali': '21 Nov',
          'attendance_date_ad': date,
          'leave_status': leaveStatus,
          'day_status': dayStatus,
        },
      ]));
      await load;
      await tester.pumpAndSettle();
    }

    await refresh('pending', 'leave');
    expect(find.text('Leave Request'), findsNWidgets(2));

    await refresh('approved', 'leave_request');
    expect(find.text('Day Off'), findsNWidgets(2));

    loadLabels('km');
    await refresh('approved', 'leave');
    expect(find.text('ច្បាប់'), findsNWidgets(2));
  });

  testWidgets('attendance history builds visible days as the user scrolls',
      (tester) async {
    Localization.load(jsonDecode(File('assets/i18n/en.json').readAsStringSync())
        as Map<String, dynamic>);
    final provider = AttendanceReportProvider();
    provider.makeAttendanceReport(_response(rows: 200).data.employeeAttendance);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: provider,
      child: const MaterialApp(
          home: Scaffold(
              body:
                  CustomScrollView(slivers: [ReportListView(asSliver: true)]))),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(AttendanceCardView).evaluate().length, lessThan(30));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1600));
    await tester.pumpAndSettle();
    expect(find.byType(AttendanceCardView).evaluate().length, lessThan(30));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
  });
}
