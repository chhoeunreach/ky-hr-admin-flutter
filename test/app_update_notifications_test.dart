import 'package:cnattendance/screen/general/generalscreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';
import 'package:cnattendance/data/source/network/model/dashboard/Dashboard.dart';
import 'package:cnattendance/data/source/network/model/notification/NotifiactionDomain.dart';
import 'package:cnattendance/utils/app_update_payload.dart';
import 'package:cnattendance/utils/notification_history.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/chat_storage_test_env.dart';

void main() {
  const android = 'https://downloads.example/hr.apk?release=14';
  const ios = 'https://apps.apple.com/app/example/id123';
  const metadata = {
    'android_url': android,
    'ios_url': ios,
    'target_version': '14.0',
    'min_required_version': '13.5',
    'force_update': false,
  };

  setUpAll(ChatStorageTestEnv.install);
  tearDownAll(ChatStorageTestEnv.uninstall);

  test('preserves the saved Android and iOS URLs from the inbox API', () {
    final notification = NotifiactionDomain.fromJson({
      'id': 42,
      'type': 'app_update',
      'notification_title': 'version 14 notice',
      'description': 'Install version 14.\nFrom HR.',
      'description_html': 'Install version 14.<br>From HR.',
      'app_update': metadata,
    });
    expect(notification.notificationTitle, 'version 14 notice');
    expect(notification.description, 'Install version 14.\nFrom HR.');
    expect(
        configuredAppUpdateUri(notification.appUpdate, isIOS: false).toString(),
        android);
    expect(
        configuredAppUpdateUri(notification.appUpdate, isIOS: true).toString(),
        ios);
    expect(isForcedAppUpdate(notification.appUpdate, '13.4'), isTrue);
    expect(isForcedAppUpdate(notification.appUpdate, '13.5'), isFalse);
  });

  test('keeps the configured download URL after a push is saved and reloaded',
      () async {
    SharedPreferences.setMockInitialValues({});
    await GetStorage().erase();
    await NotificationHistory.saveRemoteMessage(
      const RemoteMessage(
        messageId: 'update-42',
        data: {...metadata, 'type': 'app_update', 'notification_id': '42'},
      ),
      title: 'version 14 notice',
      body: 'Install version 14.',
    );
    final notification =
        (await NotificationHistory.loadStoredNotifications()).single;
    expect(notification.id, 42);
    expect(notification.type, 'app_update');
    expect(
        configuredAppUpdateUri(notification.appUpdate, isIOS: false).toString(),
        android);
  });

  test('keeps server version-check controls and ignores invalid schemes', () {
    final version = AppVersionInfo.fromJson({
      ...metadata,
      'version_check_enabled': false,
    });
    expect(version.versionCheckEnabled, isFalse);
    expect(version.downloadUrl, android);
    expect(
        configuredAppUpdateUri({'android_url': 'javascript:alert(1)'},
            isIOS: false),
        isNull);
    expect(
        isAppUpdateNotification({'type': 'general'},
            legacyText: 'Payroll update'),
        isFalse);
  });

  testWidgets('Update Now opens the exact Android URL from the notification',
      (tester) async {
    Localization.load({
      'app_update': {'update_now': 'Update Now'},
    });
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    String? launchedUrl;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'launch')
        launchedUrl = call.arguments['url'] as String;
      return true;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      Get.reset();
    });

    await tester.pumpWidget(GetMaterialApp(
      home: Scaffold(
        body: TextButton(
          onPressed: () => Get.to(() => GeneralScreen(), arguments: {
            'type': 'app_update',
            'title': 'version 14 notice',
            'message': 'Install version 14.',
            ...metadata,
          }),
          child: const Text('Open notification'),
        ),
      ),
    ));
    await tester.tap(find.text('Open notification'));
    await tester.pumpAndSettle();
    expect(find.text('version 14 notice'), findsOneWidget);
    expect(find.text('downloads.example'), findsOneWidget);

    await tester.tap(find.text('Update Now'));
    await tester.pumpAndSettle();
    expect(launchedUrl, android);
  });
}
