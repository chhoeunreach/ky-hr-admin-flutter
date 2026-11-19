import 'package:cnattendance/services/push_notification_service.dart';
import 'package:cnattendance/utils/notification_history.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';

import 'helpers/chat_storage_test_env.dart';

void main() {
  setUpAll(ChatStorageTestEnv.install);
  tearDownAll(ChatStorageTestEnv.uninstall);
  setUp(() => GetStorage().erase());

  Future<({String? key, bool isNew})> store(RemoteMessage message) =>
      NotificationHistory.saveRemoteMessage(
        message,
        title: 'Attendance notice',
        body: 'The office opens at 8.',
      );

  test('repeated FCM delivery preserves the original history and read state',
      () async {
    const message = RemoteMessage(messageId: 'delivery-1');
    final first = await store(message);
    expect(first.isNew, isTrue);
    await NotificationHistory.markAsRead(first.key!);

    expect(await store(message), (key: first.key, isNew: false));
    expect(await NotificationHistory.getUnreadCount(), 0);
  });

  test('resends share the event ID while similar notices remain separate',
      () async {
    const first = RemoteMessage(
      messageId: 'delivery-1',
      data: {'notification_event_id': 'notice-1'},
    );
    const resend = RemoteMessage(
      messageId: 'delivery-2',
      data: {'notification_event_id': 'notice-1'},
    );
    const next = RemoteMessage(
      messageId: 'delivery-3',
      data: {'notification_event_id': 'notice-2'},
    );
    expect((await store(first)).isNew, isTrue);
    expect(await store(resend), (key: 'event:notice-1', isNew: false));
    expect((await store(next)).isNew, isTrue);
    expect(await NotificationHistory.getUnreadCount(), 2);
  });

  test('the OS owns visible background pushes and visible iOS pushes', () {
    const alert = RemoteMessage(notification: RemoteNotification(title: 'HR'));
    const dataOnly = RemoteMessage(data: {'title': 'HR'});
    for (final isIOS in [false, true]) {
      for (final isForeground in [false, true]) {
        expect(
          PushNotificationService.systemPresentsRemoteMessage(
            alert,
            isIOS: isIOS,
            isForeground: isForeground,
          ),
          isIOS || !isForeground,
        );
        expect(
          PushNotificationService.systemPresentsRemoteMessage(
            dataOnly,
            isIOS: isIOS,
            isForeground: isForeground,
          ),
          isFalse,
        );
      }
    }
  });

  test('only explicit update metadata triggers an update prompt', () {
    expect(
      PushNotificationService.isAppUpdatePayload(
        {'type': 'chat', 'title': 'Payroll update', 'target_version': ''},
      ),
      isFalse,
    );
    expect(
      PushNotificationService.isAppUpdatePayload({'action': 'app_update'}),
      isTrue,
    );
    expect(
      PushNotificationService.isAppUpdatePayload({'latest_version': '1.4.0'}),
      isTrue,
    );
  });
}
