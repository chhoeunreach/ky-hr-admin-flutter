import 'package:cnattendance/data/source/network/model/attendancereport/AttendanceSummary.dart';
import 'package:cnattendance/data/source/network/model/attendancereport/EmployeeAttendance.dart';
import 'package:cnattendance/data/source/network/model/attendancereport/EmployeeTodayAttendance.dart';
import 'package:cnattendance/model/employeeattendancereport.dart';
import 'package:cnattendance/model/month.dart';
import 'package:cnattendance/repositories/attendancereportrepository.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nepali_utils/nepali_utils.dart';

class AttendanceReportProvider with ChangeNotifier {
  final List<EmployeeAttendanceReport> _attendanceReport = [];
  AttendanceReportRepository repository = AttendanceReportRepository();

  final Map<String, dynamic> _todayReport = {
    'check_in_at': '-',
    'check_out_at': '-',
    'production_hour': '0 hr 0 min',
    'production_percent': 0.0,
    'day_status': 'present',
    'status_label': '',
  };

  final Map<String, dynamic> _currentMonthReport = {
    'present_days': '0',
    'worked_hour': '0h 0m',
  };

  List<Month> month = [];

  var isLoading = false;
  Future<void>? _calendarFuture;
  Future<void>? _reportFuture;
  int? _requestedMonth;
  int _reportRevision = 0;
  bool? _dateInAd;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _reportRevision++;
    super.dispose();
  }

  int selectedMonth = DateTime.now().month - 1;

  List<EmployeeAttendanceReport> get attendanceReport {
    return [..._attendanceReport];
  }

  Map<String, dynamic> get todayReport {
    return _todayReport;
  }

  Map<String, dynamic> get currentMonthReport {
    return _currentMonthReport;
  }

  Future<void> getDate() {
    return _calendarFuture ??= _initializeDate().whenComplete(() {
      _calendarFuture = null;
    });
  }

  Future<void> _initializeDate() async {
    final isAd = await repository.getDateInAd();
    if (_disposed) return;
    if (_dateInAd != isAd || month.isEmpty) {
      month = isAd ? engMonth : nepaliMonth;
      selectedMonth =
          isAd ? DateTime.now().month - 1 : NepaliDateTime.now().month - 1;
      _dateInAd = isAd;
    }
    await getAttendanceReport();
  }

  Future<void> getAttendanceReport() {
    if (_disposed) return Future.value();
    if (_reportFuture != null && _requestedMonth == selectedMonth) {
      return _reportFuture!;
    }
    final revision = ++_reportRevision;
    final requestedMonth = selectedMonth;
    _requestedMonth = requestedMonth;
    isLoading = true;
    _reportFuture = _fetchReport(requestedMonth, revision);
    notifyListeners();
    return _reportFuture!;
  }

  Future<void> _fetchReport(int requestedMonth, int revision) async {
    try {
      final response = await repository.getAttendanceReport(requestedMonth);
      if (_disposed ||
          revision != _reportRevision ||
          selectedMonth != requestedMonth) return;
      final data = response.data;
      makeTodayReport(data.employeeTodayAttendance, notify: false);
      makeMonthlyReport(data.attendanceSummary, notify: false);
      getProdHour(
          int.tryParse(data.employeeTodayAttendance.productiveTime) ?? 0,
          notify: false);
      makeAttendanceReport(data.employeeAttendance, notify: false);
    } catch (_) {
      if (!_disposed &&
          revision == _reportRevision &&
          selectedMonth == requestedMonth) rethrow;
    } finally {
      if (!_disposed && revision == _reportRevision) {
        isLoading = false;
        _reportFuture = null;
        notifyListeners();
      }
    }
  }

  void makeAttendanceReport(List<EmployeeAttendance> employeeAttendance,
      {bool notify = true}) {
    _attendanceReport.clear();
    for (var item in employeeAttendance) {
      _attendanceReport.add(EmployeeAttendanceReport(
        id: item.id,
        attendance_date: item.attendanceDate,
        attendance_date_ad: item.attendanceDateAd,
        week_day: item.weekDay,
        worked_hours: item.workedhrs ?? "-",
        working_hours: item.workingHour,
        check_in: item.checkIn,
        check_out: item.checkOut,
        overTime: item.overTime,
        underTime: item.underTime,
        isOverTime: item.isOverTime,
        isUnderTime: item.isUnderTime,
        worked_hours_min: item.workedhrsMin,
        working_hours_min: item.workingHourMin,
        dayStatus: item.dayStatus,
        rawStatusLabel: item.statusLabel,
        leaveStatus: item.leaveStatus,
        leaveType: item.leaveType,
        timeLeaveStatus: item.timeLeaveStatus,
        timeLeaveFrom: item.timeLeaveFrom,
        timeLeaveTo: item.timeLeaveTo,
      ));
    }

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final todayRows =
        _attendanceReport.where((item) => item.attendance_date_ad == today);
    if (todayRows.isNotEmpty) {
      final todayReport = todayRows.first;
      _todayReport['day_status'] = todayReport.dayStatus;
      _todayReport['status_label'] = todayReport.statusLabel;
      if (!todayReport.hasAttendance) {
        _todayReport['check_in_at'] = '-';
        _todayReport['check_out_at'] = '-';
        _todayReport['production_hour'] = '0 hr 0 min';
        _todayReport['production_percent'] = 0.0;
      }
    }

    if (notify) notifyListeners();
  }

  void makeTodayReport(EmployeeTodayAttendance employeeTodayAttendance,
      {bool notify = true}) {
    _todayReport['check_in_at'] = employeeTodayAttendance.checkInAt;
    _todayReport['check_out_at'] = employeeTodayAttendance.checkOutAt;
    _todayReport['day_status'] = 'present';
    _todayReport['status_label'] = '';

    if (notify) notifyListeners();
  }

  void makeMonthlyReport(AttendanceSummary attendanceSummary,
      {bool notify = true}) {
    _currentMonthReport['present_days'] = attendanceSummary.totalPresent;
    _currentMonthReport['worked_hour'] = attendanceSummary.totalWorkedHours;

    if (notify) notifyListeners();
  }

  String getProdHour(int value, {bool notify = true}) {
    final second = value * 60.toDouble();
    final min = second / 60;
    final minGone = (min % 60).toInt();
    final hour = min ~/ 60;

    _todayReport['production_hour'] = "$hour hr $minGone min";

    final hours = value / 60;
    final hr = hours / Constant.TOTAL_WORKING_HOUR;

    _todayReport['production_percent'] = hr > 1.0 ? 1.0 : hr;

    if (notify) notifyListeners();
    return "$hour hr $minGone min";
  }
}
