import 'package:cnattendance/utils/attendance_status.dart';
import 'package:flutter/material.dart';

class EmployeeAttendanceReport with ChangeNotifier {
  int id;
  String attendance_date;
  String attendance_date_ad;
  String week_day;
  String worked_hours;
  String working_hours;
  String check_in;
  String check_out;
  bool isOverTime;
  bool isUnderTime;
  bool isEarlyCheckOut;
  int earlyCheckOutMinutes;
  String overTime;
  String underTime;
  double worked_hours_min;
  double working_hours_min;
  String dayStatus;
  String rawStatusLabel;
  String? leaveStatus;
  String? leaveType;
  String? timeLeaveStatus;
  String? timeLeaveFrom;
  String? timeLeaveTo;

  String get statusLabel {
    if (isEarlyCheckOut) return 'Early Check Out';
    if (rawStatusLabel.trim().isNotEmpty) return rawStatusLabel;
    if (dayStatus == 'absent') return 'Absent';
    if (dayStatus == 'leave') return 'Leave';
    if (dayStatus == 'leave_request') return 'Leave Request';
    if (dayStatus == 'time_leave') return 'Time Leave';
    if (dayStatus == 'time_leave_request') return 'Time Leave Request';
    if (dayStatus == 'day_off') return 'Day Off';
    if (dayStatus == 'holiday') return 'Holiday';
    if (dayStatus == 'weekend') return 'Weekend';
    if (isUnderTime) return 'Early';
    if (isOverTime) return 'Overtime';
    return 'On Time';
  }

  bool get isPositiveStatus =>
      dayStatus == 'present' && !isUnderTime && !isEarlyCheckOut && dayStatus != 'absent';

  bool get hasAttendance =>
      hasAttendanceTime(check_in) || hasAttendanceTime(check_out);

  static EmployeeAttendanceReport statusForDay(
      Iterable<EmployeeAttendanceReport> rows) {
    return rows.firstWhere(
      (row) => attendanceExceptions.contains(row.dayStatus),
      orElse: () => rows.firstWhere(
        (row) => row.hasAttendance && !row.isPositiveStatus,
        orElse: () => rows.firstWhere(
          (row) => row.hasAttendance,
          orElse: () => rows.first,
        ),
      ),
    );
  }

  EmployeeAttendanceReport({
    required this.id,
    required this.attendance_date,
    required this.attendance_date_ad,
    required this.week_day,
    required this.worked_hours,
    required this.working_hours,
    required this.check_in,
    required this.check_out,
    required this.isOverTime,
    required this.isUnderTime,
    required this.isEarlyCheckOut,
    required this.earlyCheckOutMinutes,
    required this.overTime,
    required this.underTime,
    required this.worked_hours_min,
    required this.working_hours_min,
    required this.dayStatus,
    required this.rawStatusLabel,
    required this.leaveStatus,
    required this.leaveType,
    required this.timeLeaveStatus,
    required this.timeLeaveFrom,
    required this.timeLeaveTo,
  });

  static Map<String, List<EmployeeAttendanceReport>> groupAttendanceByDate(
      List<EmployeeAttendanceReport> attendanceList) {
    final Map<String, List<EmployeeAttendanceReport>> groupedAttendance = {};

    for (final attendance in attendanceList) {
      // Get the attendance date as the key
      final String date = attendance.attendance_date;

      // If the date is not yet a key in the map, initialize an empty list
      if (!groupedAttendance.containsKey(date)) {
        groupedAttendance[date] = [];
      }

      // Add the attendance record to the list for that date
      groupedAttendance[date]!.add(attendance);
    }

    return groupedAttendance;
  }
}
