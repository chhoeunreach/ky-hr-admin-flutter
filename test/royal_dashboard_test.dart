import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cnattendance/data/source/network/model/attendancestatus/AttendanceStatus.dart';
import 'package:cnattendance/data/source/network/model/attendancestatus/AttendanceStatusResponse.dart';
import 'package:cnattendance/model/banner_slideshow_config.dart';
import 'package:cnattendance/model/home_banner_config.dart';
import 'package:cnattendance/models/monthly_attendance_summary.dart';
import 'package:cnattendance/provider/dashboardprovider.dart';
import 'package:cnattendance/provider/prefprovider.dart';
import 'package:cnattendance/screen/dashboard/dashboard_screen.dart';
import 'package:cnattendance/theme/app_theme_data.dart';
import 'package:cnattendance/theme/app_theme_mode.dart';
import 'package:cnattendance/theme/theme_provider.dart';
import 'package:cnattendance/theme/theme_layout.dart';
import 'package:cnattendance/widget/homescreen/checkattendance.dart';
import 'package:cnattendance/widget/homescreen/home_model_view.dart';
import 'package:cnattendance/widget/homescreen/royal_dashboard_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:persistent_bottom_nav_bar_v2/persistent_bottom_nav_bar_v2.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/chat_storage_test_env.dart';

class _QrPreference extends PrefProvider {
  @override
  String get attendanceType => 'QR';
}

class _AttendanceProvider extends DashboardProvider {
  _AttendanceProvider() {
    attendanceMethods = ['QR'];
    features = {'attendance': '1'};
    animated = false;
    workspaceLatitude = 11.5;
    workspaceLongitude = 104.8;
    workspaceRadiusMeters = 50;
    isWorkspaceRadiusEnabled = true;
    isAttendanceMapEnabled = false;
  }

  final distance = Completer<double?>();
  int distanceRequests = 0;

  @override
  Future<double?> getWorkspaceDistanceMeters({bool forceHighAccuracy = false}) {
    distanceRequests++;
    return distance.future;
  }
}

class _SubmissionProvider extends _AttendanceProvider {
  final submission = Completer<AttendanceStatusResponse>();
  int submissions = 0;

  @override
  Future<AttendanceStatusResponse> verifyAttendanceApi(
    String type,
    String note, {
    String attendanceStatus = '',
    String identifier = '',
    File? attendanceSelfie,
    String offlineRequestId = '',
    DateTime? recordedAt,
  }) {
    expect(type, 'qr');
    expect(identifier, 'test attendance code');
    expect(attendanceStatus, isEmpty);
    expect(offlineRequestId, isNotEmpty);
    submissions++;
    return submission.future;
  }
}

void _mockCameraPermission() {
  const scanner =
      MethodChannel('dev.steenbakker.mobile_scanner/scanner/method');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
      scanner,
      (call) async => switch (call.method) {
            'state' => 0,
            'request' => false,
            _ => null,
          });
  addTearDown(() => messenger.setMockMethodCallHandler(scanner, null));
}

