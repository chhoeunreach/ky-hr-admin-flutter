import 'dart:convert';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/features/daily_records/daily_records_api.dart';
import 'package:cnattendance/features/daily_records/employee_records.dart';
import 'package:cnattendance/features/daily_records/my_tasks_screen.dart';
import 'package:cnattendance/features/daily_records/quick_create.dart';
import 'package:cnattendance/theme/app_theme_data.dart';
import 'package:cnattendance/theme/app_theme_mode.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:cnattendance/theme/theme_layout.dart';
import 'package:cnattendance/theme/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

class _Preferences extends Preferences {
  @override
  Future<String> getAppUrl({bool forceCheck = false}) async =>
      'https://example.test/hrms/';

  @override
  Future<String> getToken() async => 'employee-token';
}

http.Response _response(RecordData data, [int status = 200]) =>
    http.Response(jsonEncode({'data': data}), status);

class _CustomTheme extends ThemeProvider {
  @override
  ThemeLayout get layout => const ThemeLayout.defaults().setColors(
        background: const Color(0xff7d8380),
        accent: const Color(0xff7f7c7f),
      );
}

double _contrast(Color a, Color b) {
  final values = [a.computeLuminance(), b.computeLuminance()]..sort();
  return (values.last + .05) / (values.first + .05);
}

