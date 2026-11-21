import 'package:cnattendance/model/chat_contact.dart';
import 'package:cnattendance/repositories/teamsheetrepository.dart';
import 'package:cnattendance/services/push_notification_service.dart';
import 'package:cnattendance/utils/chat/chat_sender_name.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';

class _Directory extends TeamSheetRepository {
  int calls = 0;

  @override
  Future<ChatContactsPayload> getChatContacts() async {
    calls++;
    return ChatContactsPayload(
      contacts: [
        ChatContact.fromJson({'username': 'rath', 'name': 'Rath Sok'}),
      ],
      onlineContacts: [
        ChatContact.fromJson({'username': 'dara', 'name_khmer': 'សុខ ដារ៉ា'}),
      ],
    );
  }
}

void main() {
  test('incoming message uses the saved full name without a directory request',
      () async {
    final directory = _Directory();
    final name = await incomingChatSenderName(
      username: 'dara',
      savedName: ' Dara Sok ',
      repository: directory,
    );
    expect(name, 'Dara Sok');
    expect(directory.calls, 0);
  });

  test('legacy message looks up the name and uses a generic title if missing',
      () async {
    final directory = _Directory();
    final name = await incomingChatSenderName(
      username: 'dara',
      savedName: 'DARA',
      repository: directory,
    );
    expect(name, 'សុខ ដារ៉ា');
    expect(directory.calls, 1);

    final missing = await incomingChatSenderName(
      username: 'missing',
      savedName: null,
      repository: directory,
    );
    expect(missing, chatAlertFallbackTitle);
  });

  test('push uses the full name even when the system title is the username',
      () {
    final message = RemoteMessage(
      data: {
        'type': 'chat',
        'sender_username': 'dara',
        'sender_name': 'សុខ ដារ៉ា',
      },
      notification: const RemoteNotification(title: 'dara'),
    );
    expect(PushNotificationService.notificationTitleFor(message), 'សុខ ដារ៉ា');
  });

  test('push uses the request title when sender_name contains the login', () {
    final message = RemoteMessage(
      data: {
        'type': 'chat',
        'sender_username': 'dara',
        'sender_name': 'dara',
        'title': 'Dara Sok',
      },
      notification: const RemoteNotification(title: 'DARA'),
    );
    expect(PushNotificationService.notificationTitleFor(message), 'Dara Sok');
  });

  test('push with only the login uses the generic chat title', () {
    final message = RemoteMessage(
      data: {'type': 'chat', 'sender_username': 'dara', 'sender_name': 'dara'},
      notification: const RemoteNotification(title: 'DARA'),
    );
    expect(
      PushNotificationService.notificationTitleFor(message),
      chatAlertFallbackTitle,
    );
  });
}
