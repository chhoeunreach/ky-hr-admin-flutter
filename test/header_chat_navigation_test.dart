import 'dart:convert';
import 'dart:io';

import 'package:cnattendance/provider/dashboardprovider.dart';
import 'package:cnattendance/provider/notificationcontroller.dart';
import 'package:cnattendance/provider/prefprovider.dart';
import 'package:cnattendance/widget/headerprofile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

class _Notifications extends NotificationController {
  @override
  void onReady() {}

  @override
  Future<void> ensureLoaded() async {}
}

void main() {
  for (final (language, width) in [('en', 400.0), ('km', 320.0)]) {
    testWidgets('Chat appears before Send Location at ${width.toInt()}px',
        (tester) async {
      Localization.load(
          jsonDecode(File('assets/i18n/$language.json').readAsStringSync())
              as Map<String, dynamic>);
      await tester.binding.setSurfaceSize(Size(width, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      Get.put<NotificationController>(_Notifications());
      addTearDown(Get.reset);
      final dashboard = DashboardProvider()
        ..isLocationEnabled = true
        ..features = {'chat': '1', 'notifications': '1'};
      addTearDown(dashboard.dispose);

      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<DashboardProvider>.value(value: dashboard),
          ChangeNotifierProvider(create: (_) => PrefProvider()),
        ],
        child: const MaterialApp(
          home: Scaffold(body: HeaderProfile(showMenuButton: false)),
        ),
      ));
      await tester.pump();

      final chat = find.byTooltip(translate('dashboard_screen.chat'));
      final location = find.byTooltip('Send Location');
      expect(chat, findsOneWidget);
      expect(tester.getCenter(chat).dy, tester.getCenter(location).dy);
      expect(
          tester.getCenter(chat).dx, lessThan(tester.getCenter(location).dx));
      expect(tester.takeException(), isNull);

      dashboard.features = {'chat': '0', 'notifications': '1'};
      dashboard.notifyListeners();
      await tester.pump();
      expect(chat, findsNothing);
      expect(location, findsOneWidget);
    });
  }
}
