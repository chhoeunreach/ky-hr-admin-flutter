import 'package:cnattendance/features/daily_records/branch_mission_editor.dart';
import 'package:cnattendance/features/daily_records/branch_route_model.dart';
import 'package:cnattendance/features/daily_records/branch_route_storage.dart';
import 'package:cnattendance/features/daily_records/daily_records_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Branch Route Lifecycle & Offline Storage', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('RouteCheckpoint serializes and deserializes correctly', () {
      final now = DateTime.now();
      final cp = RouteCheckpoint(
        id: 'cp_1',
        branchName: 'សាខាទី២ - សែនសុខ (Sen Sok)',
        arrivedAt: now,
        latitude: 11.5832,
        longitude: 104.8912,
        notes: 'ថតរូបម៉ូដសម្លៀកបំពាក់ថ្មីបាន ១៥ ម៉ូដ',
        photoPaths: ['/tmp/photo1.jpg', '/tmp/photo2.jpg'],
      );

      final map = cp.toMap();
      expect(map['id'], equals('cp_1'));
      expect(map['branch_name'], contains('សែនសុខ'));
      expect(map['latitude'], equals(11.5832));
      expect(map['notes'], contains('១៥ ម៉ូដ'));
      expect(map['photo_paths'].length, equals(2));

      final restored = RouteCheckpoint.fromMap(map);
      expect(restored.id, equals('cp_1'));
      expect(restored.branchName, equals(cp.branchName));
      expect(restored.latitude, equals(11.5832));
      expect(restored.photoPaths.length, equals(2));
    });

    test('BranchRoute calculates duration and formatted timer strings', () {
      final startTime = DateTime.now().subtract(const Duration(hours: 2, minutes: 35, seconds: 10));
      final route = BranchRoute(
        id: 'route_101',
        purpose: 'ចុះថតរូប និងវីដេអូប្រចាំសប្តាហ៍',
        originBranch: 'សាខាទី១ - ទួលគោក (Toul Kork)',
        targetBranches: ['សាខាទី២ - សែនសុខ (Sen Sok)', 'សាខាទី៣ - ច្បារអំពៅ (Chbar Ampov)'],
        status: 'processing',
        startTime: startTime,
        startLatitude: 11.5682,
        startLongitude: 104.8921,
        startSelfiePath: '/tmp/start_selfie.jpg',
      );

      expect(route.isProcessing, isTrue);
      expect(route.isCompleted, isFalse);
      expect(route.currentDuration.inMinutes, greaterThanOrEqualTo(155));
      expect(route.formattedDuration, contains('2 ម៉ោង'));
      expect(route.liveTimerString, contains('02:35'));
    });

    test('BranchRoute serializes and deserializes supporting photos, files, and links', () {
      final route = BranchRoute(
        id: 'route_support_1',
        purpose: 'ចុះថតរូបផលិតផល 📸 ហាងទួលគោក',
        originBranch: 'សាខាទី១ - ទួលគោក (Toul Kork)',
        targetBranches: [],
        status: 'processing',
        startTime: DateTime.now(),
        supportingPhotos: ['/tmp/compressed_1.jpg', '/tmp/compressed_2.jpg'],
        supportingFiles: ['/tmp/catalog.pdf', '/tmp/price.xlsx'],
        supportingLinks: ['https://drive.google.com/test', 'https://t.me/channel'],
      );

      final map = route.toMap();
      expect(map['supporting_photos'].length, equals(2));
      expect(map['supporting_files'].length, equals(2));
      expect(map['supporting_links'].length, equals(2));

      final restored = BranchRoute.fromMap(map);
      expect(restored.supportingPhotos.first, equals('/tmp/compressed_1.jpg'));
      expect(restored.supportingFiles.last, equals('/tmp/price.xlsx'));
      expect(restored.supportingLinks.first, contains('drive.google.com'));
    });

    test('BranchRouteStorage handles active route lifecycle and history archiving', () async {
      // 1. Initially no active route
      expect(await BranchRouteStorage.getActiveRoute(), isNull);

      // 2. Start mission: save active route with status 'processing'
      final route = BranchRoute(
        id: 'route_202',
        purpose: 'ត្រួតពិនិត្យស្តុក និងថតទិដ្ឋភាពហាង',
        originBranch: 'សាខាទី១ - ទួលគោក (Toul Kork)',
        targetBranches: ['សាខាទី២ - សែនសុខ (Sen Sok)'],
        status: 'processing',
        startTime: DateTime.now(),
        startLatitude: 11.5682,
        startLongitude: 104.8921,
        startSelfiePath: '/tmp/start.jpg',
      );

      await BranchRouteStorage.saveActiveRoute(route);
      final active = await BranchRouteStorage.getActiveRoute();
      expect(active, isNotNull);
      expect(active!.id, equals('route_202'));
      expect(active.status, equals('processing'));
      expect(active.startLatitude, equals(11.5682));

      // 3. Add intermediate checkpoint during mission
      final cp = RouteCheckpoint(
        id: 'cp_202_1',
        branchName: 'សាខាទី២ - សែនសុខ (Sen Sok)',
        arrivedAt: DateTime.now(),
        latitude: 11.5950,
        longitude: 104.8820,
        notes: 'បានថតរូបផលិតផលរួចរាល់',
        photoPaths: ['/tmp/prod1.jpg'],
      );

      final updatedRoute = active.copyWith(checkpoints: [cp]);
      await BranchRouteStorage.saveActiveRoute(updatedRoute);

      final activeWithCp = await BranchRouteStorage.getActiveRoute();
      expect(activeWithCp!.checkpoints.length, equals(1));
      expect(activeWithCp.checkpoints.first.branchName, contains('សែនសុខ'));

      // 4. Complete route: status becomes 'completed', clear active, archive to history
      final completedRoute = activeWithCp.copyWith(
        status: 'completed',
        endTime: DateTime.now().add(const Duration(minutes: 50)),
        endLatitude: 11.5952,
        endLongitude: 104.8822,
        endSelfiePath: '/tmp/end.jpg',
        finalSummary: 'បានបញ្ចប់គ្រប់គោលដៅ',
        totalMinutes: 50,
      );

      await BranchRouteStorage.saveToHistory(completedRoute);
      await BranchRouteStorage.clearActiveRoute();

      // Verify active is now null
      expect(await BranchRouteStorage.getActiveRoute(), isNull);

      // Verify history contains completed route
      final history = await BranchRouteStorage.getRouteHistory();
      expect(history.length, equals(1));
      expect(history.first.id, equals('route_202'));
      expect(history.first.isCompleted, isTrue);
      expect(history.first.checkpoints.length, equals(1));
      expect(history.first.finalSummary, equals('បានបញ្ចប់គ្រប់គោលដៅ'));
    });

    testWidgets('BranchMissionEditor renders Stage 1 start view with server time and clean UI', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(MaterialApp(
        home: BranchMissionEditor(api: DailyRecordsApi()),
      ));
      await tester.pumpAndSettle();

      expect(find.text('ចាប់ផ្តើមបេសកកម្មតាមសាខា'), findsOneWidget);
      expect(find.text('គោលបំណងបេសកកម្ម (Mission Purpose) *'), findsOneWidget);
      expect(find.text('សាខាចេញដំណើរ (Auto Branch)'), findsOneWidget);
      expect(find.text('ម៉ោងចេញដំណើរ (Server Time)'), findsOneWidget);
      expect(find.text('Server Time'), findsOneWidget);
      expect(find.text('ថត Selfie & ចាប់ផ្តើមបេសកកម្ម'), findsOneWidget);

      // Verify Mandatory Selfie field is removed from form
      expect(find.text('ថតរូប Selfie ផ្ទាល់ (Front Camera)'), findsNothing);
      expect(find.text('ថតរូប Selfie ចេញដំណើរ (Mandatory Selfie)'), findsNothing);

      // Verify Purpose rich toolbar items (Image, File, Emoji, Link)
      expect(find.text('រូបភាព'), findsOneWidget);
      expect(find.text('ឯកសារ'), findsOneWidget);
      expect(find.text('Emoji'), findsOneWidget);
      expect(find.text('តំណភ្ជាប់'), findsOneWidget);

      // Verify Departure Time is read-only (no edit button)
      expect(find.text('កែប្រែ'), findsNothing);

      // Verify Target Branches is hidden
      expect(find.text('សាខាគោលដៅគ្រោងទុក (Target Branches)'), findsNothing);

      // Verify GPS status is hidden (runs in background)
      expect(find.text('កំពុងចាប់ទីតាំង GPS...'), findsNothing);
      expect(find.text('GPS ដំណើរការស្វ័យប្រវត្តក្នុង background'), findsNothing);
    });

    testWidgets('BranchMissionEditor inserts emoji into mission purpose', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(MaterialApp(
        home: BranchMissionEditor(api: DailyRecordsApi()),
      ));
      await tester.pumpAndSettle();

      // Tap emoji toolbar button to reveal tray
      await tester.tap(find.text('Emoji'));
      await tester.pumpAndSettle();

      expect(find.text('📍'), findsOneWidget);
      await tester.tap(find.text('📍'));
      await tester.pumpAndSettle();

      expect(find.text('📍'), findsWidgets);
    });

    testWidgets('BranchMissionEditor validates mission purpose before launching selfie and starting', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(MaterialApp(
        home: BranchMissionEditor(api: DailyRecordsApi()),
      ));
      await tester.pumpAndSettle();

      // Tap start button while purpose is empty
      await tester.tap(find.text('ថត Selfie & ចាប់ផ្តើមបេសកកម្ម'));
      await tester.pumpAndSettle();

      expect(find.text('សូមបញ្ចូលគោលបំណងបេសកកម្ម!'), findsOneWidget);
    });

    testWidgets('BranchMissionEditor renders Stage 2 processing view when active route is in transit (Departed)', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final active = BranchRoute(
        id: 'route_proc_1',
        purpose: 'ថតរូបផ្សព្វផ្សាយសាខា',
        originBranch: 'សាខាទី១ - ទួលគោក (Toul Kork)',
        targetBranches: ['សាខាទី២ - សែនសុខ (Sen Sok)'],
        status: 'processing',
        startTime: DateTime.now().subtract(const Duration(minutes: 15)),
      );
      await BranchRouteStorage.saveActiveRoute(active);

      await tester.pumpWidget(MaterialApp(
        home: BranchMissionEditor(api: DailyRecordsApi()),
      ));
      await tester.pumpAndSettle();

      expect(find.text('បេសកកម្មកំពុងដំណើរការ'), findsOneWidget);
      expect(find.text('បេសកកម្មកំពុងដំណើរការ (Processing)'), findsOneWidget);
      expect(find.text('ថតរូបផ្សព្វផ្សាយសាខា'), findsOneWidget);
      // When departed, only "មកដល់សាខា" is allowed
      expect(find.text('មកដល់សាខា (Arrive at Branch)'), findsOneWidget);
      expect(find.text('ចេញបន្ត (Depart)'), findsNothing);
      expect(find.text('បញ្ចប់បេសកកម្ម'), findsNothing);
      expect(find.textContaining('កំពុងធ្វើដំណើរ (ចេញពី៖ សាខាទី១ - ទួលគោក (Toul Kork))'), findsOneWidget);
    });

    testWidgets('BranchMissionEditor renders Stage 2 processing view when arrived at branch', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final active = BranchRoute(
        id: 'route_proc_2',
        purpose: 'ថតរូបផ្សព្វផ្សាយសាខា',
        originBranch: 'សាខាទី១ - ទួលគោក (Toul Kork)',
        targetBranches: ['សាខាទី២ - សែនសុខ (Sen Sok)'],
        status: 'processing',
        startTime: DateTime.now().subtract(const Duration(minutes: 40)),
        checkpoints: [
          RouteCheckpoint(
            id: 'cp_arr_1',
            branchName: 'សាខាទី២ - សែនសុខ (Sen Sok)',
            actionType: 'arrival',
            arrivedAt: DateTime.now().subtract(const Duration(minutes: 20)),
            notes: 'បានមកដល់សាខាសែនសុខ',
          ),
        ],
      );
      await BranchRouteStorage.saveActiveRoute(active);

      await tester.pumpWidget(MaterialApp(
        home: BranchMissionEditor(api: DailyRecordsApi()),
      ));
      await tester.pumpAndSettle();

      expect(find.text('បេសកកម្មកំពុងដំណើរការ'), findsOneWidget);
      expect(find.textContaining('បានមកដល់៖ សាខាទី២ - សែនសុខ (Sen Sok)'), findsOneWidget);
      // When arrived, user can depart to next branch or finish mission
      expect(find.text('ចេញបន្ត (Depart)'), findsOneWidget);
      expect(find.text('បញ្ចប់បេសកកម្ម'), findsOneWidget);
      expect(find.text('មកដល់សាខា (Arrive at Branch)'), findsNothing);
      // Checkpoint card tag
      expect(find.text('មកដល់'), findsOneWidget);
      expect(find.text('បានមកដល់សាខាសែនសុខ'), findsOneWidget);
    });

    test('BranchRoute strict sequential state machine (ចេញ -> មកដល់ -> ចេញ -> បញ្ចប់)', () {
      final startTime = DateTime.now().subtract(const Duration(hours: 1));
      // 1. Mission starts: employee departs from origin
      var route = BranchRoute(
        id: 'route_sm_1',
        purpose: 'ការងារចល័ត',
        originBranch: 'សាខាទី១ - ទួលគោក (Toul Kork)',
        targetBranches: [],
        status: 'processing',
        startTime: startTime,
      );

      expect(route.latestAction, equals('departure'));
      expect(route.isDeparted, isTrue);
      expect(route.isArrived, isFalse);
      expect(route.currentBranchName, equals('សាខាទី១ - ទួលគោក (Toul Kork)'));
      expect(route.isProcessing, isTrue); // runs indefinitely without finish

      // 2. Next action MUST be Arrival
      final arr1 = RouteCheckpoint(
        id: 'cp_1',
        branchName: 'សាខាទី២ - សែនសុខ (Sen Sok)',
        actionType: 'arrival',
        arrivedAt: startTime.add(const Duration(minutes: 25)),
      );
      route = route.copyWith(checkpoints: [...route.checkpoints, arr1]);

      expect(route.latestAction, equals('arrival'));
      expect(route.isDeparted, isFalse);
      expect(route.isArrived, isTrue);
      expect(route.currentBranchName, equals('សាខាទី២ - សែនសុខ (Sen Sok)'));

      // 3. Employee departs from Sen Sok to next branch
      final dep1 = RouteCheckpoint(
        id: 'cp_2',
        branchName: 'សាខាទី២ - សែនសុខ (Sen Sok)',
        actionType: 'departure',
        arrivedAt: startTime.add(const Duration(minutes: 50)),
      );
      route = route.copyWith(checkpoints: [...route.checkpoints, dep1]);

      expect(route.latestAction, equals('departure'));
      expect(route.isDeparted, isTrue);
      expect(route.isArrived, isFalse);
      expect(route.currentBranchName, equals('សាខាទី២ - សែនសុខ (Sen Sok)'));

      // 4. Employee arrives at Chbar Ampov
      final arr2 = RouteCheckpoint(
        id: 'cp_3',
        branchName: 'សាខាទី៣ - ច្បារអំពៅ (Chbar Ampov)',
        actionType: 'arrival',
        arrivedAt: startTime.add(const Duration(minutes: 80)),
      );
      route = route.copyWith(checkpoints: [...route.checkpoints, arr2]);

      expect(route.latestAction, equals('arrival'));
      expect(route.isDeparted, isFalse);
      expect(route.isArrived, isTrue);
      expect(route.currentBranchName, equals('សាខាទី៣ - ច្បារអំពៅ (Chbar Ampov)'));

      // 5. Still processing indefinitely until finish is triggered
      expect(route.isProcessing, isTrue);
      expect(route.isCompleted, isFalse);
    });

    testWidgets('BranchMissionEditor auto-selects origin branch from system preferences', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_branch', 'Sen Sok');

      await tester.pumpWidget(MaterialApp(
        home: BranchMissionEditor(api: DailyRecordsApi()),
      ));
      await tester.pumpAndSettle();

      expect(find.text('ប្រព័ន្ធកំណត់ស្វ័យប្រវត្តិ'), findsOneWidget);
      expect(find.text('សាខាទី២ - សែនសុខ (Sen Sok)'), findsOneWidget);
    });
  });
}
