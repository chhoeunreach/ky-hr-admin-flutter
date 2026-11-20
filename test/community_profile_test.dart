import 'dart:convert';
import 'dart:io';

import 'package:cnattendance/features/community/mention_directory.dart';
import 'package:cnattendance/features/community/social_feed_screen.dart';
import 'package:cnattendance/model/chat_contact.dart';
import 'package:cnattendance/provider/dashboardprovider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'community_feature_test.dart' show FakeCommunityApi;

Map<String, dynamic> _post(
    {String body = 'Hello team', String name = 'Dara Sok', Object id = 5}) {
  return {
    'id': 1,
    'body': body,
    'media_type': 'text',
    'media_url': null,
    'author': {'id': id, 'name': name, 'department': 'IT', 'avatar': ''},
    'created_at': '2026-11-11T02:00:00Z',
    'comments_count': 0,
    'reactions_count': 0,
    'shares_count': 0,
    'reactions': <String, dynamic>{},
    'my_reaction': null,
    'can_edit': false,
    'can_delete': false,
    'media': <dynamic>[],
  };
}

Map<String, dynamic> _comment({String body = '@Sokha Dara'}) {
  return {
    'id': 1,
    'body': body,
    'parent_id': null,
    'author': {'name': 'Dara Sok'},
    'created_at': '2026-11-11T02:00:00Z',
    'replies_count': 0,
    'reactions': <String, dynamic>{},
    'reactions_count': 0,
    'my_reaction': null,
    'can_edit': false,
    'can_delete': false,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Localization.load(jsonDecode(File('assets/i18n/en.json').readAsStringSync())
        as Map<String, dynamic>);
    MentionDirectory.resetForTest();
    MentionDirectory.debugSeed([
      ChatContact.fromJson({'id': 7, 'name': 'Sokha Dara', 'department': 'HR'}),
    ]);
  });
  tearDown(MentionDirectory.resetForTest);

  Widget app(Widget screen) => ChangeNotifierProvider(
        create: (_) => DashboardProvider()
          ..features = {
            'social_feed.view': '1',
            'social_feed.create': '1',
            'social_feed.comment': '1',
          },
        child: MaterialApp(home: screen),
      );

  testWidgets(
      'profile screen loads only that author posts with a Facebook-style header',
      (tester) async {
    final api = FakeCommunityApi();
    api.responses['GET social-feed?page=1&user_id=7'] = {
      'data': [_post(body: 'Profile post')],
      'next_page_url': null,
    };
    api.responses['GET users/profile-detail/7'] = {
      'data': {
        'name': 'Sokha Dara',
        'department': 'HR',
        'post': 'Officer',
        'branch': 'Head Office',
        'avatar': '',
      },
    };

    await tester.pumpWidget(app(SocialFeedScreen(
        api: api,
        profileAuthor: {'id': 7, 'name': 'Sokha Dara', 'department': 'HR'})));
    await tester.pumpAndSettle();

    expect(api.calls, contains('GET social-feed?page=1&user_id=7'));
    expect(api.calls, contains('GET users/profile-detail/7'));
    expect(api.calls.any((call) => call.contains('social-stories')), isFalse);
    expect(find.text('Sokha Dara'), findsWidgets);
    expect(find.text('HR · Officer'), findsOneWidget);
    expect(find.text('Officer'), findsOneWidget);
    expect(find.text('Head Office'), findsOneWidget);
    expect(find.text('Posts'), findsOneWidget);
    expect(find.text('Profile post'), findsOneWidget);
    // Profile mode hides the feed chrome.
    expect(find.text('All Posts'), findsNothing);
    expect(find.text("What's on your mind?"), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping the post author opens their profile and back returns',
      (tester) async {
    final api = FakeCommunityApi()
      ..responses['GET social-feed?page=1'] = {
        'data': [_post(name: 'Dara Sok')],
        'next_page_url': null,
      };
    await tester.pumpWidget(app(SocialFeedScreen(api: api)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dara Sok'));
    await tester.pumpAndSettle();

    expect(api.calls, contains('GET social-feed?page=1&user_id=5'));
    expect(find.text('Dara Sok'), findsWidgets);
    expect(find.text('All Posts'), findsNothing);
    expect(find.text("What's on your mind?"), findsNothing);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('All Posts'), findsOneWidget);
    expect(find.text("What's on your mind?"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a mention in a post opens that person profile',
      (tester) async {
    final api = FakeCommunityApi()
      ..responses['GET social-feed?page=1'] = {
        'data': [_post(body: '@Sokha Dara')],
        'next_page_url': null,
      };
    await tester.pumpWidget(app(SocialFeedScreen(api: api)));
    await tester.pumpAndSettle();

    // The body spans the card width while the mention sits at its left edge,
    // so tap the mention itself instead of the widget's center.
    final mention = find.text('@Sokha Dara');
    await tester.tapAt(tester.getTopLeft(mention) + const Offset(24, 10));
    await tester.pumpAndSettle();

    expect(api.calls, contains('GET social-feed?page=1&user_id=7'));
    expect(find.text('Sokha Dara'), findsWidgets);
    expect(find.text('@Sokha Dara'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping @everyone does not open a profile', (tester) async {
    final api = FakeCommunityApi()
      ..responses['GET social-feed?page=1'] = {
        'data': [_post(body: '@everyone')],
        'next_page_url': null,
      };
    await tester.pumpWidget(app(SocialFeedScreen(api: api)));
    await tester.pumpAndSettle();

    final everyone = find.text('@everyone');
    await tester.tapAt(tester.getTopLeft(everyone) + const Offset(24, 10));
    await tester.pumpAndSettle();

    expect(api.calls.any((call) => call.contains('user_id')), isFalse);
    expect(find.text('Social Feed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a mention in a comment opens that person profile',
      (tester) async {
    final api = FakeCommunityApi();
    api.responses['GET social-feed/1/comments?page=1'] = {
      'data': [_comment()],
      'next_page_url': null,
    };
    await tester.pumpWidget(app(SocialCommentsScreen(postId: 1, api: api)));
    await tester.pumpAndSettle();

    final mention = find.text('@Sokha Dara');
    await tester.tapAt(tester.getTopLeft(mention) + const Offset(24, 10));
    await tester.pumpAndSettle();

    expect(api.calls, contains('GET social-feed?page=1&user_id=7'));
    expect(find.text('Sokha Dara'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
