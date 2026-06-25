import 'dart:convert';
import 'dart:io';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/data/source/network/connect.dart';
import 'package:cnattendance/model/chat_contact.dart';
import 'package:cnattendance/provider/groupchatcontroller.dart';
import 'package:cnattendance/repositories/group_chat_repository.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:cnattendance/widget/radialDecoration.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

class CreateGroupScreen extends StatefulWidget {
  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _searchController = TextEditingController();
  final Set<String> _selectedUserIds = {};
  List<ChatContact> _contacts = [];
  List<ChatContact> _filteredContacts = [];
  bool _loading = true;
  bool _creating = false;
  File? _avatarFile;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredContacts = List.from(_contacts);
      } else {
        _filteredContacts = _contacts.where((c) =>
          c.name.toLowerCase().contains(query) ||
          c.department.toLowerCase().contains(query) ||
          c.post.toLowerCase().contains(query)
        ).toList();
      }
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
            _contacts = contacts
                .map((c) => ChatContact.fromJson(c))
                .where((c) => c.directoryType != 'admin')
                .toList();
            _filteredContacts = List.from(_contacts);
          }
        }
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _pickAvatar() async {
    final source = await Get.bottomSheet<ImageSource>(
      Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0A1E3D),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
        setState(() => _avatarFile = File(picked.path));
      }
    }
  }

  Future<void> _createGroup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      showToast('Group name is required');
      return;
    }
    if (_selectedUserIds.isEmpty) {
      showToast('Select at least one member');
      return;
    }

    setState(() => _creating = true);
    try {
      final repository = GroupChatRepository();
      await repository.createGroup(
        name: name,
        description: _descController.text.trim(),
        memberIds: _selectedUserIds.map((e) => int.tryParse(e) ?? 0).where((e) => e > 0).toList(),
        avatarFile: _avatarFile,
      );

      final controller = Get.find<GroupChatController>(tag: 'group_list');
      controller.loadGroups();
      Get.back();
      showToast('Group created successfully');
    } catch (e) {
      showToast(e.toString());
    } finally {
      setState(() => _creating = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _searchController.dispose();
    _searchController.removeListener(_onSearchChanged);
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
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Get.back(),
          ),
          title: const Text('Create Group', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          centerTitle: true,
        ),
        body: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _pickAvatar,
                            child: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 48,
                                  backgroundColor: Colors.white12,
                                  backgroundImage: _avatarFile != null
                                      ? FileImage(_avatarFile!)
                                      : null,
                                  child: _avatarFile == null
                                      ? const Icon(Icons.group, size: 44, color: Colors.white54)
                                      : null,
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
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
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _nameController,
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                            decoration: InputDecoration(
                              hintText: 'Group Name',
                              hintStyle: const TextStyle(color: Colors.white38),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.06),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                            cursorColor: Colors.white,
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _descController,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Description (optional)',
                              hintStyle: const TextStyle(color: Colors.white38),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.06),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            maxLines: 2,
                            cursorColor: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_selectedUserIds.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Container(
                        height: 56,
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _selectedUserIds.length,
                          itemBuilder: (_, i) {
                            final id = _selectedUserIds.elementAt(i);
                            final contact = _contacts.cast<ChatContact?>().firstWhere(
                              (c) => c!.sourceId == id,
                              orElse: () => null,
                            );
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Chip(
                                backgroundColor: const Color(0xFF036eb7),
                                label: Text(contact?.name ?? id, style: const TextStyle(color: Colors.white, fontSize: 13)),
                                deleteIcon: const Icon(Icons.close, size: 16, color: Colors.white70),
                                onDeleted: () {
                                  setState(() => _selectedUserIds.remove(id));
                                },
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.people, color: Colors.white54, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Add Members  ·  ${_selectedUserIds.length} selected',
                            style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Search contacts...',
                          hintStyle: const TextStyle(color: Colors.white38),
                          prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.06),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        cursorColor: Colors.white,
                      ),
                    ),
                  ),
                  if (_loading)
                    const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator(color: Colors.white)),
                    )
                  else if (_filteredContacts.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off, color: Colors.white38, size: 48),
                            const SizedBox(height: 12),
                            Text('No contacts found', style: TextStyle(color: Colors.white54)),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final contact = _filteredContacts[index];
                          final isSelected = _selectedUserIds.contains(contact.sourceId);
                          return _ContactTile(
                            contact: contact,
                            isSelected: isSelected,
                            onToggle: (val) {
                              setState(() {
                                if (val) {
                                  _selectedUserIds.add(contact.sourceId);
                                } else {
                                  _selectedUserIds.remove(contact.sourceId);
                                }
                              });
                            },
                          );
                        },
                        childCount: _filteredContacts.length,
                      ),
                    ),
                ],
              ),
            ),
            SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _creating || _selectedUserIds.isEmpty ? null : _createGroup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF036eb7),
                      disabledBackgroundColor: Colors.white12,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _creating
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(
                            'Create Group${_selectedUserIds.isNotEmpty ? ' (${_selectedUserIds.length + 1} members)' : ''}',
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
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

class _ContactTile extends StatelessWidget {
  final ChatContact contact;
  final bool isSelected;
  final ValueChanged<bool> onToggle;

  const _ContactTile({
    required this.contact,
    required this.isSelected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: Colors.white12,
        backgroundImage: contact.avatar.isNotEmpty ? NetworkImage(contact.avatar) : null,
        child: contact.avatar.isEmpty
            ? Icon(Icons.person, color: Colors.white38, size: 22)
            : null,
      ),
      title: Text(
        contact.name,
        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        contact.post.isNotEmpty ? contact.post : contact.department,
        style: const TextStyle(color: Colors.white54, fontSize: 13),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? const Color(0xFF036eb7) : Colors.transparent,
          border: Border.all(
            color: isSelected ? const Color(0xFF036eb7) : Colors.white38,
            width: 2,
          ),
        ),
        child: isSelected
            ? const Icon(Icons.check, size: 16, color: Colors.white)
            : null,
      ),
      onTap: () => onToggle(!isSelected),
    );
  }
}
