import 'dart:convert';

import 'package:cnattendance/utils/qr_scan_router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('detects meeting check-in QR by prefix', () {
    final route = QrScanRouter.classify('  meeting-qr:encrypted-payload  ');
    expect(route.kind, QrScanKind.meeting);
    expect(route.payload, 'meeting-qr:encrypted-payload');
    expect(route.isAttendance, isFalse);
  });

  test('detects HR queue pass JSON and maps it to qr_pass', () {
    final payload = jsonEncode({
      'type': 'attendance_queue_pass',
      'user_id': 7,
      'timestamp': 1700000000,
      'signature': 'sig',
    });
    final route = QrScanRouter.classify(payload);
    expect(route.kind, QrScanKind.queuePass);
    expect(route.attendanceType, 'qr_pass');
    expect(route.payload, payload);
    expect(route.isAttendance, isTrue);
  });

  test('detects payroll join URL and extracts the session token', () {
    const token = 'Abc123Def456Ghi789Jkl012Mno345Pq';
    final route = QrScanRouter.classify(
        'https://admin.example.com/payroll-queue/join/$token');
    expect(route.kind, QrScanKind.payroll);
    expect(route.payrollToken, token);
    expect(route.isAttendance, isFalse);
  });

  test('does not treat a bare 32-character token as payroll', () {
    // Daily attendance identifiers are base64 and can be exactly 32
    // alphanumeric characters, so only the printed join URL form counts.
    final route =
        QrScanRouter.classify('Abc123Def456Ghi789Jkl012Mno345Pq');
    expect(route.kind, QrScanKind.attendance);
  });

  test('detects plain URL and base64 JSON server configuration', () {
    for (final value in [
      'https://primary.example/',
      base64Encode(utf8.encode(
          '{"server_url":"http://192.168.0.113:8000/",'
          '"server_fallback_url":"http://192.168.0.113:8001/"}')),
    ]) {
      final route = QrScanRouter.classify(value);
      expect(route.kind, QrScanKind.serverConfig, reason: value);
      expect(route.isAttendance, isFalse);
    }
  });

  test('falls back to daily attendance for identifiers and unknown text', () {
    for (final value in [
      base64Encode(utf8.encode('1012attendanceidentifier')),
      'some-random-attendance-code',
      '{"type":"something_else"}',
    ]) {
      final route = QrScanRouter.classify(value);
      expect(route.kind, QrScanKind.attendance, reason: value);
      expect(route.attendanceType, 'qr');
      expect(route.isAttendance, isTrue);
    }
  });
}
