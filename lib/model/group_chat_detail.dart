import 'package:cnattendance/model/group_chat_member.dart';

class GroupChatDetail {
  final int id;
  final String name;
  final String? description;
  final String? avatar;
  final String groupCode;
  final int creatorId;
  final String? myRole;
  final int memberCount;
  final String? createdAt;
  final List<GroupChatMember> members;

  GroupChatDetail({
    required this.id,
    required this.name,
    this.description,
    this.avatar,
    required this.groupCode,
    required this.creatorId,
    this.myRole,
    required this.memberCount,
    this.createdAt,
    required this.members,
  });

  factory GroupChatDetail.fromJson(Map<String, dynamic> json) {
    return GroupChatDetail(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name'] ?? '',
      description: json['description'],
      avatar: json['avatar'],
      groupCode: json['group_code'] ?? '',
      creatorId: json['creator_id'] is int ? json['creator_id'] : int.tryParse(json['creator_id'].toString()) ?? 0,
      myRole: json['my_role'],
      memberCount: json['member_count'] ?? 0,
      createdAt: json['created_at'],
      members: (json['members'] as List?)?.map((e) => GroupChatMember.fromJson(e)).toList() ?? [],
    );
  }

  bool get isCreator => myRole == 'creator';
  bool get isAdmin => myRole == 'admin' || myRole == 'creator';
}
