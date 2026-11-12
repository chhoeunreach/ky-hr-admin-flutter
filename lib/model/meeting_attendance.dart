class MeetingAttendanceItem {
  MeetingAttendanceItem({
    required this.id,
    required this.title,
    required this.venue,
    required this.meetingDate,
    required this.meetingStartTime,
    required this.qrPayload,
    required this.isJoined,
    this.checkedInAtFormatted,
    this.attendanceStatus = 'open',
    this.checkInOpensAt,
    this.checkInClosesAt,
  });

  factory MeetingAttendanceItem.fromJson(Map<String, dynamic> json) {
    return MeetingAttendanceItem(
      id: _asInt(json['id']),
      title: _asString(json['title']),
      venue: _asString(json['venue']),
      meetingDate: _asString(json['meeting_date']),
      meetingStartTime: _asString(json['meeting_start_time']),
      qrPayload: _asString(json['qr_payload']),
      isJoined: json['is_joined'] == true ||
          json['is_joined'] == 1 ||
          json['is_joined'].toString() == '1',
      attendanceStatus: _asString(json['attendance_status']).isEmpty
          ? 'open'
          : _asString(json['attendance_status']),
      checkInOpensAt: DateTime.tryParse(_asString(json['check_in_opens_at'])),
      checkInClosesAt: DateTime.tryParse(_asString(json['check_in_closes_at'])),
      checkedInAtFormatted: _asNullableString(json['checked_in_at_formatted']),
    );
  }

  final String attendanceStatus;
  final DateTime? checkInOpensAt;
  final DateTime? checkInClosesAt;

  bool get canCheckIn => !isJoined && attendanceStatus == 'open';

  final int id;
  final String title;
  final String venue;
  final String meetingDate;
  final String meetingStartTime;
  final String qrPayload;
  final bool isJoined;
  final String? checkedInAtFormatted;

  static int _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _asString(dynamic value) {
    return value?.toString() ?? '';
  }

  static String? _asNullableString(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
