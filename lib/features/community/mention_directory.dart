import 'package:cnattendance/model/chat_contact.dart';
import 'package:cnattendance/repositories/teamsheetrepository.dart';

/// One row shown in the @ mention suggestions.
class MentionSuggestion {
  const MentionSuggestion({
    required this.id,
    required this.name,
    this.department = '',
    this.avatar = '',
    this.isEveryone = false,
  });

  final String id;
  final String name;
  final String department;
  final String avatar;
  final bool isEveryone;
}

/// Session-wide cache of employee names used for @ mention autocomplete in the
/// post composer and comment box, and for highlighting mentions when rendering
/// posts and comments. Loaded lazily on first use and reused everywhere.
class MentionDirectory {
  MentionDirectory._();

  static const int maxSuggestions = 8;

  static Future<void>? _loading;
  static bool _loaded = false;
  static List<ChatContact> _contacts = const [];
  static List<String>? _sortedNames;

  /// When set, [ensureLoaded] resolves from this list instead of the contacts
  /// API. Used by tests so they never touch the network.
  static List<ChatContact>? debugOverride;

  /// True once a load attempt has finished (even if it failed and the list is
  /// empty), so renderers know whether fallback matching is still needed.
  static bool get isLoaded => _loaded;

  static Future<void> ensureLoaded() {
    if (_loaded) return Future.value();
    return _loading ??= _load();
  }

  static Future<void> _load() async {
    final override = debugOverride;
    if (override != null) {
      _contacts = override;
      _loaded = true;
      _sortedNames = null;
      return;
    }
    try {
      final payload = await TeamSheetRepository().getChatContacts();
      final seen = <String>{};
      final merged = <ChatContact>[
        ...payload.contacts,
        ...payload.onlineContacts,
      ];
      _contacts = [
        for (final contact in merged)
          if (contact.name.trim().isNotEmpty &&
              seen.add(contact.id.isNotEmpty ? contact.id : contact.name))
            contact,
      ];
    } catch (_) {
      _contacts = const [];
    }
    _loaded = true;
    _sortedNames = null;
  }

  /// Employee names sorted longest first so rendering can match the longest
  /// possible name at an @ position.
  static List<String> get names => _sortedNames ??= [
        for (final contact in _contacts) contact.name
      ]..sort((a, b) => b.length.compareTo(a.length));

  /// Suggestions for an active @ query: `everyone` first, then employees whose
  /// name contains [typed] (case-insensitive), capped at [maxSuggestions].
  static List<MentionSuggestion> query(String typed) {
    final value = typed.trim().toLowerCase();
    final rows = <MentionSuggestion>[];
    const everyone = 'everyone';
    if (value.isEmpty || everyone.contains(value)) {
      rows.add(const MentionSuggestion(
          id: 'everyone', name: 'Everyone', isEveryone: true));
    }
    for (final contact in _contacts) {
      if (rows.length > maxSuggestions) break;
      if (value.isEmpty || contact.name.toLowerCase().contains(value)) {
        rows.add(MentionSuggestion(
          id: contact.id,
          name: contact.name,
          department: contact.department,
          avatar: contact.avatar,
        ));
      }
    }
    if (rows.length > maxSuggestions + 1) {
      rows.length = maxSuggestions + 1;
    }
    return rows;
  }

  /// Exact case-insensitive lookup used when a rendered @mention is tapped.
  /// Returns null when the name is unknown (directory not loaded yet, or the
  /// person is no longer in the contacts list).
  static MentionSuggestion? findByName(String name) {
    final value = name.trim().toLowerCase();
    if (value.isEmpty) return null;
    if (value == 'everyone') {
      return const MentionSuggestion(
          id: 'everyone', name: 'Everyone', isEveryone: true);
    }
    for (final contact in _contacts) {
      if (contact.name.trim().toLowerCase() == value) {
        return MentionSuggestion(
            id: contact.id,
            name: contact.name,
            department: contact.department,
            avatar: contact.avatar);
      }
    }
    return null;
  }

  /// Replaces the cached list wholesale. Test-only.
  static void debugSeed(List<ChatContact> contacts) {
    _contacts = contacts;
    _loaded = true;
    _loading = null;
    _sortedNames = null;
  }

  /// Clears the cache. Test-only.
  static void resetForTest() {
    debugOverride = null;
    _contacts = const [];
    _loaded = false;
    _loading = null;
    _sortedNames = null;
  }
}
