class GroupChatMessage {
  final int id;
  final int groupChatId;
  final int senderId;
  final String senderName;
  final String? senderAvatar;
  final String messageType;
  final String? message;
  final String? mediaUrl;
  final String? mediaPath;
  final String? fileName;
  final int? mediaWidth;
  final int? mediaHeight;
  final int? durationSeconds;
  final double? latitude;
  final double? longitude;
  final String? mapUrl;
  final String? createdAt;
  final bool isEdited;
  final bool isDeleted;
  final String? editedAt;
  final String? deletedAt;

  GroupChatMessage({
    required this.id,
    required this.groupChatId,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    required this.messageType,
    this.message,
    this.mediaUrl,
    this.mediaPath,
    this.fileName,
    this.mediaWidth,
    this.mediaHeight,
    this.durationSeconds,
    this.latitude,
    this.longitude,
    this.mapUrl,
    this.createdAt,
    this.isEdited = false,
    this.isDeleted = false,
    this.editedAt,
    this.deletedAt,
  });

  factory GroupChatMessage.fromJson(Map<String, dynamic> json) {
    return GroupChatMessage(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      groupChatId: json['group_chat_id'] is int ? json['group_chat_id'] : int.tryParse(json['group_chat_id'].toString()) ?? 0,
      senderId: json['sender_id'] is int ? json['sender_id'] : int.tryParse(json['sender_id'].toString()) ?? 0,
      senderName: json['sender_name'] ?? '',
      senderAvatar: json['sender_avatar'],
      messageType: json['message_type'] ?? 'text',
      message: json['message'],
      mediaUrl: json['media_url'],
      mediaPath: json['media_path'],
      fileName: json['file_name'],
      mediaWidth: json['media_width'] is int ? json['media_width'] : (json['media_width'] != null ? int.tryParse(json['media_width'].toString()) : null),
      mediaHeight: json['media_height'] is int ? json['media_height'] : (json['media_height'] != null ? int.tryParse(json['media_height'].toString()) : null),
      durationSeconds: json['duration_seconds'] is int ? json['duration_seconds'] : (json['duration_seconds'] != null ? int.tryParse(json['duration_seconds'].toString()) : null),
      latitude: json['latitude'] is double ? json['latitude'] : (json['latitude'] != null ? double.tryParse(json['latitude'].toString()) : null),
      longitude: json['longitude'] is double ? json['longitude'] : (json['longitude'] != null ? double.tryParse(json['longitude'].toString()) : null),
      mapUrl: json['map_url'],
      createdAt: json['created_at'],
      isEdited: json['is_edited'] == true,
      isDeleted: json['is_deleted'] == true,
      editedAt: json['edited_at']?.toString(),
      deletedAt: json['deleted_at']?.toString(),
    );
  }

  bool get isImage => messageType == 'image';
  bool get isVoice => messageType == 'voice';
  bool get isFile => messageType == 'file';
  bool get isLocation => messageType == 'location';
  bool get isText => messageType == 'text';
}
