import 'dart:convert';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/data/source/network/connect.dart';
import 'package:cnattendance/model/admin_chat_message.dart';
import 'package:cnattendance/services/chat_media_upload_service.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:flutter/foundation.dart';

class AdminChatRepository {
  final Preferences _preferences;
  final Connect _connect;

  AdminChatRepository({
    Preferences? preferences,
    Connect? connect,
  })  : _preferences = preferences ?? Preferences(),
        _connect = connect ?? Connect();

  Future<List<AdminChatMessage>> getMessages({
    required String conversationId,
    String adminId = '',
    String adminUsername = '',
    String internalConversationId = '',
  }) async {
    final requestUrl = _messagesUrl(
      fields: _conversationQueryFields(
        conversationId: conversationId,
        adminId: adminId,
        adminUsername: adminUsername,
        internalConversationId: internalConversationId,
      ),
    );
    final appUrl = await _preferences.getAppUrl();
    debugPrint('[ADMIN_CHAT] GET admin thread request URL=$appUrl$requestUrl');

    final scopedResponse = await _connect.getResponse(
      requestUrl,
      await _headers(),
    );
    final responseData = _decodeBody(scopedResponse.body);

    if (scopedResponse.statusCode == 200) {
      final appUrl = await _preferences.getAppUrl();
      final messages = _scopeMessages(
        _normalizeMessageMediaUrls(_readMessages(responseData), appUrl: appUrl),
        conversationId: conversationId,
        adminId: adminId,
        adminUsername: adminUsername,
        internalConversationId: internalConversationId,
        responseConversationId: _responseConversationId(responseData),
      );
      _logLoadedMessages(messages);
      if (messages.isEmpty) {
        debugPrint(
            '[ADMIN_CHAT] empty GET response body=${scopedResponse.body}');
      }
      return messages;
    }

    throw _backendMessage(responseData);
  }

  Future<List<AdminChatMessage>> sendMessage(
    String message, {
    required String conversationId,
    String adminId = '',
    String adminUsername = '',
    String internalConversationId = '',
  }) async {
    return _sendStructuredMessage(
      {
        'message': message,
        'body': message,
        'content': message,
        'type': 'text',
        'message_type': 'text',
        'chat_message_type': 'text',
      },
      conversationId: conversationId,
      adminId: adminId,
      adminUsername: adminUsername,
      internalConversationId: internalConversationId,
    );
  }

  Future<List<AdminChatMessage>> sendMediaMessage({
    required String type,
    required ChatMediaUpload upload,
    required String conversationId,
    String adminId = '',
    String adminUsername = '',
    String internalConversationId = '',
    int? durationSeconds,
    String fileName = '',
  }) async {
    return _sendStructuredMessage(
      {
        'message': '',
        'type': type,
        'message_type': type,
        'chat_message_type': type,
        'media_type': type,
        'media_url': upload.url,
        'media_path': upload.path,
        'media_width': upload.width?.toString() ?? '',
        'media_height': upload.height?.toString() ?? '',
        'duration_seconds': durationSeconds?.toString() ?? '',
        'file_name': fileName,
        'filename': fileName,
      },
      conversationId: conversationId,
      adminId: adminId,
      adminUsername: adminUsername,
      internalConversationId: internalConversationId,
    );
  }

  Future<List<AdminChatMessage>> sendLocation({
    required double latitude,
    required double longitude,
    required String conversationId,
    String adminId = '',
    String adminUsername = '',
    String internalConversationId = '',
  }) async {
    return _sendStructuredMessage(
      {
        'message': '',
        'body': '',
        'type': 'location',
        'message_type': 'location',
        'chat_message_type': 'location',
        'media_url':
            'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
      },
      conversationId: conversationId,
      adminId: adminId,
      adminUsername: adminUsername,
      internalConversationId: internalConversationId,
    );
  }

