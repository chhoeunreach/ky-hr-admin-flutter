import 'package:cnattendance/utils/attendance_status.dart';

class EmployeeAttendance {
  EmployeeAttendance({
    required this.id,
    required this.attendanceDate,
    required this.attendanceDateAd,
    required this.weekDay,
    required this.workedhrs,
    required this.checkIn,
    required this.checkOut,
    required this.isOverTime,
    required this.isUnderTime,
    required this.overTime,
    required this.underTime,
    required this.workingHour,
    required this.workingHourMin,
    required this.workedhrsMin,
    required this.dayStatus,
    required this.statusLabel,
    required this.leaveStatus,
    required this.leaveType,
    required this.timeLeaveStatus,
    required this.timeLeaveFrom,
    required this.timeLeaveTo,
  });

  factory EmployeeAttendance.fromJson(dynamic json) {
    return EmployeeAttendance(
        id: json['id'],
        attendanceDate: _toText(json['attendance_date_nepali']),
        attendanceDateAd: json['attendance_date_ad']?.toString() ?? "",
        weekDay: _toText(json['week_day']),
        workedhrs: json['worked_hours'] != null
            ? json["worked_hours"].toString()
            : "-",
        checkIn: _toText(json['check_in'], fallback: "-"),
        checkOut: _toText(json['check_out'], fallback: "-"),
        workingHour: json['working_hours'] ?? "-",
        workingHourMin: _toDouble(json['working_hours_min']),
        workedhrsMin: _toDouble(json['worked_hours_min']),
        isOverTime: json['is_overtime'] ?? false,
        isUnderTime: json['is_undertime'] ?? false,
        overTime: _toText(json['overtime'], fallback: "-"),
        underTime: _toText(json['undertime'], fallback: "-"),
        dayStatus: json['day_status']?.toString() ?? "present",
        statusLabel: json['status_label']?.toString() ?? "",
        leaveStatus: json['leave_status']?.toString(),
        leaveType: json['leave_type']?.toString(),
        timeLeaveStatus: json['time_leave_status']?.toString(),
        timeLeaveFrom: json['time_leave_from']?.toString(),
        timeLeaveTo: json['time_leave_to']?.toString());
  }

  int id;
  String attendanceDate;
  String attendanceDateAd;
  String weekDay;
  String? workedhrs;
  double workedhrsMin;
  String checkIn;
  String checkOut;
  bool isOverTime;
  bool isUnderTime;
  String overTime;
  String underTime;
  String workingHour;
  double workingHourMin;
  String dayStatus;
  String statusLabel;
  String? leaveStatus;
  String? leaveType;
  String? timeLeaveStatus;
  String? timeLeaveFrom;
  String? timeLeaveTo;

  String get resolvedDayStatus => resolveAttendanceStatus(
        hasAttendance:
            hasAttendanceTime(checkIn) || hasAttendanceTime(checkOut),
        dayStatus: dayStatus,
        statusLabel: statusLabel,
        leaveStatus: leaveStatus,
        timeLeaveStatus: timeLeaveStatus,
      );

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['id'] = id;
    map['attendance_date'] = attendanceDate;
    map['attendance_date_ad'] = attendanceDateAd;
    map['week_day'] = weekDay;
    map['check_in'] = checkIn;
    map['check_out'] = checkOut;
    map['day_status'] = dayStatus;
    map['status_label'] = statusLabel;
    return map;
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  static String _toText(dynamic value, {String fallback = ""}) {
    final text = value?.toString();
    if (text == null || text == 'null') return fallback;
    return text;
  }
}
