import 'dart:async';
import 'package:cnattendance/features/home_highlights/home_highlight_open_screen.dart';
import 'dart:convert';
import 'dart:io';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/features/home_highlights/home_highlight_api.dart';
import 'package:cnattendance/features/home_highlights/home_highlights_screen.dart';
import 'package:cnattendance/models/home_highlight.dart';
import 'package:cnattendance/widget/homescreen/monthly_attendance_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Prefs extends Preferences {
  @override
  Future<String> getToken() async => 'employee-token';

  @override
  Future<String> getAppUrl({bool forceCheck = false}) async =>
      'https://example.test/';
}

Map<String, dynamic> _highlightJson(
        {int id = 1, String title = 'Company wins award'}) =>
    {
      'id': id,
      'title': title,
      'body': '<p>We are proud to share <b>great news</b> with everyone.</p>',
      'image_url': null,
      'link_url': null,
      'link_label': null,
      'priority': 10,
      'starts_at': '2026-11-10T08:00:00+00:00',
      'ends_at': null,
      'created_at': '2026-11-09T08:00:00+00:00',
    };

void main() {
  setUp(() {
    Localization.load(jsonDecode(File('assets/i18n/en.json').readAsStringSync())
        as Map<String, dynamic>);
  });

  test('index uses the authenticated API and parses highlights', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/home-highlights');
      expect(request.headers['Authorization'], 'Bearer employee-token');
      return http.Response(
          jsonEncode({
            'data': [_highlightJson()]
          }),
          200);
    });
    final api = HomeHighlightApi(preferences: _Prefs(), client: client);
    addTearDown(api.dispose);

    final items = await api.index();

    expect(items, hasLength(1));
    expect(items.single.title, 'Company wins award');
    expect(items.single.plainBody, contains('great news'));
    expect(items.single.priority, 10);
  });

  test('history parses pagination metadata', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/home-highlights/history');
      expect(request.url.queryParameters['page'], '2');
      return http.Response(
          jsonEncode({
            'data': [_highlightJson(id: 2, title: 'Second page')],
            'meta': {
              'current_page': 2,
              'per_page': 20,
              'total': 25,
              'last_page': 3,
            },
          }),
          200);
    });
    final api = HomeHighlightApi(preferences: _Prefs(), client: client);
    addTearDown(api.dispose);

    final page = await api.history(page: 2);

    expect(page.items.single.title, 'Second page');
    expect(page.currentPage, 2);
    expect(page.lastPage, 3);
    expect(page.total, 25);
    expect(page.hasMore, isTrue);
  });

  testWidgets('home attendance card switches to highlights and opens history',
      (tester) async {
    final client = MockClient((request) async {
      if (request.url.path == '/api/home-highlights') {
        return http.Response(
            jsonEncode({
              'data': [_highlightJson()]
            }),
            200);
      }
      if (request.url.path == '/api/home-highlights/history') {
        return http.Response(
            jsonEncode({
              'data': [_highlightJson()],
              'meta': {
                'current_page': 1,
                'per_page': 20,
                'total': 1,
                'last_page': 1,
              },
            }),
            200);
      }
      return http.Response('{}', 404);
    });
    final api = HomeHighlightApi(preferences: _Prefs(), client: client);
    addTearDown(api.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HomeAttendanceClockSummary(
          clock: const Text('11:43'),
          summary: null,
          highlightsEnabled: true,
          highlightsApi: api,
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Late & Bonus'), findsOneWidget);
    expect(find.text('Highlights'), findsOneWidget);

    await tester.tap(find.text('Highlights'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Company wins award'), findsOneWidget);
    expect(find.text('View all'), findsOneWidget);

    await tester.tap(find.text('View all'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeHighlightsScreen), findsOneWidget);
    expect(find.text('Home Highlights'), findsOneWidget);
    expect(find.text('Company wins award'), findsOneWidget);
  });

  testWidgets('tapping a highlight opens its detail screen', (tester) async {
    final client = MockClient((request) async => http.Response(
        jsonEncode({
          'data': [_highlightJson()]
        }),
        200));
    final api = HomeHighlightApi(preferences: _Prefs(), client: client);
    addTearDown(api.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HomeAttendanceClockSummary(
          clock: const Text('11:43'),
          summary: null,
          highlightsEnabled: true,
          highlightsApi: api,
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Highlights'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Company wins award'));
    await tester.pumpAndSettle();

    expect(find.text('Highlight'), findsOneWidget);
    expect(find.byType(Html), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('Highlight'), findsNothing);
    expect(find.text('Late & Bonus'), findsOneWidget);
  });

  test('plain body strips markup for carousel snippets', () {
    final highlight = HomeHighlight.fromJson(_highlightJson());
    expect(
        highlight.plainBody, 'We are proud to share great news with everyone.');
    expect(highlight.snippet, isNotEmpty);
  });
  test(
      'malformed successful API responses surface an error instead of an empty list',
      () async {
    for (final body in ['<html>Login</html>', '{}', '{"data":{}}']) {
      final api = HomeHighlightApi(
          preferences: _Prefs(),
          client: MockClient((_) async => http.Response(body, 200)));
      await expectLater(api.index(), throwsA(isA<HomeHighlightException>()));
      api.dispose();
    }
  });

  test(
      'highlight images follow current API while external images remain unchanged',
      () async {
    final api = HomeHighlightApi(
        preferences: _Prefs(),
        client: MockClient((_) async => http.Response(
            jsonEncode({
              'data': [
                {
                  ..._highlightJson(),
                  'image_url':
                      'http://192.168.0.118:8000/storage/community/highlight.jpg'
                },
                {
                  ..._highlightJson(id: 2),
                  'image_url': 'https://cdn.test/picture.jpg'
                },
              ]
            }),
            200)));
    addTearDown(api.dispose);
    final items = await api.index();
    expect(items[0].imageUrl,
        'https://example.test/storage/community/highlight.jpg');
    expect(items[1].imageUrl, 'https://cdn.test/picture.jpg');
  });

  test('snippets decode HTML entities and do not break emoji characters', () {
    final item = HomeHighlight.fromJson({
      ..._highlightJson(),
      'body':
          '<p>Hello &#128512;</p><p>Second&nbsp;paragraph &amp; team</p><script>hidden()</script>'
    });
    expect(item.plainBody, 'Hello 😀 Second paragraph & team');
    expect(
        HomeHighlight.fromJson({
          ..._highlightJson(),
          'body': List.filled(141, '👨‍👩‍👧‍👦').join()
        }).snippet,
        '${List.filled(140, '👨‍👩‍👧‍👦').join()}…');
  });

  test('notification routing requires highlight type and positive ID', () {
    expect(
        homeHighlightNotificationId(
            {'type': 'home_highlight', 'home_highlight_id': '12'}),
        12);
    expect(
        homeHighlightNotificationId(
            {'type': 'chat', 'home_highlight_id': '12'}),
        isNull);
    expect(
        homeHighlightNotificationId(
            {'type': 'home_highlight', 'home_highlight_id': '-1'}),
        isNull);
  });

  testWidgets(
      'notification opens authenticated detail and can retry an unavailable item',
      (tester) async {
    var attempts = 0;
    final api = HomeHighlightApi(
        preferences: _Prefs(),
        client: MockClient((request) async {
          expect(request.url.path, '/api/home-highlights/1');
          expect(request.headers['Authorization'], 'Bearer employee-token');
          attempts++;
          return attempts == 1
              ? http.Response('{}', 404)
              : http.Response(jsonEncode({'data': _highlightJson()}), 200);
        }));
    addTearDown(api.dispose);
    await tester.pumpWidget(
        MaterialApp(home: HomeHighlightOpenScreen(id: 1, api: api)));
    await tester.pumpAndSettle();
    expect(find.text('This highlight is unavailable.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Company wins award'), findsOneWidget);
    expect(find.byType(Html), findsOneWidget);
  });

  testWidgets(
      'history exposes load more and retries a failed page without duplicates',
      (tester) async {
    var secondPageAttempts = 0;
    final api = HomeHighlightApi(
        preferences: _Prefs(),
        client: MockClient((request) async {
          final second = request.url.queryParameters['page'] == '2';
          if (second && ++secondPageAttempts == 1)
            return http.Response('{"message":"Connection interrupted"}', 503);
          return http.Response(
              jsonEncode({
                'data': second
                    ? [
                        _highlightJson(),
                        _highlightJson(id: 2, title: 'Second item')
                      ]
                    : [_highlightJson()],
                'meta': {
                  'current_page': second ? 2 : 1,
                  'last_page': 2,
                  'total': 2
                }
              }),
              200);
        }));
    addTearDown(api.dispose);
    await tester.pumpWidget(MaterialApp(home: HomeHighlightsScreen(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();
    expect(find.text('Connection interrupted'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Company wins award'), findsOneWidget);
    expect(find.text('Second item'), findsOneWidget);
    expect(find.text('Load more'), findsNothing);
  });

  testWidgets(
      'refresh discards a stale page response from an older history request',
      (tester) async {
    final pending = Completer<http.Response>();
    var firstPageCalls = 0;
    final api = HomeHighlightApi(
        preferences: _Prefs(),
        client: MockClient((request) async {
          if (request.url.queryParameters['page'] == '2') return pending.future;
          firstPageCalls++;
          return http.Response(
              jsonEncode({
                'data': [
                  _highlightJson(
                      title: firstPageCalls == 1
                          ? 'Before refresh'
                          : 'After refresh')
                ],
                'meta': {'current_page': 1, 'last_page': 2, 'total': 2}
              }),
              200);
        }));
    addTearDown(api.dispose);
    await tester.pumpWidget(MaterialApp(home: HomeHighlightsScreen(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Load more'));
    await tester.pump();
    unawaited(tester
        .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
        .show());
    await tester.pump();
    pending.complete(http.Response(
        jsonEncode({
          'data': [_highlightJson(id: 2, title: 'Stale item')],
          'meta': {'current_page': 2, 'last_page': 2, 'total': 2}
        }),
        200));
    await tester.pumpAndSettle();
    expect(find.text('After refresh'), findsOneWidget);
    expect(find.text('Stale item'), findsNothing);
  });
}