  Future<List<AdminChatMessage>> _sendStructuredMessage(
    Map<String, dynamic> body, {
    required String conversationId,
    String adminId = '',
    String adminUsername = '',
    String internalConversationId = '',
  }) async {
    final requestBody = {
      ...body,
      ..._conversationFields(
        conversationId: conversationId,
        adminId: adminId,
        adminUsername: adminUsername,
        internalConversationId: internalConversationId,
      ),
    };
    debugPrint('[ADMIN_CHAT] POST admin thread body=$requestBody');

    final response = await _connect.postResponse(
      Constant.ADMIN_CHAT_MESSAGES,
      await _headers(),
      requestBody,
    );
    var responseData = _decodeBody(response.body);

    if ((response.statusCode == 400 || response.statusCode == 422) &&
        _isInvalidTypeError(responseData) &&
        requestBody['type'] != null &&
        requestBody['type'] != 'text') {
      debugPrint('[ADMIN_CHAT] retrying media POST without type field');
      final retryBody = Map<String, dynamic>.from(requestBody)
        ..remove('type')
        ..['chat_message_type'] = requestBody['message_type'] ?? '';
      final retryResponse = await _connect.postResponse(
        Constant.ADMIN_CHAT_MESSAGES,
        await _headers(),
        retryBody,
      );
      responseData = _decodeBody(retryResponse.body);
      if (retryResponse.statusCode != 200 && retryResponse.statusCode != 201) {
        throw _backendMessage(responseData);
      }
    } else if (response.statusCode != 200 && response.statusCode != 201) {
      throw _backendMessage(responseData);
    }

    final appUrl = await _preferences.getAppUrl();
    final messages = _scopeMessages(
      _normalizeMessageMediaUrls(_readMessages(responseData), appUrl: appUrl),
      conversationId: conversationId,
      adminId: adminId,
      adminUsername: adminUsername,
      internalConversationId: internalConversationId,
      responseConversationId: _responseConversationId(responseData),
    );
    _logLoadedMessages(messages);
    return messages;
  }

  String _messagesUrl({
    required Map<String, String> fields,
  }) {
    final query = Uri(queryParameters: fields).query;
    if (query.isEmpty) {
      return Constant.ADMIN_CHAT_MESSAGES;
    }
    return '${Constant.ADMIN_CHAT_MESSAGES}?$query';
  }

  Map<String, String> _conversationFields({
    required String conversationId,
    required String adminId,
    required String adminUsername,
    required String internalConversationId,
  }) {
    final fields = <String, String>{};
    final trimmedConversationId = conversationId.trim();
    final trimmedAdminId = adminId.trim();
    final trimmedAdminUsername = adminUsername.trim();
    final trimmedInternalConversationId = internalConversationId.trim();

    if (trimmedConversationId.isNotEmpty) {
      fields['conversation_id'] = trimmedConversationId;
      fields['chat_id'] = trimmedConversationId;
    }
    if (trimmedAdminId.isNotEmpty) {
      fields['admin_id'] = trimmedAdminId;
      fields['admin_user_id'] = trimmedAdminId;
      fields['support_id'] = trimmedAdminId;
    }
    if (trimmedAdminUsername.isNotEmpty) {
      fields['admin_username'] = trimmedAdminUsername;
      fields['admin_user_name'] = trimmedAdminUsername;
      fields['support_username'] = trimmedAdminUsername;
    }
    if (trimmedInternalConversationId.isNotEmpty) {
      fields['internal_conversation_id'] = trimmedInternalConversationId;
      fields['thread_id'] = trimmedInternalConversationId;
    }

    return fields;
  }

  Map<String, String> _conversationQueryFields({
    required String conversationId,
    required String adminId,
    required String adminUsername,
    required String internalConversationId,
  }) {
    return _conversationFields(
      conversationId: conversationId,
      adminId: adminId,
      adminUsername: adminUsername,
      internalConversationId: internalConversationId,
    );
  }

