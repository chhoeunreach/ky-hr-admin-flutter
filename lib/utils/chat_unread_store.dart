import 'package:get_storage/get_storage.dart';

class ChatUnreadStore {
  ChatUnreadStore._();

  static const String _storageKey = 'chat_unread_conversations';

  static Future<int> getTotalUnreadCount() async {
    final conversations = _readConversations();
    return conversations.values.fold<int>(
      0,
      (total, item) => total + _readCount(item),
    );
  }

  static Future<int> getConversationUnreadCount(String conversationId) async {
    final conversations = _readConversations();
    return _readCount(conversations[conversationId]);
  }

  static Future<bool> addUnreadMessage({
    required String conversationId,
    required String messageKey,
    String? title,
  }) async {
    if (conversationId.trim().isEmpty || messageKey.trim().isEmpty) {
      return false;
    }

    final box = GetStorage();
    final conversations = _readConversations();
    final item = Map<String, dynamic>.from(conversations[conversationId] ?? {});
    final keys = _readKeys(item);

    if (keys.contains(messageKey)) {
      return false;
    }

    keys.add(messageKey);
    item['message_keys'] = keys.toList();
    item['count'] = keys.length;
    if (title != null && title.trim().isNotEmpty) {
      item['title'] = title.trim();
    }

    conversations[conversationId] = item;
    await box.write(_storageKey, conversations);
    return true;
  }

  static Future<int> markMessageAsRead({
    required String conversationId,
    required String messageKey,
  }) async {
    return markMessagesAsRead(
      conversationId: conversationId,
      messageKeys: [messageKey],
    );
  }

  static Future<int> markMessagesAsRead({
    required String conversationId,
    required Iterable<String> messageKeys,
  }) async {
    final trimmedConversationId = conversationId.trim();
    if (trimmedConversationId.isEmpty) {
      return 0;
    }

    final box = GetStorage();
    final conversations = _readConversations();
    final item = conversations[trimmedConversationId];
    if (item == null) {
      return 0;
    }

    final keys = _readKeys(item);
    final before = keys.length;
    keys.removeAll(
      messageKeys.map((item) => item.trim()).where((item) => item.isNotEmpty),
    );
    final removed = before - keys.length;

    if (removed <= 0) {
      return 0;
    }

    if (keys.isEmpty) {
      conversations.remove(trimmedConversationId);
    } else {
      item['message_keys'] = keys.toList();
      item['count'] = keys.length;
      conversations[trimmedConversationId] = item;
    }

    await box.write(_storageKey, conversations);
    return removed;
  }

  static Future<int> markConversationAsRead(String conversationId) async {
    final trimmedConversationId = conversationId.trim();
    if (trimmedConversationId.isEmpty) {
      return 0;
    }

    final box = GetStorage();
    final conversations = _readConversations();
    final item = conversations.remove(trimmedConversationId);
    if (item == null) {
      return 0;
    }

    final removed = _readCount(item);
    await box.write(_storageKey, conversations);
    return removed;
  }

  static Future<void> clearAll() async {
    final box = GetStorage();
    await box.write(_storageKey, <String, dynamic>{});
  }

  static Map<String, Map<String, dynamic>> _readConversations() {
    final raw = GetStorage().read(_storageKey);
    if (raw is! Map) {
      return <String, Map<String, dynamic>>{};
    }

    final mapped = <String, Map<String, dynamic>>{};
    raw.forEach((key, value) {
      if (key == null || value is! Map) {
        return;
      }
      mapped[key.toString()] = Map<String, dynamic>.from(value);
    });
    return mapped;
  }

  static Set<String> _readKeys(Map<String, dynamic>? item) {
    if (item == null) {
      return <String>{};
    }

    final rawKeys = item['message_keys'];
    if (rawKeys is! List) {
      return <String>{};
    }

    return rawKeys
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toSet();
  }

  static int _readCount(Map<String, dynamic>? item) {
    if (item == null) {
      return 0;
    }

    final keys = _readKeys(item);
    if (keys.isNotEmpty) {
      return keys.length;
    }

    final rawCount = item['count'];
    if (rawCount is int) {
      return rawCount < 0 ? 0 : rawCount;
    }

    return 0;
  }
}