void main() {
  testWidgets(
      'Quick Create sparkles briefly while idle and pause with the sheet',
      (tester) async {
    final api = DailyRecordsApi(
      preferences: _Preferences(),
      client: MockClient((_) async => _response({'assign_tasks': false})),
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(floatingActionButton: CreateRecordButton(api: api)),
    ));
    final sparkles = find.byKey(const ValueKey('quick-create-sparkles'));
    expect(sparkles, findsOneWidget);
    expect(sparkles, paints..path());
    await tester.pump(const Duration(milliseconds: 180));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
        sparkles,
        paints
          ..circle()
          ..path());
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);

    await tester.tap(find.byTooltip('Create Record'));
    await tester.pumpAndSettle();
    expect(sparkles, findsNothing);
    Navigator.of(tester.element(find.text('Quick Create'))).pop();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
        sparkles,
        paints
          ..circle()
          ..path());
  });

  for (final reduceMotion in [false, true]) {
    testWidgets(
        'Quick Create button opens and resets with reduced motion $reduceMotion',
        (tester) async {
      final api = DailyRecordsApi(
        preferences: _Preferences(),
        client: MockClient((_) async => _response({'assign_tasks': false})),
      );
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
          data:
              MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
        home: Scaffold(floatingActionButton: CreateRecordButton(api: api)),
      ));
      final button = find.byType(CreateRecordButton);
      final sparkles = find.byKey(const ValueKey('quick-create-sparkles'));
      expect(sparkles, findsOneWidget);
      if (reduceMotion) {
        await tester.pump(const Duration(seconds: 2));
        expect(sparkles, paints..path());
        expect(tester.hasRunningAnimations, isFalse);
      }
      final iconRotation = find.descendant(
        of: button,
        matching: find.byType(RotationTransition),
      );
      final buttonScale = find.descendant(
        of: button,
        matching: find.byType(ScaleTransition),
      );

      await tester.tap(find.byTooltip('Create Record'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final turns = tester.widget<RotationTransition>(iconRotation).turns.value;
      final scale = tester.widget<ScaleTransition>(buttonScale).scale.value;
      if (reduceMotion) {
        expect(turns, .125);
        expect(scale, 1);
      } else {
        expect(turns, allOf(greaterThan(0), lessThan(.125)));
        expect(scale, allOf(greaterThan(.94), lessThan(1)));
      }

      await tester.pumpAndSettle();
      final sheet = tester.element(find.text('Quick Create'));
      if (reduceMotion) {
        expect(ModalRoute.of(sheet)!.transitionDuration, Duration.zero);
      }
      Navigator.of(sheet).pop();
      await tester.pumpAndSettle();
      expect(find.text('Quick Create'), findsNothing);
      expect(tester.widget<RotationTransition>(iconRotation).turns.value, 0);
      expect(tester.widget<ScaleTransition>(buttonScale).scale.value, 1);
    });
  }

  for (final mode in AppThemeMode.values) {
    testWidgets('Quick Create matches ${mode.name} on a narrow phone',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = DailyRecordsApi(
        preferences: _Preferences(),
        client: MockClient((_) async => _response({
              'assign_tasks': true,
              'can_submit_report': true,
            })),
      );
      await tester.pumpWidget(MaterialApp(
        theme: AppThemeData.themeData(mode),
        home: Scaffold(floatingActionButton: CreateRecordButton(api: api)),
      ));
      final fab = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );
      expect(fab.backgroundColor, AppThemeData.info(mode).colors.primaryColor);
      expect(_contrast(fab.backgroundColor!, fab.foregroundColor!),
          greaterThanOrEqualTo(4.5));

      await tester.tap(find.byTooltip('Create Record'));
      await tester.pumpAndSettle();
      final heading = find.text('Quick Create');
      final inherited = EnterpriseTheme.of(tester.element(heading));
      expect(inherited.mode, mode);
      final surface = tester.widget<Material>(
        find.ancestor(of: heading, matching: find.byType(Material)).first,
      );
      expect(surface.color, inherited.contentSurface);
      for (final label in [
        'Quick Create',
        'New note',
        'Submit daily report',
        'Assign Employee Task',
        'My Tasks'
      ]) {
        final target = find.text(label);
        final material = tester.widget<Material>(
          find.ancestor(of: target, matching: find.byType(Material)).first,
        );
        expect(
          _contrast(material.color!, tester.widget<Text>(target).style!.color!),
          greaterThanOrEqualTo(4.5),
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'Quick Create keeps actions reachable with custom colors and large text',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final theme = _CustomTheme();
    addTearDown(theme.dispose);
    var checks = 0;
    final api = DailyRecordsApi(
      preferences: _Preferences(),
      client: MockClient((_) async {
        checks++;
        return checks == 1
            ? http.Response('{"message":"Unavailable"}', 503)
            : _response({'assign_tasks': true, 'can_submit_report': true});
      }),
    );
    await tester.pumpWidget(ChangeNotifierProvider<ThemeProvider>.value(
      value: theme,
      child: MaterialApp(
        theme: theme.themeData,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(floatingActionButton: CreateRecordButton(api: api)),
      ),
    ));
    await tester.tap(find.byTooltip('Create Record'));
    await tester.pumpAndSettle();
    final title = find.text('Quick Create');
    final surface = tester.widget<Material>(
      find.ancestor(of: title, matching: find.byType(Material)).first,
    );
    expect(surface.color,
        Color.alphaBlend(theme.colors.cardColor, theme.colors.backgroundColor));
    expect(_contrast(surface.color!, tester.widget<Text>(title).style!.color!),
        greaterThanOrEqualTo(4.5));
    await tester.ensureVisible(find.text('Retry'));
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Assign Employee Task'), findsOneWidget);
    await tester.ensureVisible(find.text('My Daily Records'));
    expect(find.text('My Daily Records').hitTestable(), findsOneWidget);
    await tester.ensureVisible(find.text('New note'));
    await tester.tap(find.text('New note'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<NewDailyRecordScreen>(find.byType(NewDailyRecordScreen))
            .kind,
        'note');
    expect(tester.takeException(), isNull);
  });

  test('routes assignment and record files through the authenticated API',
      () async {
    final client = MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer employee-token');
      if (request.method == 'GET') {
        expect(
            request.url.path, '/hrms/api/v1/daily-records/records/3/files/5');
        return http.Response.bytes([1, 2, 3], 200);
      }
      expect(request.url.path, '/hrms/api/v1/daily-records/assign');
      expect(jsonDecode(request.body)['employee_ids'], [2, 4]);
      return _response({'id': 3}, 201);
    });
    final api = DailyRecordsApi(preferences: _Preferences(), client: client);
    final assigned = await api.post('assign', {
      'employee_ids': [2, 4]
    });
    expect(assigned['id'], 3);
    expect(await api.attachment('records/3/files/5'), [1, 2, 3]);
    expect(recordDate('2026-11-20 18:30:00'), '21 Nov 2026, 01:30 ICT');
  });

  for (final canAssign in [false, true]) {
    testWidgets('Quick Create uses server assignment access ($canAssign)',
        (tester) async {
      final api = DailyRecordsApi(
        preferences: _Preferences(),
        client: MockClient((request) async {
          expect(request.url.path, '/hrms/api/v1/daily-records/capabilities');
          return _response({
            'assign_tasks': canAssign,
            'can_submit_report': true,
          });
        }),
      );
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
        floatingActionButton: CreateRecordButton(api: api),
        floatingActionButtonLocation:
            const AboveMoreLocation(slot: 2, slots: 3),
      )));
      await tester.tap(find.byTooltip('Create Record'));
      await tester.pumpAndSettle();
      for (final action in [
        'New note',
        'New to-do',
        'Record incident',
        'Submit daily report',
        'My Tasks'
      ]) {
        expect(find.text(action), findsOneWidget);
      }
      expect(find.text('Assign Employee Task'),
          canAssign ? findsOneWidget : findsNothing);
    });
  }

  testWidgets(
      'My Tasks acknowledges, starts, saves checklist and submits for review',
      (tester) async {
    var task = <String, dynamic>{
      'id': 11,
      'title': 'Count the stock',
      'instructions': 'Start at the front',
      'status': 'assigned',
      'priority': 'normal',
      'progress': 0,
      'checked': <int>[],
      'checklist': ['Count shelf one'],
      'due_at': '2026-11-21 07:00:00',
      'overdue': false,
    };
    final actions = <String>[];
    final api = DailyRecordsApi(
      preferences: _Preferences(),
      client: MockClient((request) async {
        if (request.url.path.endsWith('/tasks')) {
          expect(request.url.queryParameters['tab'], 'assigned');
          return _response({
            'data': [task],
            'next_page_url': null
          });
        }
        if (request.method == 'POST') {
          final fields = jsonDecode(request.body) as RecordData;
          final action = fields['action'] as String;
          actions.add(action);
          task = {
            ...task,
            if (action == 'acknowledge') 'status': 'acknowledged',
            if (action == 'start') 'status': 'in_progress',
            if (action == 'progress') 'checked': fields['checked'],
            if (action == 'submit') ...{'status': 'submitted', 'progress': 100},
          };
          if (action == 'submit')
            expect(fields['message'], 'Counted and confirmed');
        }
        return _response({'task': task});
      }),
    );
    await tester.pumpWidget(MaterialApp(home: MyTasksScreen(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Count the stock'));
    await tester.pumpAndSettle();
    for (final label in [
      'Acknowledge',
      'Start work',
      'Count shelf one',
      'Save progress and checklist',
      'Submit work report'
    ]) {
      final button = find.text(label);
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
    }
    await tester.enterText(find.byType(TextFormField), 'Counted and confirmed');
    await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Submit work report').last);
    await tester
        .tap(find.widgetWithText(FilledButton, 'Submit work report').last);
    await tester.pumpAndSettle();
    expect(actions, ['acknowledge', 'start', 'progress', 'submit']);
    expect(find.textContaining('Submitted'), findsOneWidget);
    expect(find.text('Approve'), findsNothing);
  });
}
