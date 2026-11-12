import 'package:cnattendance/model/meeting_attendance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads attendance status without requiring a QR secret', () {
    final meeting = MeetingAttendanceItem.fromJson({
      'id': '7',
      'title': 'Planning',
      'attendance_status': 'open',
      'is_joined': false,
      'check_in_opens_at': '2026-11-12T09:00:00+07:00',
    });
    expect(meeting.id, 7);
    expect(meeting.qrPayload, isEmpty);
    expect(meeting.canCheckIn, isTrue);
    expect(meeting.checkInOpensAt, DateTime.parse('2026-11-12T02:00:00Z'));
  });
  test('joined and unavailable meetings cannot offer another check-in', () {
    for (final status in ['closed', 'disabled', 'upcoming']) {
      expect(
          MeetingAttendanceItem.fromJson({'attendance_status': status})
              .canCheckIn,
          isFalse);
    }
    for (final joined in [true, 1, '1']) {
      expect(MeetingAttendanceItem.fromJson({'is_joined': joined}).canCheckIn,
          isFalse);
    }
  });
}
