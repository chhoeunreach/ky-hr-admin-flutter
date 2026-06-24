import 'dart:convert';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/data/source/network/connect.dart';
import 'package:cnattendance/model/chat_contact.dart';
import 'package:cnattendance/provider/groupchatcontroller.dart';
import 'package:cnattendance/repositories/group_chat_repository.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:cnattendance/widget/radialDecoration.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CreateGroupScreen extends StatefulWidget {
  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final Set<String> _selectedUserIds = {};
  List<ChatContact> _contacts = [];
  bool _loading = true;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    try {
      final preferences = Preferences();
      final token = await preferences.getToken();
      final appUrl = await preferences.getAppUrl();
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
          }
        }
      }
    } catch (_) {}
    setState(() => _loading = false);
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
          title: Text('Create Group', style: TextStyle(color: Colors.white)),
        ),
        body: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _nameController,
                    style: TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Group Name'),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: _descController,
                    style: TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Description (optional)'),
                    maxLines: 2,
                  ),
                  SizedBox(height: 8),
                  Obx(() {
                    final controller = Get.find<GroupChatController>(tag: 'group_list');
                    return Text(
                      '${_selectedUserIds.length} members selected',
                      style: TextStyle(color: Colors.white54),
                    );
                  }),
                ],
              ),
            ),
            Divider(color: Colors.white10),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Select Members',
                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(color: Colors.white))
                  : _contacts.isEmpty
                      ? Center(
                          child: Text('No contacts available',
                              style: TextStyle(color: Colors.white38)))
                      : ListView.builder(
                          itemCount: _contacts.length,
                          itemBuilder: (context, index) {
                            final contact = _contacts[index];
                            final isSelected = _selectedUserIds.contains(contact.sourceId);
                            return CheckboxListTile(
                              value: isSelected,
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedUserIds.add(contact.sourceId);
                                  } else {
                                    _selectedUserIds.remove(contact.sourceId);
                                  }
                                });
                              },
                              title: Text(
                                contact.name,
                                style: TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                contact.post ?? contact.department ?? '',
                                style: TextStyle(color: Colors.white54, fontSize: 13),
                              ),
                              activeColor: Colors.amber,
                              checkColor: Colors.black,
                            );
                          },
                        ),
            ),
            SafeArea(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _creating ? null : _createGroup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF1A3A6B),
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _creating
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text('Create Group',
                            style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white54),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.white24),
        borderRadius: BorderRadius.circular(10),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.amber),
        borderRadius: BorderRadius.circular(10),
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
