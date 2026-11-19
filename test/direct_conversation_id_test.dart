import 'package:cnattendance/utils/chat/direct_conversation_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String legacyControllerId(String user1, String user2) {
    final result = user1.compareTo(user2);
    if (result < 0) {
      return user1 + user2;
    } else if (result > 0) {
      return user2 + user1;
    } else {
      return user1 + user2;
    }
  }

  test('both participants derive the same conversation id', () {
    expect(
      directConversationId('alice', 'bob'),
      directConversationId('bob', 'alice'),
    );
    expect(
      directConversationId('KY0021', 'KY0007'),
      directConversationId('KY0007', 'KY0021'),
    );
  });

  test('matches the ChatController ordering for every input order', () {
    const pairs = [
      ('alice', 'bob'),
      ('bob', 'alice'),
      ('KY001', 'KY002'),
      ('KY002', 'KY001'),
      ('same', 'same'),
    ];
    for (final (a, b) in pairs) {
      expect(directConversationId(a, b), legacyControllerId(a, b));
    }
  });

  test('identical usernames produce the doubled id', () {
    expect(directConversationId('dara', 'dara'), 'daradara');
  });
}
