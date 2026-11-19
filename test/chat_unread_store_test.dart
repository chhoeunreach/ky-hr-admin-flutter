import 'package:cnattendance/utils/chat_unread_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/chat_storage_test_env.dart';

void main() {
  test('every call is a safe no-op before storage is ready', () async {
    expect(ChatUnreadStore.isStorageReady, isFalse);
    expect(
      await ChatUnreadStore.addUnreadMessage(
        conversationId: 'alicebob',
        messageKey: 'push:1',
      ),
      isFalse,
    );
    expect(await ChatUnreadStore.getTotalUnreadCount(), 0);
    expect(await ChatUnreadStore.getConversationUnreadCount('alicebob'), 0);
    expect(await ChatUnreadStore.getAllCounts(), isEmpty);
    expect(await ChatUnreadStore.markConversationAsRead('alicebob'), 0);
    expect(
      await ChatUnreadStore.markMessageAsRead(
        conversationId: 'alicebob',
        messageKey: 'push:1',
      ),
      0,
    );
    expect(
      await ChatUnreadStore.markMessagesAsRead(
        conversationId: 'alicebob',
        messageKeys: ['push:1'],
      ),
      0,
    );
    await ChatUnreadStore.clearAll();
    expect(ChatUnreadStore.isStorageReady, isFalse);
  });

  group('with initialized storage', () {
    setUpAll(ChatStorageTestEnv.install);
    tearDownAll(ChatStorageTestEnv.uninstall);

    setUp(() async {
      await ChatUnreadStore.clearAll();
    });

    test('counts messages per conversation and deduplicates keys', () async {
      expect(
        await ChatUnreadStore.addUnreadMessage(
          conversationId: 'alicebob',
          messageKey: 'push:1',
          title: 'Alice',
        ),
        isTrue,
      );
      expect(
        await ChatUnreadStore.addUnreadMessage(
          conversationId: 'alicebob',
          messageKey: 'push:1',
          title: 'Alice',
        ),
        isFalse,
      );
      expect(
        await ChatUnreadStore.addUnreadMessage(
          conversationId: 'group_5',
          messageKey: 'push:2',
        ),
        isTrue,
      );
      expect(await ChatUnreadStore.getConversationUnreadCount('alicebob'), 1);
      expect(await ChatUnreadStore.getTotalUnreadCount(), 2);
      expect(await ChatUnreadStore.getAllCounts(), {
        'alicebob': 1,
        'group_5': 1,
      });
    });

    test('markMessagesAsRead removes only the listed keys', () async {
      await ChatUnreadStore.addUnreadMessage(
        conversationId: 'alicebob',
        messageKey: 'firestore:a',
      );
      await ChatUnreadStore.addUnreadMessage(
        conversationId: 'alicebob',
        messageKey: 'push:b',
      );

      expect(
        await ChatUnreadStore.markMessagesAsRead(
          conversationId: 'alicebob',
          messageKeys: ['firestore:a'],
        ),
        1,
      );
      expect(await ChatUnreadStore.getConversationUnreadCount('alicebob'), 1);

      expect(
        await ChatUnreadStore.markMessagesAsRead(
          conversationId: 'alicebob',
          messageKeys: ['push:b', 'missing-key'],
        ),
        1,
      );
      expect(await ChatUnreadStore.getConversationUnreadCount('alicebob'), 0);
      expect(await ChatUnreadStore.getAllCounts(), isEmpty);
    });

    test('markConversationAsRead reports the removed count', () async {
      await ChatUnreadStore.addUnreadMessage(
        conversationId: 'alicebob',
        messageKey: 'push:1',
      );
      await ChatUnreadStore.addUnreadMessage(
        conversationId: 'alicebob',
        messageKey: 'push:2',
      );

      expect(await ChatUnreadStore.markConversationAsRead('alicebob'), 2);
      expect(await ChatUnreadStore.markConversationAsRead('alicebob'), 0);
      expect(await ChatUnreadStore.getTotalUnreadCount(), 0);
    });

    test('clearAll resets every conversation', () async {
      await ChatUnreadStore.addUnreadMessage(
        conversationId: 'alicebob',
        messageKey: 'push:1',
      );
      await ChatUnreadStore.addUnreadMessage(
        conversationId: 'group_5',
        messageKey: 'push:2',
      );
      expect(await ChatUnreadStore.getTotalUnreadCount(), 2);

      await ChatUnreadStore.clearAll();
      expect(await ChatUnreadStore.getTotalUnreadCount(), 0);
      expect(await ChatUnreadStore.getAllCounts(), isEmpty);
    });
  });
}
