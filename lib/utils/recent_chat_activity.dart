import 'package:cloud_firestore/cloud_firestore.dart';

/// Update conversation activity without rescanning history for each new message.
/// Edits and deletions rebuild the per-contact maximum to retain exact ordering.
void applyRecentChatSnapshot(
  Map<String, DateTime> latest,
  QuerySnapshot<Map<String, dynamic>> snapshot, {
  required bool isSent,
}) {
  final changes = snapshot.docChanges;
  if (changes.isEmpty) return;
  final rebuild =
      changes.any((change) => change.type != DocumentChangeType.added);
  if (rebuild) latest.clear();
  final documents =
      rebuild ? snapshot.docs : changes.map((change) => change.doc);
  for (final document in documents) {
    final data = document.data();
    final username =
        (data?[isSent ? 'reciever' : 'sender'] ?? '').toString().trim();
    final timestamp = data?['date'];
    if (username.isEmpty || timestamp is! Timestamp) continue;
    final date = timestamp.toDate();
    final previous = latest[username];
    if (previous == null || date.isAfter(previous)) latest[username] = date;
  }
}
