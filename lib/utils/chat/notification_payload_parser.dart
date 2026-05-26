import 'package:flutter/foundation.dart';

class ChatNotificationPayload {
  final String type;
  final String chatMessageType;
  final String senderName;
  final String senderImage;
  final String senderUsername;
  final String projectId;
  final String conversationId;
  final String title;
  final String message;
  final String body;
  final String description;
  final String mediaUrl;
  final String userType;
  final String role;
  final String isAdmin;
  final String admin;
  final String directoryType;
  final String chatMode;
  final String adminId;
  final String adminUsername;
  final String internalConversationId;

  const ChatNotificationPayload({
    required this.type,
    required this.chatMessageType,
    required this.senderName,
    required this.senderImage,
    required this.senderUsername,
    required this.projectId,
    required this.conversationId,
    required this.title,
    required this.message,
    required this.body,
    required this.description,
    required this.mediaUrl,
    required this.userType,
    required this.role,
    required this.isAdmin,
    required this.admin,
    required this.directoryType,
    required this.chatMode,
    required this.adminId,
    required this.adminUsername,
    required this.internalConversationId,
  });

  factory ChatNotificationPayload.fromData(
    Map<String, dynamic> data, {
    String title = '',
    String message = '',
  }) {
    final payload = ChatNotificationPayload(
      type: _read(data, 'type'),
      chatMessageType: _read(data, 'chat_message_type').trim().isNotEmpty
          ? _read(data, 'chat_message_type')
          : _read(data, 'message_type'),
      senderName: _read(data, 'sender_name'),
      senderImage: _read(data, 'sender_image'),
      senderUsername: _read(data, 'sender_username'),
      projectId: _read(data, 'project_id'),
      conversationId: _read(data, 'conversation_id'),
      title: title,
      message: message,
      body: _read(data, 'body'),
      description: _read(data, 'description'),
      mediaUrl: _read(data, 'media_url'),
      userType: _read(data, 'user_type'),
      role: _read(data, 'role'),
      isAdmin: _read(data, 'is_admin'),
      admin: _read(data, 'admin'),
      directoryType: _read(data, 'directory_type'),
      chatMode: _read(data, 'chat_mode'),
      adminId: _read(data, 'admin_id'),
      adminUsername: _read(data, 'admin_username'),
      internalConversationId: _read(data, 'internal_conversation_id'),
    );

    debugPrint('[PUSH] parsed notification payload=${payload.toLogMap()}');
    return payload;
  }

  Map<String, String> toMap({String localKey = ''}) {
    return {
      'type': type,
      'chat_message_type': chatMessageType,
      'message_type': chatMessageType,
      'sender_name': senderName,
      'sender_image': senderImage,
      'sender_username': senderUsername,
      'project_id': projectId,
      'conversation_id': conversationId,
      'title': title,
      'message': message,
      'body': body,
      'description': description,
      'media_url': mediaUrl,
      'user_type': userType,
      'role': role,
      'is_admin': isAdmin,
      'admin': admin,
      'directory_type': directoryType,
      'chat_mode': chatMode,
      'admin_id': adminId,
      'admin_username': adminUsername,
      'internal_conversation_id': internalConversationId,
      'local_key': localKey,
    };
  }

  Map<String, String> toLogMap() {
    return {
      'type': type,
      'chat_message_type': chatMessageType,
      'sender_name': senderName,
      'sender_username': senderUsername,
      'conversation_id': conversationId,
      'user_type': userType,
      'role': role,
      'directory_type': directoryType,
      'chat_mode': chatMode,
      'admin_id': adminId,
      'admin_username': adminUsername,
      'internal_conversation_id': internalConversationId,
      'message': message,
      'media_url': mediaUrl,
    };
  }

  static String _read(Map<String, dynamic> data, String key) {
    return data[key]?.toString() ?? '';
  }
}
