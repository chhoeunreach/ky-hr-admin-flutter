import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/services/background_sync_manager.dart';
import 'package:cnattendance/services/database_helper.dart';
import 'package:cnattendance/utils/app_device_info.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class QueuedAttendanceException implements Exception {
  final String message;
  QueuedAttendanceException(this.message);

  @override
  String toString() => message;
}

class AttendanceSyncService {
  AttendanceSyncService({
    DatabaseHelper? db,
    Preferences? preferences,
    http.Client? client,
  })  : _db = db ?? DatabaseHelper.instance,
        _preferences = preferences ?? Preferences(),
        _client = client ?? http.Client();

  final DatabaseHelper _db;
  final Preferences _preferences;
  final http.Client _client;
  final Uuid _uuid = const Uuid();

  String createOfflineRequestId() => _uuid.v4();

  Future<int> queueAttendance({
    required String attendanceType,
    required String identifier,
    required String attendanceStatusType,
    required String note,
    required String latitude,
    required String longitude,
    required String routerBssid,
    required File? selfie,
    String? offlineRequestId,
    DateTime? recordedAt,
  }) async {
    final selfiePath = selfie == null ? '' : await _copySelfieToQueue(selfie);
    final id = await _db.insertAttendanceUpload(
      offlineRequestId: offlineRequestId ?? createOfflineRequestId(),
      attendanceType: attendanceType,
      identifier: identifier,
      attendanceStatusType: attendanceStatusType,
      note: note,
      latitude: latitude,
      longitude: longitude,
      routerBssid: routerBssid,
      selfiePath: selfiePath,
      recordedAt: (recordedAt ?? DateTime.now()).toIso8601String(),
    );

    try {
      await BackgroundSyncManager.instance.scheduleOneOffUpload();
    } catch (e) {
      developer.log('Could not schedule attendance sync: $e',
          name: 'AttendanceSync');
    }

    return id;
  }

  Future<void> processPendingAttendance() async {
    await _db.resetStuckAttendanceUploadingToPending();
    final pending = await _db.getPendingAttendanceUploads();

    for (final record in pending) {
      final claimed = await _db.markAttendanceAsUploading(record.id);
      if (!claimed) continue;

      final result = await _uploadAttendance(record);
      if (result.success) {
        await _deleteLocalFileSafely(record.selfiePath);
        await _db.deleteAttendanceUploadRecord(record.id);
      } else if (result.retriable) {
        await _db.markAttendanceAsPendingAndIncrementRetry(
          record.id,
          error: result.message,
        );
      } else {
        await _db.deleteAttendanceUploadRecord(record.id);
        developer.log(
          'Offline attendance #${record.id} rejected: ${result.message}',
          name: 'AttendanceSync',
        );
      }
    }
  }

  Future<_AttendanceUploadResult> _uploadAttendance(
    AttendanceUploadRecord record,
  ) async {
    try {
      final appUrl = await _preferences.getAppUrl();
      final token = await _preferences.getToken();
      if (token.trim().isEmpty) {
        return _AttendanceUploadResult.retry('Missing login token');
      }

      final uri = Uri.parse(appUrl + Constant.ATTENDANCE_URL);
      final deviceDetails = await AppDeviceInfo.getDetails();
      final request = http.MultipartRequest('POST', uri)
        ..headers.addAll({
          'Accept': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        })
        ..fields.addAll({
          'attendance_type': record.attendanceType,
          'latitude': record.latitude,
          'longitude': record.longitude,
          'router_bssid': record.routerBssid,
          'identifier': record.identifier,
          'attendance_status_type': record.attendanceStatusType,
          'note': record.note,
          'offline_request_id': record.offlineRequestId,
          'recorded_at': record.recordedAt,
          'device_name': deviceDetails.deviceName,
          'device_model': deviceDetails.deviceModel,
          'os_version': deviceDetails.osVersion,
          'app_name': deviceDetails.appName,
          'app_version': deviceDetails.appVersion,
          'app_build': deviceDetails.appBuild,
        });

      final selfie = File(record.selfiePath);
      if (record.selfiePath.isNotEmpty && await selfie.exists()) {
        request.files.add(await http.MultipartFile.fromPath(
          'selfie',
          selfie.path,
        ));
      }

      final response =
          await http.Response.fromStream(await _client.send(request));
      if (response.statusCode == 200 || response.statusCode == 201) {
        return _AttendanceUploadResult.success();
      }

      final message = _messageFromResponse(response.body);
      if (response.statusCode >= 500 || response.statusCode == 429) {
        return _AttendanceUploadResult.retry(message);
      }

      return _AttendanceUploadResult.reject(message);
    } on SocketException catch (e) {
      return _AttendanceUploadResult.retry(e.message);
    } on TimeoutException catch (e) {
      return _AttendanceUploadResult.retry(e.message ?? 'Request timed out');
    } catch (e) {
      return _AttendanceUploadResult.retry(e.toString());
    }
  }

  Future<String> _copySelfieToQueue(File selfie) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final queueDir = Directory(p.join(docsDir.path, 'attendance_queue'));
    if (!await queueDir.exists()) {
      await queueDir.create(recursive: true);
    }

    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${p.basename(selfie.path)}';
    final targetPath = p.join(queueDir.path, fileName);
    return (await selfie.copy(targetPath)).path;
  }

  Future<void> _deleteLocalFileSafely(String localPath) async {
    if (localPath.trim().isEmpty) return;
    try {
      final file = File(localPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  String _messageFromResponse(String body) {
    try {
      final decoded = json.decode(body);
      if (decoded is Map && decoded['message'] != null) {
        return decoded['message'].toString();
      }
    } catch (_) {}
    return body.trim().isEmpty ? 'Attendance sync failed' : body;
  }
}

class _AttendanceUploadResult {
  final bool success;
  final bool retriable;
  final String message;

  _AttendanceUploadResult._({
    required this.success,
    required this.retriable,
    required this.message,
  });

  factory _AttendanceUploadResult.success() => _AttendanceUploadResult._(
        success: true,
        retriable: false,
        message: '',
      );

  factory _AttendanceUploadResult.retry(String message) =>
      _AttendanceUploadResult._(
        success: false,
        retriable: true,
        message: message,
      );

  factory _AttendanceUploadResult.reject(String message) =>
      _AttendanceUploadResult._(
        success: false,
        retriable: false,
        message: message,
      );
}
