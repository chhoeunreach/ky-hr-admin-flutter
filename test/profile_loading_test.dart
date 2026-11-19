import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/data/source/network/model/login/User.dart';
import 'package:cnattendance/provider/dashboardprovider.dart';
import 'package:cnattendance/provider/profileprovider.dart';
import 'package:cnattendance/screen/profile/profilescreen.dart';
import 'package:cnattendance/widget/morescreen/services.dart';
import 'package:cnattendance/widget/profile/basicdetail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Preferences extends Preferences {
  Completer<bool>? calendar;
  @override
  Future<String> getAppUrl({bool forceCheck = false}) async =>
      'https://example.test/';
  @override
  Future<String> getToken() async => 'token';
  @override
  Future<User> getUser() async => User(
      id: 1,
      name: 'Cached Employee',
      email: '',
      username: 'employee',
      avatar: '',
      workspace_type: '1');
  @override
  Future<bool> getEnglishDate() => calendar?.future ?? Future.value(true);
}

http.Response _response() => http.Response(
    jsonEncode({
      'status': true,
      'message': 'OK',
      'status_code': 200,
      'data': {
        'id': 1,
        'name': 'Employee with a very long name that must fit a small phone',
        'username': 'employee',
        'email': 'very.long.employee.email@example.test',
        'avatar': '',
        'post': 'Engineer',
        'phone': '012345678',
        'dob': '2000-01-01',
        'joining_date': '2020-01-01',
        'bank_name': '',
        'bank_account_no': '',
        'bank_account_type': '',
      },
    }),
    200);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Localization.load(jsonDecode(File('assets/i18n/en.json').readAsStringSync())
        as Map<String, dynamic>);
  });

  test('profile refreshes share a request and complete after date formatting',
      () async {
    final prefs = _Preferences()..calendar = Completer<bool>();
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return _response();
    });
    final provider = ProfileProvider(preferences: prefs, client: client);
    addTearDown(provider.dispose);
    addTearDown(client.close);
    final first = provider.getProfile();
    final second = provider.getProfile();
    expect(identical(first, second), isTrue);
    var complete = false;
    final observed = first.then((_) => complete = true);
    await Future<void>.delayed(Duration.zero);
    expect(complete, isFalse);
    expect(provider.profile.post, isEmpty);
    prefs.calendar!.complete(true);
    await observed;
    expect(calls, 1);
    expect(provider.profile.post, 'Engineer');
  });

  test('profile completion after disposal does not publish changes', () async {
    final prefs = _Preferences()..calendar = Completer<bool>();
    final client = MockClient((_) async => _response());
    addTearDown(client.close);
    final provider = ProfileProvider(preferences: prefs, client: client);
    var updates = 0;
    provider.addListener(() => updates++);
    final pending = provider.getProfile();
    await Future<void>.delayed(Duration.zero);
    final before = updates;
    provider.dispose();
    prefs.calendar!.complete(true);
    await pending;
    expect(updates, before);
    expect(provider.profile.post, isEmpty);
  });

  testWidgets(
      'Profile retries a failed load and long details fit a narrow screen',
      (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var calls = 0;
    final client = MockClient((_) async => ++calls == 1
        ? http.Response('{"message":"Offline"}', 503)
        : _response());
    final provider =
        ProfileProvider(preferences: _Preferences(), client: client);
    final dashboard = DashboardProvider();
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider<ProfileProvider>.value(value: provider),
      ChangeNotifierProvider<DashboardProvider>.value(value: dashboard),
    ], child: MaterialApp(home: ProfileScreen())));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.byType(BasicDetail), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
    dashboard.dispose();
    client.close();
  });

  testWidgets(
      'the More profile link shows Back and returns to More', (tester) async {
    final client = MockClient((_) async => _response());
    final profile =
        ProfileProvider(preferences: _Preferences(), client: client);
    final dashboard = DashboardProvider();
    addTearDown(client.close);
    addTearDown(profile.dispose);
    addTearDown(dashboard.dispose);

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<ProfileProvider>.value(value: profile),
        ChangeNotifierProvider<DashboardProvider>.value(value: dashboard),
      ],
      child: MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('More')),
          body: Services('Profile', Icons.person, ProfileScreen()),
        ),
      ),
    ));

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    final scaffold = tester.widget<Scaffold>(find.descendant(
      of: find.byType(ProfileScreen),
      matching: find.byType(Scaffold),
    ));
    expect(scaffold.drawer, isNull);
    expect(scaffold.endDrawer, isNull);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('More'), findsOneWidget);
    expect(find.byType(ProfileScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'closing Profile during a load does not update disposed screen state',
      (tester) async {
    final response = Completer<http.Response>();
    final client = MockClient((_) => response.future);
    final provider =
        ProfileProvider(preferences: _Preferences(), client: client);
    final dashboard = DashboardProvider();
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider<ProfileProvider>.value(value: provider),
      ChangeNotifierProvider<DashboardProvider>.value(value: dashboard),
    ], child: MaterialApp(home: ProfileScreen())));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    response.complete(_response());
    await tester.pump();
    expect(tester.takeException(), isNull);
    provider.dispose();
    dashboard.dispose();
    client.close();
  });
}
