import 'package:cnattendance/provider/chatbadgecontroller.dart';
import 'package:cnattendance/utils/chat_unread_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'helpers/chat_storage_test_env.dart';

void main() {
  late ChatBadgeController badge;

  setUpAll(() async {
    await ChatStorageTestEnv.install();
    badge = Get.put(ChatBadgeController(), permanent: true);
  });

  tearDownAll(() async {
    Get.reset();
    await ChatStorageTestEnv.uninstall();
  });

  setUp(() async {
    await ChatUnreadStore.clearAll();
    badge.unreadCount.value = 0;
    badge.conversationCounts.clear();
    badge.activeConversationId.value = null;
  });

  test('conversationUnread sums matching keys and skips empty ids', () {
    badge.conversationCounts.assignAll({
      'admin:7': 2,
      'group_5': 3,
      'alicebob': 1,
    });
    expect(
      badge.conversationUnread([
        'admin:7',
        'group_5',
        'alicebob',
        '',
        '  ',
        'missing',
      ]),
      6,
    );
  });

  test('incoming message is ignored while the conversation is open', () async {
    badge.activeConversationId.value = 'openroom';
    expect(
      await badge.handleIncomingMessage(
        conversationId: 'openroom',
        messageKey: 'push:open-1',
      ),
      isFalse,
    );
    expect(await ChatUnreadStore.getConversationUnreadCount('openroom'), 0);
    expect(badge.unreadCount.value, 0);
  });

  test('incoming message increments the badge and deduplicates keys',
      () async {
    badge.activeConversationId.value = 'otherroom';
    expect(
      await badge.handleIncomingMessage(
        conversationId: 'hotroom',
        messageKey: 'push:hot-1',
        title: 'Dara',
      ),
      isTrue,
    );
    expect(badge.unreadCount.value, 1);
    expect(badge.conversationCounts['hotroom'], 1);

    expect(
      await badge.handleIncomingMessage(
        conversationId: 'hotroom',
        messageKey: 'push:hot-1',
        title: 'Dara',
      ),
      isFalse,
    );
    expect(badge.unreadCount.value, 1);
    expect(badge.conversationCounts['hotroom'], 1);
  });

  test('marking the conversation read clears it from the badge', () async {
    await badge.handleIncomingMessage(
      conversationId: 'hotroom',
      messageKey: 'push:hot-1',
    );
    expect(badge.unreadCount.value, 1);

    expect(await badge.markConversationAsRead('hotroom'), 1);
    expect(badge.unreadCount.value, 0);
    expect(badge.conversationCounts.containsKey('hotroom'), isFalse);
  });

  test('ensureRegistered reuses the live controller', () {
    expect(identical(ChatBadgeController.ensureRegistered(), badge), isTrue);
  });
}