  List<AdminChatMessage> _scopeMessages(
    List<AdminChatMessage> messages, {
    required String conversationId,
    required String adminId,
    required String adminUsername,
    required String internalConversationId,
    required String responseConversationId,
  }) {
    final requestedConversationId = conversationId.trim();
    final requestedAdminId = adminId.trim();
    final requestedAdminUsername = adminUsername.trim();
    final requestedInternalConversationId = internalConversationId.trim();
    final returnedConversationId = responseConversationId.trim();
    final acceptedInternalIds = <String>{
      if (requestedInternalConversationId.isNotEmpty)
        requestedInternalConversationId,
      if (returnedConversationId.isNotEmpty) returnedConversationId,
    };

    debugPrint(
      '[ADMIN_CHAT] scope request'
      ' | conversation_id=$requestedConversationId'
      ' | internal_conversation_id=$requestedInternalConversationId'
      ' | response_conversation_id=$returnedConversationId'
      ' | admin_id=$requestedAdminId'
      ' | admin_username=$requestedAdminUsername',
    );

    final scoped = messages.where((message) {
      final messageConversationId = message.conversationId.trim();
      final messageAdminId = message.adminId.trim();
      final messageAdminUsername = message.adminUsername.trim();

      if (messageConversationId.startsWith('employee_admin_') &&
          requestedConversationId.startsWith('employee_admin_')) {
        return messageConversationId == requestedConversationId;
      }

      if (acceptedInternalIds.contains(messageConversationId)) {
        return true;
      }

      if (messageAdminId.isNotEmpty && requestedAdminId.isNotEmpty) {
        return messageAdminId == requestedAdminId;
      }

      if (messageAdminUsername.isNotEmpty &&
          requestedAdminUsername.isNotEmpty) {
        return messageAdminUsername == requestedAdminUsername;
      }

      if (messageConversationId.isEmpty &&
          messageAdminId.isEmpty &&
          messageAdminUsername.isEmpty) {
        debugPrint(
          '[ADMIN_CHAT] dropped unscoped admin message'
          ' | requested_conversation_id=$requestedConversationId'
          ' | requested_admin_id=$requestedAdminId'
          ' | message_id=${message.id}',
        );
      }

      return false;
    }).toList();

    if (scoped.isNotEmpty || messages.isEmpty) {
      return scoped;
    }

    final allReturnedMessagesAreUnscoped = messages.every((message) {
      return message.conversationId.trim().isEmpty &&
          message.adminId.trim().isEmpty &&
          message.adminUsername.trim().isEmpty;
    });
    if (allReturnedMessagesAreUnscoped &&
        (requestedConversationId.startsWith('employee_admin_') ||
            requestedAdminId.isNotEmpty ||
            requestedAdminUsername.isNotEmpty ||
            returnedConversationId.isNotEmpty)) {
      debugPrint(
        '[ADMIN_CHAT] using scoped endpoint messages without row identifiers'
        ' | requested_conversation_id=$requestedConversationId'
        ' | requested_admin_id=$requestedAdminId'
        ' | count=${messages.length}',
      );
      return messages;
    }

    return scoped;
  }

  String _responseConversationId(Map<String, dynamic> responseData) {
    final data = responseData['data'];
    if (data is! Map) {
      return '';
    }

    final internalConversationId = data['internal_conversation_id'];
    if (internalConversationId != null &&
        internalConversationId.toString().trim().isNotEmpty) {
      return internalConversationId.toString().trim();
    }

    final conversationId = data['conversation_id'];
    if (conversationId != null &&
        conversationId.toString().trim().isNotEmpty &&
        !conversationId.toString().trim().startsWith('employee_admin_')) {
      return conversationId.toString().trim();
    }

    return '';
  }