Widget _app(Widget child,
        {required DashboardProvider dashboard, Locale? locale}) =>
    MultiProvider(
      providers: [
        ChangeNotifierProvider<DashboardProvider>.value(value: dashboard),
        ChangeNotifierProvider<PrefProvider>(create: (_) => _QrPreference()),
      ],
      child: MaterialApp(
        locale: locale,
        builder: EasyLoading.init(),
        supportedLocales: const [Locale('en'), Locale('km')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: AppThemeData.themeData(AppThemeMode.royalBlueGold),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

void _loadLanguage(String code) {
  Localization.load(
    jsonDecode(File('assets/i18n/$code.json').readAsStringSync())
        as Map<String, dynamic>,
  );
}

Future<void> _setSize(WidgetTester tester, double width) async {
  await tester.binding.setSurfaceSize(Size(width, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Widget _home(WidgetTester tester,
    {HomeBannerConfig? banner, bool loading = false}) {
  final clock = ValueNotifier(DateTime.utc(2026, 11, 18, 1, 30));
  final animation = AnimationController(vsync: tester);
  addTearDown(clock.dispose);
  addTearDown(animation.dispose);
  return HomeModelView(
    clockNow: clock,
    summary: null,
    pulseController: animation,
    animated: false,
    onAttendanceTap: () {},
    onRefreshZone: () {},
    allowedDistanceMeters: 50,
    distanceMeters: null,
    isInZone: false,
    isRefreshingZone: false,
    attendanceList: const {},
    bannerConfig: banner,
    dashboardLoading: loading,
  );
}

MockClient _api() => MockClient((request) async {
      final path = request.url.path;
      final Object data;
      if (path.contains('banner-slideshow')) {
        data = {
          'slides': [
            {'id': 'first', 'title': 'First banner', 'enabled': true},
            {'id': 'second', 'title': 'Second banner', 'enabled': true},
          ],
          'intervalSeconds': 2,
        };
      } else if (path.endsWith('/quotes')) {
        data = {
          'quotes': [
            {
              'id': 'quote',
              'text': 'វិន័យល្អ នាំមកនូវភាពជោគជ័យ',
              'translation': 'Good discipline leads to success',
            },
          ],
        };
      } else if (path.endsWith('/social-stories')) {
        data = [
          {
            'author': {'name': 'Story author'},
            'stories': [
              {'media_type': 'text', 'caption': 'Story caption'}
            ],
          },
        ];
      } else if (path.endsWith('/home-highlights')) {
        data = [
          {'id': 1, 'title': 'Company highlight'},
        ];
      } else {
        return http.Response('{}', 404);
      }
      return http.Response.bytes(utf8.encode(jsonEncode({'data': data})), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });

void main() {
  setUpAll(ChatStorageTestEnv.install);
  tearDownAll(ChatStorageTestEnv.uninstall);
  setUp(() {
    _loadLanguage('en');
    SharedPreferences.setMockInitialValues({'app_url': '/test/'});
  });

  test('theme selection survives a preferences reload', () async {
    final selected = ThemeProvider();
    addTearDown(selected.dispose);
    await selected.setMode(AppThemeMode.royalBlueGold);
    expect(
        (await SharedPreferences.getInstance())
            .getString(ThemeProvider.storageKey),
        'royal_blue_gold');
    final reloaded = ThemeProvider();
    addTearDown(reloaded.dispose);
    await reloaded.load();
    expect(reloaded.mode, AppThemeMode.royalBlueGold);
  });

  test('Royal Blue & Gold adds a mode alongside every existing theme',
      () async {
    const existingIds = {
      'light',
      'dark',
      'ky_enterprise',
      'neo_glass',
      'premium_gradient',
      'amoled',
      'sunset',
      'ocean_blue',
      'forest_green',
      'royal_purple',
      'copper_brown',
      'rose_pink',
      'khmer_heritage',
    };
    expect(
      AppThemeMode.values.map((mode) => mode.id).toSet(),
      {...existingIds, 'royal_blue_gold'},
    );
    expect(AppThemeData.themes.keys.toSet(), AppThemeMode.values.toSet());
    for (final id in existingIds) {
      expect(AppThemeData.info(AppThemeModeX.fromId(id)).id, id);
    }

    SharedPreferences.setMockInitialValues({
      ThemeProvider.storageKey: 'khmer_heritage',
    });
    final provider = ThemeProvider();
    addTearDown(provider.dispose);
    await provider.load();
    expect(provider.mode, AppThemeMode.khmerHeritage);
    expect(
        (await SharedPreferences.getInstance())
            .getString(ThemeProvider.storageKey),
        'khmer_heritage');
    const heritageAccent = Color(0xffb58b39);
    const royalAccent = Color(0xffffd700);
    await provider.saveLayout(
      AppThemeMode.khmerHeritage,
      const ThemeLayout.defaults()
          .setColors(background: null, accent: heritageAccent),
    );
    await provider.saveLayout(
      AppThemeMode.royalBlueGold,
      const ThemeLayout.defaults()
          .setColors(background: null, accent: royalAccent),
    );
    expect(provider.mode, AppThemeMode.khmerHeritage);
    expect(provider.layout.accent, heritageAccent);
    await provider.setMode(AppThemeMode.royalBlueGold);
    expect(provider.layout.accent, royalAccent);
    await provider.setMode(AppThemeMode.khmerHeritage);
    expect(provider.layout.accent, heritageAccent);
    expect(
      AppThemeData.info(AppThemeMode.royalBlueGold).name,
      'Royal Blue & Gold',
    );
  });

  test('banner publication dates and action copy round-trip', () {
    final active = BannerSlide.fromJson({
      'id': 'campaign',
      'title': 'Campaign',
      'subtitle': 'November',
      'actionLabel': 'Open',
      'startsAt': '2026-11-18T00:00:00Z',
      'endsAt': '2026-11-19T00:00:00Z',
      'enabled': true,
    });
    expect(active.isPublished(DateTime.utc(2026, 11, 17)), isFalse);
    expect(active.isPublished(DateTime.utc(2026, 11, 18)), isTrue);
    expect(active.isPublished(DateTime.utc(2026, 11, 19)), isFalse);
    expect(BannerSlide.fromJson(active.toJson()).subtitle, 'November');
  });

  for (final width in [320.0, 360.0, 390.0, 430.0]) {
    testWidgets('Royal dashboard lays out Khmer at width $width',
        (tester) async {
      _loadLanguage('km');
      await _setSize(tester, width);
      final dashboard = _AttendanceProvider();
      addTearDown(dashboard.dispose);
      final client = _api();
      addTearDown(client.close);
      await http.runWithClient(() async {
        await tester.pumpWidget(_app(
          _home(
            tester,
            loading: true,
            banner: const HomeBannerConfig(
              bannerTitle: 'ប្រព័ន្ធគ្រប់គ្រងធនធានមនុស្សសម្រាប់បុគ្គលិកទាំងអស់',
              quote: 'វិន័យល្អ នាំមកនូវភាពជោគជ័យ និងការទទួលខុសត្រូវ',
            ),
          ),
          dashboard: dashboard,
          locale: const Locale('km'),
        ));
        await tester.pump();
        expect(find.byType(RoyalClockCard), findsOneWidget);
        expect(find.byType(RoyalQuotation), findsOneWidget);
        expect(find.byType(RoyalAttendanceScanner), findsOneWidget);
        expect(find.text('គោលដៅប្រាក់រង្វាន់ប្រចាំខែ'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => client);
    });
  }

  testWidgets(
      'banner pauses, wraps by swipe, and stays independent of quotations',
      (tester) async {
    await _setSize(tester, 390);
    final dashboard = DashboardProvider()
      ..features = {
        'social_feed.stories.view': '1',
      };
    addTearDown(dashboard.dispose);
    final client = _api();
    addTearDown(client.close);
    await http.runWithClient(() async {
      await tester.pumpWidget(_app(_home(tester), dashboard: dashboard));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('First banner'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Good discipline leads to success'), findsOneWidget,
          reason: tester
              .widgetList<Text>(find.byType(Text))
              .map((text) => text.data)
              .join(' | '));
      expect(find.text('Story author'), findsOneWidget);

      final canvas = find.byKey(const ValueKey('home-banner-canvas'));
      final hold = await tester.startGesture(tester.getCenter(canvas));
      await tester.pump(const Duration(seconds: 6));
      expect(find.text('First banner'), findsOneWidget);
      await hold.up();
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('First banner'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Second banner'), findsOneWidget);
      await tester.drag(canvas, const Offset(-100, 0));
      await tester.pumpAndSettle();
      expect(find.text('First banner'), findsOneWidget);

      final highlightsTab = find.widgetWithText(OutlinedButton, 'Highlights');
      await tester.ensureVisible(highlightsTab);
      await tester.tap(highlightsTab);
      await tester.pumpAndSettle();
      expect(find.text('Company highlight'), findsOneWidget);
      expect(find.text('Story author'), findsNothing);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Stories'));
      await tester.pumpAndSettle();
      expect(find.text('Company highlight'), findsNothing);
      expect(find.text('Story author'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
  });

  for (final distance in [10.0, 65.0, null]) {
    testWidgets('scanner preflight deduplicates taps with GPS result $distance',
        (tester) async {
      await _setSize(tester, 390);
      final dashboard = _AttendanceProvider();
      addTearDown(dashboard.dispose);
      _mockCameraPermission();
      final client = _api();
      addTearDown(client.close);
      await http.runWithClient(() async {
        await tester.pumpWidget(
          _app(const CheckAttendance(), dashboard: dashboard),
        );
        await tester.pump(const Duration(milliseconds: 500));
        final action = find.byIcon(Icons.qr_code_scanner_rounded);
        await tester.ensureVisible(action);
        await tester.tap(action);
        await tester.tap(action);
        await tester.pump(const Duration(milliseconds: 500));
        expect(dashboard.distanceRequests, 1);
        expect(find.byType(AlertDialog), findsNothing);
        dashboard.distance.complete(distance);
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));
        if (distance == 10) {
          expect(find.byType(AlertDialog), findsOneWidget);
          expect(find.text('Camera permission is required to scan attendance.'),
              findsOneWidget);
        } else {
          expect(find.byType(AlertDialog), findsNothing);
          expect(find.byType(Dialog), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => client);
    });
  }

  testWidgets('attendance remains locked through submission and result',
      (tester) async {
    await _setSize(tester, 390);
    _mockCameraPermission();
    final dashboard = _SubmissionProvider()..distance.complete(10);
    addTearDown(dashboard.dispose);
    final client = _api();
    addTearDown(client.close);
    await http.runWithClient(() async {
      await tester
          .pumpWidget(_app(const CheckAttendance(), dashboard: dashboard));
      await tester.pump(const Duration(milliseconds: 500));
      final action = find.byIcon(Icons.qr_code_scanner_rounded);
      await tester.ensureVisible(action);
      await tester.tap(action);
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      final cameraDialog = find.byType(AlertDialog);
      expect(cameraDialog, findsOneWidget);
      Navigator.of(tester.element(cameraDialog)).pop('test attendance code');
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(dashboard.submissions, 1);
      expect(
          tester
              .widget<RoyalAttendanceScanner>(
                  find.byType(RoyalAttendanceScanner))
              .onTap,
          isNull);
      dashboard.submission.complete(AttendanceStatusResponse(
        status: true,
        message: 'Recorded by server',
        statusCode: 200,
        data: AttendanceStatus(
          checkInAt: '08:00',
          checkOutAt: '-',
          productiveTimeInMin: 0,
        ),
      ));
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(find.text('Recorded by server'), findsOneWidget);
      expect(dashboard.submissions, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
  });

  testWidgets('Royal navigation selects the attendance history tab at 320 dp',
      (tester) async {
    await _setSize(tester, 320);
    final controller = PersistentTabController();
    addTearDown(controller.dispose);
    const titles = [
      'Home',
      'Social Feed',
      'Repair',
      'Leave',
      'Attendance',
      'More'
    ];
    await tester.pumpWidget(MaterialApp(
      theme: AppThemeData.themeData(AppThemeMode.royalBlueGold),
      home: PersistentTabView(
        controller: controller,
        tabs: [
          for (final title in titles)
            PersistentTabConfig(
              screen: Scaffold(body: Text('$title destination')),
              item: ItemConfig(
                  icon: const Icon(Icons.circle_outlined), title: title),
            ),
        ],
        navBarBuilder: (config) => DashboardNavigationBar(
          navBarConfig: config,
          visibleTabs: const [0, 1, 2, 3, 4, 5],
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Home destination'), findsOneWidget);
    expect(find.byIcon(Icons.qr_code_scanner_rounded), findsNothing);
    await tester.tap(find.text('Attendance'));
    await tester.pumpAndSettle();
    expect(controller.index, 4);
    expect(find.text('Attendance destination'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('bonus distinguishes loading, empty data, and a backend target',
      (tester) async {
    Widget card({bool loading = false, MonthlyAttendanceSummary? summary}) =>
        MaterialApp(
          theme: AppThemeData.themeData(AppThemeMode.royalBlueGold),
          home: Scaffold(
            body: RoyalAttendanceHighlights(
              summary: summary,
              employees: const [],
              quote: null,
              onQuote: () {},
              loading: loading,
            ),
          ),
        );
    await tester.pumpWidget(card(loading: true));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.pumpWidget(card());
    expect(find.text('—'), findsNWidgets(2));
    await tester.pumpWidget(card(
      summary: const MonthlyAttendanceSummary(
        month: '2026-11',
        lateCount: 3,
        deduction: 0,
        bonusTarget: 35,
        completedDays: 10,
        workingDays: 20,
      ),
    ));
    expect(find.text(r'$35.00'), findsOneWidget);
    expect(find.text('Monthly bonus target'), findsOneWidget);
  });
}
