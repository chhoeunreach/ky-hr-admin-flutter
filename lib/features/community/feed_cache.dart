import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Bounded on-device copy of the first feed page.
///
/// The cache is intentionally small (it never stores more than one page) so a
/// cold start can paint useful posts immediately without growing preferences
/// or stale data indefinitely. Writes are best-effort: storage failures must
/// never break the network path.
class FeedCache {
  static const int _version = 1;
  static const int _maxPosts = 30;
  static const Duration _maxAge = Duration(days: 7);

  static String _key(int userId) => 'social_feed_cache_v${_version}_${userId}';

  static Future<Map<String, dynamic>?> read(int userId) async {
    if (userId <= 0) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(userId));
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final savedAt = DateTime.tryParse('${decoded['saved_at'] ?? ''}');
      if (savedAt == null || DateTime.now().difference(savedAt) > _maxAge)
        return null;
      final data = decoded['data'];
      if (data is! List || data.isEmpty) return null;
      return {
        'data': data
            .whereType<Map>()
            .take(_maxPosts)
            .map((post) => Map<String, dynamic>.from(post))
            .toList(),
        'next_cursor': decoded['next_cursor'],
        'has_more': decoded['has_more'] == true,
      };
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(int userId, Map<String, dynamic> response) async {
    if (userId <= 0) return;
    final data = response['data'];
    if (data is! List || data.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _key(userId),
          jsonEncode({
            'saved_at': DateTime.now().toUtc().toIso8601String(),
            'data': data.whereType<Map>().take(_maxPosts).toList(),
            'next_cursor': response['next_cursor'],
            'has_more': response['has_more'] == true ||
                response['next_page_url'] != null,
          }));
    } catch (_) {
      // A full disk or disabled preferences store must not affect the feed.
    }
  }

  static Future<void> clear(int userId) async {
    if (userId <= 0) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(userId));
    } catch (_) {}
  }
}
