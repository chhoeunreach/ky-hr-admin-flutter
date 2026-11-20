import 'package:cnattendance/core/ky_security/ky_security_manager.dart';
import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/data/source/network/model/login/User.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecoveryPreferences extends Preferences {
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

class _AndroidSecurityManager extends KySecurityManager {
  _AndroidSecurityManager(http.Client client)
      : super(preferences: _RecoveryPreferences(), client: client);

  @override
  bool get securityApplies => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('an unavailable registered key routes to administrator recovery',
      () async {
    SharedPreferences.setMockInitialValues({
      'ky_security_installation_uuid_v1':
          'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    });
    const securityChannel = MethodChannel('kneayerng/ky_security');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(securityChannel, (call) async {
      switch (call.method) {
        case 'installationIdentity':
          expect(call.arguments, {
            'legacyUuid': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
            'keyAlias': 'kneayerng_device_key_u42',
          });
          return 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
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
        case 'selectKeyAlias':
          return null;
        case 'rotateInstallationIdentity':
          return 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
        default:
          fail('Unexpected native security method: ${call.method}');
      }
    });
    addTearDown(
        () => messenger.setMockMethodCallHandler(securityChannel, null));

    final client = MockClient((request) async {
      if (request.url.path.endsWith('/config')) {
        return http.Response('{"enabled":true}', 200);
      }
      if (request.url.path.endsWith('/releases/check')) {
        return http.Response('{"mandatory_update":false}', 200);
      }
      if (request.url.path.endsWith('/devices/status')) {
        return http.Response(
          '{"authorized":true,"device_id":"device-uuid",'
          '"public_key_fingerprint":"registered-key"}',
          200,
        );
      }
      fail('Unexpected security request: ${request.url}');
    });

    final result = await _AndroidSecurityManager(client).initialize();

    expect(result, {
      'state': 'registrationRequired',
      'reason': 'device_key_unavailable',
    });
    expect(
      (await SharedPreferences.getInstance())
          .getString('ky_security_installation_uuid_v1'),
      isNull,
    );
  });
}
