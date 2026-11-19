import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/utils/chat_unread_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/chat_storage_test_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('logout stays a safe no-op before storage is ready', () async {
    SharedPreferences.setMockInitialValues({'user_name': 'Dara'});
    expect(ChatUnreadStore.isStorageReady, isFalse);

    await Preferences().clearPrefs();

    expect(ChatUnreadStore.isStorageReady, isFalse);
    expect(await ChatUnreadStore.getTotalUnreadCount(), 0);
  });

  group('with storage ready', () {
    setUpAll(ChatStorageTestEnv.install);
    tearDownAll(ChatStorageTestEnv.uninstall);

    test('clearPrefs wipes stored chat unread counts', () async {
      SharedPreferences.setMockInitialValues({});
      expect(
        await ChatUnreadStore.addUnreadMessage(
          conversationId: 'alicebob',
          messageKey: 'push:1',
        ),
        isTrue,
      );
      expect(await ChatUnreadStore.getTotalUnreadCount(), 1);

      await Preferences().clearPrefs();

      expect(await ChatUnreadStore.getTotalUnreadCount(), 0);
      expect(await ChatUnreadStore.getAllCounts(), isEmpty);
    });
  });
}
