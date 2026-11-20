import 'dart:convert';
import 'dart:typed_data';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/features/daily_records/daily_records_api.dart';
import 'package:cnattendance/features/daily_records/daily_summaries.dart';
import 'package:cnattendance/features/daily_records/quick_create.dart';
import 'package:cnattendance/features/daily_records/record_widgets.dart';
import 'package:cnattendance/features/daily_records/work_record_editor.dart';
import 'package:cnattendance/screen/dashboard/dashboard_screen.dart';
import 'package:cnattendance/theme/app_theme_data.dart';
import 'package:cnattendance/theme/app_theme_mode.dart';
import 'package:cnattendance/theme/theme_layout.dart';
import 'package:cnattendance/theme/theme_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:persistent_bottom_nav_bar_v2/persistent_bottom_nav_bar_v2.dart';
import 'package:provider/provider.dart';

class _Preferences extends Preferences {
  @override
  Future<String> getAppUrl({bool forceCheck = false}) async =>
      'https://example.test/';

  @override
  Future<String> getToken() async => 'token';
}

http.Response _data(RecordData data, [int code = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode({'data': data})), code,
        headers: {'Content-Type': 'application/json; charset=utf-8'});

DailyRecordsApi _api(Future<http.Response> Function(http.Request) response) =>
    DailyRecordsApi(preferences: _Preferences(), client: MockClient(response));

const _customerCatalog = {
  'categories': [
    {
      'id': 1,
      'name_en': 'Customer Issues',
      'name_km': 'បញ្ហាអតិថិជន',
      'fields': [
        {
          'key': 'customer',
          'label_en': 'Customer name',
          'label_km': 'ឈ្មោះអតិថិជន',
          'type': 'text',
          'required': false
        },
      ],
      'children': [
        {
          'id': 2,
          'name_en': 'Buyback request declined',
          'name_km': 'ហាងមិនអាចទិញចូល',
          'fields': [
            {
              'key': 'reason',
              'label_en': 'Reason',
              'label_km': 'មូលហេតុ',
              'type': 'select',
              'required': true,
              'options': ['Price disagreement']
            },
          ],
        },
      ],
    },
  ],
};

const _activityCatalog = {
  'categories': [
    {'id': 4, 'name_en': 'Sales', 'name_km': 'ការលក់', 'children': []},
  ],
};

