import 'dart:convert';
import 'dart:io';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/data/source/network/connect.dart';
import 'package:cnattendance/model/group_chat.dart';
import 'package:cnattendance/model/group_chat_detail.dart';
import 'package:cnattendance/model/group_chat_message.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:http/http.dart' as http;
import 'package:http_interceptor_plus/http_interceptor_plus.dart';

class GroupChatRepository {
  final Preferences _preferences;
  final Connect _connect;

  GroupChatRepository({
    Preferences? preferences,
    Connect? connect,
  })  : _preferences = preferences ?? Preferences(),
        _connect = connect ?? Connect();

  Future<List<GroupChat>> getGroups() async {
    final response = await _connect.getResponse(
      Constant.GROUP_CHAT,
      await _headers(),
    );
    return _processList(response);
  }

  Future<GroupChatDetail> getGroupDetail(int groupId) async {
    final response = await _connect.getResponse(
      '${Constant.GROUP_CHAT}/$groupId',
      await _headers(),
    );
    final data = _decodeBody(response.body);
    if (response.statusCode == 200) {
      final responseData = data['data'];
      if (responseData is Map) {
        return GroupChatDetail.fromJson(
            Map<String, dynamic>.from(responseData));
      }
    }
    throw _errorMessage(data);
  }

  Future<Map<String, dynamic>> createGroup({
    required String name,
    String? description,
    List<int>? memberIds,
    File? avatarFile,
  }) async {
    final token = await _preferences.getToken();
    final appUrl = await _preferences.getAppUrl();
    final uri = Uri.parse('$appUrl${Constant.GROUP_CHAT}');

    final request = http.MultipartRequest('POST', uri);
    request.headers['Accept'] = 'application/json; charset=UTF-8';
    request.headers['Authorization'] = 'Bearer $token';
    if (name.trim().isNotEmpty) {
      request.fields['name'] = name.trim();
    }
    if (description != null && description.isNotEmpty) {
      request.fields['description'] = description;
    }
    if (memberIds != null && memberIds.isNotEmpty) {
      for (var i = 0; i < memberIds.length; i++) {
        request.fields['member_ids[$i]'] = memberIds[i].toString();
      }
    }
    if (avatarFile != null) {
      request.files.add(await http.MultipartFile.fromPath('avatar', avatarFile.path));
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final data = _decodeBody(response.body);

    if (response.statusCode == 200) {
      final responseData = data['data'];
      if (responseData is Map) {
        return Map<String, dynamic>.from(responseData);
      }
      return {};
    }
    throw _errorMessage(data);
  }

  Future<void> updateGroupAvatar(int groupId, File avatarFile) async {
    final token = await _preferences.getToken();
    final appUrl = await _preferences.getAppUrl();
    final uri = Uri.parse('$appUrl${Constant.GROUP_CHAT}/$groupId');

    final request = http.MultipartRequest('POST', uri);
    request.headers['Accept'] = 'application/json; charset=UTF-8';
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath('avatar', avatarFile.path));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final data = _decodeBody(response.body);

    if (response.statusCode != 200) {
      throw _errorMessage(data);
    }
  }

  Future<void> updateGroup(int groupId,
      {String? name, String? description}) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (description != null) body['description'] = description;

