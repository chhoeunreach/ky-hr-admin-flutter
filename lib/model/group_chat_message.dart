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
    final rawType = (json['message_type'] ??
            json['type'] ??
            json['media_type'] ??
            json['chat_message_type'] ??
            'text')
        .toString()
        .toLowerCase();
    final normalizedType = (rawType == 'audio')
        ? 'voice'
        : (rawType == 'document'
            ? 'file'
            : (rawType == 'photo' ? 'image' : rawType));

    return GroupChatMessage(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      groupChatId: json['group_chat_id'] is int ? json['group_chat_id'] : int.tryParse(json['group_chat_id'].toString()) ?? 0,
      senderId: json['sender_id'] is int ? json['sender_id'] : int.tryParse(json['sender_id'].toString()) ?? 0,
      senderName: json['sender_name'] ?? json['name'] ?? '',
      senderAvatar: json['sender_avatar'] ?? json['avatar'],
      messageType: normalizedType,
      message: json['message'] ?? json['text'] ?? json['body'],
      mediaUrl: json['media_url'] ?? json['url'] ?? json['file_url'] ?? json['attachment_url'],
      mediaPath: json['media_path'] ?? json['path'] ?? json['attachment_path'],
      fileName: json['file_name'] ?? json['filename'] ?? json['name'],
      mediaWidth: json['media_width'] is int
          ? json['media_width']
          : (json['media_width'] != null
              ? int.tryParse(json['media_width'].toString())
              : (json['width'] is int
                  ? json['width']
                  : int.tryParse(json['width']?.toString() ?? ''))),
      mediaHeight: json['media_height'] is int
          ? json['media_height']
          : (json['media_height'] != null
              ? int.tryParse(json['media_height'].toString())
              : (json['height'] is int
                  ? json['height']
                  : int.tryParse(json['height']?.toString() ?? ''))),
      durationSeconds: json['duration_seconds'] is int
          ? json['duration_seconds']
          : (json['duration_seconds'] != null
              ? int.tryParse(json['duration_seconds'].toString())
              : (json['duration'] is int
                  ? json['duration']
                  : int.tryParse(json['duration']?.toString() ?? ''))),
      latitude: json['latitude'] is double
          ? json['latitude']
          : (json['latitude'] != null
              ? double.tryParse(json['latitude'].toString())
              : (json['lat'] is double
                  ? json['lat']
                  : double.tryParse(json['lat']?.toString() ?? ''))),
      longitude: json['longitude'] is double
          ? json['longitude']
          : (json['longitude'] != null
              ? double.tryParse(json['longitude'].toString())
              : (json['lng'] is double
                  ? json['lng']
                  : double.tryParse(json['lng']?.toString() ?? ''))),
      mapUrl: json['map_url'] ?? json['maps_url'],
      createdAt: json['created_at']?.toString(),
      isEdited: json['is_edited'] == true || json['is_edited'] == 1 || json['is_edited'] == '1',
      isDeleted: json['is_deleted'] == true || json['is_deleted'] == 1 || json['is_deleted'] == '1',
      editedAt: json['edited_at']?.toString(),
      deletedAt: json['deleted_at']?.toString(),
    );
  }

  bool get isImage => messageType == 'image' || messageType == 'photo';
  bool get isVoice => messageType == 'voice' || messageType == 'audio';
  bool get isFile => messageType == 'file' || messageType == 'document';
  bool get isLocation => messageType == 'location';
  bool get isText =>
      messageType == 'text' || (!isVoice && !isImage && !isFile && !isLocation);
}
