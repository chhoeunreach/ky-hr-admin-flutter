import 'dart:convert';

import 'package:cnattendance/services/server_configuration.dart';

/// What a single scanned QR payload is meant to do.
enum QrScanKind { attendance, queuePass, meeting, payroll, serverConfig }

/// Classified result of one scan produced by [QrScanRouter.classify].
class QrScanRoute {
  const QrScanRoute(this.kind, this.payload, {this.payrollToken});

  final QrScanKind kind;

  /// Raw trimmed QR content.
  final String payload;

  /// Session token extracted from a payroll queue join URL.
  final String? payrollToken;

  /// `attendance_type` understood by the attendance API for this payload.
  String get attendanceType => kind == QrScanKind.queuePass ? 'qr_pass' : 'qr';

  bool get isAttendance =>
      kind == QrScanKind.attendance || kind == QrScanKind.queuePass;
}

/// Detects the kind of a scanned QR so one scanner button can serve every
/// supported QR: daily attendance, HR queue pass, meeting check-in, payroll
/// queue join URL, and server configuration.
class QrScanRouter {
  static const _meetingPrefix = 'meeting-qr:';
  static final _payrollJoinPath =
      RegExp(r'/payroll-queue/join/([A-Za-z0-9]+)$');

  static QrScanRoute classify(String raw) {
    final value = raw.trim();

    if (value.startsWith(_meetingPrefix)) {
      return QrScanRoute(QrScanKind.meeting, value);
    }
    if (_isQueuePass(value)) {
      return QrScanRoute(QrScanKind.queuePass, value);
    }
    final payrollToken = _payrollToken(value);
    if (payrollToken != null) {
      return QrScanRoute(QrScanKind.payroll, value,
          payrollToken: payrollToken);
    }
    if (_isServerConfiguration(value)) {
      return QrScanRoute(QrScanKind.serverConfig, value);
    }
    return QrScanRoute(QrScanKind.attendance, value);
  }

  static bool _isQueuePass(String value) {
    try {
      final decoded = jsonDecode(value);
      return decoded is Map && decoded['type'] == 'attendance_queue_pass';
    } catch (_) {
      return false;
    }
  }

  /// Only the printed join-URL form is recognized. A bare 32-character token
  /// is deliberately not matched because daily attendance identifiers are
  /// base64 strings that can be exactly 32 alphanumeric characters.
  static String? _payrollToken(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    return _payrollJoinPath.firstMatch(uri.path)?.group(1);
  }

  static bool _isServerConfiguration(String value) {
    try {
      ServerConfiguration.parse(value);
      return true;
    } on FormatException {
      return false;
    }
  }
}
