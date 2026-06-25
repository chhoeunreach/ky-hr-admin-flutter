import 'package:cnattendance/model/group_chat.dart';
import 'package:cnattendance/provider/groupchatcontroller.dart';
import 'package:cnattendance/screen/profile/group_chat_screen.dart';
import 'package:cnattendance/screen/profile/create_group_screen.dart';
import 'package:cnattendance/screen/profile/group_info_screen.dart';
import 'package:cnattendance/widget/radialDecoration.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class GroupListScreen extends StatefulWidget {
  @override
  State<GroupListScreen> createState() => _GroupListScreenState();
}

class _GroupListScreenState extends State<GroupListScreen> {
  final GroupChatController _controller = Get.put(GroupChatController(), tag: 'group_list');
  final _searchController = TextEditingController();
  var _showSearch = false;

  @override
  void initState() {
    super.initState();
    _controller.loadGroups();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
          title: _showSearch
              ? TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: const InputDecoration(
                    hintText: 'Search groups...',
                    hintStyle: TextStyle(color: Colors.white38),
                    border: InputBorder.none,
                  ),
                  cursorColor: Colors.white,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                )
              : const Text('Chats', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          actions: [
            IconButton(
              icon: Icon(_showSearch ? Icons.close : Icons.search, color: Colors.white),
              onPressed: () {
                setState(() {
                  _showSearch = !_showSearch;
                  if (!_showSearch) _searchController.clear();
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.add, color: Colors.white),
              onPressed: () => Get.to(() => CreateGroupScreen()),
            ),
          ],
        ),
        body: Obx(() {
          if (_controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }

          final query = _searchController.text.trim().toLowerCase();
          final groups = query.isEmpty
              ? _controller.groups
              : _controller.groups.where((g) =>
                  g.name.toLowerCase().contains(query) ||
                  (g.lastMessage?.message?.toLowerCase().contains(query) ?? false)
                ).toList();

          if (groups.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(query.isEmpty ? Icons.chat_bubble_outline : Icons.search_off,
                      color: Colors.white24, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    query.isEmpty ? 'No conversations yet' : 'No groups found',
                    style: const TextStyle(color: Colors.white38, fontSize: 16),
                  ),
                  if (query.isEmpty) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Get.to(() => CreateGroupScreen()),
                      child: const Text('Start a new group'),
                    ),
                  ],
                ],
              ),
            );
          }
          return RefreshIndicator(
            color: Colors.white,
            onRefresh: () => _controller.loadGroups(),
            child: ListView.separated(
              itemCount: groups.length,
              separatorBuilder: (_, __) => Divider(color: Colors.white.withOpacity(0.05), height: 1),
              itemBuilder: (context, index) {
                final group = groups[index];
                return _GroupTile(
                  group: group,
                  onTap: () => Get.to(() => GroupChatScreen(groupId: group.id, groupName: group.name)),
                  onLongPress: () => _showGroupOptions(group),
                );
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
        decoration: const BoxDecoration(
          color: Color(0xFF0A1E3D),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.white),
              title: const Text('View Info', style: TextStyle(color: Colors.white)),
              onTap: () { Get.back(); Get.to(() => GroupInfoScreen(groupId: group.id)); },
            ),
            if (group.isCreator)
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red[300]),
                title: Text('Delete Group', style: TextStyle(color: Colors.red[300])),
                onTap: () { Get.back(); _confirmDelete(group.id); },
              ),
            if (!group.isCreator)
              ListTile(
                leading: Icon(Icons.exit_to_app, color: Colors.red[300]),
                title: Text('Leave Group', style: TextStyle(color: Colors.red[300])),
                onTap: () { Get.back(); _confirmLeave(group.id); },
              ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(int groupId) {
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF0A1E3D),
        title: const Text('Delete Group?', style: TextStyle(color: Colors.white)),
        content: const Text('This action cannot be undone.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          TextButton(
            onPressed: () { Get.back(); _controller.deleteGroup(groupId); },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmLeave(int groupId) {
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF0A1E3D),
        title: const Text('Leave Group?', style: TextStyle(color: Colors.white)),
        content: const Text('You will no longer have access to this group.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          TextButton(
            onPressed: () { Get.back(); _controller.leaveGroup(groupId); },
            child: const Text('Leave', style: TextStyle(color: Colors.red)),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white12,
                backgroundImage: group.avatar != null ? NetworkImage(group.avatar!) : null,
                child: group.avatar == null
                    ? const Icon(Icons.group, size: 26, color: Colors.white54)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            group.name,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (group.lastMessageAt != null)
                          Text(
                            _formatTime(group.lastMessageAt!),
                            style: const TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            group.lastMessage != null
                                ? '${group.lastMessage!.senderName}: ${_previewText(group.lastMessage!)}'
                                : '${group.memberCount} members',
                            style: TextStyle(
                              color: group.lastMessage != null ? Colors.white54 : Colors.white38,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (group.memberAvatars.isNotEmpty && group.lastMessage == null)
                          const SizedBox(width: 4),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
