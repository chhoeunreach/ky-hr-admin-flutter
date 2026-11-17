import 'dart:async';
import 'package:cnattendance/model/chat_contact.dart';
import 'package:cnattendance/provider/teamsheetprovider.dart';
import 'package:cnattendance/repositories/teamsheetrepository.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repository extends TeamSheetRepository {
  final List<Completer<ChatContactsPayload>> requests = [];
  @override
  Future<ChatContactsPayload> getChatContacts() {
    final request = Completer<ChatContactsPayload>();
    requests.add(request);
    return request.future;
  }
}

ChatContactsPayload _payload() => ChatContactsPayload(
      contacts: [
        ChatContact.fromJson({'username': 'Dara'})
      ],
      onlineContacts: [
        ChatContact.fromJson({'username': 'Dara'})
      ],
    );

void main() {
  test(
      'concurrent contact loads share one request and notify once with both lists',
      () async {
    final repository = _Repository();
    final provider = TeamSheetProvider()..repository = repository;
    addTearDown(provider.dispose);
    var updates = 0;
    provider.addListener(() {
      updates++;
      expect(provider.chatContacts, hasLength(1));
      expect(provider.onlineChatContacts, hasLength(1));
    });
    final first = provider.getChatContacts();
    final second = provider.getChatContacts();
    expect(identical(first, second), isTrue);
    repository.requests.single.complete(_payload());
    await Future.wait([first, second]);
    expect(updates, 1);
  });

  test('failed contact requests can retry', () async {
    final repository = _Repository();
    final provider = TeamSheetProvider()..repository = repository;
    addTearDown(provider.dispose);
    final pending = provider.getChatContacts();
    final expectation = expectLater(pending, throwsStateError);
    repository.requests.first.completeError(StateError('Offline'));
    await expectation;
    final retry = provider.getChatContacts();
    repository.requests.last.complete(_payload());
    await retry;
    expect(repository.requests, hasLength(2));
  });

  test('contact completion after closing its provider does not update lists',
      () async {
    final repository = _Repository();
    final provider = TeamSheetProvider()..repository = repository;
    final pending = provider.getChatContacts();
    provider.dispose();
    repository.requests.single.complete(_payload());
    await pending;
    expect(provider.chatContacts, isEmpty);
  });
}
