class GroupChatMember {
  final int id;
  final int userId;
  final String name;
  final String? username;
  final String? avatar;
  final String role;
  final String? joinedAt;

  GroupChatMember({
    required this.id,
    required this.userId,
    required this.name,
    this.username,
    this.avatar,
    required this.role,
    this.joinedAt,
  });

  factory GroupChatMember.fromJson(Map<String, dynamic> json) {
    return GroupChatMember(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      userId: json['user_id'] is int ? json['user_id'] : int.tryParse(json['user_id'].toString()) ?? 0,
      name: json['name'] ?? '',
      username: json['username'],
      avatar: json['avatar'],
      role: json['role'] ?? 'member',
      joinedAt: json['joined_at'],
    );
  }

  bool get isCreator => role == 'creator';
  bool get isAdmin => role == 'admin' || role == 'creator';
}
