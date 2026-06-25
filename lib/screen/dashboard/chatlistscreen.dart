import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/model/chat_contact.dart';
import 'package:cnattendance/model/group_chat.dart';
import 'package:cnattendance/provider/groupchatcontroller.dart';
import 'package:cnattendance/provider/teamsheetprovider.dart';
import 'package:cnattendance/screen/profile/admin_chat_thread_screen.dart';
import 'package:cnattendance/screen/profile/chatscreen.dart';
import 'package:cnattendance/screen/profile/group_chat_screen.dart';
import 'package:cnattendance/screen/profile/new_message_screen.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:cnattendance/widget/premium_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class ChatListScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TeamSheetProvider(),
      child: ChatList(),
    );
  }
}

class ChatList extends StatefulWidget {
  @override
  State<ChatList> createState() => _ChatListState();
}

enum _ChatFilter { all, online, admin, groups }

class _ChatListState extends State<ChatList> {
  final TextEditingController _searchController = TextEditingController();
  final Preferences _preferences = Preferences();
  final Map<String, DateTime> _sentChatAt = {};
  final Map<String, DateTime> _receivedChatAt = {};
  final Map<String, DateTime> _latestChatAt = {};
  final List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
      _chatSubscriptions = [];
  final GroupChatController _groupController =
      Get.put(GroupChatController(), tag: 'group_list');
  bool _initialState = true;
  bool _isLoading = false;
  _ChatFilter _selectedFilter = _ChatFilter.all;
  String _query = '';
  String _currentUsername = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialState) {
      _initialState = false;
      _loadTeam();
      _loadGroups();
    }
  }

  @override
  void dispose() {
    for (final subscription in _chatSubscriptions) {
      subscription.cancel();
    }
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTeam() async {
    setState(() {
      _isLoading = true;
    });
    try {
      await Provider.of<TeamSheetProvider>(context, listen: false)
          .getChatContacts();
      await _listenRecentChats();
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadGroups() async {
    await _groupController.loadGroups();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _listenRecentChats() async {
    final username = (await _preferences.getUsername()).trim();
    if (username.isEmpty || username == _currentUsername) {
      return;
    }

    for (final subscription in _chatSubscriptions) {
      await subscription.cancel();
    }
    _chatSubscriptions.clear();
    _sentChatAt.clear();
    _receivedChatAt.clear();
    _latestChatAt.clear();
    _currentUsername = username;

    final messages = FirebaseFirestore.instance
        .collection('messages')
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snapshot, _) => snapshot.data() ?? {},
          toFirestore: (value, _) => value,
        );

    _chatSubscriptions.add(
      messages
          .where('sender', isEqualTo: username)
          .snapshots()
          .listen((snapshot) => _updateRecentChats(snapshot, isSent: true)),
    );
    _chatSubscriptions.add(
      messages
          .where('reciever', isEqualTo: username)
          .snapshots()
          .listen((snapshot) => _updateRecentChats(snapshot, isSent: false)),
    );
  }

  void _updateRecentChats(
    QuerySnapshot<Map<String, dynamic>> snapshot, {
    required bool isSent,
  }) {
    final target = isSent ? _sentChatAt : _receivedChatAt;
    target.clear();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final otherUsername =
          (data[isSent ? 'reciever' : 'sender'] ?? '').toString().trim();
      final timestamp = data['date'];

      if (otherUsername.isEmpty || timestamp is! Timestamp) {
        continue;
      }

      final messageDate = timestamp.toDate();
      final existing = target[otherUsername];
      if (existing == null || messageDate.isAfter(existing)) {
        target[otherUsername] = messageDate;
      }
    }

    _mergeRecentChats();
  }

  void _mergeRecentChats() {
    final merged = <String, DateTime>{};

    for (final source in [_sentChatAt, _receivedChatAt]) {
      source.forEach((username, date) {
        final existing = merged[username];
        if (existing == null || date.isAfter(existing)) {
          merged[username] = date;
        }
      });
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _latestChatAt
        ..clear()
        ..addAll(merged);
    });
  }

  List<ChatContact> allContacts(List<ChatContact> contacts) => contacts;

  List<ChatContact> onlineContacts(
    List<ChatContact> contacts,
    List<ChatContact> backendOnlineContacts,
  ) {
    final onlineUsernames = backendOnlineContacts
        .map((contact) => contact.username.trim())
        .where((username) => username.isNotEmpty)
        .toSet();

    if (onlineUsernames.isNotEmpty) {
      return contacts
          .where((contact) =>
              !contact.usesAdminThread &&
              !_isCurrentUser(contact) &&
              onlineUsernames.contains(contact.username.trim()))
          .toList();
    }

    return contacts
        .where((contact) =>
            !contact.usesAdminThread &&
            !_isCurrentUser(contact) &&
            contact.isOnline)
        .toList();
  }

  List<ChatContact> adminContacts(List<ChatContact> contacts) =>
      contacts.where((contact) => contact.usesAdminThread).toList();

  List<ChatContact> _filteredContacts(List<ChatContact> contacts) {
    final provider = Provider.of<TeamSheetProvider>(context, listen: false);
    final sanitizedContacts = _uniqueContacts(
      contacts.where((contact) => !_isCurrentUser(contact)).toList(),
    );
    final selectedContacts = switch (_selectedFilter) {
      _ChatFilter.all => allContacts(sanitizedContacts),
      _ChatFilter.online =>
        onlineContacts(sanitizedContacts, provider.onlineChatContacts),
      _ChatFilter.admin => adminContacts(sanitizedContacts),
      _ChatFilter.groups => <ChatContact>[],
    };

    final filtered = selectedContacts
        .where((contact) => contact.matchesSearch(_query))
        .toList();

    filtered.sort((a, b) {
      final aLatest = _latestChatAt[_contactThreadKey(a)];
      final bLatest = _latestChatAt[_contactThreadKey(b)];

      if (aLatest != null && bLatest != null) {
        return bLatest.compareTo(aLatest);
      }

      if (aLatest != null) {
        return -1;
      }

      if (bLatest != null) {
        return 1;
      }

      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return filtered;
  }

  bool _isCurrentUser(ChatContact contact) {
    return contact.username.trim().isNotEmpty &&
        contact.username.trim() == _currentUsername.trim();
  }

  List<ChatContact> _uniqueContacts(List<ChatContact> contacts) {
    final unique = <String, ChatContact>{};

    for (final contact in contacts) {
      final key = _contactThreadKey(contact).trim().isNotEmpty
          ? _contactThreadKey(contact).trim()
          : contact.username.trim();
      if (key.isEmpty) {
        continue;
      }

      final existing = unique[key];
      if (existing == null) {
        unique[key] = contact;
        continue;
      }

      // Prefer richer records from the backend when duplicates point to the same user.
      final replacementScore = _contactScore(contact);
      final existingScore = _contactScore(existing);
      if (replacementScore > existingScore) {
        unique[key] = contact;
      }
    }

    return unique.values.toList();
  }

  int _contactScore(ChatContact contact) {
    var score = 0;
    if (contact.name.trim().isNotEmpty) score += 1;
    if (contact.avatar.trim().isNotEmpty) score += 1;
    if (contact.post.trim().isNotEmpty) score += 1;
    if (contact.department.trim().isNotEmpty) score += 1;
    if (contact.isOnline) score += 1;
    return score;
  }

  void _openChat(ChatContact contact) {
    debugPrint(
      '[ADMIN_CHAT] tapped contact'
      ' | name=${contact.name}'
      ' | user_type=${contact.userType}'
      ' | role=${contact.role}'
      ' | is_admin=${contact.isAdminValue}'
      ' | directory_type=${contact.directoryType}'
      ' | chat_mode=${contact.chatMode}'
      ' | conversation_id=${contact.conversationId}'
      ' | admin_id=${contact.resolvedAdminId}'
      ' | admin_username=${contact.resolvedAdminUsername}',
    );

    if (contact.usesAdminThread) {
      Get.to(const AdminChatThreadScreen(), arguments: {
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

    Get.to(ChatScreen(), arguments: {
      'name': contact.name,
      'avatar': contact.avatar,
      'username': contact.username,
      'employeeId': contact.id.isNotEmpty ? contact.id : contact.sourceId,
    });
  }

  String _contactThreadKey(ChatContact contact) {
    if (contact.usesAdminThread) {
      if (contact.conversationId.trim().isNotEmpty) {
        return contact.conversationId.trim();
      }
      if (contact.resolvedAdminId.isNotEmpty) {
        return 'admin:${contact.resolvedAdminId}';
      }
    }
    return contact.username.trim();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TeamSheetProvider>(context);
    final contactList = _filteredContacts(provider.chatContacts);
    final onlineContactList = onlineContacts(
            _uniqueContacts(provider.chatContacts), provider.onlineChatContacts)
        .take(12)
        .toList();

    final filteredGroups = _groupController.groups
        .where((g) =>
            _query.isEmpty ||
            g.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return PremiumBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: RefreshIndicator(
            color: Colors.white,
            backgroundColor: Colors.blueGrey,
            onRefresh: () async {
              await _loadTeam();
              await _loadGroups();
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      children: [
                        _Header(onCompose: () {
                          Get.to(() => const NewMessageScreen())?.then((_) {
                            _loadGroups();
                            _loadTeam();
                          });
                        }),
                        const SizedBox(height: 14),
                        _SearchField(
                          controller: _searchController,
                          onChanged: (value) {
                            setState(() {
                              _query = value;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        if (_selectedFilter != _ChatFilter.groups &&
                            onlineContactList.isNotEmpty)
                          _ActiveStories(onlineContactList, _openChat),
                        if (_selectedFilter != _ChatFilter.groups &&
                            onlineContactList.isNotEmpty)
                          const SizedBox(height: 18),
                        _Filters(
                          selectedFilter: _selectedFilter,
                          onAllTap: () {
                            setState(() {
                              _selectedFilter = _ChatFilter.all;
                            });
                          },
                          onOnlineTap: () {
                            setState(() {
                              _selectedFilter = _ChatFilter.online;
                            });
                          },
                          onAdminTap: () {
                            setState(() {
                              _selectedFilter = _ChatFilter.admin;
                            });
                          },
                          onGroupsTap: () {
                            setState(() {
                              _selectedFilter = _ChatFilter.groups;
                            });
                          },
                        ),
                        const SizedBox(height: 10),
                        if (_selectedFilter != _ChatFilter.groups &&
                            filteredGroups.isNotEmpty &&
                            _selectedFilter == _ChatFilter.all) ...[
                          _SectionHeader(
                              label: translate('chat_list_screen.groups')),
                          ...filteredGroups.map((group) => _GroupChatTile(
                                group: group,
                                onTap: () => Get.to(() => GroupChatScreen(
                                    groupId: group.id,
                                    groupName: group.name)),
                              )),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  ),
                ),
                if (_selectedFilter == _ChatFilter.groups)
                  ..._groupsSlivers(filteredGroups)
                else
                  ..._contactsSlivers(contactList, provider, filteredGroups),
                const SliverPadding(padding: EdgeInsets.only(bottom: 20)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _groupsSlivers(List<GroupChat> groups) {
    if (_groupController.isLoading.value) {
      return const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(top: 60),
            child: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
        ),
      ];
    }
    if (groups.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 60),
            child: Center(
              child: Text(
                translate('chat_list_screen.no_groups'),
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverList.builder(
          itemCount: groups.length,
          itemBuilder: (context, index) {
            final group = groups[index];
            return _GroupChatTile(
              key: ValueKey('group_${group.id}'),
              group: group,
              onTap: () => Get.to(() =>
                  GroupChatScreen(groupId: group.id, groupName: group.name)),
            );
          },
        ),
      ),
    ];
  }

  List<Widget> _contactsSlivers(List<ChatContact> contactList,
      TeamSheetProvider provider, List<GroupChat> filteredGroups) {
    if (_isLoading && provider.chatContacts.isEmpty) {
      return const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(top: 60),
            child: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
        ),
      ];
    }
    if (contactList.isEmpty &&
        (_selectedFilter != _ChatFilter.all || filteredGroups.isEmpty)) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 60),
            child: Center(
              child: Text(
                translate('chat_list_screen.no_chats'),
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverList.builder(
          itemCount: contactList.length,
          itemBuilder: (context, index) {
            final contact = contactList[index];
            return _ChatListTile(
              key: ValueKey('contact_${contact.id}_${contact.username}'),
              contact: contact,
              onTap: () => _openChat(contact),
            );
          },
        ),
      ),
    ];
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onCompose;

  const _Header({required this.onCompose});

  @override
  Widget build(BuildContext context) {
    final enterprise = EnterpriseTheme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            translate('dashboard_screen.chat'),
            style: TextStyle(
              color: enterprise.text,
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        IconButton(
          onPressed: onCompose,
          icon: Icon(Icons.edit_square, color: enterprise.text),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchField({
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final enterprise = EnterpriseTheme.of(context);
    return EnterpriseGlass(
      radius: 24,
      padding: EdgeInsets.zero,
      glowOpacity: 0.08,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(color: enterprise.text, fontWeight: FontWeight.w700),
        cursorColor: enterprise.accent,
        decoration: InputDecoration(
          hintText: translate('chat_list_screen.search'),
          hintStyle: TextStyle(color: enterprise.mutedText),
          prefixIcon: Icon(Icons.search, color: enterprise.mutedText),
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
      ),
    );
  }
}

class _ActiveStories extends StatelessWidget {
  final List<ChatContact> contactList;
  final ValueChanged<ChatContact> onTap;

  const _ActiveStories(this.contactList, this.onTap);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: contactList.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final contact = contactList[index];
          return GestureDetector(
            onTap: () => onTap(contact),
            child: SizedBox(
              width: 68,
              child: Column(
                children: [
                  _Avatar(contact: contact, size: 62, showActive: true),
                  const SizedBox(height: 6),
                  Text(
                    contact.name.split(' ').first,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  final _ChatFilter selectedFilter;
  final VoidCallback onAllTap;
  final VoidCallback onOnlineTap;
  final VoidCallback onAdminTap;
  final VoidCallback onGroupsTap;

  const _Filters({
    required this.selectedFilter,
    required this.onAllTap,
    required this.onOnlineTap,
    required this.onAdminTap,
    required this.onGroupsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _FilterChip(
          label: translate('chat_list_screen.all'),
          selected: selectedFilter == _ChatFilter.all,
          onTap: onAllTap,
        ),
        const SizedBox(width: 10),
        _FilterChip(
          label: translate('chat_list_screen.online'),
          selected: selectedFilter == _ChatFilter.online,
          onTap: onOnlineTap,
        ),
        const SizedBox(width: 10),
        _FilterChip(
          label: translate('chat_list_screen.admin'),
          selected: selectedFilter == _ChatFilter.admin,
          onTap: onAdminTap,
        ),
        const SizedBox(width: 10),
        _FilterChip(
          label: translate('chat_list_screen.groups'),
          selected: selectedFilter == _ChatFilter.groups,
          onTap: onGroupsTap,
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enterprise = EnterpriseTheme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(colors: [enterprise.primary, enterprise.accent])
              : null,
          color: selected ? null : enterprise.glassFill,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: enterprise.glassStroke),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : enterprise.text,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ChatListTile extends StatelessWidget {
  final ChatContact contact;
  final VoidCallback onTap;

  const _ChatListTile({
    super.key,
    required this.contact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enterprise = EnterpriseTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: EnterpriseGlass(
          radius: 22,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          glowOpacity: 0.06,
          child: Row(
            children: [
              _Avatar(contact: contact, size: 58, showActive: true),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: enterprise.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      contact.post.isEmpty ? contact.department : contact.post,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(color: enterprise.mutedText, fontSize: 14),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: enterprise.mutedText),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final ChatContact contact;
  final double size;
  final bool showActive;

  const _Avatar({
    required this.contact,
    required this.size,
    required this.showActive,
  });

  bool _hasValidNetworkImage(String url) {
    final uri = Uri.tryParse(url.trim());
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = contact.avatar.trim();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipOval(
          child: _hasValidNetworkImage(avatarUrl)
              ? CachedNetworkImage(
                  imageUrl: avatarUrl,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    width: size,
                    height: size,
                    color: Colors.white12,
                    child: Icon(Icons.person,
                        color: Colors.white, size: size * .48),
                  ),
                )
              : Container(
                  width: size,
                  height: size,
                  color: Colors.white12,
                  child: Icon(
                    Icons.person,
                    color: Colors.white,
                    size: size * .48,
                  ),
                ),
        ),
        if (showActive)
          Positioned(
            right: 0,
            bottom: 2,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: contact.isOnline ? Colors.green : Colors.grey,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;

  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4, left: 8),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _GroupChatTile extends StatelessWidget {
  final GroupChat group;
  final VoidCallback onTap;

  const _GroupChatTile({
    super.key,
    required this.group,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enterprise = EnterpriseTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: EnterpriseGlass(
          radius: 22,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          glowOpacity: 0.06,
          child: Row(
            children: [
              ClipOval(
                child: group.avatar != null && group.avatar!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: group.avatar!,
                        width: 58,
                        height: 58,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _GroupAvatarPlaceholder(),
                      )
                    : _GroupAvatarPlaceholder(),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: enterprise.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      group.lastMessage != null
                          ? '${group.lastMessage!.senderName}: ${_lastMessagePreview(group.lastMessage!)}'
                          : '${group.memberCount} members',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(color: enterprise.mutedText, fontSize: 14),
                    ),
                  ],
                ),
              ),
              if (group.lastMessageAt != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    _formatGroupTime(group.lastMessageAt!),
                    style: TextStyle(color: enterprise.mutedText, fontSize: 11),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _lastMessagePreview(dynamic lastMessage) {
    final type = lastMessage.messageType;
    if (type == 'image') return 'Sent a photo';
    if (type == 'voice') return 'Sent a voice message';
    if (type == 'file') return 'Sent a file';
    if (type == 'location') return 'Sent a location';
    return lastMessage.message ?? '';
  }

  String _formatGroupTime(String isoTime) {
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

class _GroupAvatarPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: const BoxDecoration(
        color: Colors.white12,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.group, color: Colors.white54, size: 30),
    );
  }
}
