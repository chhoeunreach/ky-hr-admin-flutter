import 'package:cnattendance/provider/dashboardprovider.dart';
import 'package:cnattendance/widget/customalertdialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Attendance Geofence Warning & Exception Test', () {
    test('AttendanceApiException stores error_code and data payload', () {
      const exception = AttendanceApiException(
        'បេសកកម្មរបស់អ្នកទៅកាន់ Branch B បានបញ្ចប់រួចរាល់ហើយ!',
        errorCode: 'BRANCH_ROUTE_COMPLETED',
        statusCode: 403,
        data: {
          'error_type': 'branch_route_completed',
          'attempted_branch': 'Branch B',
          'home_branch': 'Branch A',
          'distance_in_meter': 2450.5,
          'allowed_radius_in_meter': 100.0,
          'can_retry': false,
        },
      );

      expect(exception.statusCode, equals(403));
      expect(exception.errorCode, equals('BRANCH_ROUTE_COMPLETED'));
      expect(exception.data?['attempted_branch'], equals('Branch B'));
      expect(exception.data?['can_retry'], isFalse);
      expect(exception.toString(), contains('Branch B'));
    });

    testWidgets('CustomAlertDialog renders red warning icon and distance box when isWarning is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomAlertDialog(
              'វត្តមានស្ថិតនៅក្រៅបរិវេណសាខា',
              isWarning: true,
              distanceMeters: 1450,
              allowedRadiusMeters: 100,
              actionLabel: 'ផ្ទុក GPS ឡើងវិញ',
            ),
          ),
        ),
      );

      // Verify warning icon exists
      expect(find.byIcon(Icons.location_off_rounded), findsOneWidget);

      // Verify message and distance text exist
      expect(find.text('វត្តមានស្ថិតនៅក្រៅបរិវេណសាខា'), findsOneWidget);
      expect(find.text('1450 ម៉ែត្រ'), findsOneWidget);
      expect(find.text('100 ម៉ែត្រ'), findsOneWidget);
      expect(find.text('ផ្ទុក GPS ឡើងវិញ'), findsOneWidget);
    });
  });
}
