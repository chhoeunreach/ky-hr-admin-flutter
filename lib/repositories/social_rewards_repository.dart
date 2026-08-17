import 'dart:convert';
import 'dart:io';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/data/source/network/connect.dart';
import 'package:cnattendance/data/source/network/model/generalresponse.dart';
import 'package:cnattendance/model/social_reward.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class SocialRewardsRepository {
  Future<SocialRewardListResponse> getRewards() async {
    final headers = await _authorizedHeaders();

    try {
      final response = await Connect()
          .getResponse(Constant.HR_KY_ADMIN_SOCIAL_REWARDS_URL, headers);
      debugPrint(response.body.toString());

      final responseData = _decodeResponseBody(response.body);

      if (response.statusCode == 200) {
        return SocialRewardListResponse.fromJson(responseData);
      } else {
        throw responseData['message'] ?? 'Unable to load social rewards';
      }
    } catch (e) {
      throw unknownError(e);
    }
  }

  Future<SocialRewardListResponse> getEmployeeRewards({
    required int employeeId,
  }) async {
    final headers = await _authorizedHeaders();

    try {
      final response = await Connect().getResponse(
        '${Constant.HR_KY_ADMIN_SOCIAL_REWARDS_LIST_URL}'
        '?employee_id=$employeeId',
        headers,
      );
      debugPrint(response.body.toString());

      final responseData = _decodeResponseBody(response.body);

      if (response.statusCode == 200) {
        return SocialRewardListResponse.fromJson(responseData);
      } else {
        throw responseData['message'] ?? 'Unable to load social rewards';
      }
    } catch (e) {
      throw unknownError(e);
    }
  }

  Future<GeneralResponse> createReward({
    required String existingEmployeeId,
    required String logDate,
    required String fbPostUrl,
    required String fbStoryUrl,
    required String tiktokUrl,
  }) async {
    final headers = await _authorizedHeaders();

    try {
      final response = await Connect().postResponse(
        Constant.HR_KY_ADMIN_SOCIAL_REWARDS_URL,
        headers,
        {
          'existing_employee_id': existingEmployeeId,
          'log_date': logDate,
          'fb_post_url': fbPostUrl,
          'fb_story_url': fbStoryUrl,
          'tiktok_url': tiktokUrl,
          'reward_points': '1',
        },
      );

      debugPrint(response.body.toString());
      final responseData = _decodeResponseBody(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return GeneralResponse.fromJson(responseData);
      } else {
        throw responseData['message'] ?? 'Unable to create social reward';
      }
    } catch (e) {
      throw unknownError(e);
    }
  }

  Future<SocialReward?> getTodayReward({required int employeeId}) async {
    final headers = await _authorizedHeaders();

    try {
      final response = await Connect().getResponse(
        '${Constant.HR_KY_ADMIN_SOCIAL_REWARDS_TODAY_URL}'
        '?employee_id=$employeeId',
        headers,
      );

      debugPrint(response.body.toString());
      final responseData = _decodeResponseBody(response.body);

      if (response.statusCode == 200) {
        final data = responseData['data'];
        if (data is Map<String, dynamic>) {
          final record = data['record'] ?? data['reward'] ?? data['log'];
          if (record is Map<String, dynamic>) {
            return SocialReward.fromJson(record);
          }
          if (data.containsKey('id') || data.containsKey('fb_post_url')) {
            return SocialReward.fromJson(data);
          }
          return null;
        }
        return null;
      } else {
        throw responseData['message'] ?? 'Unable to check social reward status';
      }
    } catch (e) {
      throw unknownError(e);
    }
  }

  Future<bool> hasSubmittedToday({required int employeeId}) async {
    return await getTodayReward(employeeId: employeeId) != null;
  }

  Future<GeneralResponse> submitDayLog({
    required int employeeId,
    required String fbPostUrl,
    required String fbStoryUrl,
    required String tiktokUrl,
    required File fbPostPhoto,
    required File fbStoryPhoto,
    required File tiktokPhoto,
  }) async {
    final fields = {
      'employee_id': employeeId.toString(),
      'existing_employee_id': employeeId.toString(),
      'fb_post_url': fbPostUrl,
      'fb_story_url': fbStoryUrl,
      'tiktok_url': tiktokUrl,
    };
    final files = {
      'fb_post_photo': fbPostPhoto,
      'fb_story_photo': fbStoryPhoto,
      'tiktok_photo': tiktokPhoto,
    };

    final response = await _sendMultipartResponse(
      url: Constant.HR_KY_ADMIN_SOCIAL_REWARDS_SUBMIT_URL,
      fields: fields,
      files: files,
    );

    if (_isMethodUnsupported(response)) {
      final fallbackResponse = await _sendMultipartResponse(
        url: Constant.HR_KY_ADMIN_SOCIAL_REWARDS_URL,
        fields: {
          ...fields,
          'log_date': DateTime.now().toIso8601String().split('T').first,
        },
        files: files,
      );
      return _parseMultipartResponse(
        fallbackResponse,
        fallbackError: 'Unable to submit social reward',
      );
    }

    return _parseMultipartResponse(
      response,
      fallbackError: 'Unable to submit social reward',
    );
  }

  Future<GeneralResponse> updateDayLog({
    required int rewardId,
    required int employeeId,
    required String fbPostUrl,
    required String fbStoryUrl,
    required String tiktokUrl,
    File? fbPostPhoto,
    File? fbStoryPhoto,
    File? tiktokPhoto,
  }) async {
    final files = <String, File>{};
    if (fbPostPhoto != null) {
      files['fb_post_photo'] = fbPostPhoto;
    }
    if (fbStoryPhoto != null) {
      files['fb_story_photo'] = fbStoryPhoto;
    }
    if (tiktokPhoto != null) {
      files['tiktok_photo'] = tiktokPhoto;
    }

    return _sendDayLogMultipart(
      url: '${Constant.HR_KY_ADMIN_SOCIAL_REWARDS_UPDATE_URL}/$rewardId',
      fields: {
        'employee_id': employeeId.toString(),
        'existing_employee_id': employeeId.toString(),
        'fb_post_url': fbPostUrl,
        'fb_story_url': fbStoryUrl,
        'tiktok_url': tiktokUrl,
      },
      files: files,
      fallbackError: 'Unable to update social reward',
    );
  }

  Future<GeneralResponse> overrideReward({
    required int rewardId,
    required String fbPostUrl,
    required String fbStoryUrl,
    required String tiktokUrl,
    required String reason,
  }) async {
    final headers = await _authorizedHeaders();

    try {
      final response = await Connect().postResponse(
        Constant.HR_KY_ADMIN_SOCIAL_REWARDS_OVERRIDE_URL,
        headers,
        {
          'target_record_id': rewardId.toString(),
          'fb_post_url': fbPostUrl,
          'fb_story_url': fbStoryUrl,
          'tiktok_url': tiktokUrl,
          'reason': reason,
        },
      );

      debugPrint(response.body.toString());
      final responseData = _decodeResponseBody(response.body);

      if (response.statusCode == 200) {
        return GeneralResponse.fromJson(responseData);
      } else {
        throw responseData['message'] ?? 'Unable to override social reward';
      }
    } catch (e) {
      throw unknownError(e);
    }
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
      return {
        'message': decoded?.toString() ?? 'Invalid server response',
      };
    } on FormatException {
      return {
        'message': body.trim().isEmpty
            ? 'Empty server response'
            : 'Invalid server response. Please check the API endpoint.',
      };
    }
  }

  Future<GeneralResponse> _sendDayLogMultipart({
    required String url,
    required Map<String, String> fields,
    required Map<String, File> files,
    required String fallbackError,
  }) async {
    final response = await _sendMultipartResponse(
      url: url,
      fields: fields,
      files: files,
    );

    return _parseMultipartResponse(response, fallbackError: fallbackError);
  }

  Future<http.Response> _sendMultipartResponse({
    required String url,
    required Map<String, String> fields,
    required Map<String, File> files,
  }) async {
    final preferences = Preferences();
    final appUrl = await preferences.getAppUrl();
    final token = await preferences.getToken();
    final uri = Uri.parse('$appUrl$url');

    try {
      final request = http.MultipartRequest('POST', uri)
        ..headers.addAll({
          'Accept': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        })
        ..fields.addAll(fields);

      for (final entry in files.entries) {
        request.files.add(
          await http.MultipartFile.fromPath(entry.key, entry.value.path),
        );
      }

      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);
      debugPrint(response.body.toString());
      return response;
    } catch (e) {
      throw unknownError(e);
    }
  }

  GeneralResponse _parseMultipartResponse(
    http.Response response, {
    required String fallbackError,
  }) {
    final responseData = _decodeResponseBody(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return GeneralResponse.fromJson(responseData);
    }
    throw responseData['message'] ?? fallbackError;
  }

  bool _isMethodUnsupported(http.Response response) {
    if (response.statusCode != 405) {
      return false;
    }
    final responseData = _decodeResponseBody(response.body);
    final message = responseData['message']?.toString().toLowerCase() ?? '';
    return message.contains('post method is not supported') ||
        message.contains('method is not supported');
  }
}
