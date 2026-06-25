import 'package:cached_network_image/cached_network_image.dart';
import 'package:cnattendance/model/chat_contact.dart';
import 'package:cnattendance/model/group_chat.dart';
import 'package:cnattendance/provider/groupchatcontroller.dart';
import 'package:cnattendance/repositories/group_chat_repository.dart';
import 'package:cnattendance/repositories/teamsheetrepository.dart';
import 'package:cnattendance/screen/profile/admin_chat_thread_screen.dart';
import 'package:cnattendance/screen/profile/chatscreen.dart';
import 'package:cnattendance/screen/profile/group_chat_screen.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class NewMessageScreen extends StatefulWidget {
  const NewMessageScreen({super.key});

  @override
  State<NewMessageScreen> createState() => _NewMessageScreenState();
}

class _NewMessageScreenState extends State<NewMessageScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TeamSheetRepository _teamRepository = TeamSheetRepository();
  final GroupChatRepository _groupRepository = GroupChatRepository();
  final Map<String, ChatContact> _selectedContacts = {};

  List<ChatContact> _contacts = [];
  List<GroupChat> _groups = [];
  bool _loading = true;
  bool _creatingGroup = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadDirectory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDirectory() async {
    setState(() => _loading = true);
    try {
      final payload = await _teamRepository.getChatContacts();
      final groups = await _groupRepository.getGroups();
      if (!mounted) return;
      setState(() {
        _contacts = _uniqueContacts(payload.contacts);
        _groups = groups;
      });
    } catch (error) {
      showToast(error.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  List<ChatContact> _uniqueContacts(List<ChatContact> contacts) {
    final unique = <String, ChatContact>{};
    for (final contact in contacts) {
      final key = _contactKey(contact);
      if (key.isEmpty) continue;
      unique[key] = contact;
    }
    return unique.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  List<ChatContact> get _filteredContacts {
    final search = _query.trim().toLowerCase();
    if (search.isEmpty) return _contacts;
    return _contacts.where((contact) => contact.matchesSearch(search)).toList();
  }

  List<GroupChat> get _filteredGroups {
    final search = _query.trim().toLowerCase();
    if (search.isEmpty || _selectedContacts.isNotEmpty) return [];
    return _groups
        .where((group) => group.name.toLowerCase().contains(search))
        .toList();
  }

  void _toggleContact(ChatContact contact) {
    final key = _contactKey(contact);
    if (key.isEmpty) return;
    setState(() {
      if (_selectedContacts.containsKey(key)) {
        _selectedContacts.remove(key);
      } else {
        _selectedContacts[key] = contact;
      }
    });
  }

  Future<void> _continue() async {
    final selected = _selectedContacts.values.toList();
    if (selected.isEmpty) return;

    if (selected.length == 1) {
      _openContact(selected.first);
      return;
    }

    if (selected.any((contact) => contact.usesAdminThread)) {
      showToast('Admin contacts can only be messaged one at a time.');
      return;
    }

    setState(() => _creatingGroup = true);
    try {
      final memberIds = selected
          .where((contact) => !contact.usesAdminThread)
          .map((contact) => int.tryParse(
              contact.sourceId.isNotEmpty ? contact.sourceId : contact.id))
          .whereType<int>()
          .where((id) => id > 0)
          .toList();

      if (memberIds.isEmpty) {
        showToast('Select employee contacts to create a group.');
        return;
      }

      final created = await _groupRepository.createGroup(
        name: '',
        memberIds: memberIds,
      );
      if (Get.isRegistered<GroupChatController>(tag: 'group_list')) {
        Get.find<GroupChatController>(tag: 'group_list').loadGroups();
      }
      final groupId = int.tryParse(created['id'].toString());
      final groupName = created['name']?.toString() ?? 'New group';

      if (!mounted) return;
      Get.off(
          () => GroupChatScreen(groupId: groupId ?? 0, groupName: groupName));
      showToast('Group created successfully');
    } catch (error) {
      showToast(error.toString());
    } finally {
      if (mounted) {
        setState(() => _creatingGroup = false);
      }
    }
  }

  void _openContact(ChatContact contact) {
    if (contact.usesAdminThread) {
      Get.off(const AdminChatThreadScreen(), arguments: {
        'name': contact.name,
        'avatar': contact.avatar,
        'conversationId': contact.conversationId,
        'internalConversationId': contact.internalConversationId,
        'adminId': contact.resolvedAdminId,
        'adminUsername': contact.resolvedAdminUsername,
        'username': contact.resolvedAdminUsername,
      });
      return;
    }

    Get.off(ChatScreen(), arguments: {
      'name': contact.name,
      'avatar': contact.avatar,
      'username': contact.username,
      'employeeId': contact.id.isNotEmpty ? contact.id : contact.sourceId,
    });
  }

  String _contactKey(ChatContact contact) {
    if (contact.usesAdminThread) {
      return 'admin:${contact.resolvedAdminId}';
    }
    if (contact.sourceId.trim().isNotEmpty) {
      return 'employee:${contact.sourceId.trim()}';
    }
    if (contact.id.trim().isNotEmpty) {
      return 'employee:${contact.id.trim()}';
    }
    return contact.username.trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leadingWidth: 92,
        leading: TextButton(
          onPressed: () => Get.back(),
          child: const Text('Cancel'),
        ),
        centerTitle: true,
        title: const Text(
          'New message',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          TextButton(
            onPressed:
                _selectedContacts.isEmpty || _creatingGroup ? null : _continue,
            child: Text(_selectedContacts.length > 1 ? 'Create' : 'Chat'),
          ),
        ],
      ),
      body: Column(
        children: [
          _RecipientSearchBar(
            controller: _searchController,
            selectedContacts: _selectedContacts.values.toList(),
            onRemove: _toggleContact,
            onChanged: (value) => setState(() => _query = value),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadDirectory,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        if (_filteredGroups.isNotEmpty) ...[
                          const _SectionLabel('Groups'),
                          ..._filteredGroups.map(
                            (group) => _GroupRecipientTile(
                              group: group,
                              onTap: () => Get.off(() => GroupChatScreen(
                                  groupId: group.id, groupName: group.name)),
                            ),
                          ),
                        ],
                        if (_filteredContacts.isNotEmpty) ...[
                          if (_filteredGroups.isNotEmpty)
                            const _SectionLabel('People'),
                          ..._filteredContacts.map(
                            (contact) => _ContactRecipientTile(
                              contact: contact,
                              selected: _selectedContacts
                                  .containsKey(_contactKey(contact)),
                              onTap: () => _toggleContact(contact),
                            ),
                          ),
                        ],
                        if (_filteredContacts.isEmpty &&
                            _filteredGroups.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 80),
                            child: Center(
                              child: Text(
                                'No recipients found',
                                style: TextStyle(color: Colors.black54),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
          if (_selectedContacts.isNotEmpty)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _creatingGroup ? null : _continue,
                    child: _creatingGroup
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(_selectedContacts.length > 1
                            ? 'Create group'
                            : 'Start chat'),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RecipientSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final List<ChatContact> selectedContacts;
  final ValueChanged<ChatContact> onRemove;
  final ValueChanged<String> onChanged;

  const _RecipientSearchBar({
    required this.controller,
    required this.selectedContacts,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xfff7f7f8),
      padding: const EdgeInsets.fromLTRB(22, 12, 18, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 9),
            child: Text(
              'To:',
              style: TextStyle(color: Colors.black54, fontSize: 16),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ...selectedContacts.map(
                  (contact) => InputChip(
                    label: Text(contact.name),
                    onDeleted: () => onRemove(contact),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                SizedBox(
                  width: selectedContacts.isEmpty ? double.infinity : 150,
                  child: TextField(
                    controller: controller,
                    onChanged: onChanged,
                    autofocus: true,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      hintText: 'Search',
                    ),
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 6),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.black54,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ContactRecipientTile extends StatelessWidget {
  final ChatContact contact;
  final bool selected;
  final VoidCallback onTap;

  const _ContactRecipientTile({
    required this.contact,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
      leading: _RecipientAvatar(
        imageUrl: contact.avatar,
        fallbackIcon:
            contact.usesAdminThread ? Icons.admin_panel_settings : Icons.person,
      ),
      title: Text(
        contact.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        contact.usesAdminThread
            ? 'Admin support'
            : (contact.post.isNotEmpty ? contact.post : contact.department),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: selected
          ? const Icon(Icons.check_circle, color: Color(0xff0a84ff))
          : null,
    );
  }
}

class _GroupRecipientTile extends StatelessWidget {
  final GroupChat group;
  final VoidCallback onTap;

  const _GroupRecipientTile({
    required this.group,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
      leading: _RecipientAvatar(
        imageUrl: group.avatar ?? '',
        fallbackIcon: Icons.group,
      ),
      title: Text(
        group.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
      ),
      subtitle: Text('${group.memberCount} members'),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

class _RecipientAvatar extends StatelessWidget {
  final String imageUrl;
  final IconData fallbackIcon;

  const _RecipientAvatar({
    required this.imageUrl,
    required this.fallbackIcon,
  });

  bool get _hasNetworkImage {
    final uri = Uri.tryParse(imageUrl.trim());
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasNetworkImage) {
      return CircleAvatar(
        radius: 28,
        backgroundColor: const Color(0xffe8eaef),
        child: Icon(fallbackIcon, color: Colors.black45),
      );
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => CircleAvatar(
          radius: 28,
          backgroundColor: const Color(0xffe8eaef),
          child: Icon(fallbackIcon, color: Colors.black45),
        ),
      ),
    );
  }
}
