import 'dart:convert';
import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/features/home_highlights/home_highlight_api.dart';
import 'package:cnattendance/models/home_highlight.dart';
import 'package:cnattendance/widget/homescreen/monthly_attendance_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class TimingPreferences extends Preferences {
  @override
  Future<String> getToken() async => 'test';
  @override
  Future<String> getAppUrl({bool forceCheck = false}) async =>
      'https://example.test/';
}

void main() {
  setUpAll(() => Localization.load({}));
  late Map<String, dynamic> settings;
  late bool hasHighlights;
  late HomeHighlightApi api;
  late int requests;
  setUp(() {
    settings = {
      'auto_switch_enabled': true,
      'late_bonus_seconds': 5,
      'highlights_seconds': 8
    };
    hasHighlights = true;
    requests = 0;
    api = HomeHighlightApi(
        preferences: TimingPreferences(),
        client: MockClient((_) async {
          requests++;
          return http.Response(
              jsonEncode({
                'data': hasHighlights
                    ? [
                        {'id': 1, 'title': 'Company news'}
                      ]
                    : [],
                'display_settings': settings
              }),
              200);
        }));
  });
  tearDown(() => api.dispose());
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: HomeAttendanceClockSummary(
                clock: const Text('10:00'),
                summary: null,
                highlightsEnabled: true,
                highlightsApi: api))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
  }

  final lateTab = find.byKey(const ValueKey('home-late-bonus-tab'));
  final highlightsTab = find.byKey(const ValueKey('home-highlights-tab'));

  test('settings parse safely and legacy responses remain manual', () {
    expect(
        HomeHighlightDisplaySettings.fromJson(null).autoSwitchEnabled, isFalse);
    final parsed = HomeHighlightDisplaySettings.fromJson({
      'auto_switch_enabled': '1',
      'late_bonus_seconds': 1,
      'highlights_seconds': 9999
    });
    expect(parsed.autoSwitchEnabled, isTrue);
    expect(parsed.lateBonusSeconds, 5);
    expect(parsed.highlightsSeconds, 300);
  });

  testWidgets('switches each tab after the company duration', (tester) async {
    await open(tester);
    expect(lateTab, findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 250));
    expect(highlightsTab, findsOneWidget);
    await tester.pump(const Duration(seconds: 8));
    await tester.pump(const Duration(milliseconds: 250));
    expect(lateTab, findsOneWidget);
    expect(highlightsTab, findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('manual tab selection restarts that tabs timer', (tester) async {
    await open(tester);
    await tester.pump(const Duration(seconds: 4));
    await tester.tap(find.text('Highlights'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(seconds: 5));
    expect(highlightsTab, findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 250));
    expect(lateTab, findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('disabled switching and an empty highlights list stay manual',
      (tester) async {
    settings['auto_switch_enabled'] = false;
    await open(tester);
    await tester.pump(const Duration(seconds: 20));
    expect(lateTab, findsOneWidget);
    await tester.tap(find.text('Highlights'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(seconds: 20));
    expect(highlightsTab, findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    settings['auto_switch_enabled'] = true;
    hasHighlights = false;
    await open(tester);
    await tester.pump(const Duration(seconds: 20));
    expect(lateTab, findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'background pauses switching and periodic refresh applies admin changes',
      (tester) async {
    await open(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 20));
    expect(lateTab, findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 250));
    expect(highlightsTab, findsOneWidget);
    settings['auto_switch_enabled'] = false;
    await tester.pump(const Duration(minutes: 1));
    await tester.pump(const Duration(milliseconds: 250));
    final lateVisible = lateTab.evaluate().isNotEmpty;
    await tester.pump(const Duration(seconds: 20));
    await tester.pump(const Duration(milliseconds: 250));
    expect(lateTab.evaluate().isNotEmpty, lateVisible);
    expect(requests, greaterThanOrEqualTo(3));
    await tester.pumpWidget(const SizedBox());
  });
}
