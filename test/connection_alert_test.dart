import 'dart:convert';
import 'dart:io';

import 'package:cnattendance/services/connection_alert.dart';
import 'package:cnattendance/services/server_status_service.dart';
import 'package:cnattendance/utils/navigationservice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:overlay_support/overlay_support.dart';

void main() {
  setUp(() {
    ConnectionAlert.resetForTesting();
    Localization.load(
        jsonDecode(File('assets/i18n/en.json').readAsStringSync())
            as Map<String, dynamic>);
  });

  ServerCheckResult result(bool connected, String message) => ServerCheckResult(
        url: 'https://primary.example/',
        isConnected: connected,
        message: message,
      );

  Widget host({required Widget Function(BuildContext) dialogBuilder}) =>
      OverlaySupport.global(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: dialogBuilder,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

  testWidgets('keeps prompting on retry until a server responds',
      (tester) async {
    var connected = false;
    var checks = 0;
    await tester.pumpWidget(host(
      dialogBuilder: (_) => ConnectionAlertDialog(
        primaryUrl: 'https://primary.example/',
        fallbackUrl: 'https://backup.example/',
        checkServer: () async {
          checks++;
          return result(connected, 'Connection timed out.');
        },
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Cannot connect to server'), findsOneWidget);
    expect(find.textContaining('https://primary.example/'), findsOneWidget);
    expect(find.textContaining('https://backup.example/'), findsOneWidget);
    expect(find.text('Connection timed out.'), findsNothing);

    // First retry fails, so the alert stays and surfaces the error.
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.byType(ConnectionAlertDialog), findsOneWidget);
    expect(find.text('Connection timed out.'), findsOneWidget);
    expect(checks, 1);

    // Next retry succeeds, so the alert finally closes.
    connected = true;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.byType(ConnectionAlertDialog), findsNothing);
    expect(find.text('open'), findsOneWidget);
    expect(checks, 2);
  });

  testWidgets('automatic re-check closes the alert once a server responds',
      (tester) async {
    await tester.pumpWidget(host(
      dialogBuilder: (_) => ConnectionAlertDialog(
        primaryUrl: 'https://primary.example/',
        checkServer: () async => result(true, 'Connected.'),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(ConnectionAlertDialog), findsOneWidget);

    // The periodic re-check runs without any user interaction.
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(find.byType(ConnectionAlertDialog), findsNothing);
  });

  testWidgets('ConnectionAlert shows a single blocking dialog',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      navigatorKey: NavigationService.navigatorKey,
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => ConnectionAlert.show(
              primaryUrl: 'https://primary.example/',
              fallbackUrl: 'https://backup.example/',
            ),
            child: const Text('trigger'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();
    // A second trigger while the alert is on screen is ignored.
    ConnectionAlert.show(
      primaryUrl: 'https://primary.example/',
      fallbackUrl: 'https://backup.example/',
    );
    await tester.pump();
    expect(find.byType(ConnectionAlertDialog), findsOneWidget);
    expect(find.text('Cannot connect to server'), findsOneWidget);

    // The barrier cannot dismiss the alert; only a successful re-check can.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byType(ConnectionAlertDialog), findsOneWidget);
  });

  testWidgets('shows only the primary line when no backup exists',
      (tester) async {
    await tester.pumpWidget(host(
      dialogBuilder: (_) => ConnectionAlertDialog(
        primaryUrl: 'https://primary.example/',
        checkServer: () async => result(false, 'Connection refused'),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('https://primary.example/'), findsOneWidget);
    expect(find.textContaining('https://backup.example/'), findsNothing);
  });

  testWidgets('switching to backup requires user confirmation', (tester) async {
    String? switchedTo;
    await tester.pumpWidget(host(
      dialogBuilder: (_) => ConnectionAlertDialog(
        primaryUrl: 'https://primary.example/',
        fallbackUrl: 'https://backup.example/',
        checkServer: () async => result(false, 'Connection timed out.'),
        switchServer: (url) async {
          switchedTo = url;
          return result(true, 'Connected.');
        },
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Switch to Backup Server'), findsOneWidget);

    // Tap switch to backup
    await tester.tap(find.text('Switch to Backup Server'));
    await tester.pumpAndSettle();

    // Confirmation dialog appears
    expect(find.text('Confirm Server Switch'), findsOneWidget);
    expect(find.textContaining('https://backup.example/'), findsWidgets);

    // Cancel first
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(switchedTo, isNull);
    expect(find.byType(ConnectionAlertDialog), findsOneWidget);

    // Tap again and confirm
    await tester.tap(find.text('Switch to Backup Server'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(switchedTo, 'https://backup.example/');
    expect(find.byType(ConnectionAlertDialog), findsNothing);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('scanning new QR requires user confirmation before switching',
      (tester) async {
    String? switchedTo;
    await tester.pumpWidget(host(
      dialogBuilder: (_) => ConnectionAlertDialog(
        primaryUrl: 'https://primary.example/',
        checkServer: () async => result(false, 'Connection timed out.'),
        scanQr: (_) async => 'https://newserver.example/',
        switchServer: (url) async {
          switchedTo = url;
          return result(true, 'Connected.');
        },
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Scan New QR Code'), findsOneWidget);

    // Tap scan QR
    await tester.tap(find.text('Scan New QR Code'));
    await tester.pumpAndSettle();

    // Confirmation dialog appears
    expect(find.text('Confirm Server Switch'), findsOneWidget);
    expect(find.textContaining('https://newserver.example/'), findsWidgets);

    // Confirm switch
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(switchedTo, 'https://newserver.example/');
    expect(find.byType(ConnectionAlertDialog), findsNothing);
    await tester.pump(const Duration(seconds: 5));
  });
}