    final response = await _connect.postResponse(
      '${Constant.GROUP_CHAT}/$groupId',
      await _headers(),
      body,
    );
    _checkResponse(response);
  }

  Future<void> deleteGroup(int groupId) async {
    final appUrl = await _preferences.getAppUrl();
    final uri = Uri.parse('$appUrl${Constant.GROUP_CHAT}/$groupId');

    final client = LoggingMiddleware(http.Client());
    final response = await client.delete(uri, headers: await _headers());
    _checkResponse(response);
  }

  Future<void> addMembers(int groupId, List<int> userIds) async {
    final response = await _connect.postResponse(
      '${Constant.GROUP_CHAT}/$groupId/members',
      await _headers(),
      {'user_ids': jsonEncode(userIds)},
    );
    _checkResponse(response);
  }

  Future<void> removeMember(int groupId, int userId) async {
    final appUrl = await _preferences.getAppUrl();
    final uri =
        Uri.parse('$appUrl${Constant.GROUP_CHAT}/$groupId/members/$userId');

    final client = LoggingMiddleware(http.Client());
    final response = await client.delete(uri, headers: await _headers());
    _checkResponse(response);
  }

  Future<void> updateMemberRole(int groupId, int userId, String role) async {
    final response = await _connect.postResponse(
      '${Constant.GROUP_CHAT}/$groupId/members/$userId/role',
      await _headers(),
      {'role': role},
    );
    _checkResponse(response);
  }

  Future<void> leaveGroup(int groupId) async {
    final response = await _connect.postResponse(
      '${Constant.GROUP_CHAT}/$groupId/leave',
      await _headers(),
      {},
    );
    _checkResponse(response);
  }

  Future<List<GroupChatMessage>> getMessages(int groupId) async {
    final response = await _connect.getResponse(
      '${Constant.GROUP_CHAT}/$groupId/messages',
      await _headers(),
    );
    final data = _decodeBody(response.body);
    if (response.statusCode == 200) {
      final responseData = data['data'];
      if (responseData is Map) {
        final messages = responseData['messages'];
        if (messages is List) {
          return messages.map((m) => GroupChatMessage.fromJson(m)).toList();
        }
      }
      return [];
    }
    throw _errorMessage(data);
  }

  Future<GroupChatMessage> sendMessage(int groupId, String text) async {
    final response = await _connect.postResponse(
      '${Constant.GROUP_CHAT}/$groupId/messages',
      await _headers(),
      {'message': text},
    );
    return _processSingleMessage(response);
  }

  Future<GroupChatMessage> editMessage(
      int groupId, int messageId, String text) async {
    final response = await _connect.postResponse(
      '${Constant.GROUP_CHAT}/$groupId/messages/$messageId',
      await _headers(),
      {'message': text},
    );
    return _processSingleMessage(response);
  }

  Future<GroupChatMessage> deleteMessage(int groupId, int messageId) async {
    final appUrl = await _preferences.getAppUrl();
    final uri =
        Uri.parse('$appUrl${Constant.GROUP_CHAT}/$groupId/messages/$messageId');

    final client = LoggingMiddleware(http.Client());
    final response = await client.delete(uri, headers: await _headers());
    return _processSingleMessage(response);
  }

  Future<GroupChatMessage> sendMediaMessage(
    int groupId, {
    required String type,
    required String mediaUrl,
    String? mediaPath,
    String? fileName,
    int? durationSeconds,
    int? mediaWidth,
    int? mediaHeight,
  }) async {
    final body = <String, dynamic>{
      'message_type': type,
      'media_url': mediaUrl,
    };
    if (mediaPath != null) body['media_path'] = mediaPath;
    if (fileName != null) body['file_name'] = fileName;
    if (durationSeconds != null)
      body['duration_seconds'] = durationSeconds.toString();
    if (mediaWidth != null) body['media_width'] = mediaWidth.toString();
    if (mediaHeight != null) body['media_height'] = mediaHeight.toString();

    final response = await _connect.postResponse(
      '${Constant.GROUP_CHAT}/$groupId/messages',
      await _headers(),
      body,
    );
    return _processSingleMessage(response);
  }

  Future<GroupChatMessage> sendLocation(
    int groupId, {
    required double latitude,
    required double longitude,
  }) async {
    final response = await _connect.postResponse(
      '${Constant.GROUP_CHAT}/$groupId/messages',
      await _headers(),
      {
        'message_type': 'location',
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
      },
    );
    return _processSingleMessage(response);
  }

  Future<Map<String, dynamic>> uploadMedia(String filePath, String type) async {
    final token = await _preferences.getToken();
    final appUrl = await _preferences.getAppUrl();
    final uri = Uri.parse('$appUrl${Constant.GROUP_CHAT_MEDIA_UPLOAD}');

    final request = http.MultipartRequest('POST', uri);
    request.headers['Accept'] = 'application/json; charset=UTF-8';
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['type'] = type;
    request.files.add(await http.MultipartFile.fromPath('file', filePath));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final data = _decodeBody(response.body);

    if (response.statusCode == 200) {
      final responseData = data['data'];
      if (responseData is Map) {
        return Map<String, dynamic>.from(responseData);
      }
      return {};
    }
    throw _errorMessage(data);
  }

  Future<Map<String, String>> _headers() async {
    final token = await _preferences.getToken();
    return {
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _decodeBody(String body) {
    if (body.trim().isEmpty) return {};
    try {
      final decoded = json.decode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return {'message': decoded.toString()};
    } catch (_) {
      return {'message': body};
    }
  }

  List<GroupChat> _processList(http.Response response) {
    final data = _decodeBody(response.body);
    if (response.statusCode == 200) {
      final responseData = data['data'];
      if (responseData is List) {
        return responseData.map((item) => GroupChat.fromJson(item)).toList();
      }
      return [];
    }
    throw _errorMessage(data);
  }

  GroupChatMessage _processSingleMessage(http.Response response) {
    final data = _decodeBody(response.body);
    if (response.statusCode == 200) {
      final responseData = data['data'];
      if (responseData is Map) {
        final message = responseData['message'];
        if (message != null) {
          return GroupChatMessage.fromJson(message);
        }
      }
    }
    throw _errorMessage(data);
  }

  void _checkResponse(http.Response response) {
    final data = _decodeBody(response.body);
    if (response.statusCode != 200) {
      throw _errorMessage(data);
    }
  }

  String _errorMessage(Map<String, dynamic> data) {
    return data['message']?.toString() ?? 'Group chat request failed';
  }
}
