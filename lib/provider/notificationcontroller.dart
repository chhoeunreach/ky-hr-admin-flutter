import 'dart:convert';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/data/source/network/model/notification/NotifiactionDomain.dart';
import 'package:cnattendance/data/source/network/model/notification/NotificationResponse.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:cnattendance/utils/app_badge_sync.dart';
import 'package:cnattendance/utils/notification_history.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:cnattendance/model/notification.dart' as Not;
import 'package:intl/intl.dart';
import 'package:nepali_date_picker/nepali_date_picker.dart';

class NotificationController extends GetxController {
  static int per_page = 10;
  int page = 1;

  var _notificationList = <Not.Notification>[].obs;
  final isInitialLoading = false.obs;
  final isLoadingMore = false.obs;
  final hasMore = true.obs;
  final errorMessage = ''.obs;
  final unreadCount = 0.obs;
  late ScrollController controller;

  List<Not.Notification> get notificationList {
    return [..._notificationList];
  }

  int get badgeCount => unreadCount.value;

  Future<void> ensureLoaded() async {
    if (_notificationList.isNotEmpty || isInitialLoading.value) {
      await refreshBadgeCount();
      return;
    }
    await refreshNotifications();
  }

  Future<void> refreshNotifications() async {
    page = 1;
    hasMore.value = true;
    errorMessage.value = '';
    isInitialLoading.value = true;

    try {
      await getNotification();
      await refreshBadgeCount();
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isInitialLoading.value = false;
    }
  }

  Future<void> refreshBadgeCount() async {
    unreadCount.value = await NotificationHistory.getUnreadCount(
      excludingTypes: {'chat', 'group_chat'},
    );
  }

  Future<void> syncAppIconBadge() async {
    await AppBadgeSync.sync(notificationUnreadOverride: unreadCount.value);
  }

  Future<NotificationResponse> getNotification() async {
    Preferences preferences = Preferences();
    var uri =
        Uri.parse(await preferences.getAppUrl() + Constant.NOTIFICATION_URL)
            .replace(queryParameters: {
      'page': page.toString(),
      'per_page': per_page.toString(),
    });

    String token = await preferences.getToken();

    Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token'
    };

    try {
      final response = await http.get(uri, headers: headers);
      debugPrint(response.body.toString());

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        final jsonResponse = NotificationResponse.fromJson(responseData);
        await makeNotificationList(jsonResponse.data);
        return jsonResponse;
      } else {
        var errorMessage = responseData['message'];
        throw errorMessage;
      }
    } catch (e) {
      throw e;
    }
  }

  Future<void> makeNotificationList(List<NotifiactionDomain> data) async {
    Preferences preferences = Preferences();
    bool isAd = await preferences.getEnglishDate();

    if (page == 1) {
      _notificationList.clear();
      await _mergeLocalNotifications();
    }

    if (data.isEmpty) {
      hasMore.value = false;
      return;
    }

    if (data.isNotEmpty) {
      for (var item in data) {
        DateTime tempDate =
            _parseNotificationDate(item.notificationPublishedDate);
        NepaliDateTime nepaliDate = tempDate.toNepaliDateTime();
        print(nepaliDate);

        _addNotificationIfMissing(
          Not.Notification(
              id: item.id,
              title: item.notificationTitle,
              description: item.description,
              month: isAd
                  ? DateFormat('MMM').format(tempDate)
                  : NepaliDateFormat('MMMM').format(nepaliDate),
              day: isAd
                  ? DateFormat('dd').format(tempDate)
                  : NepaliDateFormat('dd').format(nepaliDate),
              date: tempDate,
              isRead: item.isRead),
        );
      }

      _sortNotificationsByDate();
      hasMore.value = data.length >= per_page;
      page += 1;
    }
  }

  DateTime _parseNotificationDate(String value) {
    try {
      return DateFormat("yyyy-MM-dd").parse(value);
    } catch (_) {
      final parsed = DateTime.tryParse(value);
      return parsed ?? DateTime.now();
    }
  }

  void _addNotificationIfMissing(Not.Notification notification) {
    final exists = _notificationList.any(
      (item) =>
          item.localKey == notification.localKey &&
              notification.localKey != null ||
          item.title.trim() == notification.title.trim() &&
              item.description.trim() == notification.description.trim() &&
              item.date.toIso8601String() ==
                  notification.date.toIso8601String(),
    );

    if (!exists) {
      _notificationList.add(notification);
    }
  }

  Future<void> _mergeLocalNotifications() async {
    final localNotifications =
        await NotificationHistory.loadStoredNotifications();
    for (final item in localNotifications) {
      _addNotificationIfMissing(item);
    }
    _sortNotificationsByDate();
  }

  void _sortNotificationsByDate() {
    final sorted = [..._notificationList]
      ..sort((a, b) => b.date.compareTo(a.date));
    _notificationList.assignAll(sorted);
  }

  Future<void> syncLocalNotificationState() async {
    await _mergeLocalNotifications();
    await refreshBadgeCount();
    await syncAppIconBadge();
  }

  Future<void> markNotificationAsRead(Not.Notification notification) async {
    if (notification.isRead) {
      return;
    }

    if (notification.localKey != null) {
      await NotificationHistory.markAsRead(notification.localKey!);
    } else if (notification.id > 0) {
      await _markNotificationAsReadOnServer(notification.id);
    }

    final index = _notificationList.indexWhere((item) {
      if (notification.localKey != null) {
        return item.localKey == notification.localKey;
      }
      return item.id == notification.id;
    });
    if (index != -1) {
      _notificationList[index].isRead = true;
      _notificationList.refresh();
    }

    await refreshBadgeCount();
    await syncAppIconBadge();
  }

  Future<void> markLocalNotificationAsRead(String localKey) async {
    await NotificationHistory.markAsRead(localKey);

    final index =
        _notificationList.indexWhere((item) => item.localKey == localKey);
    if (index != -1 && !_notificationList[index].isRead) {
      _notificationList[index].isRead = true;
      _notificationList.refresh();
    }

    await refreshBadgeCount();
    await syncAppIconBadge();
  }

  Future<void> _markNotificationAsReadOnServer(int id) async {
    final preferences = Preferences();
    final token = await preferences.getToken();
    final uri = Uri.parse(
      '${await preferences.getAppUrl()}${Constant.NOTIFICATION_URL}/$id/read',
    );

    final response = await http.post(uri, headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token'
    });

    if (response.statusCode < 200 || response.statusCode >= 300) {
      debugPrint('Notification read sync failed: ${response.body}');
    }
  }

  @override
  void onInit() {
    controller = ScrollController()..addListener(_loadMore);
    super.onInit();
  }

  @override
  void onReady() {
    refreshNotifications();
    super.onReady();
  }

  @override
  void onClose() {
    controller.removeListener(_loadMore);
    controller.dispose();
    super.onClose();
  }

  Future<void> _loadMore() async {
    if (!controller.hasClients ||
        isInitialLoading.value ||
        isLoadingMore.value ||
        !hasMore.value) {
      return;
    }

    final threshold = controller.position.maxScrollExtent - 120;
    if (controller.position.pixels >= threshold) {
      isLoadingMore.value = true;
      errorMessage.value = '';
      try {
        await getNotification();
      } catch (e) {
        errorMessage.value = e.toString();
      } finally {
        isLoadingMore.value = false;
      }
    }
  }
}
