import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cnattendance/provider/chatbadgecontroller.dart';
import 'package:cnattendance/provider/notificationcontroller.dart';
import 'package:cnattendance/screen/general/generalscreen.dart';
import 'package:cnattendance/screen/profile/admin_chat_thread_screen.dart';
import 'package:cnattendance/screen/profile/chatscreen.dart';
import 'package:cnattendance/screen/profile/groupchatscreen.dart';
import 'package:cnattendance/utils/app_badge_sync.dart';
import 'package:cnattendance/utils/chat_unread_store.dart';
import 'package:cnattendance/utils/chat/notification_payload_parser.dart';
import 'package:cnattendance/utils/incoming_chat_listener.dart';
import 'package:cnattendance/utils/navigationservice.dart';
import 'package:cnattendance/utils/notification_history.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:in_app_notification/in_app_notification.dart';
import 'package:overlay_support/overlay_support.dart';
import '../firebase_options.dart';
import '../utils/constant.dart';

class PushNotificationService {
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
      'title': _messageTitle(message),
      'body': _messageBody(message),
      'type': message.data['type'],
      'chat_message_type':
          message.data['chat_message_type'] ?? message.data['message_type'],
      'data': message.data.toString(),
    };
  }

  static Future<void> _reportIosPushSetupStatus() async {
    try {
      final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
      final fcmToken = await FirebaseMessaging.instance.getToken();
      final settings =
          await FirebaseMessaging.instance.getNotificationSettings();

      final apnsReady = apnsToken != null && apnsToken.trim().isNotEmpty;
      final fcmReady = fcmToken != null && fcmToken.trim().isNotEmpty;

      debugPrint('iOS APNS token: ${_maskToken(apnsToken)}');
      debugPrint('iOS FCM token: ${_maskToken(fcmToken)}');
      _logPushDiagnostic('iOS setup status', {
        'authorization': _authorizationStatusLabel(settings.authorizationStatus),
        'alert': settings.alert.name,
        'badge': settings.badge.name,
        'sound': settings.sound.name,
        'apns': _maskToken(apnsToken),
        'fcm': _maskToken(fcmToken),
      });

      final statusMessage = apnsReady && fcmReady
          ? 'iOS push ready\nAPNS: ${_maskToken(apnsToken)}\nFCM: ${_maskToken(fcmToken)}'
          : 'iOS push not ready\nAPNS: ${_maskToken(apnsToken)}\nFCM: ${_maskToken(fcmToken)}';

      WidgetsBinding.instance.addPostFrameCallback((_) {
        showToast(statusMessage);
      });
    } catch (e) {
      debugPrint('iOS push setup check failed: $e');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showToast('iOS push check failed\n$e');
      });
    }
  }

  static Map<String, String> _notificationPayload(
    RemoteMessage message, {
    String? localKey,
  }) {
    return ChatNotificationPayload.fromData(
      message.data,
      title: _messageTitle(message),
      message: _messageBody(message),
    ).toMap(localKey: localKey ?? "");
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

  static NotificationContent _chatNotificationContent(
    RemoteMessage message, {
    int? badge,
    String? localKey,
  }) {
    final payload = _notificationPayload(message, localKey: localKey);
    final type = payload['type'] ?? '';
    final isGroupChat = type == 'group_chat';
    final senderName = (payload['sender_name']?.trim().isNotEmpty ?? false)
        ? payload['sender_name']!.trim()
        : _messageTitle(message);
    final conversationTitle =
        isGroupChat ? (payload['title'] ?? 'Digital HRMS Chat') : senderName;
    final avatar = payload['sender_image']?.trim() ?? '';

    return NotificationContent(
      id: DateTime.now().millisecondsSinceEpoch.remainder(1000000),
      channelKey: 'digital_hr_channel',
      title: conversationTitle,
      body: _messageBody(message),
      summary: isGroupChat ? senderName : 'Digital HRMS Chat',
      category: NotificationCategory.Message,
      notificationLayout: isGroupChat
          ? NotificationLayout.MessagingGroup
          : NotificationLayout.Messaging,
      groupKey: payload['conversation_id']?.isNotEmpty == true
          ? payload['conversation_id']
          : payload['type'],
      largeIcon: _hasValidRemoteUrl(avatar) ? avatar : null,
      wakeUpScreen: true,
      badge: badge,
      payload: payload,
    );
  }

  static String _toastMessage(RemoteMessage message) {
    final title = _messageTitle(message).trim();
    final body = _messageBody(message).trim();

    if (title.isEmpty && body.isEmpty) {
      return "You have a new Digital HRMS notification";
    }

    if (body.isEmpty || body == title) {
      return title;
    }

    if (title.isEmpty) {
      return body;
    }

    return "$title\n$body";
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
      Get.to(GroupChatScreen(), arguments: {
        "projectName": payload["title"] ?? "Notification",
        "projectId": payload["project_id"],
        "projectSlug": payload["conversation_id"],
        "leader": [],
        "member": [],
      });
      return;
    }

    Get.to(GeneralScreen(), arguments: {
      "title": payload["title"] ?? "Notification",
      "message": payload["message"] ?? "",
      "date": ""
    });
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

  static Future<void> _showForegroundSystemNotification(
    RemoteMessage message, {
    String? localKey,
  }) async {
    final badge = await _currentUnreadNotificationBadge();
    await AwesomeNotifications().createNotification(
      content: _chatNotificationContent(
        message,
        badge: badge,
        localKey: localKey,
      ),
    );
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

  static Future<void> _trackIncomingChatUnread(
    RemoteMessage message, {
    required bool includeDirectChat,
  }) async {
    final type = message.data["type"]?.toString().trim() ?? "";
    final isDirectChat = type == "chat";
    final isGroupChat = type == "group_chat";

    if (!isGroupChat && !(includeDirectChat && isDirectChat)) {
      return;
    }

    final conversationId = _chatConversationId(message);
    if (conversationId.isEmpty) {
      return;
    }

    final title =
        (message.data["title"]?.toString().trim().isNotEmpty ?? false)
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

  static Future<String?> _storeNotificationHistory(
      RemoteMessage message) async {
    final localKey = await NotificationHistory.saveRemoteMessage(
      message,
      title: _messageTitle(message),
      body: _messageBody(message),
    );

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

    return localKey;
  }

  static Future<void> _openNotification(
    RemoteMessage message, {
    String? localKey,
  }) async {
    final resolvedLocalKey =
        localKey ?? await _storeNotificationHistory(message);
    await _openNotificationFromPayload(
      _notificationPayload(message, localKey: resolvedLocalKey),
    );
  }

  @pragma('vm:entry-point')
  static Future<void> _onAwesomeNotificationActionReceived(
      ReceivedAction receivedAction) async {
    await _openNotificationFromPayload(receivedAction.payload ?? {});
  }

  static void _showMessengerAlert(
    RemoteMessage message, {
    String? localKey,
  }) {
    final context = NavigationService.navigatorKey.currentState?.context;
    if (context == null) {
      return;
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
    } catch (e) {
      print(e);
    }
  }

  @pragma('vm:entry-point')
  static Future<void> _messageHandler(RemoteMessage message) async {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    await GetStorage.init();
    _logPushDiagnostic('onBackgroundMessage', _messageLogDetails(message));
    await _trackIncomingChatUnread(
      message,
      includeDirectChat: true,
    );
    final localKey = await _storeNotificationHistory(message);
    FlutterRingtonePlayer().play(
      fromAsset: "assets/sound/beep.mp3",
    );
    if (message.notification == null) {
      final badge = await _currentUnreadNotificationBadge();
      await AwesomeNotifications().createNotification(
        content: _chatNotificationContent(
          message,
          badge: badge,
          localKey: localKey,
        ),
      );
    }
    print(message.data.toString());
  }

  static Future<void> _finishStartupSetup() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: true,
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
        final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        print('APNS Token: $apnsToken');
        await FirebaseMessaging.instance
            .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
        await _reportIosPushSetupStatus();
      }

      final initialMessage =
          await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        _logPushDiagnostic(
          'getInitialMessage',
          _messageLogDetails(initialMessage),
        );
      } else {
        _logPushDiagnostic('getInitialMessage', {'message': 'none'});
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

  static Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(_messageHandler);
    FirebaseFirestore.instance.settings =
        const Settings(persistenceEnabled: false);
    FirebaseFirestore.instance.clearPersistence();

    AwesomeNotifications().initialize(
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

    await AwesomeNotifications().setListeners(
      onActionReceivedMethod: _onAwesomeNotificationActionReceived,
    );

    AwesomeNotifications().isNotificationAllowed().then((isAllowed) {
      if (!isAllowed) {
        AwesomeNotifications().requestPermissionToSendNotifications();
      }
    });

    FirebaseMessaging.onMessage.listen((event) async {
      _logPushDiagnostic('onMessage', _messageLogDetails(event));
      await _trackIncomingChatUnread(
        event,
        includeDirectChat: false,
      );
      final localKey = await _storeNotificationHistory(event);
      FlutterRingtonePlayer().play(
        fromAsset: "assets/sound/beep.mp3",
      );
      showToast(
        _toastMessage(event),
        onTap: () => _openNotification(event, localKey: localKey),
      );
      await _showForegroundSystemNotification(event, localKey: localKey);
      _showMessengerAlert(event, localKey: localKey);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) async {
      _logPushDiagnostic('onMessageOpenedApp', _messageLogDetails(message));
      final localKey = await _storeNotificationHistory(message);
      print(message.data.toString());
      await _openNotification(message, localKey: localKey);
    });
  }

  static Future<void> finishStartupSetup() async {
    await _finishStartupSetup();
  }

  @pragma('vm:entry-point')
  static Future<void> handleBackgroundMessage(RemoteMessage message) async {
    await _messageHandler(message);
  }
}
