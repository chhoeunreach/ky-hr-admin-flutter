import 'package:cnattendance/services/push_notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('message key prefers the FCM message id for deduplication', () {
    final message = RemoteMessage(
      messageId: 'id-1',
      data: {'type': 'chat', 'conversation_id': 'alicebob'},
    );
    expect(PushNotificationService.chatMessageKeyFor(message), 'push:id-1');
  });

  test('message key falls back to a stable composite when no id exists', () {
    RemoteMessage build() => RemoteMessage(
          data: {
            'type': 'chat',
            'conversation_id': 'alicebob',
            'sender_username': 'alice',
            'body': 'hi',
          },
        );
    final first = PushNotificationService.chatMessageKeyFor(build());
    final second = PushNotificationService.chatMessageKeyFor(build());
    expect(first, second);
    expect(first, 'push:chat|alicebob|alice||hi');
  });

  test('conversation id comes from the payload', () {
    final message = RemoteMessage(
      data: {'type': 'chat', 'conversation_id': 'alicebob'},
    );
    expect(PushNotificationService.chatConversationIdFor(message), 'alicebob');

    final missing = RemoteMessage(data: {'type': 'chat'});
    expect(PushNotificationService.chatConversationIdFor(missing), '');
  });

  test(
      'tracking gate counts group chats always and direct chat only when included',
      () {
    RemoteMessage typed(String type) => RemoteMessage(data: {'type': type});

    expect(
      PushNotificationService.shouldTrackChatUnread(
        typed('group_chat'),
        includeDirectChat: false,
      ),
      isTrue,
    );
    expect(
      PushNotificationService.shouldTrackChatUnread(
        typed('group_chat'),
        includeDirectChat: true,
      ),
      isTrue,
    );
    expect(
      PushNotificationService.shouldTrackChatUnread(
        typed('chat'),
        includeDirectChat: false,
      ),
      isFalse,
    );
    expect(
      PushNotificationService.shouldTrackChatUnread(
        typed('chat'),
        includeDirectChat: true,
      ),
      isTrue,
    );
    expect(
      PushNotificationService.shouldTrackChatUnread(
        typed('notice'),
        includeDirectChat: true,
      ),
      isFalse,
    );
    expect(
      PushNotificationService.shouldTrackChatUnread(
        RemoteMessage(),
        includeDirectChat: true,
      ),
      isFalse,
    );
  });
}
