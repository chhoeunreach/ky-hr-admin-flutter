class GroupChat {
  final int id;
  final String name;
  final String? description;
  final String? avatar;
  final String groupCode;
  final int creatorId;
  final String? myRole;
  final int memberCount;
  final List<String> memberAvatars;
  final GroupChatLastMessage? lastMessage;
  final String? lastMessageAt;
  final String? createdAt;

  GroupChat({
    required this.id,
    required this.name,
    this.description,
    this.avatar,
    required this.groupCode,
    required this.creatorId,
    this.myRole,
    required this.memberCount,
    required this.memberAvatars,
    this.lastMessage,
    this.lastMessageAt,
    this.createdAt,
  });

  factory GroupChat.fromJson(Map<String, dynamic> json) {
    return GroupChat(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name'] ?? '',
      description: json['description'],
      avatar: json['avatar'],
      groupCode: json['group_code'] ?? '',
      creatorId: json['creator_id'] is int ? json['creator_id'] : int.tryParse(json['creator_id'].toString()) ?? 0,
      myRole: json['my_role'],
      memberCount: json['member_count'] ?? 0,
      memberAvatars: (json['member_avatars'] as List?)?.map((e) => e.toString()).toList() ?? [],
      lastMessage: json['last_message'] != null
          ? GroupChatLastMessage.fromJson(json['last_message'])
          : null,
      lastMessageAt: json['last_message_at'],
      createdAt: json['created_at'],
    );
  }

  bool get isCreator => myRole == 'creator';
  bool get isAdmin => myRole == 'admin' || myRole == 'creator';
}

class GroupChatLastMessage {
  final String? message;
  final String messageType;
  final String senderName;
  final int senderId;
  final String? createdAt;

  GroupChatLastMessage({
    this.message,
    required this.messageType,
    required this.senderName,
    required this.senderId,
    this.createdAt,
  });

  factory GroupChatLastMessage.fromJson(Map<String, dynamic> json) {
    return GroupChatLastMessage(
      message: json['message'],
      messageType: json['message_type'] ?? 'text',
      senderName: json['sender_name'] ?? '',
      senderId: json['sender_id'] is int ? json['sender_id'] : int.tryParse(json['sender_id'].toString()) ?? 0,
      createdAt: json['created_at'],
    );
  }
}
