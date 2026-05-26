import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:cnattendance/utils/chat_unread_store.dart';
import 'package:cnattendance/utils/notification_history.dart';
import 'package:flutter/foundation.dart';

class AppBadgeSync {
  AppBadgeSync._();

  static Future<int> sync({
    int? notificationUnreadOverride,
    int? chatUnreadOverride,
  }) async {
    final notificationUnread = notificationUnreadOverride ??
        await NotificationHistory.getUnreadCount(
          excludingTypes: {'chat', 'group_chat'},
        );
    final chatUnread =
        chatUnreadOverride ?? await ChatUnreadStore.getTotalUnreadCount();
    final total = notificationUnread + chatUnread;
    final safeTotal = total < 0 ? 0 : total;

    try {
      await AwesomeNotifications().setGlobalBadgeCounter(safeTotal);
    } catch (e) {
      debugPrint('Unable to sync global app badge: $e');
    }

    return safeTotal;
  }
}
