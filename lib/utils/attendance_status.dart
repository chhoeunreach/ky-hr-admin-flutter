String _normalize(String? value) => (value ?? '')
    .replaceAll('\u200b', '')
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[()]'), '')
    .replaceAll(RegExp(r'[\s-]+'), '_');

bool hasAttendanceTime(String? value) {
  final time = value?.trim().toLowerCase();
  return time != null && time.isNotEmpty && time != '-' && time != 'null';
}

const attendanceExceptions = {
  'leave',
  'leave_request',
  'time_leave',
  'time_leave_request',
  'day_off',
  'holiday',
  'weekend',
};

String? _requestStatus(String? value, String type) =>
    switch (_normalize(value)) {
      'approved' => type,
      'pending' || 'review' || 'on_review' || 'under_review' =>
        '${type}_request',
      _ => null,
    };

String resolveAttendanceStatus({
  required bool hasAttendance,
  String? dayStatus,
  String? statusLabel,
  String? leaveStatus,
  String? timeLeaveStatus,
}) {
  final status = _normalize(dayStatus);
  final label = _normalize(statusLabel);
  final leave = _requestStatus(leaveStatus, 'leave');
  if (leave != null) return leave;

  final isTimeLeaveLabel = label.startsWith('time_leave_');
  if (label.endsWith('_approved')) {
    return isTimeLeaveLabel ? 'time_leave' : 'leave';
  }
  if (label.endsWith('_pending') || label.endsWith('_review')) {
    return isTimeLeaveLabel ? 'time_leave_request' : 'leave_request';
  }

  if (attendanceExceptions.contains(status)) return status;
  if (attendanceExceptions.contains(label)) return label;
  if (label == 'សុំច្បាប់' || label == 'សំណើឈប់សម្រាក') {
    return 'leave_request';
  }
  if (label == 'ច្បាប់' || label == 'ឈប់សម្រាក') return 'leave';
  if (status == 'dayoff' || label == 'dayoff' || label == 'ថ្ងៃសម្រាក') {
    return 'day_off';
  }

  final timeLeave = _requestStatus(timeLeaveStatus, 'time_leave');
  if (timeLeave != null) return timeLeave;
  if (!hasAttendance) return 'absent';
  return switch (status) {
    '' || 'absent' => 'present',
    _ => status,
  };
}
