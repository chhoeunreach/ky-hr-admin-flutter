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

  static Future<String?> saveRemoteMessage(
    RemoteMessage message, {
    required String title,
    required String body,
  }) async {
    final trimmedTitle = title.trim();
    final trimmedBody = body.trim();

    if (trimmedTitle.isEmpty && trimmedBody.isEmpty) {
      return null;
    }

    final box = GetStorage();
    final existing = _readRawEntries(box);
    final date = (message.sentTime ?? DateTime.now()).toUtc().toIso8601String();
    final dedupeKey = (message.messageId != null &&
            message.messageId!.trim().isNotEmpty)
        ? 'message:${message.messageId!.trim()}'
        : '$trimmedTitle|$trimmedBody|$date';

    existing.removeWhere((item) => item['key'] == dedupeKey);
    existing.insert(0, {
      'key': dedupeKey,
      'messageId': message.messageId,
      'type': message.data['type']?.toString() ?? '',
      'title': trimmedTitle,
      'description': trimmedBody,
      'date': date,
      'isRead': false,
    });

    if (existing.length > _maxEntries) {
      existing.removeRange(_maxEntries, existing.length);
    }

    await box.write(_storageKey, existing);
    return dedupeKey;
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

      notifications.add(
        Not.Notification(
          id: -1000000 - index,
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
}
