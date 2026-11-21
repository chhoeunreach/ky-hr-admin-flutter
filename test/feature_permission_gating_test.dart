import 'dart:convert';
import 'dart:io';

import 'package:cnattendance/features/repair_price/providers/repair_price_provider.dart';
import 'package:cnattendance/features/repair_price/repositories/repair_price_repository.dart';
import 'package:cnattendance/provider/dashboardprovider.dart';
import 'package:cnattendance/widget/homescreen/royal_quick_actions.dart';
import 'package:cnattendance/widget/leavescreen/leavebutton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:provider/provider.dart';

class _PermissionsRepository extends RepairPriceRepository {
  _PermissionsRepository(this.permissions);

  Map<String, dynamic>? permissions;

  @override
  Future<Map<String, dynamic>?> fetchPermissions() async => permissions;
}

void main() {
  setUpAll(() {
    Localization.load(
      jsonDecode(File('assets/i18n/en.json').readAsStringSync())
          as Map<String, dynamic>,
    );
  });

  Future<void> pumpLeaveButton(
    WidgetTester tester,
    Map<String, String> features,
  ) async {
    final dashboard = DashboardProvider()..features = features;
    addTearDown(dashboard.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DashboardProvider>.value(value: dashboard),
        ],
        child: MaterialApp(
          home: Scaffold(body: LeaveButton()),
        ),
      ),
    );
  }

  testWidgets(
      'time leave button is hidden until the saveTimeLeaveRequest '
      'function is granted', (tester) async {
    await pumpLeaveButton(tester, {
      'mobile.function.Leave.saveLeaveRequestDetail': '1',
    });
    expect(find.text('Issue Leave'), findsOneWidget);
    expect(find.text('Time Leave'), findsNothing);

    await pumpLeaveButton(tester, {
      'mobile.function.Leave.saveLeaveRequestDetail': '1',
      'mobile.function.Leave.saveTimeLeaveRequest': '1',
    });
    expect(find.text('Issue Leave'), findsOneWidget);
    expect(find.text('Time Leave'), findsOneWidget);
  });

  Future<void> pumpQuickActions(
    WidgetTester tester, {
    required Map<String, String> features,
    required Map<String, dynamic>? repairPermissions,
  }) async {
    final dashboard = DashboardProvider()..features = features;
    final repair = RepairPriceProvider(
      repository: _PermissionsRepository(repairPermissions),
    );
    await repair.loadWebPermissions();
    addTearDown(dashboard.dispose);
    addTearDown(repair.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DashboardProvider>.value(value: dashboard),
          ChangeNotifierProvider<RepairPriceProvider>.value(value: repair),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: RoyalQuickActions()),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
      'quick actions hide repair and time off when the backend denies them',
      (tester) async {
    await pumpQuickActions(
      tester,
      features: {
        'mobile.function.Leave.saveLeaveRequestDetail': '1',
        'mobile.function.Leave.saveTimeLeaveRequest': '1',
      },
      repairPermissions: {'can_view': false},
    );
    expect(find.text('Time Off'), findsOneWidget);
    expect(find.text('Repair'), findsNothing);

    await pumpQuickActions(
      tester,
      features: {
        'mobile.function.Leave.saveLeaveRequestDetail': '1',
      },
      repairPermissions: {'can_view': true},
    );
    expect(find.text('Time Off'), findsNothing);
    expect(find.text('Request'), findsOneWidget);
    expect(find.text('Repair'), findsOneWidget);
  });
}
