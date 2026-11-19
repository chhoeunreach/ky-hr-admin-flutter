import 'dart:convert';
import 'dart:io';

import 'package:cnattendance/provider/chatbadgecontroller.dart';
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
  testWidgets(
      'chat and notification badges show counts, cap at 99+, and hide at zero',
      (tester) async {
    Localization.load(
        jsonDecode(File('assets/i18n/en.json').readAsStringSync())
            as Map<String, dynamic>);
    await tester.binding.setSurfaceSize(const Size(400, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final notifications = _Notifications()..unreadCount.value = 5;
    Get.put<NotificationController>(notifications);
    final badge = ChatBadgeController();
    Get.put<ChatBadgeController>(badge, permanent: true);
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

    badge.unreadCount.value = 3;
    await tester.pump();

    final chat = find.byTooltip(translate('dashboard_screen.chat'));
    final bell = find.byTooltip('Notifications');
    expect(chat, findsOneWidget);
    expect(find.descendant(of: chat, matching: find.text('3')), findsOneWidget);
    expect(find.descendant(of: bell, matching: find.text('5')), findsOneWidget);

    badge.unreadCount.value = 150;
    notifications.unreadCount.value = 150;
    await tester.pump();
    expect(
      find.descendant(of: chat, matching: find.text('99+')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: bell, matching: find.text('99+')),
      findsOneWidget,
    );

    badge.unreadCount.value = 0;
    notifications.unreadCount.value = 0;
    await tester.pump();
    expect(
      find.descendant(of: chat, matching: find.textContaining(RegExp(r'\d'))),
      findsNothing,
    );
    expect(
      find.descendant(of: bell, matching: find.textContaining(RegExp(r'\d'))),
      findsNothing,
    );
  });
}
