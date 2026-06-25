import 'dart:convert';
import 'dart:io';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/data/source/network/connect.dart';
import 'package:cnattendance/model/chat_contact.dart';
import 'package:cnattendance/model/group_chat_detail.dart';
import 'package:cnattendance/model/group_chat_member.dart';
import 'package:cnattendance/provider/groupchatcontroller.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:cnattendance/widget/radialDecoration.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

class GroupInfoScreen extends StatefulWidget {
  final int groupId;

  const GroupInfoScreen({required this.groupId});

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  late GroupChatController _controller;
  final ImagePicker _picker = ImagePicker();

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
          title: const Text('Group Info', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          centerTitle: true,
        ),
        body: Obx(() {
          final group = _controller.currentGroup.value;
          if (_controller.isLoading.value && group == null) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }
          if (group == null) {
            return Center(child: Text('Group not found', style: TextStyle(color: Colors.white54)));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _HeaderSection(
                group: group,
                isAdmin: group.isAdmin,
                onEditName: () => _showEditGroupDialog(group),
                onChangeAvatar: () => _pickAvatar(group.id),
              ),
              const SizedBox(height: 24),
              _MembersSection(
                group: group,
                controller: _controller,
                onAddMembers: () => _showAddMembersDialog(group.id),
              ),
              const SizedBox(height: 24),
              _ActionsSection(group: group, controller: _controller),
            ],
          );
        }),
      ),
    );
  }

  void _showEditGroupDialog(GroupChatDetail group) {
    final nameController = TextEditingController(text: group.name);
    final descController = TextEditingController(text: group.description ?? '');

    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF0A1E3D),
        title: const Text('Edit Group', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDeco('Group Name'),
              cursorColor: Colors.white,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDeco('Description'),
              maxLines: 2,
              cursorColor: Colors.white,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Get.back();
              _controller.updateGroupInfo(
                group.id,
                name: nameController.text.trim(),
                description: descController.text.trim(),
              );
            },
            child: const Text('Save', style: TextStyle(color: Colors.amber)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAvatar(int groupId) async {
    final source = await Get.bottomSheet<ImageSource>(
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
              leading: const Icon(Icons.camera_alt, color: Colors.white),
              title: const Text('Take Photo', style: TextStyle(color: Colors.white)),
              onTap: () => Get.back(result: ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white),
              title: const Text('Choose from Gallery', style: TextStyle(color: Colors.white)),
              onTap: () => Get.back(result: ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null) {
      final picked = await _picker.pickImage(source: source, maxWidth: 512, maxHeight: 512);
      if (picked != null) {
        _controller.updateGroupAvatar(groupId, File(picked.path));
      }
    }
  }

  void _showAddMembersDialog(int groupId) {
    Get.dialog(
      AddMembersDialog(groupId: groupId, controller: _controller),
    );
  }

  InputDecoration _inputDeco(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
      focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
    );
  }
}

class AddMembersDialog extends StatefulWidget {
  final int groupId;
  final GroupChatController controller;

  const AddMembersDialog({required this.groupId, required this.controller});

  @override
  State<AddMembersDialog> createState() => _AddMembersDialogState();
}

class _AddMembersDialogState extends State<AddMembersDialog> {
  List<ChatContact> _contacts = [];
  List<ChatContact> _filtered = [];
  final Set<String> _selected = {};
  bool _loading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _searchController.addListener(_onSearch);
  }

  void _onSearch() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty ? List.from(_contacts) : _contacts.where((c) =>
        c.name.toLowerCase().contains(q) ||
        c.department.toLowerCase().contains(q)
      ).toList();
    });
  }

  Future<void> _loadContacts() async {
    try {
      final preferences = Preferences();
      final token = await preferences.getToken();
      final connect = Connect();
      final response = await connect.getResponse(
        Constant.CHAT_CONTACTS,
        {'Authorization': 'Bearer $token', 'Accept': 'application/json; charset=UTF-8'},
      );
      final data = _decodeBody(response.body);
      if (response.statusCode == 200) {
        final responseData = data['data'];
        if (responseData is Map) {
          final contacts = responseData['contacts'];
          if (contacts is List) {
            final existingIds = widget.controller.currentGroup.value?.members.map((m) => m.userId.toString()).toSet() ?? {};
            _contacts = contacts
                .map((c) => ChatContact.fromJson(c))
                .where((c) => c.directoryType != 'admin' && !existingIds.contains(c.sourceId))
                .toList();
            _filtered = List.from(_contacts);
          }
        }
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearch);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0A1E3D),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Add Members', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Get.back(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search contacts...',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
                filled: true,
                fillColor: Colors.white.withOpacity(0.06),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              cursorColor: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          if (_selected.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text('${_selected.length} selected', style: const TextStyle(color: Colors.white54, fontSize: 13)),
            ),
          Flexible(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : _filtered.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: Text('No contacts available', style: TextStyle(color: Colors.white38))),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) {
                          final c = _filtered[i];
                          final sel = _selected.contains(c.sourceId);
                          return ListTile(
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.white12,
                              backgroundImage: c.avatar.isNotEmpty ? NetworkImage(c.avatar) : null,
                              child: c.avatar.isEmpty ? const Icon(Icons.person, color: Colors.white38, size: 18) : null,
                            ),
                            title: Text(c.name, style: const TextStyle(color: Colors.white, fontSize: 14)),
                            subtitle: Text(c.post, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            trailing: Container(
                              width: 22, height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: sel ? const Color(0xFF036eb7) : Colors.transparent,
                                border: Border.all(color: sel ? const Color(0xFF036eb7) : Colors.white38, width: 2),
                              ),
                              child: sel ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                            ),
                            onTap: () => setState(() { if (sel) { _selected.remove(c.sourceId); } else { _selected.add(c.sourceId); } }),
                          );
                        },
                      ),
          ),
          if (_selected.isNotEmpty)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF036eb7),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      final ids = _selected.map((e) => int.tryParse(e) ?? 0).where((e) => e > 0).toList();
                      if (ids.isNotEmpty) {
                        widget.controller.addMembers(widget.groupId, ids);
                      }
                      Get.back();
                    },
                    child: Text('Add ${_selected.length} member${_selected.length > 1 ? 's' : ''}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Map<String, dynamic> _decodeBody(String body) {
    if (body.trim().isEmpty) return {};
    try {
      final decoded = json.decode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return {'message': decoded.toString()};
    } catch (_) {
      return {'message': body};
    }
  }
}

