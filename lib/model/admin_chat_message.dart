import 'dart:convert';

class AdminChatMessage {
  final String id;
  final String message;
  final String sender;
  final String senderName;
  final String conversationId;
  final String adminId;
  final String adminUsername;
  final DateTime dateTime;
  final String type;
  final String mediaUrl;
  final String mediaPath;
  final String fileName;
  final int? mediaWidth;
  final int? mediaHeight;
  final int? durationSeconds;
  final double? latitude;
  final double? longitude;

  const AdminChatMessage({
    required this.id,
    required this.message,
    required this.sender,
    required this.senderName,
    required this.conversationId,
    required this.adminId,
    required this.adminUsername,
    required this.dateTime,
    required this.type,
    required this.mediaUrl,
    required this.mediaPath,
    required this.fileName,
    this.mediaWidth,
    this.mediaHeight,
    this.durationSeconds,
    this.latitude,
    this.longitude,
  });

  factory AdminChatMessage.fromJson(dynamic json) {
    final map = json is Map<String, dynamic> ? json : <String, dynamic>{};
    final rawMessage = _readString(
      map,
      ['message', 'body', 'text', 'content'],
    );
    final rawType = _readString(
      map,
      ['type', 'message_type', 'chat_message_type', 'media_type'],
      fallback: 'text',
    );

    return AdminChatMessage(
      id: _readString(map, ['id', 'message_id']),
      message: _decodeMessage(rawMessage),
      sender: _readString(map, [
        'sender',
        'sender_username',
        'from',
        'from_user',
        'user_type',
        'sender_type',
      ]),
      senderName: _readString(map, ['sender_name', 'name', 'from_name']),
      conversationId: _readString(map, ['conversation_id', 'conversationId']),
      adminId: _readString(map, ['admin_id', 'admin_user_id']),
      adminUsername: _readString(map, ['admin_username', 'admin_user_name']),
      dateTime: _readDate(map),
      type: _normalizeType(rawType, map),
      mediaUrl: _readString(map, [
        'media_url',
        'url',
        'attachment_url',
        'file_url',
        'path_url',
      ]),
      mediaPath: _readString(map, ['media_path', 'path', 'attachment_path']),
      fileName: _readString(map, ['file_name', 'filename', 'name']),
      mediaWidth: _readInt(map['media_width'] ?? map['width']),
      mediaHeight: _readInt(map['media_height'] ?? map['height']),
      durationSeconds: _readInt(map['duration_seconds'] ?? map['duration']),
      latitude: _readDouble(map['latitude'] ?? map['lat']),
      longitude: _readDouble(map['longitude'] ?? map['lng'] ?? map['lon']),
    );
  }

  bool get isFromAdmin {
    final value = sender.trim().toLowerCase();
    return value == 'admin' || value == 'administrator';
  }

  static String _readString(
    Map<String, dynamic> map,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = map[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return fallback;
  }

  static DateTime _readDate(Map<String, dynamic> map) {
    final value = map['date'] ??
        map['created_at'] ??
        map['createdAt'] ??
        map['time'] ??
        map['timestamp'];
    if (value == null) {
      return DateTime.now();
    }

    final parsed = DateTime.tryParse(value.toString());
    return parsed ?? DateTime.now();
  }

  static int? _readInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    return int.tryParse(value.toString());
  }

  static double? _readDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is double) {
      return value;
    }
    if (value is int) {
      return value.toDouble();
    }
    return double.tryParse(value.toString());
  }

  static String _decodeMessage(String value) {
    if (value.trim().isEmpty) {
      return '';
    }

    try {
      return utf8.decode(base64.decode(value));
    } catch (_) {
      return value;
    }
  }

  static String _normalizeType(String value, Map<String, dynamic> map) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'photo' || normalized == 'picture') {
      return 'image';
    }
    if (normalized == 'audio') {
      return 'voice';
    }
    if (normalized == 'document' ||
        normalized == 'attachment' ||
        normalized == 'application') {
      return 'file';
    }
    if (normalized.isNotEmpty && normalized != 'text') {
      return normalized;
    }

    final mediaUrl = _readString(map, [
      'media_url',
      'url',
      'attachment_url',
      'file_url',
      'path_url',
    ]);
    if (mediaUrl.trim().isEmpty) {
      return 'text';
    }

    final fileName = _readString(map, ['file_name', 'filename', 'name']);
    final source = '$mediaUrl $fileName'.toLowerCase();
    if (source.contains('.jpg') ||
        source.contains('.jpeg') ||
        source.contains('.png') ||
        source.contains('.gif') ||
        source.contains('.webp') ||
        source.contains('.heic')) {
      return 'image';
    }
    if (source.contains('.m4a') ||
        source.contains('.mp4') ||
        source.contains('.mp3') ||
        source.contains('.wav') ||
        source.contains('.aac') ||
        source.contains('.webm') ||
        source.contains('.ogg')) {
      return 'voice';
    }
    return 'file';
  }

  AdminChatMessage copyWith({
    String? id,
    String? message,
    String? sender,
    String? senderName,
    String? conversationId,
    String? adminId,
    String? adminUsername,
    DateTime? dateTime,
    String? type,
    String? mediaUrl,
    String? mediaPath,
    String? fileName,
    int? mediaWidth,
    int? mediaHeight,
    int? durationSeconds,
    double? latitude,
    double? longitude,
  }) {
    return AdminChatMessage(
      id: id ?? this.id,
      message: message ?? this.message,
      sender: sender ?? this.sender,
      senderName: senderName ?? this.senderName,
      conversationId: conversationId ?? this.conversationId,
      adminId: adminId ?? this.adminId,
      adminUsername: adminUsername ?? this.adminUsername,
      dateTime: dateTime ?? this.dateTime,
      type: type ?? this.type,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaPath: mediaPath ?? this.mediaPath,
      fileName: fileName ?? this.fileName,
      mediaWidth: mediaWidth ?? this.mediaWidth,
      mediaHeight: mediaHeight ?? this.mediaHeight,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}
