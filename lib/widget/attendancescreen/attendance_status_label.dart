import 'package:flutter_translate/flutter_translate.dart';

String attendanceStatusLabel(String status, String fallback) {
  final normalizedStatus = status.trim().toLowerCase();
  final normalizedFallback = fallback.trim().toLowerCase();
  switch (normalizedStatus.isNotEmpty ? normalizedStatus : normalizedFallback) {
    case 'present':
      return translate('attendance_status.present');
    case 'absent':
      return translate('attendance_status.absent');
    case 'leave':
      return translate('attendance_status.leave');
    case 'time_leave':
      return translate('attendance_status.time_leave');
    case 'leave_request':
      return translate('attendance_status.leave_request');
    case 'time_leave_request':
      return translate('attendance_status.time_leave_request');
    case 'day_off':
      return translate('attendance_status.day_off');
    case 'holiday':
      return translate('attendance_status.holiday');
    case 'weekend':
      return translate('attendance_status.weekend');
    case 'late':
      return translate('attendance_status.late');
    case 'early':
      return translate('attendance_status.early');
  }

  if (normalizedFallback == 'on review' || normalizedFallback == 'pending') {
    return translate('attendance_status.pending');
  }
  if (normalizedFallback == 'approved') {
    return translate('attendance_status.approved');
  }
  if (normalizedFallback == 'rejected') {
    return translate('attendance_status.rejected');
  }
  return fallback;
}
