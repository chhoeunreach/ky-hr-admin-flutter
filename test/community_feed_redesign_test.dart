import 'dart:convert';
import 'dart:io';

import 'package:cnattendance/features/community/social_feed_screen.dart';
import 'package:cnattendance/features/community/community_strings.dart';
import 'package:cnattendance/provider/dashboardprovider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'community_feature_test.dart' show FakeCommunityApi, postFixture;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Localization.load(jsonDecode(File('assets/i18n/en.json').readAsStringSync())
        as Map<String, dynamic>);
  });

  testWidgets('background posts render centered white text', (tester) async {
    final api = FakeCommunityApi()
      ..responses['GET social-feed?page=1'] = {
        'data': [
          {
            ...postFixture(),
            'id': 2,
            'body': 'Monday motivation',
            'background': 'ocean'
          }
        ],
        'next_page_url': null,
      };
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => DashboardProvider()..features = {'social_feed.view': '1'},
      child: MaterialApp(home: SocialFeedScreen(api: api)),
    ));
    await tester.pumpAndSettle();
    final body = tester.widget<SelectableText>(find.byWidgetPredicate(
        (widget) =>
            widget is SelectableText && widget.data == 'Monday motivation'));
    expect(body.textAlign, TextAlign.center);
    expect(body.style?.color, Colors.white);
    expect(body.style?.fontSize, 22);
    expect(tester.takeException(), isNull);
  });

  testWidgets('formatted post text renders bold and italic spans',
      (tester) async {
    final api = FakeCommunityApi()
      ..responses['GET social-feed?page=1'] = {
        'data': [
          {...postFixture(), 'id': 2, 'body': '**Bold** and _italic_'}
        ],
        'next_page_url': null,
      };
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => DashboardProvider()..features = {'social_feed.view': '1'},
      child: MaterialApp(home: SocialFeedScreen(api: api)),
    ));
    await tester.pumpAndSettle();
    final selectable = tester.widget<SelectableText>(find.byWidgetPredicate(
        (widget) =>
            widget is SelectableText &&
            widget.textSpan?.toPlainText() == 'Bold and italic'));
    final spans = selectable.textSpan!.children!.cast<TextSpan>();
    expect(
        spans.any((span) =>
            span.text == 'Bold' && span.style?.fontWeight == FontWeight.w800),
        isTrue);
    expect(
        spans.any((span) =>
            span.text == 'italic' && span.style?.fontStyle == FontStyle.italic),
        isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('category filters preserve posts and support loading more',
      (tester) async {
    final api = FakeCommunityApi()
      ..responses['GET social-feed?page=1'] = {
        'data': [
          {...postFixture(), 'body': 'Company update'},
          {
            ...postFixture(),
            'id': 2,
            'body': 'Team update',
            'visibility': 'department'
          },
          {
            ...postFixture(),
            'id': 3,
            'body': 'Important news',
            'is_announcement': true
          },
          {
            ...postFixture(),
            'id': 4,
            'body': 'Friday gathering',
            'category': 'event'
          },
        ],
        'next_page_url': 'page=2',
      }
      ..responses['GET social-feed?page=2'] = {
        'data': [
          {
            ...postFixture(),
            'id': 5,
            'body': 'Another event',
            'category': 'event'
          }
        ],
        'next_page_url': null,
      };
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => DashboardProvider()..features = {'social_feed.view': '1'},
      child: MaterialApp(home: SocialFeedScreen(api: api)),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Team'));
    await tester.pumpAndSettle();
    expect(find.text('Team update'), findsOneWidget);
    expect(find.text('Company update'), findsNothing);
    await tester.tap(find.text('Announcement'));
    await tester.pumpAndSettle();
    expect(find.text('Important news'), findsOneWidget);
    expect(find.text('Team update'), findsNothing);
    await tester.tap(find.text('Event'));
    await tester.pumpAndSettle();
    expect(find.text('Friday gathering'), findsOneWidget);
    await tester.tap(find.text('Load more posts'));
    await tester.pumpAndSettle();
    expect(find.text('Another event'), findsOneWidget);
    expect(api.calls, contains('GET social-feed?page=2'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('composer and all post actions fit a narrow display',
      (tester) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = FakeCommunityApi()
      ..responses['GET social-feed?page=1'] = {
        'data': [postFixture()],
        'next_page_url': null,
      };
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => DashboardProvider()
        ..features = {
          'social_feed.view': '1',
          'social_feed.create': '1',
          'social_feed.react': '1',
          'social_feed.share': '1',
          'social_feed.stories.view': '0',
        },
      child: MaterialApp(home: SocialFeedScreen(api: api)),
    ));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Photo'), findsOneWidget);
    expect(find.byTooltip(communityText('Video')), findsOneWidget);
    expect(find.text(communityText('Like')), findsOneWidget);
    expect(find.text(communityText('Comment')), findsOneWidget);
    expect(find.text(communityText('Share')), findsOneWidget);
    expect(find.text(communityText('Send')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
