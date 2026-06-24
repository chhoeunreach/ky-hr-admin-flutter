import 'package:cnattendance/model/group_chat_detail.dart';
import 'package:cnattendance/model/group_chat_member.dart';
import 'package:cnattendance/provider/groupchatcontroller.dart';
import 'package:cnattendance/widget/radialDecoration.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class GroupInfoScreen extends StatefulWidget {
  final int groupId;

  const GroupInfoScreen({required this.groupId});

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  late GroupChatController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.find<GroupChatController>(tag: 'group_chat_${widget.groupId}');
    if (_controller.currentGroup.value?.id != widget.groupId) {
      _controller.loadGroupDetail(widget.groupId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: RadialDecoration(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('Group Info', style: TextStyle(color: Colors.white)),
        ),
        body: Obx(() {
          final group = _controller.currentGroup.value;
          if (_controller.isLoading.value && group == null) {
            return Center(child: CircularProgressIndicator(color: Colors.white));
          }
          if (group == null) {
            return Center(
              child: Text('Group not found', style: TextStyle(color: Colors.white54)),
            );
          }
          return ListView(
            padding: EdgeInsets.all(16),
            children: [
              _HeaderSection(group: group),
              SizedBox(height: 24),
              _MembersSection(
                group: group,
                controller: _controller,
              ),
              SizedBox(height: 24),
              _ActionsSection(
                group: group,
                controller: _controller,
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  final GroupChatDetail group;

  const _HeaderSection({required this.group});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: Colors.white12,
          backgroundImage: group.avatar != null ? NetworkImage(group.avatar!) : null,
          child: group.avatar == null
              ? Icon(Icons.group, size: 40, color: Colors.white54)
              : null,
        ),
        SizedBox(height: 12),
        Text(
          group.name,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (group.description != null && group.description!.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              group.description!,
              style: TextStyle(color: Colors.white54),
              textAlign: TextAlign.center,
            ),
          ),
        SizedBox(height: 8),
        Text(
          '${group.memberCount} members',
          style: TextStyle(color: Colors.white54, fontSize: 14),
        ),
      ],
    );
  }
}

class _MembersSection extends StatelessWidget {
  final GroupChatDetail group;
  final GroupChatController controller;

  const _MembersSection({required this.group, required this.controller});

  @override
  Widget build(BuildContext context) {
    final creators = group.members.where((m) => m.isCreator).toList();
    final admins = group.members.where((m) => m.isAdmin && !m.isCreator).toList();
    final regulars = group.members.where((m) => !m.isAdmin).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Members',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (group.isAdmin)
              TextButton.icon(
                onPressed: () => _showAddMembersDialog(context),
                icon: Icon(Icons.person_add, color: Colors.amber, size: 18),
                label: Text('Add', style: TextStyle(color: Colors.amber)),
              ),
          ],
        ),
        SizedBox(height: 8),
        if (creators.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.only(left: 8, bottom: 4),
            child: Text('Owner', style: TextStyle(color: Colors.amber, fontSize: 12)),
          ),
          ...creators.map((m) => _MemberTile(member: m, group: group, controller: controller)),
          SizedBox(height: 8),
        ],
        if (admins.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.only(left: 8, bottom: 4),
            child: Text('Admins', style: TextStyle(color: Colors.blue[200], fontSize: 12)),
          ),
          ...admins.map((m) => _MemberTile(member: m, group: group, controller: controller)),
          SizedBox(height: 8),
        ],
        if (regulars.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.only(left: 8, bottom: 4),
            child: Text('Members', style: TextStyle(color: Colors.white38, fontSize: 12)),
          ),
          ...regulars.map((m) => _MemberTile(member: m, group: group, controller: controller)),
        ],
      ],
    );
  }

  void _showAddMembersDialog(BuildContext context) {
    Get.dialog(
      AlertDialog(
        backgroundColor: Color(0xFF0A1E3D),
        title: Text('Add Members', style: TextStyle(color: Colors.white)),
        content: Text('Coming soon: contact selection', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final GroupChatMember member;
  final GroupChatDetail group;
  final GroupChatController controller;

  const _MemberTile({
    required this.member,
    required this.group,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.white12,
        backgroundImage: member.avatar != null ? NetworkImage(member.avatar!) : null,
        child: member.avatar == null
            ? Icon(Icons.person, color: Colors.white54)
            : null,
      ),
      title: Text(
        member.name,
        style: TextStyle(color: Colors.white),
      ),
      subtitle: Row(
        children: [
          if (member.isCreator)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('Owner',
                  style: TextStyle(color: Colors.amber, fontSize: 11)),
            )
          else if (member.isAdmin)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('Admin',
                  style: TextStyle(color: Colors.blue[200], fontSize: 11)),
            )
          else
            Text('Member', style: TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
      trailing: group.isCreator && !member.isCreator
          ? PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: Colors.white54),
              onSelected: (value) {
                switch (value) {
                  case 'promote':
                    controller.promoteToAdmin(group.id, member.userId);
                    break;
                  case 'demote':
                    controller.demoteToMember(group.id, member.userId);
                    break;
                  case 'remove':
                    _confirmRemove(context);
                    break;
                }
              },
              itemBuilder: (_) => [
                if (!member.isAdmin)
                  PopupMenuItem(
                    value: 'promote',
                    child: Text('Promote to Admin',
                        style: TextStyle(color: Colors.white)),
                  ),
                if (member.isAdmin && group.isCreator)
                  PopupMenuItem(
                    value: 'demote',
                    child: Text('Demote to Member',
                        style: TextStyle(color: Colors.white)),
                  ),
                PopupMenuItem(
                  value: 'remove',
                  child: Text('Remove', style: TextStyle(color: Colors.red[300])),
                ),
              ],
            )
          : null,
    );
  }

  void _confirmRemove(BuildContext context) {
    Get.dialog(
      AlertDialog(
        backgroundColor: Color(0xFF0A1E3D),
        title: Text('Remove Member?', style: TextStyle(color: Colors.white)),
        content: Text('Remove ${member.name} from the group?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text('Cancel')),
          TextButton(
            onPressed: () {
              Get.back();
              controller.removeMember(group.id, member.userId);
            },
            child: Text('Remove', style: TextStyle(color: Colors.red[300])),
          ),
        ],
      ),
    );
  }
}

class _ActionsSection extends StatelessWidget {
  final GroupChatDetail group;
  final GroupChatController controller;

  const _ActionsSection({required this.group, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!group.isCreator)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _confirmLeave(context),
              icon: Icon(Icons.exit_to_app, color: Colors.red[300]),
              label: Text('Leave Group', style: TextStyle(color: Colors.red[300])),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.red.withOpacity(0.3)),
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        if (group.isCreator) ...[
          SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _confirmDelete(context),
              icon: Icon(Icons.delete, color: Colors.red[300]),
              label: Text('Delete Group', style: TextStyle(color: Colors.red[300])),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.red.withOpacity(0.3)),
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _confirmLeave(BuildContext context) {
    Get.dialog(
      AlertDialog(
        backgroundColor: Color(0xFF0A1E3D),
        title: Text('Leave Group?', style: TextStyle(color: Colors.white)),
        content: Text('You will no longer have access to this group.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text('Cancel')),
          TextButton(
            onPressed: () {
              Get.back();
              controller.leaveGroup(group.id);
            },
            child: Text('Leave', style: TextStyle(color: Colors.red[300])),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    Get.dialog(
      AlertDialog(
        backgroundColor: Color(0xFF0A1E3D),
        title: Text('Delete Group?', style: TextStyle(color: Colors.white)),
        content: Text('This action cannot be undone.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text('Cancel')),
          TextButton(
            onPressed: () {
              Get.back();
              controller.deleteGroup(group.id);
            },
            child: Text('Delete', style: TextStyle(color: Colors.red[300])),
          ),
        ],
      ),
    );
  }
}
