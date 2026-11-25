import 'package:cnattendance/repositories/teamsheetrepository.dart';

const chatAlertFallbackTitle = 'KNEAYERNG Chat';

String? chatSenderDisplayName(
  Iterable<Object?> candidates, {
  required String username,
}) {
  final login = username.trim().toLowerCase();
  for (final candidate in candidates.whereType<String>()) {
    final name = candidate.trim();
    if (name.isNotEmpty && name.toLowerCase() != login) return name;
  }
  return null;
}

Future<String> incomingChatSenderName({
  required String username,
  required Object? savedName,
  TeamSheetRepository? repository,
}) async {
  final name = chatSenderDisplayName([savedName], username: username);
  if (name != null) return name;

  try {
    final directory = await (repository ?? TeamSheetRepository())
        .getChatContacts()
        .timeout(const Duration(seconds: 3));
    final candidates = [
      for (final contact in [
        ...directory.contacts,
        ...directory.onlineContacts
      ])
        if (!contact.usesAdminThread && contact.username.trim() == username)
          contact.name,
    ];
    return chatSenderDisplayName(candidates, username: username) ??
        chatAlertFallbackTitle;
  } catch (_) {
    return chatAlertFallbackTitle;
  }
}
