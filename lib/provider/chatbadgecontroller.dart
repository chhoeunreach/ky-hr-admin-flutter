import 'package:cnattendance/utils/app_badge_sync.dart';
import 'package:cnattendance/utils/chat_unread_store.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

class ChatBadgeController extends GetxController {
  final unreadCount = 0.obs;
  final activeConversationId = RxnString();

  static ChatBadgeController ensureRegistered() {
    if (Get.isRegistered<ChatBadgeController>()) {
      return Get.find<ChatBadgeController>();
    }

    return Get.put(ChatBadgeController(), permanent: true);
  }

  @override
  void onInit() {
    refreshUnreadCount();
    super.onInit();
  }

  Future<void> refreshUnreadCount() async {
    unreadCount.value = await ChatUnreadStore.getTotalUnreadCount();
  }

  Future<void> syncAppBadge() async {
    await AppBadgeSync.sync(chatUnreadOverride: unreadCount.value);
  }

  Future<bool> handleIncomingMessage({
    required String conversationId,
    required String messageKey,
    String? title,
  }) async {
    final trimmedConversationId = conversationId.trim();
    if (trimmedConversationId.isEmpty) {
      return false;
    }

    if (activeConversationId.value == trimmedConversationId) {
      return false;
    }

    final added = await ChatUnreadStore.addUnreadMessage(
      conversationId: trimmedConversationId,
      messageKey: messageKey,
      title: title,
    );

    if (!added) {
      return false;
    }

    await refreshUnreadCount();
    await syncAppBadge();
    return true;
  }

  Future<int> markConversationAsRead(String conversationId) async {
    final removed = await ChatUnreadStore.markConversationAsRead(conversationId);
    if (removed <= 0) {
      return 0;
    }

    await refreshUnreadCount();
    await syncAppBadge();
    return removed;
  }

  Future<int> markMessageAsRead({
    required String conversationId,
    required String messageKey,
  }) async {
    final removed = await ChatUnreadStore.markMessageAsRead(
      conversationId: conversationId,
      messageKey: messageKey,
    );
    if (removed <= 0) {
      return 0;
    }

    await refreshUnreadCount();
    await syncAppBadge();
    return removed;
  }

  Future<int> markMessagesAsRead({
    required String conversationId,
    required Iterable<String> messageKeys,
  }) async {
    final removed = await ChatUnreadStore.markMessagesAsRead(
      conversationId: conversationId,
      messageKeys: messageKeys,
    );
    if (removed <= 0) {
      return 0;
    }

    await refreshUnreadCount();
    await syncAppBadge();
    return removed;
  }

  Future<void> setActiveConversation(String conversationId) async {
    activeConversationId.value = conversationId.trim();
    await markConversationAsRead(conversationId);
  }

  void clearActiveConversation(String conversationId) {
    if (activeConversationId.value == conversationId.trim()) {
      activeConversationId.value = null;
    }
  }

  @override
  void onClose() {
    debugPrint('ChatBadgeController disposed');
    super.onClose();
  }
}
