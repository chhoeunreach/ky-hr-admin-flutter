import 'dart:convert';

import 'package:cnattendance/features/community/feed_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('round-trips the first page and trims it to the cache limit', () async {
    final posts =
        List.generate(40, (i) => <String, dynamic>{'id': i, 'body': 'Post $i'});
    await FeedCache.write(7, {
      'data': posts,
      'next_cursor': 'cursor-2',
      'has_more': true,
    });

    final cached = await FeedCache.read(7);
    expect(cached, isNotNull);
    expect(cached!['data'], hasLength(30));
    expect((cached['data'] as List).first, containsPair('id', 0));
    expect(cached['next_cursor'], 'cursor-2');
    expect(cached['has_more'], isTrue);
  });

  test('ignores expired, malformed, empty, and missing entries', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'social_feed_cache_v1_8',
        jsonEncode({
          'saved_at': DateTime.now()
              .subtract(const Duration(days: 8))
              .toUtc()
              .toIso8601String(),
          'data': [
            {'id': 1}
          ],
        }));
    expect(await FeedCache.read(8), isNull);

    await prefs.setString('social_feed_cache_v1_9', 'not-json');
    expect(await FeedCache.read(9), isNull);

    await FeedCache.write(10, {'data': const []});
    expect(await FeedCache.read(10), isNull);
    expect(await FeedCache.read(0), isNull);
  });

  test('clear removes only the requested user cache', () async {
    await FeedCache.write(11, {
      'data': [
        {'id': 1}
      ],
    });
    await FeedCache.write(12, {
      'data': [
        {'id': 2}
      ],
    });
    await FeedCache.clear(11);
    expect(await FeedCache.read(11), isNull);
    expect(await FeedCache.read(12), isNotNull);
  });
}
