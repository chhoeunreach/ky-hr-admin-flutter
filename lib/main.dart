import 'dart:async';
import 'dart:io';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/model/auth.dart';
import 'package:cnattendance/provider/attendancereportprovider.dart';
import 'package:cnattendance/provider/chatbadgecontroller.dart';
import 'package:cnattendance/provider/dashboardprovider.dart';
import 'package:cnattendance/provider/leaveprovider.dart';
import 'package:cnattendance/provider/morescreenprovider.dart';
import 'package:cnattendance/provider/payslipdetailprovider.dart';
import 'package:cnattendance/provider/payslipprovider.dart';
import 'package:cnattendance/provider/prefprovider.dart';
import 'package:cnattendance/provider/profileprovider.dart';
import 'package:cnattendance/provider/ssfprovider.dart';
import 'package:cnattendance/provider/notificationcontroller.dart';
import 'package:cnattendance/screen/auth/login_screen.dart';
import 'package:cnattendance/screen/dashboard/dashboard_screen.dart';
import 'package:cnattendance/screen/general/generalscreen.dart';
import 'package:cnattendance/screen/profile/admin_chat_thread_screen.dart';
import 'package:cnattendance/screen/profile/chatscreen.dart';
import 'package:cnattendance/screen/profile/editprofilescreen.dart';
import 'package:cnattendance/screen/profile/groupchatscreen.dart';
import 'package:cnattendance/screen/profile/payslipdetailscreen.dart';
import 'package:cnattendance/screen/profile/profilescreen.dart';
import 'package:cnattendance/screen/profile/meetingdetailscreen.dart';
import 'package:cnattendance/screen/splashscreen.dart';
import 'package:cnattendance/utils/app_badge_sync.dart';
import 'package:cnattendance/utils/chat_unread_store.dart';
import 'package:cnattendance/utils/chat/notification_payload_parser.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:cnattendance/utils/incoming_chat_listener.dart';
import 'package:cnattendance/utils/navigationservice.dart';
import 'package:cnattendance/utils/notification_history.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_mentions/flutter_mentions.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'package:in_app_notification/in_app_notification.dart';
import 'package:flutter_translate/flutter_translate.dart';

String _messageTitle(RemoteMessage message) {
  return message.notification?.title ??
      message.data["notification_title"] ??
      message.data["sender_name"] ??
      message.data["title"] ??
      message.data["subject"] ??
      "Notification";
}

String _messageBody(RemoteMessage message) {
  return message.notification?.body ??
      message.data["message"] ??
      message.data["body"] ??
      message.data["description"] ??
      message.data["content"] ??
      "";
}

String _messageAvatar(RemoteMessage message) {
  return message.data["sender_image"] ?? "";
}

bool _hasValidRemoteUrl(String? value) {
  if (value == null) {
    return false;
  }

  final uri = Uri.tryParse(value.trim());
  return uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty;
}

String _maskToken(String? token) {
  if (token == null || token.trim().isEmpty) {
    return 'missing';
  }

  final trimmed = token.trim();
  if (trimmed.length <= 12) {
    return trimmed;
  }

  return '${trimmed.substring(0, 6)}...${trimmed.substring(trimmed.length - 6)}';
}

void _logPushDiagnostic(String label,
    [Map<String, Object?> details = const {}]) {
  final buffer = StringBuffer('[PUSH] $label');
  details.forEach((key, value) {
    buffer.write(' | $key=$value');
  });
  print(buffer.toString());
}

