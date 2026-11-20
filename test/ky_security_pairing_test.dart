import 'package:cnattendance/core/ky_security/ky_security_manager.dart';
import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _PairingPreferences extends Preferences {
  _PairingPreferences(this.url);
  final String url;

  @override
  Future<String> getAppUrl({bool forceCheck = false}) async => url;
}

class _AndroidSecurity extends KySecurityManager {
  _AndroidSecurity(String url, http.Client client)
      : super(preferences: _PairingPreferences(url), client: client);

  @override
  bool get securityApplies => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('USB debug pairing continues after Laravel confirms enforcement is off',
      () async {
    final manager =
        _AndroidSecurity('http://127.0.0.1:8000/', MockClient((request) async {
      expect(request.url.toString(),
          'http://127.0.0.1:8000/api/app-security/v1/config');
      expect(request.headers['authorization'], isNull);
      expect(request.followRedirects, isFalse);
      return http.Response('{"enabled":false}', 200);
    }));

    expect(await manager.initialize(), {'state': 'disabled'});
    expect(manager.enforcementEnabled, isFalse);
  });

  test('an enforced server requires HTTPS even through USB', () async {
    final manager =
        _AndroidSecurity('http://127.0.0.1:8000/', MockClient((request) async {
      expect(request.url.path, endsWith('/config'));
      return http.Response('{"enabled":true}', 200);
    }));

    expect((await manager.initialize())['reason'], 'https_required');
  });

  test('remote cleartext pairing is rejected before a security request',
      () async {
    final manager =
        _AndroidSecurity('http://192.168.0.113:8000/', MockClient((_) async {
      fail('Unexpected security request over cleartext');
    }));
    expect((await manager.initialize())['reason'], 'https_required');
  });

  test('missing endpoints and invalid policies do not disable enforcement',
      () async {
    for (final (status, response, reason) in [
      (404, '', 'security_endpoint_missing'),
      (302, '', 'security_endpoint_redirected'),
      (200, '{"status":true}', 'security_response_invalid'),
      (200, '<html>Login</html>', 'security_response_invalid'),
    ]) {
      final manager =
          _AndroidSecurity('http://127.0.0.1:8000/', MockClient((_) async {
        return http.Response(response, status);
      }));
      final result = await manager.initialize();
      expect(result['state'], 'offlineRestricted');
      expect(result['reason'], reason);
    }
  });
}
