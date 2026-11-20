import 'dart:convert';

import 'package:cnattendance/core/ky_security/ky_security_manager.dart';
import 'package:cnattendance/core/ky_security/ky_optional_update_prompt.dart';
import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/data/source/network/model/login/User.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _OptionalUpdatePreferences extends Preferences {
  @override
  Future<String> getAppUrl({bool forceCheck = false}) async =>
      'https://hr.rvstechsolution.com/';

  @override
  Future<String> getToken() async => 'account-token';

  @override
  Future<User> getUser() async => User(
        id: 42,
        name: 'Test User',
        email: 'test@example.com',
        username: 'test',
        avatar: '',
        workspace_type: '1',
      );
}

class _AndroidOptionalUpdateManager extends KySecurityManager {
  _AndroidOptionalUpdateManager(http.Client client)
      : super(preferences: _OptionalUpdatePreferences(), client: client);

  @override
  bool get securityApplies => true;
}

Future<Map<String, dynamic>> _initializeWithReleaseCheck(
  Map<String, dynamic> releaseCheck,
) async {
  SharedPreferences.setMockInitialValues({
    'ky_security_integrity_reported_at_42':
        DateTime.now().millisecondsSinceEpoch,
  });
  const channel = MethodChannel('kneayerng/ky_security');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(channel, (call) async {
    switch (call.method) {
      case 'identity':
        return {
          'packageName': 'com.kneayerng.hrms',
          'signingSha256': 'approved-signer',
          'versionName': '1.3.1',
          'versionCode': 18,
          'androidSdk': 31,
          'androidVersion': '12',
          'deviceModel': 'Test Device',
        };
      case 'installationIdentity':
        return 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
      case 'selectKeyAlias':
        return 'kneayerng_device_key_u42';
      case 'sign':
        return 'test-signature';
      case 'clearAuthorizationLease':
        return null;
      default:
        fail('Unexpected native security method: ${call.method}');
    }
  });
  addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

  final client = MockClient((request) async {
    if (request.url.path.endsWith('/config')) {
      return http.Response('{"enabled":true}', 200);
    }
    if (request.url.path.endsWith('/releases/check')) {
      return http.Response(jsonEncode(releaseCheck), 200);
    }
    if (request.url.path.endsWith('/devices/status')) {
      return http.Response(
        '{"authorized":true,"device_id":"device-uuid",'
        '"public_key_fingerprint":"registered-key"}',
        200,
      );
    }
    if (request.url.path.endsWith('/sessions')) {
      return http.Response(
        '{"session_id":"session-uuid","session_token":"session-token",'
        '"refresh_token":"refresh-token",'
        '"expires_at":"2099-01-01T00:00:00Z"}',
        200,
      );
    }
    if (request.url.path.endsWith('/heartbeat')) {
      return http.Response(
        '{"authorized":true,"device_id":"device-uuid",'
        '"server_time":"${DateTime.now().toUtc().toIso8601String()}"}',
        200,
      );
    }
    fail('Unexpected security request: ${request.url}');
  });

  return _AndroidOptionalUpdateManager(client).initialize();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('authorized device receives a compatible optional newer release',
      () async {
    final latestRelease = {
      'version_name': '1.4.0',
      'version_code': 19,
      'minimum_android_sdk': 28,
      'compatible_with_device': true,
      'download_url': 'https://kneayerng.com/app/download/android',
    };
    final state = await _initializeWithReleaseCheck({
      'mandatory_update': false,
      'latest_release': latestRelease,
    });

    expect(state['state'], 'authorized');
    expect(state['optional_update'], latestRelease);
  });

  test('mandatory update takes precedence over the optional prompt', () async {
    final state = await _initializeWithReleaseCheck({
      'mandatory_update': true,
      'latest_release': {
        'version_name': '1.4.0',
        'version_code': 19,
        'minimum_android_sdk': 28,
        'compatible_with_device': true,
      },
    });

    expect(state['state'], 'mandatoryUpdate');
    expect(state.containsKey('optional_update'), isFalse);
  });

  test('device-incompatible newer release is not offered as optional',
      () async {
    final state = await _initializeWithReleaseCheck({
      'mandatory_update': false,
      'latest_release': {
        'version_name': '2.0.0',
        'version_code': 20,
        'minimum_android_sdk': 36,
        'compatible_with_device': false,
      },
    });

    expect(state['state'], 'authorized');
    expect(state.containsKey('optional_update'), isFalse);
  });

  testWidgets('optional update prompt can be dismissed without blocking',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => KyOptionalUpdatePrompt.show(context, {
              'version_name': '2.0.0',
              'download_url': 'https://kneayerng.com/app/download/android',
            }),
            child: const Text('Check update'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Check update'));
    await tester.pumpAndSettle();
    expect(find.text('Version 2.0.0 is available.'), findsOneWidget);

    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    expect(find.text('App update available'), findsNothing);
    expect(find.text('Check update'), findsOneWidget);
  });
}
