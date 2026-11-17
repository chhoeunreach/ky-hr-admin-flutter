import 'dart:convert';
import 'dart:io';

import 'package:cnattendance/features/community/social_feed_screen.dart';
import 'package:cnattendance/features/home_highlights/home_highlight_api.dart';
import 'package:cnattendance/models/home_highlight.dart';
import 'package:cnattendance/widget/homescreen/monthly_attendance_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'community_feature_test.dart' show FakeCommunityApi, storyGroup;

class _AutomaticHighlights extends HomeHighlightApi {
  @override
  Future<HomeHighlightFeed> feed() async => const HomeHighlightFeed(
        items: [HomeHighlight(id: 1, title: 'Company news')],
        settings: HomeHighlightDisplaySettings(
            autoSwitchEnabled: true, lateBonusSeconds: 5, highlightsSeconds: 5),
      );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Localization.load(jsonDecode(File('assets/i18n/en.json').readAsStringSync())
        as Map<String, dynamic>);
  });

  Widget home(FakeCommunityApi api, {bool enabled = true}) => MaterialApp(
          home: Scaffold(
              body: HomeAttendanceClockSummary(
        clock: const Text('10:00'),
        summary: null,
        storiesEnabled: enabled,
        storiesApi: api,
      )));

  testWidgets('stories are permission gated and load only when selected',
      (tester) async {
    final api = FakeCommunityApi();
    await tester.pumpWidget(home(api, enabled: false));
    await tester.pumpAndSettle();
    expect(find.text('Stories'), findsNothing);
    expect(api.calls, isEmpty);
    await tester.pumpWidget(home(api));
    await tester.pumpAndSettle();
    expect(api.calls, isEmpty);
    await tester.tap(find.text('Stories'));
    await tester.pumpAndSettle();
    expect(api.calls, ['GET social-stories']);
    expect(find.text('No active stories.'), findsOneWidget);
    expect(find.text('Create story'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Home story cards open the viewer without creation controls',
      (tester) async {
    final api = FakeCommunityApi()
      ..responses['GET social-stories'] = {
        'data': [storyGroup()]
      };
    await tester.pumpWidget(home(api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stories'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dara'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(SocialStoryViewer), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(
        api.calls.where((call) => call == 'GET social-stories'), hasLength(2));
    expect(find.text('Create story'), findsNothing);
    expect(find.byType(SocialStoryComposer), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('stories errors offer retry', (tester) async {
    final api = FakeCommunityApi()..failure = Exception('Offline');
    await tester.pumpWidget(home(api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stories'));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    api.failure = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Create story'), findsNothing);
    expect(find.text('No active stories.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'three Home tabs fit a phone and stories join automatic switching',
      (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final highlights = _AutomaticHighlights();
    addTearDown(highlights.dispose);
    final stories = FakeCommunityApi();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: HomeAttendanceClockSummary(
      clock: const Text('10:00'),
      summary: null,
      highlightsEnabled: true,
      highlightsApi: highlights,
      storiesEnabled: true,
      storiesApi: stories,
    ))));
    await tester.pumpAndSettle();
    expect(find.text('Late & Bonus'), findsOneWidget);
    expect(find.text('Highlights'), findsOneWidget);
    final tabCenters = [
      tester.getCenter(find.text('Late & Bonus')).dy,
      tester.getCenter(find.text('Highlights')).dy,
      tester.getCenter(find.text('Stories')).dy,
    ];
    expect(tabCenters.toSet().length, 1);
    await tester.tap(find.text('Stories'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-stories-tab')), findsOneWidget);
    expect(find.text('Create story'), findsNothing);
    expect(find.text('No active stories.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byKey(const ValueKey('home-late-bonus-tab')), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byKey(const ValueKey('home-highlights-tab')), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byKey(const ValueKey('home-stories-tab')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
