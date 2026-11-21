import 'package:cnattendance/utils/attendance_status.dart';

class EmployeeTodayAttendance {
  EmployeeTodayAttendance({
    required this.checkInAt,
    required this.checkOutAt,
    required this.productiveTime,
    this.dayStatus,
    this.statusLabel,
    this.leaveStatus,
    this.timeLeaveStatus,
  });

  factory EmployeeTodayAttendance.fromJson(dynamic json) {
    return EmployeeTodayAttendance(
        checkInAt: json['check_in_at']?.toString() ?? "-",
        checkOutAt: json['check_out_at']?.toString() ?? "-",
        productiveTime: json['productive_time_in_min']?.toString() ?? "0",
        dayStatus: json['day_status']?.toString(),
        statusLabel: json['status_label']?.toString(),
        leaveStatus: json['leave_status']?.toString(),
        timeLeaveStatus: json['time_leave_status']?.toString());
  }

  String checkInAt;
  String checkOutAt;
  String productiveTime;
  final String? dayStatus;
  final String? statusLabel;
  final String? leaveStatus;
  final String? timeLeaveStatus;

  String get resolvedDayStatus => resolveAttendanceStatus(
        hasAttendance:
            hasAttendanceTime(checkInAt) || hasAttendanceTime(checkOutAt),
        dayStatus: dayStatus,
        statusLabel: statusLabel,
        leaveStatus: leaveStatus,
        timeLeaveStatus: timeLeaveStatus,
      );

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['check_in_at'] = checkInAt;
    map['check_out_at'] = checkOutAt;
    if (dayStatus != null) map['day_status'] = dayStatus;
    if (statusLabel != null) map['status_label'] = statusLabel;
    if (leaveStatus != null) map['leave_status'] = leaveStatus;
    if (timeLeaveStatus != null) map['time_leave_status'] = timeLeaveStatus;
    return map;
  }
}
