import 'dart:convert';
import 'dart:io';

import 'package:cnattendance/provider/dashboardprovider.dart';
import 'package:cnattendance/provider/prefprovider.dart';
import 'package:cnattendance/widget/homescreen/checkattendance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Dashboard extends DashboardProvider {
  void updateMethods(List<String> methods) {
    attendanceMethods = methods;
    notifyListeners();
  }

  void refresh() => notifyListeners();
}

class _Preferences extends PrefProvider {
  final List<List<String>> resolutions = [];
  @override
  Future<String> getAttendanceType(List<String> methods) async {
    resolutions.add(List.of(methods));
    return 'Default';
  }
}

class _MeasuredAttendance extends CheckAttendance {
  final VoidCallback onBuild;
  _MeasuredAttendance(this.onBuild);

  @override
  CheckAttendanceState createState() => _MeasuredAttendanceState();
}

class _MeasuredAttendanceState extends CheckAttendanceState {
  @override
  Widget build(BuildContext context) {
    (widget as _MeasuredAttendance).onBuild();
    return super.build(context);
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Localization.load(jsonDecode(File('assets/i18n/en.json').readAsStringSync())
        as Map<String, dynamic>);
  });

  testWidgets('clock ticks do not rebuild attendance or reread preferences',
      (tester) async {
    final dashboard = _Dashboard()..animated = false;
    final preferences = _Preferences();
    var builds = 0;
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<DashboardProvider>.value(value: dashboard),
        ChangeNotifierProvider<PrefProvider>.value(value: preferences),
      ],
      child: MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
        child: _MeasuredAttendance(() => builds++),
      ))),
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    final initialBuilds = builds;
    expect(preferences.resolutions, [[]]);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(builds, initialBuilds);
    expect(preferences.resolutions, [[]]);
    dashboard.refresh();
    await tester.pump();
    expect(preferences.resolutions, [[]]);
    dashboard.updateMethods(['QR']);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(preferences.resolutions, [
      [],
      ['QR']
    ]);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    dashboard.dispose();
    preferences.dispose();
  });
}
