import 'package:cnattendance/services/server_status_service.dart';
import 'package:cnattendance/services/server_url_resolver.dart';
import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/data/source/network/model/login/Login.dart';
import 'package:cnattendance/data/source/network/model/login/User.dart';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const appUrlKey = 'app_url';
  const appEnvelope =
      '{"status":true,"message":"Data found","status_code":200}';

  ServerStatusService buildService(http.Client client) =>
      ServerStatusService(client: client);

  setUp(() {
    SharedPreferences.setMockInitialValues({
      appUrlKey: 'https://example.com/',
      'user_token': 'token',
      'user_id': 42,
      'verified_company_server': 'https://example.com/',
      'login_server': 'https://example.com/',
    });
  });

  group('ServerStatusService.checkServer', () {
    test(
        'checkCurrentServer reports primary outage and manual switch to backup works',
        () async {
      var primaryDown = false;
      final client = MockClient((request) async {
        if (request.url.host == 'example.com' && primaryDown) {
          throw http.ClientException('Connection refused');
        }
        if (request.url.host == 'backup.example.com') {
          return http.Response(appEnvelope, 200);
        }
        return http.Response(
          '{"status":true,"message":"Data found","data":'
          '{"server_fallback_url":"https://backup.example.com/"}}',
          200,
        );
      });
      final preferences = Preferences(
        serverUrlResolver: ServerUrlResolver(client: client),
      );
      final service =
          ServerStatusService(preferences: preferences, client: client);
      expect((await service.checkCurrentServer()).url, 'https://example.com/');
      primaryDown = true;
      final failedResult = await service.checkCurrentServer();
      expect(failedResult.isConnected, isFalse);
      expect(await preferences.getAppUrl(), 'https://example.com/');

      // Explicit switch to backup server
      final switchResult =
          await service.switchServer('https://backup.example.com/');
      expect(switchResult.isConnected, isTrue);
      expect(switchResult.url, 'https://backup.example.com/');
      expect(await preferences.getAppUrl(), 'https://backup.example.com/');
    });

    test('probes the lightweight app-version endpoint', () async {
      final service = buildService(MockClient((request) async {
        expect(request.url.toString(), 'https://example.com/api/app-version');
        return http.Response(appEnvelope, 200);
      }));

      final result = await service.checkCurrentServer();

      expect(result.isConnected, isTrue);
      expect(result.statusCode, 200);
    });

    test('any HTTP response below 500 counts as reachable', () async {
      final service = buildService(
          MockClient((request) async => http.Response('Not Found', 404)));

      final result = await service.checkCurrentServer();

      expect(result.isConnected, isTrue);
      expect(result.statusCode, 404);
      expect(result.message, contains('404'));
    });

    test('HTTP 500 means the server is online but unusable', () async {
      final service = buildService(
          MockClient((request) async => http.Response('Server Error', 500)));

      final result = await service.checkCurrentServer();

      expect(result.isConnected, isFalse);
      expect(result.message, contains('online'));
    });

    test('invalid server URL is reported as not connected', () async {
      final service = buildService(
          MockClient((request) async => http.Response(appEnvelope, 200)));

      final result = await service.checkServer('not a url');

      expect(result.isConnected, isFalse);
      expect(result.message, 'Invalid server QR code or URL.');
    });
  });

  group('ServerStatusService.switchServer', () {
    test(
        'backup works and preserves successful login across restart after manual switch',
        () async {
      var primaryDown = false;
      final client = MockClient((request) async {
        if (request.url.host == 'primary.example' && primaryDown) {
          throw http.ClientException('Connection refused');
        }
        if (request.url.path == '/api/app-version') {
          return http.Response(appEnvelope, 200);
        }
        expect(request.url.host, 'backup.example');
        expect(request.headers['Authorization'], 'Bearer login-token');
        return http.Response('{"status":true}', 200);
      });
      final preferences =
          Preferences(serverUrlResolver: ServerUrlResolver(client: client));
      final service =
          ServerStatusService(preferences: preferences, client: client);
      final result =
          await service.switchServer(base64Encode(utf8.encode(jsonEncode({
        'server_url': 'https://primary.example/',
        'server_fallback_url': 'https://backup.example/',
      }))));
      expect(result.isConnected, isTrue);
      expect(result.url, 'https://primary.example/');

      primaryDown = true;
      // Never auto-switches: stays configured server
      expect(await preferences.getAppUrl(), 'https://primary.example/');

      // User explicitly confirms switching to backup:
      final switchResult =
          await service.switchServer('https://backup.example/');
      expect(switchResult.isConnected, isTrue);
      expect(await preferences.getAppUrl(), 'https://backup.example/');

      // Persist the successful login, then recreate preferences/resolver as on
      // restart. Server stays backup without another scan.
      await preferences.saveUser(Login(
        user: User(
            id: 42,
            name: 'Employee',
            email: 'employee@example.com',
            username: 'employee',
            avatar: '',
            workspace_type: '1'),
        tokens: 'login-token',
      ));
      final restarted =
          Preferences(serverUrlResolver: ServerUrlResolver(client: client));
      expect(await restarted.getAppUrl(), 'https://backup.example/');
      expect(await restarted.getConfiguredAppUrl(), 'https://backup.example/');
      expect(await restarted.getUserId(), 42);
      final response = await client.get(
        Uri.parse('${await restarted.getAppUrl()}api/dashboard'),
        headers: {'Authorization': 'Bearer ${await restarted.getToken()}'},
      );
      expect(response.statusCode, 200);
      await restarted.clearPrefs();
      expect((await SharedPreferences.getInstance()).getString('login_server'),
          isNull);
      expect(
          (await SharedPreferences.getInstance())
              .getString('verified_company_server'),
          isNull);
      client.close();
    });
    test('fresh scan never connects to backup before successful login',
        () async {
      final client = MockClient((request) async {
        expect(request.url.host, 'primary.example');
        throw http.ClientException('Connection refused');
      });
      final preferences =
          Preferences(serverUrlResolver: ServerUrlResolver(client: client));
      final service =
          ServerStatusService(preferences: preferences, client: client);
      final result = await service.switchServer(jsonEncode({
        'server_url': 'https://primary.example/',
        'server_fallback_url': 'https://backup.example/',
      }));
      expect(result.isConnected, isFalse);
      expect(await preferences.getConfiguredAppUrl(), 'https://example.com/');
    });

    test('failed backup scan preserves previously configured server', () async {
      final service = buildService(
          MockClient((request) async => http.Response('Unavailable', 503)));
      final result = await service.switchServer(jsonEncode({
        'server_url': 'https://primary.example/',
        'server_fallback_url': 'https://backup.example/',
      }));
      expect(result.isConnected, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(appUrlKey), 'https://example.com/');
      expect(
          prefs.getString('server_fallback:https://primary.example/'), isNull);
    });

    test('saves the URL when the server answers with the app envelope',
        () async {
      final service = buildService(MockClient((request) async {
        expect(request.url.toString(),
            'https://other.example.com/api/app-version');
        return http.Response(appEnvelope, 200);
      }));

      final result = await service.switchServer('https://other.example.com');

      expect(result.isConnected, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(appUrlKey), 'https://other.example.com/');
    });

    test('does not save a reachable server that is not the app backend',
        () async {
      final service = buildService(
          MockClient((request) async => http.Response('<html></html>', 404)));

      final result = await service.switchServer('https://other.example.com');

      expect(result.isConnected, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(appUrlKey), 'https://example.com/');
    });

    test('failed HR response cannot verify a company', () async {
      final service = buildService(MockClient((request) async => http.Response(
          '{"status":false,"message":"Company unavailable"}', 200)));
      final result = await service.switchServer('https://other.example.com');
      expect(result.isConnected, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(appUrlKey), 'https://example.com/');
    });
  });
}
