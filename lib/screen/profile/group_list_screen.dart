import 'package:cnattendance/model/group_chat.dart';
import 'package:cnattendance/provider/groupchatcontroller.dart';
import 'package:cnattendance/screen/profile/group_chat_screen.dart';
import 'package:cnattendance/screen/profile/create_group_screen.dart';
import 'package:cnattendance/screen/profile/group_info_screen.dart';
import 'package:cnattendance/widget/radialDecoration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class GroupListScreen extends StatefulWidget {
  @override
  State<GroupListScreen> createState() => _GroupListScreenState();
}

class _GroupListScreenState extends State<GroupListScreen> {
  final GroupChatController _controller = Get.put(GroupChatController(), tag: 'group_list');

  @override
  void initState() {
    super.initState();
    _controller.loadGroups();
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
          title: Text('Groups', style: TextStyle(color: Colors.white)),
          actions: [
            IconButton(
              icon: Icon(Icons.add, color: Colors.white),
              onPressed: () => Get.to(() => CreateGroupScreen()),
            ),
          ],
        ),
        body: Obx(() {
          if (_controller.isLoading.value) {
            return Center(child: CircularProgressIndicator(color: Colors.white));
          }
          if (_controller.groups.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.group, color: Colors.white38, size: 64),
                  SizedBox(height: 16),
                  Text(
                    'No groups yet',
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Get.to(() => CreateGroupScreen()),
                    child: Text('Create a group'),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            color: Colors.white,
            onRefresh: () => _controller.loadGroups(),
            child: ListView.builder(
              itemCount: _controller.groups.length,
              itemBuilder: (context, index) {
                final group = _controller.groups[index];
                return _GroupTile(group: group, onTap: () {
                  Get.to(() => GroupChatScreen(groupId: group.id, groupName: group.name));
                }, onLongPress: () {
                  _showGroupOptions(group);
                });
              },
            ),
          );
        }),
      ),
    );
  }

  void _showGroupOptions(GroupChat group) {
    Get.bottomSheet(
      Container(
        decoration: BoxDecoration(
          color: Color(0xFF0A1E3D),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.info_outline, color: Colors.white),
              title: Text('View Info', style: TextStyle(color: Colors.white)),
              onTap: () {
                Get.back();
                Get.to(() => GroupInfoScreen(groupId: group.id));
              },
            ),
            if (group.isCreator)
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red[300]),
                title: Text('Delete Group', style: TextStyle(color: Colors.red[300])),
                onTap: () {
                  Get.back();
                  _confirmDelete(group.id);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(int groupId) {
    Get.dialog(
      AlertDialog(
        backgroundColor: Color(0xFF0A1E3D),
        title: Text('Delete Group?', style: TextStyle(color: Colors.white)),
        content: Text('This action cannot be undone.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text('Cancel')),
          TextButton(
            onPressed: () {
              Get.back();
              _controller.deleteGroup(groupId);
            },
            child: Text('Delete', style: TextStyle(color: Colors.red[300])),
          ),
        ],
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  final GroupChat group;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _GroupTile({required this.group, required this.onTap, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.white12,
        backgroundImage: group.avatar != null ? NetworkImage(group.avatar!) : null,
        child: group.avatar == null
            ? Icon(Icons.group, color: Colors.white54)
            : null,
      ),
      title: Text(
        group.name,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (group.lastMessage != null)
            Text(
              '${group.lastMessage!.senderName}: ${_previewText(group.lastMessage!)}',
              style: TextStyle(color: Colors.white54, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          if (group.lastMessageAt != null)
            Text(
              _formatTime(group.lastMessageAt!),
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
        ],
      ),
      trailing: Text(
        '${group.memberCount} members',
        style: TextStyle(color: Colors.white38, fontSize: 12),
      ),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }

  String _previewText(dynamic lastMessage) {
    final type = lastMessage.messageType;
    if (type == 'image') return 'Sent a photo';
    if (type == 'voice') return 'Sent a voice message';
    if (type == 'file') return 'Sent a file';
    if (type == 'location') return 'Sent a location';
    return lastMessage.message ?? '';
  }

  String _formatTime(String isoTime) {
    try {
      final dt = DateTime.parse(isoTime);
      final now = DateTime.now();
      if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
        return DateFormat('hh:mm a').format(dt);
      }
      return DateFormat('MMM dd').format(dt);
    } catch (_) {
      return '';
    }
  }
}
