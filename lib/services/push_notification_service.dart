import 'package:cnattendance/features/home_highlights/home_highlight_open_screen.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/provider/chatbadgecontroller.dart';
import 'package:cnattendance/provider/notificationcontroller.dart';
import 'package:cnattendance/screen/general/generalscreen.dart';
import 'package:cnattendance/screen/profile/admin_chat_thread_screen.dart';
import 'package:cnattendance/screen/profile/chatscreen.dart';
import 'package:cnattendance/screen/profile/group_chat_screen.dart';
import 'package:cnattendance/utils/app_badge_sync.dart';
import 'package:cnattendance/utils/chat_unread_store.dart';
import 'package:cnattendance/utils/chat/notification_payload_parser.dart';
import 'package:cnattendance/utils/fcm_token.dart';
import 'package:cnattendance/utils/navigationservice.dart';
import 'package:cnattendance/utils/notification_history.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_notification/in_app_notification.dart';
import 'package:cnattendance/utils/app_device_info.dart';
import 'package:cnattendance/widget/app_update_dialog.dart';
import '../firebase_options.dart';
import '../utils/constant.dart';

const String _iosTestFlightUpdateUrl =
    'https://testflight.apple.com/join/hPG4ZA38';

class PushNotificationService {
  static Future<void>? _initialization;
  static Future<void>? _initialNotificationOpen;
  static ReceivedAction? _initialLocalAction;

  static String _messageTitle(RemoteMessage message) {
    return message.notification?.title ??
        message.data["notification_title"] ??
        message.data["sender_name"] ??
        message.data["title"] ??
        message.data["subject"] ??
        "Notification";
  }

  static String _messageBody(RemoteMessage message) {
    return message.notification?.body ??
        message.data["message"] ??
        message.data["body"] ??
        message.data["description"] ??
        message.data["content"] ??
        "";
  }

  static String _messageAvatar(RemoteMessage message) {
    return message.data["sender_image"] ?? "";
  }