  Future<Map<String, String>> _headers() async {
    final token = await _preferences.getToken();
    return {
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _decodeBody(String body) {
    if (body.trim().isEmpty) {
      return {};
    }

    try {
      final decoded = json.decode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return {'message': decoded.toString()};
    } catch (_) {
      return {'message': body};
    }
  }

  List<AdminChatMessage> _readMessages(Map<String, dynamic> responseData) {
    final data = responseData['data'];
    final messages = responseData['messages'] ??
        responseData['message_list'] ??
        (data is Map
            ? data['messages'] ??
                data['message_list'] ??
                data['items'] ??
                data['data'] ??
                (data['conversation'] is Map
                    ? data['conversation']['messages'] ??
                        data['conversation']['message_list'] ??
                        data['conversation']['items']
                    : null)
            : data);

    if (messages is! List) {
      return [];
    }

    return messages.map((item) => AdminChatMessage.fromJson(item)).toList();
  }

  List<AdminChatMessage> _normalizeMessageMediaUrls(
    List<AdminChatMessage> messages, {
    required String appUrl,
  }) {
    return messages.map((message) {
      final normalizedMediaUrl = _resolveMediaUrl(
        mediaUrl: message.mediaUrl,
        mediaPath: message.mediaPath,
        appUrl: appUrl,
      );
      if (normalizedMediaUrl == message.mediaUrl) {
        return message;
      }
      return message.copyWith(mediaUrl: normalizedMediaUrl);
    }).toList();
  }

  String _resolveMediaUrl({
    required String mediaUrl,
    required String mediaPath,
    required String appUrl,
  }) {
    final trimmedUrl = mediaUrl.trim();
    final trimmedPath = mediaPath.trim();

    final repairedFromPath = _resolveStorageUrl(trimmedPath, appUrl: appUrl);
    if (repairedFromPath.isNotEmpty) {
      return repairedFromPath;
    }

    return _resolveStorageUrl(trimmedUrl, appUrl: appUrl);
  }

  String _resolveStorageUrl(String value, {required String appUrl}) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
      final path = uri.path.toLowerCase();
      if (path.contains('/chat/images/') ||
          path.contains('/chat/voice/') ||
          path.contains('/chat/files/')) {
        final fixedPath = path.startsWith('/storage/')
            ? uri.path
            : uri.path.startsWith('/')
                ? '/storage${uri.path}'
                : '/storage/${uri.path}';
        return uri.replace(path: fixedPath).toString();
      }
      return trimmed;
    }

    final baseUri = Uri.tryParse(appUrl);
    if (baseUri == null) {
      return trimmed;
    }

    if (trimmed.startsWith('/storage/')) {
      return baseUri.resolve(trimmed).toString();
    }
    if (trimmed.startsWith('storage/')) {
      return baseUri.resolve('/$trimmed').toString();
    }
    if (trimmed.startsWith('chat/')) {
      return baseUri.resolve('/storage/$trimmed').toString();
    }
    if (trimmed.startsWith('/chat/')) {
      return baseUri.resolve('/storage${trimmed}').toString();
    }
    if (trimmed.startsWith('/')) {
      return baseUri.resolve(trimmed).toString();
    }
    return trimmed;
  }

  void _logLoadedMessages(List<AdminChatMessage> messages) {
    debugPrint('[ADMIN_CHAT] loaded messages count=${messages.length}');
    for (var index = 0; index < messages.length && index < 3; index += 1) {
      final message = messages[index];
      debugPrint(
        '[ADMIN_CHAT] loaded message[$index]'
        ' | id=${message.id}'
        ' | conversation_id=${message.conversationId}'
        ' | admin_id=${message.adminId}'
        ' | admin_username=${message.adminUsername}'
        ' | sender=${message.sender}'
        ' | type=${message.type}'
        ' | message=${message.message}',
      );
    }
  }

  String _backendMessage(Map<String, dynamic> responseData) {
    final message = responseData['message'];
    if (message != null && message.toString().trim().isNotEmpty) {
      return message.toString();
    }
    return 'Admin chat request failed';
  }

  bool _isInvalidTypeError(Map<String, dynamic> responseData) {
    final message = _backendMessage(responseData).toLowerCase();
    return message.contains('selected type is invalid') ||
        (message.contains('type') && message.contains('invalid'));
  }
}
