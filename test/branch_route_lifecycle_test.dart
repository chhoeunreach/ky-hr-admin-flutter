import 'package:cnattendance/features/daily_records/branch_route_model.dart';
import 'package:cnattendance/features/daily_records/branch_route_storage.dart';
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
      expect(route.formattedDuration, contains('២ ម៉ោង'));
      expect(route.liveTimerString, contains('02:35'));
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
  });
}