String _authorizationStatusLabel(AuthorizationStatus status) {
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

Map<String, Object?> _messageLogDetails(RemoteMessage message) {
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

Future<void> _reportIosPushSetupStatus() async {
  try {
    final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
    final fcmToken = await FirebaseMessaging.instance.getToken();
    final settings = await FirebaseMessaging.instance.getNotificationSettings();

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

    // Overlay-based toasts are not safe before runApp() mounts the widget tree.
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

Map<String, String> _notificationPayload(
  RemoteMessage message, {
  String? localKey,
}) {
  return ChatNotificationPayload.fromData(
    message.data,
    title: _messageTitle(message),
    message: _messageBody(message),
  ).toMap(localKey: localKey ?? "");
}

Future<int?> _currentUnreadNotificationBadge() async {
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

NotificationContent _chatNotificationContent(
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

String _toastMessage(RemoteMessage message) {
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

Future<void> _openNotificationFromPayload(Map<String, String?> payload) async {
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

bool _isAdminThreadPayload(Map<String, String?> payload) {
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

bool _parseBoolLike(dynamic value) {
  if (value == null) return false;
  final v = value.toString().trim().toLowerCase();
  return v == '1' || v == 'true' || v == 'yes';
}

Future<void> _showForegroundSystemNotification(
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

Future<void> _syncUnreadBadgeFromStorage() async {
  await AppBadgeSync.sync();
}

String _chatConversationId(RemoteMessage message) {
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

String _chatMessageKey(RemoteMessage message) {
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

Future<void> _trackIncomingChatUnread(
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

Future<String?> _storeNotificationHistory(RemoteMessage message) async {
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

Future<void> _openNotification(
  RemoteMessage message, {
  String? localKey,
}) async {
  final resolvedLocalKey = localKey ?? await _storeNotificationHistory(message);
  await _openNotificationFromPayload(
    _notificationPayload(message, localKey: resolvedLocalKey),
  );
}

@pragma('vm:entry-point')
Future<void> _onAwesomeNotificationActionReceived(
    ReceivedAction receivedAction) async {
  await _openNotificationFromPayload(receivedAction.payload ?? {});
}

void _showMessengerAlert(
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    var delegate = await LocalizationDelegate.create(
        fallbackLocale: 'en_US',
        supportedLocales: [
          'en_US',
          'ar',
          'es',
          'ne',
          'fa',
          'in',
          'km',
          'pt',
          'ru',
          'de',
          'tr',
          'fr'
        ]);

    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    await GetStorage.init();
    ChatBadgeController.ensureRegistered();

    FirebaseMessaging.onBackgroundMessage(_messageHandler);
    FirebaseFirestore.instance.settings = Settings(persistenceEnabled: false);
    FirebaseFirestore.instance.clearPersistence();

    if (Platform.isAndroid) {
      await FlutterDisplayMode.setHighRefreshRate();
    }

    AwesomeNotifications().initialize(
        'resource://drawable/app_icon',
        [
          NotificationChannel(
              channelGroupKey: 'digital_hr_group',
              channelKey: 'digital_hr_channel',
              channelName: 'Digital Hr notifications',
              channelDescription: 'Digital HR Alert',
              channelShowBadge: true,
              defaultColor: Color(0xFF9D50DD),
              ledColor: Colors.white)
        ],
        channelGroups: [
          NotificationChannelGroup(
              channelGroupKey: 'digital_hr_group', channelGroupName: 'HR group')
        ],
        debug: true);

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

    runApp(LocalizedApp(delegate, MyApp()));
    Future.microtask(() => IncomingChatListener.instance.start());
    unawaited(_finishStartupSetup());
    configLoading();
  } catch (error, stackTrace) {
    debugPrint('App startup failed: $error');
    debugPrintStack(stackTrace: stackTrace);
    runApp(_StartupErrorApp(error: error.toString()));
  }
}

Future<void> _finishStartupSetup() async {
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
      'authorization': _authorizationStatusLabel(settings.authorizationStatus),
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

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
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

Future<void> _messageHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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

void configLoading() {
  EasyLoading.instance
    ..indicatorType = EasyLoadingIndicatorType.cubeGrid
    ..loadingStyle = EasyLoadingStyle.dark
    ..indicatorSize = 50.0
    ..radius = 0.0
    ..progressColor = Colors.blue
    ..backgroundColor = Colors.white
    ..indicatorColor = Colors.blue
    ..textColor = Colors.black
    ..maskType = EasyLoadingMaskType.none
    ..userInteractions = false
    ..dismissOnTap = false;
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    ChatBadgeController.ensureRegistered();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ChatBadgeController.ensureRegistered().refreshUnreadCount();
      if (Get.isRegistered<NotificationController>()) {
        final controller = Get.find<NotificationController>();
        controller.syncLocalNotificationState();
      } else {
        AppBadgeSync.sync();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var localizationDelegate = LocalizedApp.of(context).delegate;
    final storage = GetStorage();

    return OverlaySupport.global(
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (ctx) => Auth(),
          ),
          ChangeNotifierProvider(
            create: (ctx) => Preferences(),
          ),
          ChangeNotifierProvider(
            create: (ctx) => LeaveProvider(),
          ),
          ChangeNotifierProvider(
            create: (ctx) => PrefProvider(),
          ),
          ChangeNotifierProvider(
            create: (ctx) => ProfileProvider(),
          ),
          ChangeNotifierProvider(
            create: (ctx) => AttendanceReportProvider(),
          ),
          ChangeNotifierProvider(
            create: (ctx) => DashboardProvider(),
          ),
          ChangeNotifierProvider(
            create: (ctx) => MoreScreenProvider(),
          ),
          ChangeNotifierProvider(
            create: (ctx) => PaySlipProvider(),
          ),
          ChangeNotifierProvider(
            create: (ctx) => PaySlipDetailProvider(),
          ),
          ChangeNotifierProvider(
            create: (ctx) => SSFProvider(),
          ),
        ],
        child: Portal(
          child: InAppNotification(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                // Dismiss the keyboard when tapping outside the TextField
                FocusScope.of(context).requestFocus();
              },
              child: LocalizationProvider(
                state: LocalizationProvider.of(context).state,
                child: GetMaterialApp(
                  navigatorKey: NavigationService.navigatorKey,
                  debugShowCheckedModeBanner: false,
                  localizationsDelegates: [
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                    localizationDelegate
                  ],
                  supportedLocales: localizationDelegate.supportedLocales,
                  locale: Locale(storage.read("language") ?? "en"),
                  theme: ThemeData(
                      canvasColor: const Color.fromRGBO(255, 255, 255, 1),
                      fontFamily: 'GoogleSans',
                      primarySwatch: Colors.blue,
                      brightness: Brightness.dark,
                      elevatedButtonTheme: ElevatedButtonThemeData(
                          style: ElevatedButton.styleFrom(
                              textStyle: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontFamily: "GoogleSans"))),
                      appBarTheme: AppBarTheme(
                          actionsIconTheme: IconThemeData(color: Colors.white),
                          iconTheme: IconThemeData(color: Colors.white),
                          titleTextStyle: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontFamily: "GoogleSans"))),
                  initialRoute: '/',
                  routes: {
                    '/': (_) => SplashScreen(),
                    LoginScreen.routeName: (_) => LoginScreen(),
                    DashboardScreen.routeName: (_) => DashboardScreen(),
                    ProfileScreen.routeName: (_) => ProfileScreen(),
                    EditProfileScreen.routeName: (_) => EditProfileScreen(),
                    MeetingDetailScreen.routeName: (_) => MeetingDetailScreen(),
                    PaySlipDetailScreen.routeName: (_) => PaySlipDetailScreen(),
                  },
                  builder: EasyLoading.init(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 56,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 16),
                const Text(
                  'App failed to start',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  error,
                  style: const TextStyle(color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