class _HeaderSection extends StatelessWidget {
  final GroupChatDetail group;
  final bool isAdmin;
  final VoidCallback onEditName;
  final VoidCallback onChangeAvatar;

  const _HeaderSection({
    required this.group,
    required this.isAdmin,
    required this.onEditName,
    required this.onChangeAvatar,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 48,
              backgroundColor: Colors.white12,
              backgroundImage: group.avatar != null ? NetworkImage(group.avatar!) : null,
              child: group.avatar == null
                  ? const Icon(Icons.group, size: 44, color: Colors.white54)
                  : null,
            ),
            if (isAdmin)
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: onChangeAvatar,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF036eb7),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF0A1E3D), width: 2),
                    ),
                    child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                group.name,
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
            if (isAdmin) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onEditName,
                child: const Icon(Icons.edit, color: Colors.white54, size: 18),
              ),
            ],
          ],
        ),
        if (group.description != null && group.description!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 20, right: 20),
            child: Text(
              group.description!,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
        const SizedBox(height: 6),
        Text('${group.memberCount} members', style: const TextStyle(color: Colors.white38, fontSize: 13)),
      ],
    );
  }
}

class _MembersSection extends StatelessWidget {
  final GroupChatDetail group;
  final GroupChatController controller;
  final VoidCallback? onAddMembers;

  const _MembersSection({
    required this.group,
    required this.controller,
    this.onAddMembers,
  });

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
            const Text('Members', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            if (group.isAdmin)
              TextButton.icon(
                onPressed: onAddMembers,
                icon: const Icon(Icons.person_add, color: Colors.amber, size: 18),
                label: const Text('Add', style: TextStyle(color: Colors.amber)),
              ),
          ],
        ),
        const SizedBox(height: 4),
        if (creators.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 4, top: 8),
            child: Text('Owner', style: TextStyle(color: Colors.amber[200], fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          ...creators.map((m) => _MemberTile(member: m, group: group, controller: controller)),
        ],
        if (admins.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 4, top: 8),
            child: Text('Admins', style: TextStyle(color: Colors.blue[200], fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          ...admins.map((m) => _MemberTile(member: m, group: group, controller: controller)),
        ],
        if (regulars.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 4, top: 8),
            child: Text('Members', style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          ...regulars.map((m) => _MemberTile(member: m, group: group, controller: controller)),
        ],
      ],
    );
  }
}

class _MemberTile extends StatelessWidget {
  final GroupChatMember member;
  final GroupChatDetail group;
  final GroupChatController controller;

  const _MemberTile({required this.member, required this.group, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: Colors.white12,
          backgroundImage: member.avatar != null ? NetworkImage(member.avatar!) : null,
          child: member.avatar == null ? const Icon(Icons.person, color: Colors.white54, size: 18) : null,
        ),
        title: Text(member.name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
        subtitle: Row(
          children: [
            if (member.isCreator)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                child: Text('Owner', style: TextStyle(color: Colors.amber[200], fontSize: 11)),
              )
            else if (member.isAdmin)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.blue.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                child: Text('Admin', style: TextStyle(color: Colors.blue[200], fontSize: 11)),
              )
            else
              Text('Member', style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ),
        trailing: group.isCreator && !member.isCreator
            ? PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white54, size: 20),
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
                    const PopupMenuItem(value: 'promote', child: Text('Promote to Admin', style: TextStyle(color: Colors.white))),
                  if (member.isAdmin && group.isCreator)
                    const PopupMenuItem(value: 'demote', child: Text('Demote to Member', style: TextStyle(color: Colors.white))),
                  const PopupMenuItem(value: 'remove', child: Text('Remove', style: TextStyle(color: Colors.red))),
                ],
              )
            : null,
      ),
    );
  }

  void _confirmRemove(BuildContext context) {
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF0A1E3D),
        title: const Text('Remove Member?', style: TextStyle(color: Colors.white)),
        content: Text('Remove ${member.name} from the group?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Get.back();
              controller.removeMember(group.id, member.userId);
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
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
              icon: const Icon(Icons.exit_to_app, color: Colors.red),
              label: const Text('Leave Group', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.red.withOpacity(0.3)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        if (group.isCreator) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _confirmDelete(context),
              icon: const Icon(Icons.delete, color: Colors.red),
              label: const Text('Delete Group', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.red.withOpacity(0.3)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        backgroundColor: const Color(0xFF0A1E3D),
        title: const Text('Leave Group?', style: TextStyle(color: Colors.white)),
        content: const Text('You will no longer have access to this group.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Get.back();
              controller.leaveGroup(group.id);
            },
            child: const Text('Leave', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF0A1E3D),
        title: const Text('Delete Group?', style: TextStyle(color: Colors.white)),
        content: const Text('This action cannot be undone.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Get.back();
              controller.deleteGroup(group.id);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