Future<void> _choose(WidgetTester tester, Type type, String label,
    {int index = 0}) async {
  final field =
      find.byWidgetPredicate((widget) => widget.runtimeType == type).at(index);
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> _text(WidgetTester tester, String label, String value) async {
  final error = tester.widgetList<RecordFailure>(find.byType(RecordFailure));
  expect(error.map((failure) => failure.error), isEmpty);
  final field = find.widgetWithText(TextFormField, label);
  if (field.evaluate().isEmpty) {
    await tester.scrollUntilVisible(field, 200,
        scrollable: find.byType(Scrollable).first);
  }
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pump();
}

Future<void> _press(WidgetTester tester, String label) async {
  final finder = find.text(label);
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(finder, 200,
        scrollable: find.byType(Scrollable).first);
  }
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

class _CustomWorkTheme extends ThemeProvider {
  @override
  ThemeLayout get layout => const ThemeLayout.defaults().setColors(
        background: const Color(0xff787e82),
        accent: const Color(0xffd5af65),
      );
}

double _contrast(Color first, Color second) {
  final values = [first.computeLuminance(), second.computeLuminance()]..sort();
  return (values.last + .05) / (values.first + .05);
}

void _expectReadableScreen(WidgetTester tester, Color header) {
  final context = tester.element(find.byType(AppBar));
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  expect(theme.appBarTheme.backgroundColor, header);
  for (final (background, foreground) in [
    (header, theme.appBarTheme.titleTextStyle!.color!),
    (header, theme.appBarTheme.iconTheme!.color!),
    (theme.scaffoldBackgroundColor, scheme.onSurface),
    (scheme.surface, scheme.onSurfaceVariant),
    (theme.inputDecorationTheme.fillColor!, scheme.onSurface),
    (
      theme.inputDecorationTheme.fillColor!,
      theme.inputDecorationTheme.labelStyle!.color!
    ),
    (scheme.surface, scheme.primary),
    (scheme.primary, scheme.onPrimary),
  ]) {
    expect(_contrast(background, foreground), greaterThanOrEqualTo(4.5));
  }
}

void main() {
  for (final mode in AppThemeMode.values) {
    testWidgets('Daily Records routes stay readable in ${mode.name}',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _api((request) async {
        final path = request.url.path;
        if (path.endsWith('/capabilities')) {
          return _data({'work_records': true, 'review_reports': true});
        }
        if (path.endsWith('/catalog')) {
          return _data(request.url.queryParameters['kind'] == 'incident'
              ? _customerCatalog
              : _activityCatalog);
        }
        if (path.endsWith('/preview'))
          return _data({
            'records': {'data': []}
          });
        return _data({'data': []});
      });
      await tester.pumpWidget(MaterialApp(
        theme: AppThemeData.themeData(mode),
        home: Scaffold(floatingActionButton: CreateRecordButton(api: api)),
      ));
      for (final action in [
        'Daily Activity',
        'Incident Report',
        'Personal Note',
        'My Records',
        'My Tasks',
        'Daily Summary',
        'Review Reports',
      ]) {
        await tester.tap(find.byTooltip('Create Record'));
        await tester.pumpAndSettle();
        await _press(tester, action);
        _expectReadableScreen(
            tester, AppThemeData.info(mode).colors.primaryColor);
        expect(tester.takeException(), isNull, reason: action);
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
    });
  }

  testWidgets('Custom colors apply to the activity form and date picker',
      (tester) async {
    final theme = _CustomWorkTheme();
    addTearDown(theme.dispose);
    final api = _api((request) async {
      if (request.url.path.endsWith('/capabilities'))
        return _data({'work_records': true});
      if (request.url.path.endsWith('/catalog')) return _data(_activityCatalog);
      return _data({});
    });
    await tester.pumpWidget(ChangeNotifierProvider<ThemeProvider>.value(
      value: theme,
      child: MaterialApp(
        theme: theme.themeData,
        home: Scaffold(floatingActionButton: CreateRecordButton(api: api)),
      ),
    ));
    await tester.tap(find.byTooltip('Create Record'));
    await tester.pumpAndSettle();
    await _press(tester, 'Daily Activity');
    _expectReadableScreen(tester, theme.colors.primaryColor);
    expect(tester.takeException(), isNull, reason: 'Activity editor');
    await _press(tester, 'Activity date');
    final picker = tester.element(find.byType(DatePickerDialog));
    final scheme = Theme.of(picker).colorScheme;
    expect(_contrast(scheme.surfaceContainerHigh, scheme.onSurface),
        greaterThanOrEqualTo(4.5));
    expect(
        _contrast(scheme.primary, scheme.onPrimary), greaterThanOrEqualTo(4.5));
    expect(tester.takeException(), isNull);
  });

  test('Work record attachments preserve nested fields in multipart JSON',
      () async {
    final api = _api((request) async {
      expect(request.headers['Authorization'], 'Bearer token');
      expect(
          request.headers['content-type'], startsWith('multipart/form-data'));
      expect(request.body, contains('name="payload"'));
      expect(request.body, contains('"fields":{"reason":"Price dispute"}'));
      expect(request.body, contains('name="files[]"; filename="evidence.txt"'));
      expect(request.body, contains('Evidence text'));
      return _data({'id': 3}, 201);
    });
    final response = await api.postWork('work-records', {
      'kind': 'incident',
      'fields': {'reason': 'Price dispute'},
    }, files: [
      PlatformFile(
          name: 'evidence.txt',
          size: 13,
          bytes: Uint8List.fromList(utf8.encode('Evidence text'))),
    ]);
    expect(response['id'], 3);
  });

  testWidgets('The existing launcher sits above More when tabs are reordered',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: PersistentTabView(
        tabs: [
          for (final title in ['Home', 'More', 'Attendance'])
            PersistentTabConfig(
              screen: Text('$title destination'),
              item: ItemConfig(icon: const Icon(Icons.circle), title: title),
            ),
        ],
        floatingActionButton: const CreateRecordButton(),
        floatingActionButtonLocation:
            const AboveMoreLocation(slot: 1, slots: 3),
        navBarBuilder: (config) => DashboardNavigationBar(
          navBarConfig: config,
          visibleTabs: const [0, 1, 2],
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final button = tester.getRect(find.byType(CreateRecordButton));
    final more = tester.getRect(find.text('More'));
    expect(button.center.dx, closeTo(more.center.dx, 1));
    expect(button.bottom, lessThan(more.top));
    expect(find.byType(CreateRecordButton), findsOneWidget);
  });

  testWidgets(
      'Khmer Quick Create exposes classified work and authorized mobile review',
      (tester) async {
    final api = _api((request) async => _data({
          'work_records': true,
          'assign_tasks': false,
          'review_reports': true,
        }));
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('km'),
      supportedLocales: const [Locale('km'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Scaffold(floatingActionButton: CreateRecordButton(api: api)),
    ));
    await tester.tap(find.byTooltip('Create Record'));
    await tester.pumpAndSettle();
    expect(find.text('កត់ត្រាសកម្មភាពការងារ'), findsOneWidget);
    expect(find.text('រាយការណ៍បញ្ហា / ហេតុការណ៍'), findsOneWidget);
    expect(find.text('ពិនិត្យរបាយការណ៍'), findsOneWidget);
    expect(find.text('ប្រគល់ការងារឱ្យបុគ្គលិក'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Activity submits a real category and work result',
      (tester) async {
    RecordData? submitted;
    final api = _api((request) async {
      final route = request.url.path;
      if (route.endsWith('/catalog')) return _data(_activityCatalog);
      if (route.endsWith('/work-records')) {
        submitted = jsonDecode(request.body) as RecordData;
        return _data({'id': 15}, 201);
      }
      return _data({'draft': null});
    });
    await tester.pumpWidget(
        MaterialApp(home: WorkRecordEditor(api: api, kind: 'activity')));
    await tester.pumpAndSettle();
    await _text(tester, 'Title', 'Delivery follow-up');
    await _choose(tester, DropdownButtonFormField<int>, 'Sales');
    await _text(tester, 'Work performed', 'Confirmed the date');
    await _text(tester, 'Work result', 'Customer confirmed');
    await _press(tester, 'Save record');
    expect(submitted?['kind'], 'activity');
    expect(submitted?['category_id'], 4);
    expect(submitted?['result'], 'Customer confirmed');
    expect(submitted?['activity_date'], isNotEmpty);
  });

  testWidgets(
      'Incident restores a draft and validates the selected subcategory fields',
      (tester) async {
    RecordData? submitted;
    final api = _api((request) async {
      final route = request.url.path;
      if (route.endsWith('/catalog')) return _data(_customerCatalog);
      if (route.endsWith('/work-records')) {
        submitted = jsonDecode(request.body) as RecordData;
        return _data({'id': 16}, 201);
      }
      return _data({
        'draft': {
          'kind': 'incident',
          'title': 'Draft incident',
          'body': 'Customer asked about buyback',
          'occurred_at': '2026-11-20T13:00',
          'revision': 0,
        }
      });
    });
    await tester.pumpWidget(
        MaterialApp(home: WorkRecordEditor(api: api, kind: 'incident')));
    await tester.pumpAndSettle();
    expect(
        tester
            .widgetList<RecordFailure>(find.byType(RecordFailure))
            .map((failure) => failure.error),
        isEmpty);
    expect(find.text('Draft recovered'), findsOneWidget);
    expect(find.text('Draft incident'), findsOneWidget);
    expect(find.text('Customer name'), findsNothing);
    await _choose(tester, DropdownButtonFormField<int>, 'Customer Issues');
    expect(find.text('Customer name'), findsOneWidget);
    await _choose(
        tester, DropdownButtonFormField<int>, 'Buyback request declined',
        index: 1);
    await _choose(
        tester, DropdownButtonFormField<String>, 'Price disagreement');
    await _press(tester, 'Save record');
    expect(submitted?['subcategory_id'], 2);
    expect(submitted?['fields'], {'reason': 'Price disagreement'});
  });

  testWidgets(
      'Daily summary submits linked work rather than duplicating activity text',
      (tester) async {
    RecordData? submitted;
    final api = _api((request) async {
      if (request.method == 'POST') {
        submitted = jsonDecode(request.body) as RecordData;
        return _data({'id': 5});
      }
      return _data({
        'report': null,
        'records': {
          'data': [
            {'id': 6, 'kind': 'activity', 'title': 'Inventory count'}
          ]
        },
        'tasks': {'data': []},
      });
    });
    await tester.pumpWidget(
        MaterialApp(home: DailySummaryEditor(api: api, date: '2026-11-20')));
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        true);
    await _text(tester, 'Completed work summary', 'Finished the shift count');
    await _press(tester, 'Submit report');
    expect(submitted?['record_ids'], [6]);
    expect(submitted?['report_date'], '2026-11-20');
    expect(submitted?['summary'], 'Finished the shift count');
  });

  testWidgets(
      'Manager reviews the current summary version from the mobile inbox',
      (tester) async {
    var approved = false;
    final api = _api((request) async {
      if (request.url.path.endsWith('/summary-inbox')) {
        return _data({
          'data': [
            {
              'id': 5,
              'employee': 'Operations One',
              'report_date': '2026-11-20',
              'status': 'submitted'
            }
          ]
        });
      }
      if (request.method == 'POST') {
        final body = jsonDecode(request.body);
        expect(body['version'], 2);
        expect(body['action'], 'approve');
        approved = true;
      }
      return _data({
        'report': {
          'id': 5,
          'employee': 'Operations One',
          'report_date': '2026-11-20',
          'status': approved ? 'approved' : 'submitted',
          'version': 2
        },
        'selected_version': 2,
        'content': {'summary': 'Inventory counted'},
      });
    });
    await tester.pumpWidget(
        MaterialApp(home: DailySummariesScreen(api: api, manager: true)));
    await tester.pumpAndSettle();
    await _press(tester, 'Operations One');
    await _press(tester, 'Approve');
    expect(approved, true);
    expect(find.textContaining('Approved'), findsOneWidget);
  });
}
