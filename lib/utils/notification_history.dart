import 'package:cnattendance/utils/app_update_payload.dart';
import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/model/notification.dart' as Not;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import 'package:nepali_date_picker/nepali_date_picker.dart';

class NotificationHistory {
  NotificationHistory._();

  static const String _storageKey = 'local_notification_history';
  static const int _maxEntries = 50;

  static Future<({String? key, bool isNew})> saveRemoteMessage(
    RemoteMessage message, {
    required String title,
    required String body,
  }) async {
    final trimmedTitle = title.trim();
    final trimmedBody = body.trim();

    if (trimmedTitle.isEmpty && trimmedBody.isEmpty) {
      return (key: null, isNew: false);
    }

    final box = GetStorage();
    final existing = _readRawEntries(box);
    final date = (message.sentTime ?? DateTime.now()).toUtc().toIso8601String();
    final eventId =
        message.data['notification_event_id']?.toString().trim() ?? '';
    final messageId = message.messageId?.trim() ?? '';
    final deliveryKey = messageId.isEmpty ? null : 'message:$messageId';
    final dedupeKey = eventId.isNotEmpty
        ? 'event:$eventId'
        : deliveryKey ?? '$trimmedTitle|$trimmedBody|$date';

    for (final item in existing) {
      final key = item['key'];
      if (key is String && (key == dedupeKey || key == deliveryKey)) {
        return (key: key, isNew: false);
      }
    }
    existing.insert(0, {
      'key': dedupeKey,
      'messageId': message.messageId,
      'type': message.data['type']?.toString() ?? '',
      'notification_for_id': _noticeIdFromData(message.data),
      if (message.data['type'] == 'daily_records')
        'server_notification_id': _parseInt(message.data['notification_id']),
      if (isAppUpdateNotification(message.data)) ...{
        'app_update': appUpdateMetadata(message.data),
        'server_notification_id': _parseInt(message.data['notification_id']),
      },
      'title': trimmedTitle,
      'description': trimmedBody,
      'date': date,
      'isRead': false,
    });

    if (existing.length > _maxEntries) {
      existing.removeRange(_maxEntries, existing.length);
    }

    await box.write(_storageKey, existing);
    return (key: dedupeKey, isNew: true);
  }

  static Future<List<Not.Notification>> loadStoredNotifications() async {
    final box = GetStorage();
    final preferences = Preferences();
    final isAd = await preferences.getEnglishDate();
    final entries = _readRawEntries(box);
    final notifications = <Not.Notification>[];

    for (var index = 0; index < entries.length; index++) {
      final item = entries[index];
      final parsedDate =
          DateTime.tryParse(item['date']?.toString() ?? '')?.toLocal() ??
              DateTime.now();
      final nepaliDate = parsedDate.toNepaliDateTime();
      final serverId = _parseInt(item['server_notification_id']);
      final update = item['app_update'];

      notifications.add(
        Not.Notification(
          id: serverId > 0 ? serverId : -1000000 - index,
          title: item['title']?.toString() ?? 'Notification',
          description: item['description']?.toString() ?? '',
          month: isAd
              ? DateFormat('MMM').format(parsedDate)
              : NepaliDateFormat('MMMM').format(nepaliDate),
          day: isAd
              ? DateFormat('dd').format(parsedDate)
              : NepaliDateFormat('dd').format(nepaliDate),
          date: parsedDate,
          localKey: item['key']?.toString(),
          isRead: item['isRead'] == true,
          type: item['type']?.toString() ?? '',
          notificationForId: _parseInt(item['notification_for_id']),
          appUpdate: update is Map ? appUpdateMetadata(update) : const {},
        ),
      );
    }

    return notifications;
  }

  static Future<int> getUnreadCount({
    Set<String> excludingTypes = const {},
  }) async {
    final box = GetStorage();
    final entries = _readRawEntries(box);
    return entries.where((item) {
      if (item['isRead'] == true) {
        return false;
      }

      final type = item['type']?.toString() ?? '';
      return !excludingTypes.contains(type);
    }).length;
  }

  static Future<void> markAllAsRead() async {
    final box = GetStorage();
    final entries = _readRawEntries(box);

    for (final item in entries) {
      item['isRead'] = true;
    }

    await box.write(_storageKey, entries);
  }

  static Future<void> markAsRead(String key) async {
    final box = GetStorage();
    final entries = _readRawEntries(box);

    for (final item in entries) {
      if (item['key'] == key) {
        item['isRead'] = true;
        break;
      }
    }

    await box.write(_storageKey, entries);
  }

  static List<Map<String, dynamic>> _readRawEntries(GetStorage box) {
    final raw = box.read(_storageKey);
    if (raw is! List) {
      return <Map<String, dynamic>>[];
    }

    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static int _parseInt(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _noticeIdFromData(Map<String, dynamic> data) {
    if (data['type'] == 'home_highlight') {
      final id = int.tryParse('${data['home_highlight_id'] ?? ''}');
      if (id != null && id > 0) return '$id';
    }
    for (final key in const ['notice_id', 'notification_for_id', 'id']) {
      final value = data[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }

    return '';
  }
}