  static bool _hasValidRemoteUrl(String? value) {
    if (value == null) {
      return false;
    }

    final uri = Uri.tryParse(value.trim());
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  static String _maskToken(String? token) {
    if (token == null || token.trim().isEmpty) {
      return 'missing';
    }

    final trimmed = token.trim();
    if (trimmed.length <= 12) {
      return trimmed;
    }

    return '${trimmed.substring(0, 6)}...${trimmed.substring(trimmed.length - 6)}';
  }

  static void _logPushDiagnostic(String label,
      [Map<String, Object?> details = const {}]) {
    final buffer = StringBuffer('[PUSH] $label');
    details.forEach((key, value) {
      buffer.write(' | $key=$value');
    });
    print(buffer.toString());
  }

  static String _authorizationStatusLabel(AuthorizationStatus status) {
    switch (status) {
      case AuthorizationStatus.authorized:
        return 'authorized';
      case AuthorizationStatus.denied:
        return 'denied';
      case AuthorizationStatus.notDetermined:
        return 'notDetermined';
      case AuthorizationStatus.provisional:
        return 'provisional';
    }
  }

  static Map<String, Object?> _messageLogDetails(RemoteMessage message) {
    return {
      'messageId': message.messageId,
      'sentTime': message.sentTime?.toIso8601String(),
      'type': message.data['type'],
      'chat_message_type':
          message.data['chat_message_type'] ?? message.data['message_type'],
    };
  }

  static Future<void> _reportIosPushSetupStatus(String? fcmToken) async {
    try {
      final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
      final settings =
          await FirebaseMessaging.instance.getNotificationSettings();

      _logPushDiagnostic('iOS setup status', {
        'authorization':
            _authorizationStatusLabel(settings.authorizationStatus),
        'alert': settings.alert.name,
        'badge': settings.badge.name,
        'sound': settings.sound.name,
        'apns': _maskToken(apnsToken),
        'fcm': _maskToken(fcmToken),
      });
    } catch (e) {
      debugPrint('iOS push setup check failed: $e');
    }
  }

  static Map<String, String> _notificationPayload(
    RemoteMessage message, {
    String? localKey,
  }) {
    final payload = ChatNotificationPayload.fromData(
      message.data,
      title: _messageTitle(message),
      message: _messageBody(message),
    ).toMap(localKey: localKey ?? "");
    for (final key in const [
      'action',
      'home_highlight_id',
      'target_version',
      'latest_version',
      'download_url',
      'url',
      'android_url',
      'android_download_url',
      'play_store_url',
      'ios_url',
      'ios_download_url',
      'app_store_url',
      'apple_store_url',
      'force_update',
    ]) {
      final value = message.data[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) payload[key] = value;
    }
    return payload;
  }

  static Future<int?> _currentUnreadNotificationBadge() async {
    if (!Platform.isIOS) {
      return null;
    }

    try {
      final notificationUnread = await NotificationHistory.getUnreadCount(
        excludingTypes: {'chat', 'group_chat'},
      );
      final chatUnread = await ChatUnreadStore.getTotalUnreadCount();
      final totalUnread = notificationUnread + chatUnread;
      return totalUnread > 0 ? totalUnread : 1;
    } catch (e) {
      debugPrint('Unable to read unread notification badge count: $e');
      return 1;
    }
  }

  @visibleForTesting
  static bool isAppUpdatePayload(Map<String, dynamic> data) {
    final type = data['type']?.toString().toLowerCase().trim() ?? '';
    if (type == 'app_update' || type == 'version_update') return true;
    if (data['action']?.toString().toLowerCase().trim() == 'app_update') {
      return true;
    }
    return ['target_version', 'latest_version'].any(
      (key) => data[key]?.toString().trim().isNotEmpty ?? false,
    );
  }

  static Future<void> _showAppUpdatePrompt({
    required String targetVersion,
    required String downloadUrl,
    required String title,
    required String message,
    required bool forceUpdate,
  }) async {
    final context =
        NavigationService.navigatorKey.currentContext ?? Get.context;
    if (context == null) {
      debugPrint('Unable to show app update prompt: no active BuildContext');
      return;
    }

    try {
      final details = await AppDeviceInfo.getDetails();
      final currentVersion = details.appVersion;
      if (!context.mounted ||
          (targetVersion.isNotEmpty &&
              !AppDeviceInfo.isVersionOlder(currentVersion, targetVersion))) {
        return;
      }
      await showAppUpdateDialog(
        automatic: true,
        context: context,
        currentVersion: currentVersion,
        latestVersion:
            targetVersion.isNotEmpty ? targetVersion : currentVersion,
        downloadUrl: downloadUrl.isNotEmpty
            ? downloadUrl
            : (Platform.isIOS
                ? _iosTestFlightUpdateUrl
                : 'https://hr.kneayerng.com'),
        releaseNotes: message,
        alertTitle: title,
        isForceUpdate: forceUpdate,
      );
    } catch (e) {
      debugPrint('Failed to show AppUpdateDialog: $e');
    }
  }

  static String _platformDownloadUrl(Map<String, dynamic> data) {
    String read(List<String> keys) {
      for (final key in keys) {
        final value = data[key]?.toString().trim() ?? '';
        if (value.isNotEmpty) return value;
      }
      return '';
    }

    final platformUrl = Platform.isIOS
        ? read([
            'ios_url',
            'app_store_url',
            'apple_store_url',
            'ios_download_url',
          ])
        : read([
            'android_url',
            'play_store_url',
            'android_download_url',
          ]);

    if (platformUrl.isNotEmpty) return platformUrl;
    if (Platform.isIOS) return _iosTestFlightUpdateUrl;

    final fallbackUrl = read(['download_url', 'url']);
    return fallbackUrl.isNotEmpty ? fallbackUrl : 'https://hr.kneayerng.com';
  }

  static NotificationContent _buildNotificationContent(
    RemoteMessage message, {
    int? badge,
    String? localKey,
  }) {
    final payload = _notificationPayload(message, localKey: localKey);
    final type = payload['type'] ?? '';
    final isGroupChat = type == 'group_chat';
    final isDirectChat = type == 'chat';
    final isChat = isGroupChat || isDirectChat;
    final senderName = (payload['sender_name']?.trim().isNotEmpty ?? false)
        ? payload['sender_name']!.trim()
        : _messageTitle(message);
    final conversationTitle = isGroupChat
        ? (payload['title'] ?? 'Digital HRMS Chat')
        : (isDirectChat ? senderName : _messageTitle(message));
    final avatar = payload['sender_image']?.trim() ?? '';

    return NotificationContent(
      id: DateTime.now().millisecondsSinceEpoch.remainder(1000000),
      channelKey: 'digital_hr_channel',
      title: conversationTitle,
      body: _messageBody(message),
      summary: isChat
          ? (isGroupChat ? senderName : 'Digital HRMS Chat')
          : 'Digital HRMS',
      category:
          isChat ? NotificationCategory.Message : NotificationCategory.Reminder,
      notificationLayout: isGroupChat
          ? NotificationLayout.MessagingGroup
          : (isDirectChat
              ? NotificationLayout.Messaging
              : NotificationLayout.Default),
      groupKey: payload['conversation_id']?.isNotEmpty == true
          ? payload['conversation_id']
          : payload['type'],
      largeIcon: _hasValidRemoteUrl(avatar) ? avatar : null,
      wakeUpScreen: true,
      badge: badge,
      payload: payload,
    );
  }

  static Future<void> _openNotificationFromPayload(
      Map<String, String?> payload) async {
    final localKey = payload['local_key']?.trim();
    if (localKey != null && localKey.isNotEmpty) {
      if (Get.isRegistered<NotificationController>()) {
        await Get.find<NotificationController>().markLocalNotificationAsRead(
          localKey,
        );
      } else {
        await NotificationHistory.markAsRead(localKey);
        await _syncUnreadBadgeFromStorage();
      }
    }

    final type = payload["type"];
    final highlightId = homeHighlightNotificationId(payload);
    if (highlightId != null) {
      Get.to(() => HomeHighlightOpenScreen(id: highlightId));
      return;
    }

    if (isAppUpdatePayload(payload)) {
      await _showAppUpdatePrompt(
        targetVersion: payload['target_version'] ?? payload['latest_version'] ?? '',
        downloadUrl: _platformDownloadUrl(payload),
        title: payload['title'] ?? 'មានកំណែអាប់ដេតថ្មី',
        message: payload['message'] ?? '',
        forceUpdate: _parseBoolLike(payload['force_update']),
      );
      return;
    }

    if (type == "chat") {
      if (_isAdminThreadPayload(payload)) {
        _logPushDiagnostic('open admin thread from push', {
          'conversation_id': payload['conversation_id'],
          'admin_id': payload['admin_id'],
          'admin_username': payload['admin_username'],
          'chat_mode': payload['chat_mode'],
          'internal_conversation_id': payload['internal_conversation_id'],
        });
        Get.to(const AdminChatThreadScreen(), arguments: {
          "name": payload["sender_name"] ?? payload["title"] ?? "Admin",
          "avatar": payload["sender_image"] ?? "",
          "conversationId": payload["conversation_id"] ?? "",
          "adminId": payload["admin_id"] ?? "",
          "adminUsername":
              payload["admin_username"] ?? payload["sender_username"] ?? "",
          "username":
              payload["admin_username"] ?? payload["sender_username"] ?? "",
          "internalConversationId": payload["internal_conversation_id"] ?? "",
        });
        return;
      }

      Get.to(ChatScreen(), arguments: {
        "name": payload["sender_name"] ?? payload["title"] ?? "Notification",
        "avatar": payload["sender_image"] ?? "",
        "username": payload["sender_username"] ?? "",
      });
      return;
    }

    if (type == "group_chat") {
      final conversationId = payload["conversation_id"] ?? "";
      final groupId =
          int.tryParse(conversationId.replaceAll("group_", "")) ?? 0;
      if (groupId > 0) {
        Get.to(GroupChatScreen(
          groupId: groupId,
          groupName: payload["title"] ?? "Group",
        ));
      }
      return;
    }

    Get.to(GeneralScreen(), arguments: {
      "title": payload["title"] ?? "Notification",
      "message": payload["message"] ?? "",
      "id": payload["id"] ?? "",
      "notice_id": _noticeIdFromPayload(payload),
      "date": "",
      "type": payload["type"] ?? "",
      "download_url": _platformDownloadUrl(Map<String, dynamic>.from(payload)),
    });
  }

  static String _noticeIdFromPayload(Map<String, String?> payload) {
    for (final key in const ['notice_id', 'notification_for_id', 'id']) {
      final value = payload[key]?.trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }

    return '';
  }

  static bool _isAdminThreadPayload(Map<String, String?> payload) {
    final chatMode = payload["chat_mode"]?.trim().toLowerCase();
    final userType = payload["user_type"]?.trim().toLowerCase();
    final role = payload["role"]?.trim().toLowerCase();
    final directoryType = payload["directory_type"]?.trim().toLowerCase();

    return chatMode == "admin_thread" ||
        userType == "admin" ||
        role == "admin" ||
        directoryType == "admin" ||
        _parseBoolLike(payload["is_admin"]) ||
        _parseBoolLike(payload["admin"]);
  }

  static bool _parseBoolLike(dynamic value) {
    if (value == null) return false;
    final v = value.toString().trim().toLowerCase();
    return v == '1' || v == 'true' || v == 'yes';
  }

  @visibleForTesting
  static bool systemPresentsRemoteMessage(
    RemoteMessage message, {
    required bool isIOS,
    required bool isForeground,
  }) =>
      message.notification != null && (isIOS || !isForeground);

  static Future<void> _showSystemNotification(
    RemoteMessage message, {
    String? localKey,
  }) async {
    try {
      final badge = await _currentUnreadNotificationBadge();
      await AwesomeNotifications().createNotification(
        content: _buildNotificationContent(
          message,
          badge: badge,
          localKey: localKey,
        ),
      );
    } catch (e) {
      debugPrint('Failed to show system notification: $e');
    }
  }

  static Future<void> _syncUnreadBadgeFromStorage() async {
    await AppBadgeSync.sync();
  }

  static String _chatConversationId(RemoteMessage message) {
    final conversationId =
        message.data["conversation_id"]?.toString().trim() ?? "";
    _logPushDiagnostic('incoming chat conversation', {
      'conversation_id': conversationId,
      'admin_id': message.data["admin_id"],
      'admin_username': message.data["admin_username"],
      'chat_mode': message.data["chat_mode"],
    });
    return conversationId;
  }

  static String _chatMessageKey(RemoteMessage message) {
    final messageId = message.messageId?.trim() ?? "";
    if (messageId.isNotEmpty) {
      return 'push:$messageId';
    }

    final type = message.data["type"]?.toString().trim() ?? "";
    final conversationId = _chatConversationId(message);
    final sender = message.data["sender_username"]?.toString().trim() ??
        message.data["sender_name"]?.toString().trim() ??
        '';
    final sentAt = message.sentTime?.toUtc().toIso8601String() ?? '';
    final body = _messageBody(message).trim();
    return 'push:$type|$conversationId|$sender|$sentAt|$body';
  }

  @visibleForTesting
  static bool shouldTrackChatUnread(
    RemoteMessage message, {
    required bool includeDirectChat,
  }) {
    final type = message.data["type"]?.toString().trim() ?? "";
    final isDirectChat = type == "chat";
    final isGroupChat = type == "group_chat";
    return isGroupChat || (includeDirectChat && isDirectChat);
  }

  @visibleForTesting
  static String chatConversationIdFor(RemoteMessage message) {
    return _chatConversationId(message);
  }

  @visibleForTesting
  static String chatMessageKeyFor(RemoteMessage message) {
    return _chatMessageKey(message);
  }

  static Future<void> _trackIncomingChatUnread(
    RemoteMessage message, {
    required bool includeDirectChat,
  }) async {
    if (!shouldTrackChatUnread(
      message,
      includeDirectChat: includeDirectChat,
    )) {
      return;
    }

    final conversationId = _chatConversationId(message);
    if (conversationId.isEmpty) {
      return;
    }

    final title = (message.data["title"]?.toString().trim().isNotEmpty ?? false)
        ? message.data["title"]!.toString().trim()
        : _messageTitle(message);

    if (Get.isRegistered<ChatBadgeController>()) {
      await Get.find<ChatBadgeController>().handleIncomingMessage(
        conversationId: conversationId,
        messageKey: _chatMessageKey(message),
        title: title,
      );
      return;
    }

    final added = await ChatUnreadStore.addUnreadMessage(
      conversationId: conversationId,
      messageKey: _chatMessageKey(message),
      title: title,
    );
    if (added) {
      await AppBadgeSync.sync();
    }
  }

  static Future<({String? key, bool isNew})> _storeNotificationHistory(
    RemoteMessage message,
  ) async {
    final entry = await NotificationHistory.saveRemoteMessage(
      message,
      title: _messageTitle(message),
      body: _messageBody(message),
    );
    if (!entry.isNew) return entry;

    try {
      if (Get.isRegistered<NotificationController>()) {
        await Get.find<NotificationController>().syncLocalNotificationState();
      } else {
        await _syncUnreadBadgeFromStorage();
      }
    } catch (e) {
      debugPrint('Unable to sync local notification state: $e');
      await _syncUnreadBadgeFromStorage();
    }

    return entry;
  }

  static Future<void> _openNotification(
    RemoteMessage message, {
    String? localKey,
  }) async {
    final resolvedLocalKey =
        localKey ?? (await _storeNotificationHistory(message)).key;
    await _openNotificationFromPayload(
      _notificationPayload(message, localKey: resolvedLocalKey),
    );
  }

  /// Read launch actions once, after the authenticated home screen is ready.
  static Future<void> openInitialNotification() =>
      _initialNotificationOpen ??= _openInitialNotification();

  static Future<void> _openInitialNotification() async {
    try {
      final localAction = _initialLocalAction;
      _initialLocalAction = null;
      if (localAction != null) {
        await _onAwesomeNotificationActionReceived(localAction);
        return;
      }
      final message = await FirebaseMessaging.instance.getInitialMessage();
      if (message != null) {
        _logPushDiagnostic('getInitialMessage', _messageLogDetails(message));
        await _openNotification(message);
      }
    } catch (error) {
      debugPrint('Unable to open initial notification: $error');
    }
  }

  @pragma('vm:entry-point')
  static Future<void> _onAwesomeNotificationActionReceived(
      ReceivedAction receivedAction) async {
    await _openNotificationFromPayload(receivedAction.payload ?? {});
  }

  static bool _showMessengerAlert(
    RemoteMessage message, {
    String? localKey,
  }) {
    final context = NavigationService.navigatorKey.currentState?.context;
    if (context == null) {
      return false;
    }

    final title = _messageTitle(message);
    final body = _messageBody(message);
    final avatar = _messageAvatar(message);
    final isChat = message.data["type"] == "chat";

    try {
      InAppNotification.show(
        duration: const Duration(seconds: 4),
        onTap: () => _openNotification(message, localKey: localKey),
        child: Container(
          margin: const EdgeInsets.fromLTRB(14, 16, 14, 0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.18),
                blurRadius: 22,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minLeadingWidth: 0,
              leading: _hasValidRemoteUrl(avatar)
                  ? CircleAvatar(
                      radius: 24,
                      backgroundImage: NetworkImage(avatar),
                      backgroundColor: Colors.grey.shade200,
                    )
                  : CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(0xffeaf1ff),
                      child: Icon(
                        isChat ? Icons.person : Icons.notifications,
                        color: const Color(0xff011754),
                      ),
                    ),
              title: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xff011754),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xff5d6785),
                    fontSize: 13,
                    height: 1.25,
                  ),
                ),
              ),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xff7d88a5),
              ),
            ),
          ),
        ),
        context: context,
      );
      return true;
    } catch (e) {
      debugPrint('Failed to show in-app notification: $e');
      return false;
    }
  }

  @pragma('vm:entry-point')
  static Future<void> _messageHandler(RemoteMessage message) async {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    await GetStorage.init();
    ChatUnreadStore.markStorageReady();
    _logPushDiagnostic('onBackgroundMessage', _messageLogDetails(message));
    final entry = await _storeNotificationHistory(message);
    if (!entry.isNew) return;
    await _trackIncomingChatUnread(message, includeDirectChat: true);
    // The OS presents messages that already carry a notification payload.
    if (!systemPresentsRemoteMessage(
      message,
      isIOS: Platform.isIOS,
      isForeground: false,
    )) {
      await _showSystemNotification(message, localKey: entry.key);
    }
  }

  static Future<void> _syncFcmTokenWithBackend(String? token) async {
    if (!FcmToken.isValid(token)) {
      return;
    }

    final preferences = Preferences();
    final authToken = await preferences.getToken();
    if (authToken.trim().isEmpty) {
      _logPushDiagnostic('token refresh skipped: not logged in');
      return;
    }

    try {
      final uri = Uri.parse(
          await preferences.getAppUrl() + Constant.UPDATE_FCM_TOKEN_URL);
      final response = await http.post(uri, headers: {
        'Accept': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $authToken',
      }, body: {
        'fcm_token': token!,
      });
      _logPushDiagnostic('token refresh synced', {
        'status': response.statusCode,
        'fcm': _maskToken(token),
      });
    } catch (e) {
      debugPrint('Failed to sync refreshed FCM token: $e');
    }
  }

  static Future<void> _finishStartupSetup() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      _logPushDiagnostic('notification permission result', {
        'authorization':
            _authorizationStatusLabel(settings.authorizationStatus),
        'alert': settings.alert.name,
        'badge': settings.badge.name,
        'sound': settings.sound.name,
        'announcement': settings.announcement.name,
      });

      if (Platform.isIOS) {
        await FirebaseMessaging.instance
            .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      final fcmToken = await FcmToken.get();
      if (Platform.isIOS) {
        await _reportIosPushSetupStatus(fcmToken);
      }
      if (fcmToken != null && fcmToken.isNotEmpty) {
        await _syncFcmTokenWithBackend(fcmToken);
      }

      final data =
          await PlatformAssetBundle().load('assets/ca/lets-encrypt-r3.pem');
      SecurityContext.defaultContext
          .setTrustedCertificatesBytes(data.buffer.asUint8List());
    } catch (e, stackTrace) {
      debugPrint('Deferred startup setup failed: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static Future<void> initialize() => _initialization ??= _initialize();

  static Future<void> _initialize() async {
    FirebaseMessaging.onBackgroundMessage(_messageHandler);
    FirebaseFirestore.instance.settings =
        const Settings(persistenceEnabled: false);
    FirebaseFirestore.instance.clearPersistence();

    await AwesomeNotifications().initialize(
      'resource://drawable/app_icon',
      [
        NotificationChannel(
          channelGroupKey: 'digital_hr_group',
          channelKey: 'digital_hr_channel',
          channelName: 'Digital Hr notifications',
          channelDescription: 'Digital HR Alert',
          channelShowBadge: true,
          defaultColor: const Color(0xFF9D50DD),
          ledColor: Colors.white,
          importance: NotificationImportance.High,
        ),
        NotificationChannel(
          channelGroupKey: 'digital_hr_group',
          channelKey: 'ahpu_channel_11',
          channelName: 'Digital Hr alerts',
          channelDescription: 'Digital HR Updates & Alerts',
          channelShowBadge: true,
          defaultColor: const Color(0xFF9D50DD),
          ledColor: Colors.white,
          importance: NotificationImportance.High,
        ),
      ],
      channelGroups: [
        NotificationChannelGroup(
          channelGroupKey: 'digital_hr_group',
          channelGroupName: 'HR group',
        ),
      ],
      debug: true,
    );

    _initialLocalAction =
        await AwesomeNotifications().getInitialNotificationAction(
      removeFromActionEvents: true,
    );
    await AwesomeNotifications().setListeners(
      onActionReceivedMethod: _onAwesomeNotificationActionReceived,
    );

    FirebaseMessaging.onMessage.listen((message) async {
      _logPushDiagnostic('onMessage', _messageLogDetails(message));
      final entry = await _storeNotificationHistory(message);
      if (!entry.isNew) return;
      await _trackIncomingChatUnread(message, includeDirectChat: false);

      // iOS already presents foreground pushes that carry a system alert.
      if (systemPresentsRemoteMessage(
        message,
        isIOS: Platform.isIOS,
        isForeground: true,
      )) {
        return;
      }

      if (isAppUpdatePayload(message.data)) {
        final targetVersion =
            message.data['target_version']?.toString().trim() ?? '';
        await _showAppUpdatePrompt(
          targetVersion: targetVersion.isNotEmpty
              ? targetVersion
              : (message.data['latest_version']?.toString().trim() ?? ''),
          downloadUrl: _platformDownloadUrl(message.data),
          title: _messageTitle(message),
          message: _messageBody(message),
          forceUpdate: _parseBoolLike(message.data['force_update']),
        );
      } else if (!_showMessengerAlert(message, localKey: entry.key)) {
        await _showSystemNotification(message, localKey: entry.key);
      }
    });

    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      _logPushDiagnostic('onTokenRefresh', {'fcm': _maskToken(token)});
      _syncFcmTokenWithBackend(token);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) async {
      _logPushDiagnostic('onMessageOpenedApp', _messageLogDetails(message));
      await _openNotification(message);
    });
  }

  static Future<void> finishStartupSetup() async {
    await _finishStartupSetup();
  }
}
