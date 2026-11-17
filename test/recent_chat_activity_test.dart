// Snapshot test doubles avoid a Firebase app and live network calls.
// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cnattendance/utils/recent_chat_activity.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Document = QueryDocumentSnapshot<Map<String, dynamic>>;

class _Doc extends Fake implements _Document {
  _Doc(this.value);
  final Map<String, dynamic> value;
  @override
  Map<String, dynamic> data() => value;
}

class _Change extends Fake implements DocumentChange<Map<String, dynamic>> {
  _Change(this.type, this.doc);
  @override
  final DocumentChangeType type;
  @override
  final _Document doc;
}

class _Snapshot extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  _Snapshot(this.docChanges, {this.history});
  @override
  final List<DocumentChange<Map<String, dynamic>>> docChanges;
  final List<_Document>? history;
  @override
  List<_Document> get docs =>
      history ?? (throw StateError('New messages must not scan history'));
}

_Document _message(String username, int second, {bool sent = true}) => _Doc({
      sent ? 'reciever' : 'sender': username,
      'date': Timestamp.fromDate(DateTime.utc(2026, 1, 1, 0, 0, second)),
    });

void main() {
  test('new messages update activity without reading the full history', () {
    final latest = <String, DateTime>{};
    applyRecentChatSnapshot(
        latest,
        _Snapshot([
          _Change(DocumentChangeType.added, _message('Dara', 10)),
          _Change(DocumentChangeType.added, _message('Dara', 5)),
        ]),
        isSent: true);
    applyRecentChatSnapshot(
        latest,
        _Snapshot([
          _Change(DocumentChangeType.added, _message('Sophea', 20)),
        ]),
        isSent: true);
    expect(latest.map((key, value) => MapEntry(key, value.toUtc())), {
      'Dara': DateTime.utc(2026, 1, 1, 0, 0, 10),
      'Sophea': DateTime.utc(2026, 1, 1, 0, 0, 20)
    });
  });

  test('deleting the newest message restores the previous conversation date',
      () {
    final latest = {'Dara': DateTime.utc(2026, 1, 1, 0, 0, 20)};
    applyRecentChatSnapshot(
        latest,
        _Snapshot([
          _Change(DocumentChangeType.removed, _message('Dara', 20)),
        ], history: [
          _message('Dara', 10)
        ]),
        isSent: true);
    expect(latest['Dara']?.toUtc(), DateTime.utc(2026, 1, 1, 0, 0, 10));
  });

  test(
      'modified participants remove stale activity and received messages use sender',
      () {
    final latest = {'Old user': DateTime.utc(2026, 1, 1)};
    applyRecentChatSnapshot(
        latest,
        _Snapshot([
          _Change(DocumentChangeType.modified,
              _message('New user', 10, sent: false)),
        ], history: [
          _message('New user', 10, sent: false)
        ]),
        isSent: false);
    expect(latest.keys, ['New user']);
  });

  test(
      'metadata-only updates leave activity intact and invalid dates are ignored',
      () {
    final latest = {'Dara': DateTime.utc(2026, 1, 1)};
    applyRecentChatSnapshot(latest, _Snapshot([]), isSent: true);
    applyRecentChatSnapshot(
        latest,
        _Snapshot([
          _Change(DocumentChangeType.added,
              _Doc({'reciever': 'Dara', 'date': null})),
          _Change(DocumentChangeType.added, _message('', 10)),
        ]),
        isSent: true);
    expect(latest, {'Dara': DateTime.utc(2026, 1, 1)});
  });
}
