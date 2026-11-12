import 'package:cnattendance/features/community/reaction_button.dart';
import 'package:cnattendance/features/community/community_strings.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/features/community/community_api.dart';
import 'package:cnattendance/features/community/community_media.dart';
import 'package:cnattendance/features/community/flash_view_presenter.dart';
import 'package:cnattendance/features/community/social_feed_screen.dart';
import 'package:cnattendance/provider/dashboardprovider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiPreferences extends Preferences {
  @override
  Future<String> getAppUrl({bool forceCheck = false}) async =>
      'https://example.test/';
  @override
  Future<String> getToken() async => 'test-token';
}

class FakeCommunityApi extends CommunityApi {
  final List<String> calls = [];
  final List<Map<String, dynamic>?> payloads = [];
  final Map<String, Map<String, dynamic>> responses = {};
  Object? failure;
  Completer<Map<String, dynamic>>? pendingComment;
  @override
  Future<Map<String, dynamic>> request(String method, String path,
      {Map<String, dynamic>? data,
      String? filePath,
      String? fileMime,
      List<String>? filePaths,
      List<String>? fileMimes}) async {
    calls.add('$method $path');
    payloads.add(data);
    if (failure != null) throw failure!;
    if (method == 'POST' &&
        path.endsWith('/comments') &&
        pendingComment != null) return pendingComment!.future;
    return responses['$method $path'] ?? {'data': [], 'next_page_url': null};
  }
}

