import 'dart:convert';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/data/source/network/connect.dart';
import 'package:cnattendance/data/source/network/model/generalresponse.dart';
import 'package:cnattendance/model/meeting_attendance.dart';
import 'package:cnattendance/utils/constant.dart';

class MeetingAttendanceRepository {
  Future<List<MeetingAttendanceItem>> getMeetings() async {
    final response = await Connect().getResponse(
      Constant.MEETING_ATTENDANCE_STATUS_URL,
      await _authorizedHeaders(),
    );
    final responseData = _decodeResponseBody(response.body);

    if (response.statusCode == 200) {
      final data = responseData['data'];
      final meetings = data is Map<String, dynamic> ? data['meetings'] : [];
      return meetings is List
          ? meetings
              .whereType<Map<String, dynamic>>()
              .map(MeetingAttendanceItem.fromJson)
              .toList()
          : <MeetingAttendanceItem>[];
    }

    throw responseData['message'] ?? 'Unable to load meeting attendance';
  }

  Future<GeneralResponse> scan(String qrPayload) async {
    final response = await Connect().postResponse(
      Constant.MEETING_ATTENDANCE_SCAN_URL,
      await _authorizedHeaders(),
      {'qr_payload': qrPayload},
    );
    final responseData = _decodeResponseBody(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return GeneralResponse.fromJson(responseData);
    }

    throw responseData['message'] ?? 'Unable to record meeting attendance';
  }

  Future<Map<String, String>> _authorizedHeaders() async {
    final preferences = Preferences();
    final token = await preferences.getToken();

    return {
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _decodeResponseBody(String body) {
    try {
      final decoded = json.decode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return {'message': decoded?.toString() ?? 'Invalid server response'};
    } on FormatException {
      return {
        'message': body.trim().isEmpty
            ? 'Empty server response'
            : 'Invalid server response. Please check the API endpoint.',
      };
    }
  }
}
