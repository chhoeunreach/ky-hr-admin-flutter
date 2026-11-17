import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cnattendance/data/source/network/model/attendancereport/AttendanceReportResponse.dart';
import 'package:cnattendance/provider/attendancereportprovider.dart';
import 'package:cnattendance/repositories/attendancereportrepository.dart';
import 'package:cnattendance/widget/attendancescreen/attendancecardview.dart';
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

AttendanceReportResponse _response({String present = '10', int rows = 0}) =>
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
        'employee_today_attendance': {
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
            }
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