Map<String, dynamic> postFixture({bool owner = false}) => {
      'id': 1,
      'body': 'Hello team',
      'media_type': 'text',
      'media_url': null,
      'author': {'name': 'Dara'},
      'created_at': '2026-11-11T02:00:00Z',
      'comments_count': 0,
      'reactions_count': 0,
      'shares_count': 0,
      'reactions': <String, dynamic>{},
      'my_reaction': null,
      'can_edit': owner,
      'can_delete': owner,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues(
        {'user_id': 10, 'user_token': 'test'});
    Localization.load(jsonDecode(File('assets/i18n/en.json').readAsStringSync())
        as Map<String, dynamic>);
  });

  Widget app(Widget screen, Map<String, String> features) =>
      ChangeNotifierProvider(
        create: (_) => DashboardProvider()..features = features,
        child: MaterialApp(home: screen),
      );

  test('media embeds reject scripts, credentials and lookalike providers', () {
    expect(communityMediaUri('link', 'javascript:alert(1)'), isNull);
    expect(communityMediaUri('image', 'https://user:pass@host.test/photo.png'),
        isNull);
    expect(
        communityMediaUri(
            'youtube', 'https://youtube.com.evil.test/embed/abcdefghijk'),
        isNull);
    expect(
        communityMediaUri(
            'youtube', 'https://www.youtube.com/embed/abcdefghijk'),
        isNotNull);
    expect(
        communityMediaUri('facebook',
            'https://www.facebook.com/plugins/video.php?href=https%3A%2F%2Fevil.test'),
        isNull);
    expect(communityMediaUri('image', 'https://example.test/photo.png'),
        isNotNull);
    expect(
        communityMediaUri('video',
            'http://192.168.100.96:8000/storage/community/team-update.mp4'),
        isNotNull);
    expect(communityMediaUri('video', 'http://evil.test/media/team-update.mp4'),
        isNull);
    expect(
        communityMediaUri('image',
            'https://example.com/banner.jpg, https://www.youtube.com/watch?v=ScMzIvxBSi4'),
        isNull);
    expect(
        communityMediaUri(
            'image', 'https://example.com/a.jpg,https://example.com/b.jpg'),
        isNull);
  });

  test(
      'API sends bearer token, preserves data and surfaces validation failures',
      () async {
    final api = CommunityApi(
        preferences: ApiPreferences(),
        client: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer test-token');
          expect(request.url.path, '/api/social-feed');
          expect(jsonDecode(request.body)['body'], 'Hello');
          return http.Response(
              jsonEncode({
                'errors': {
                  'body': ['Message is required.']
                }
              }),
              422);
        }));
    await expectLater(
        api.request('POST', 'social-feed', data: {'body': 'Hello'}),
        throwsA(predicate(
            (error) => error.toString().contains('Message is required.'))));
    api.dispose();
  });

  for (final width in [320.0, 768.0]) {
    testWidgets(
        'feed fits $width and hides mutation controls for read-only users',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = FakeCommunityApi()
        ..responses['GET social-feed?page=1'] = {
          'data': [postFixture()],
          'next_page_url': null
        };
      await tester.pumpWidget(app(SocialFeedScreen(api: api),
          {'social-feed': '1', 'social_feed.view': '1'}));
      await tester.pumpAndSettle();
      expect(find.text('Hello team'), findsOneWidget);
      expect(find.text('Create post'), findsNothing);
      expect(find.text('Share'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('selecting a reaction sends its exact value', (tester) async {
    final api = FakeCommunityApi()
      ..responses['GET social-feed?page=1'] = {
        'data': [postFixture()],
        'next_page_url': null
      }
      ..responses['PUT social-feed/1/reaction'] = {
        'data': {...postFixture(), 'my_reaction': 'love', 'reactions_count': 1}
      };
    await tester.pumpWidget(app(SocialFeedScreen(api: api),
        {'social_feed.view': '1', 'social_feed.react': '1'}));
    await tester.pumpAndSettle();
    await tester.longPress(find.byType(CommunityReactionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reaction-choice-love')));
    await tester.pumpAndSettle();
    expect(api.calls, contains('PUT social-feed/1/reaction'));
    expect(api.payloads.last, {'reaction': 'love'});
    expect(find.text(communityText('Love')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('post commands can follow notifications and hide a post',
      (tester) async {
    final api = FakeCommunityApi()
      ..responses['GET social-feed?page=1'] = {
        'data': [postFixture()],
        'next_page_url': null
      }
      ..responses['POST social-feed/1/notifications'] = {
        'notifications_enabled': true
      }
      ..responses['POST social-feed/1/hide'] = {'hidden': true};
    await tester.pumpWidget(app(SocialFeedScreen(api: api), {
      'social_feed.view': '1',
      'social_feed.follow': '1',
      'social_feed.hide': '1',
    }));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Turn notifications on'));
    await tester.pumpAndSettle();
    expect(api.calls, contains('POST social-feed/1/notifications'));

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hide post'));
    await tester.pumpAndSettle();
    expect(api.calls, contains('POST social-feed/1/hide'));
    expect(find.text('Hello team'), findsNothing);
  });

  testWidgets('notifications load, mark read and open the referenced post',
      (tester) async {
    final api = FakeCommunityApi()
      ..responses['GET social-notifications?page=1'] = {
        'data': [
          {
            'id': 7,
            'type': 'comment',
            'read_at': null,
            'created_at': '2026-11-11T02:00:00Z',
            'social_post_id': 1,
            'actor': {'name': 'Dara'},
          }
        ],
        'current_page': 1,
        'last_page': 1,
        'next_page_url': null,
      }
      ..responses['POST social-notifications/7/read'] = {'message': 'ok'}
      ..responses['POST social-notifications/read-all'] = {'message': 'ok'}
      ..responses['GET social-feed/1'] = {'data': postFixture()};
    await tester.pumpWidget(app(SocialNotificationsScreen(api: api), {}));
    await tester.pumpAndSettle();
    expect(find.textContaining('Dara'), findsOneWidget);

    await tester.tap(find.textContaining('Dara'));
    await tester.pumpAndSettle();
    expect(api.calls, contains('POST social-notifications/7/read'));
    expect(api.calls, contains('GET social-feed/1'));
    expect(find.text('Hello team'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark all read'));
    await tester.pumpAndSettle();
    expect(api.calls, contains('POST social-notifications/read-all'));
    expect(find.text('Mark all read'), findsNothing);
  });

  testWidgets('composer validates empty text and publishes immediately',
      (tester) async {
    final api = FakeCommunityApi();
    await tester.pumpWidget(app(SocialPostComposer(api: api), {}));
    await tester.tap(find.text('Publish post'));
    await tester.pumpAndSettle();
    expect(api.calls, isEmpty);
    expect(find.text('Write a message.'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'New employee post');
    await tester.tap(find.text('Publish post'));
    await tester.pumpAndSettle();
    expect(api.calls, ['POST social-feed']);
    expect(api.payloads.single?['body'], 'New employee post');
  });

  testWidgets('permission errors show a retry and remain usable',
      (tester) async {
    final api = FakeCommunityApi()..failure = Exception('Access revoked.');
    await tester
        .pumpWidget(app(SocialFeedScreen(api: api), {'social_feed.view': '1'}));
    await tester.pumpAndSettle();
    expect(find.text('Access revoked.'), findsOneWidget);
    api.failure = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Access revoked.'), findsNothing);
    expect(find.text('No posts yet. Start a conversation with your team.'),
        findsOneWidget);
  });

  testWidgets(
      'flash popup dismisses, acknowledges revision, and does not repeat in session',
      (tester) async {
    final api = FakeCommunityApi()
      ..responses['GET flash-views'] = {
        'data': [
          {
            'id': 91,
            'revision': 2,
            'title': 'Announcement',
            'body': 'Welcome everyone',
            'media_type': 'text',
            'display_policy': 'session'
          },
        ]
      };
    await tester.pumpWidget(app(
        Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () =>
                        FlashViewPresenter.showPending(context, apiClient: api),
                    child: const Text('Show popup')))),
        {'flash_view.view': '1'}));
    await tester.tap(find.text('Show popup'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome everyone'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(api.calls, contains('POST flash-views/91/acknowledge'));
    expect(api.payloads.last, {'revision': 2});
    await tester.tap(find.text('Show popup'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome everyone'), findsNothing);
  });

  testWidgets('comments publish and hide controls without comment permission',
      (tester) async {
    final api = FakeCommunityApi()
      ..responses['GET social-feed/1/comments?page=1'] = {
        'data': [],
        'next_page_url': null
      };
    await tester.pumpWidget(app(SocialCommentsScreen(postId: 1, api: api),
        {'social_feed.comment': '1'}));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Excellent work');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();
    final index = api.calls.indexOf('POST social-feed/1/comments');
    expect(index, greaterThanOrEqualTo(0));
    expect(api.payloads[index], {'body': 'Excellent work'});
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
        app(SocialCommentsScreen(postId: 1, api: FakeCommunityApi()), {}));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets(
      'leaving comments while publishing does not reuse disposed controls',
      (tester) async {
    final pending = Completer<Map<String, dynamic>>();
    final api = FakeCommunityApi()..pendingComment = pending;
    await tester.pumpWidget(app(SocialCommentsScreen(postId: 1, api: api),
        {'social_feed.comment': '1'}));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'A pending comment');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    pending.complete({
      'data': {'id': 1}
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('sharing asks for a caption and publishes a feed share',
      (tester) async {
    final api = FakeCommunityApi()
      ..responses['GET social-feed?page=1'] = {
        'data': [postFixture()],
        'next_page_url': null
      };
    await tester.pumpWidget(app(SocialFeedScreen(api: api),
        {'social_feed.view': '1', 'social_feed.share': '1'}));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Useful update');
    await tester.tap(find.widgetWithText(FilledButton, 'Share'));
    await tester.pumpAndSettle();
    final index = api.calls.indexOf('POST social-feed/1/share');
    expect(index, greaterThanOrEqualTo(0));
    expect(api.payloads[index], {'body': 'Useful update'});
  });

  testWidgets('missing Flash View permission performs no request',
      (tester) async {
    final api = FakeCommunityApi();
    await tester.pumpWidget(app(
        Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () =>
                        FlashViewPresenter.showPending(context, apiClient: api),
                    child: const Text('Show popup')))),
        {}));
    await tester.tap(find.text('Show popup'));
    await tester.pumpAndSettle();
    expect(api.calls, isEmpty);
  });

  testWidgets('Khmer feed title uses the selected language', (tester) async {
    Localization.load(jsonDecode(File('assets/i18n/km.json').readAsStringSync())
        as Map<String, dynamic>);
    await tester.pumpWidget(app(
        SocialFeedScreen(api: FakeCommunityApi()), {'social_feed.view': '1'}));
    await tester.pumpAndSettle();
    expect(find.text('បណ្តាញសង្គម'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
