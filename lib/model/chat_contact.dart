class ChatContact {
  final String id;
  final String name;
  final String username;
  final String email;
  final String phone;
  final String department;
  final String branch;
  final String post;
  final String avatar;
  final dynamic onlineStatus;
  final String role;
  final String userType;
  final dynamic isAdminValue;
  final dynamic adminValue;
  final dynamic isOnlineValue;
  final String directoryType;
  final String sourceId;
  final String chatMode;
  final String conversationId;
  final String internalConversationId;
  final String adminId;
  final String adminUsername;

  const ChatContact({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    required this.phone,
    required this.department,
    required this.branch,
    required this.post,
    required this.avatar,
    required this.onlineStatus,
    required this.role,
    required this.userType,
    required this.isAdminValue,
    required this.adminValue,
    required this.isOnlineValue,
    required this.directoryType,
    required this.sourceId,
    required this.chatMode,
    required this.conversationId,
    required this.internalConversationId,
    required this.adminId,
    required this.adminUsername,
  });

  factory ChatContact.fromJson(dynamic json) {
    final map = json is Map<String, dynamic> ? json : <String, dynamic>{};

    return ChatContact(
      id: _firstString(map, ['id', 'employee_id', 'user_id']),
      name: _firstString(map, ['name', 'full_name', 'employee_name']),
      username: _firstString(map, ['username', 'user_name', 'login']),
      email: _stringValue(map['email']),
      phone: _stringValue(map['phone']),
      department: _stringValue(map['department']),
      branch: _stringValue(map['branch']),
      post: _stringValue(map['post']),
      avatar: _firstString(map, ['avatar', 'image', 'photo']),
      onlineStatus: map['online_status'] ?? map['is_online'] ?? map['online'],
      role: _stringValue(map['role']),
      userType: _firstString(map, ['user_type', 'type']),
      isAdminValue: map['is_admin'] ?? map['isAdmin'] ?? map['admin_user'],
      adminValue: map['admin'] ?? map['is_admin_contact'],
      isOnlineValue: map['is_online'] ?? map['online'],
      directoryType: _firstString(map, ['directory_type', 'contact_type']),
      sourceId: _firstString(map, ['source_id', 'admin_id', 'employee_id']),
      chatMode: _firstString(map, ['chat_mode', 'message_mode']),
      conversationId: _firstString(
          map, ['conversation_id', 'conversationId', 'chat_id']),
      internalConversationId: _firstString(
          map, ['internal_conversation_id', 'thread_id']),
      adminId: _firstString(map, ['admin_id', 'admin_user_id', 'support_id']),
      adminUsername: _firstString(
          map, ['admin_username', 'admin_user_name', 'support_username']),
    );
  }

  bool get isAdmin {
    final roleValue = role.trim().toLowerCase();
    final userTypeValue = userType.trim().toLowerCase();

    return parseBoolLike(isAdminValue) ||
        parseBoolLike(adminValue) ||
        roleValue == 'admin' ||
        userTypeValue == 'admin';
  }

  bool get isEmployee => userType.trim().toLowerCase() == 'employee';

  bool get usesAdminThread {
    return isAdmin ||
        directoryType.trim().toLowerCase() == 'admin' ||
        chatMode.trim().toLowerCase() == 'admin_thread' ||
        containsAdminWord(directoryType) ||
        containsAdminWord(chatMode) ||
        containsAdminWord(role);
  }

  String get resolvedAdminId {
    if (adminId.trim().isNotEmpty) {
      return adminId.trim();
    }
    if (sourceId.trim().isNotEmpty) {
      return sourceId.trim();
    }
    return id.trim();
  }

  String get resolvedAdminUsername {
    if (adminUsername.trim().isNotEmpty) {
      return adminUsername.trim();
    }
    return username.trim();
  }

  bool get isOnline {
    return parseBoolLike(onlineStatus) || parseBoolLike(isOnlineValue);
  }

  bool matchesSearch(String query) {
    final search = query.trim().toLowerCase();
    if (search.isEmpty) {
      return true;
    }

    return [
      name,
      username,
      email,
      phone,
      department,
      branch,
      post,
    ].any((value) => value.toLowerCase().contains(search));
  }

  static String _stringValue(dynamic value) => (value ?? '').toString();

  static String _firstString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return '';
  }
}

bool parseBoolLike(dynamic value) {
  if (value == null) return false;
  final v = value.toString().trim().toLowerCase();
  return v == '1' || v == 'true' || v == 'yes';
}

bool containsAdminWord(String? value) {
  if (value == null) return false;
  final v = value.trim().toLowerCase();
  return v.contains('admin') ||
      v.contains('administrator') ||
      v.contains('administration');
}
