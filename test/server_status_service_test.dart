import 'package:cnattendance/services/server_status_service.dart';
import 'package:cnattendance/services/server_url_resolver.dart';
import 'package:cnattendance/data/source/datastore/preferences.dart';
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
    });
  });

  group('ServerStatusService.checkServer', () {
    test(
        'manual test selects backup after connection refused and forces recovery check',
        () async {
      var primaryDown = false;
      final client = MockClient((request) async {
        if (request.url.host == 'example.com' && primaryDown) {
          throw http.ClientException('Connection refused');
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
      final backupResult = await service.checkCurrentServer();
      expect(backupResult.isConnected, isTrue);
      expect(backupResult.url, 'https://backup.example.com/');
      expect(backupResult.message, contains('backup'));
      expect(await preferences.getAppUrl(), 'https://backup.example.com/');

      // The button must bypass even a recently cached backup selection.
      primaryDown = false;
      expect((await service.checkCurrentServer()).url, 'https://example.com/');
      expect(await preferences.getAppUrl(), 'https://example.com/');
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
        'fresh scan connects to backup while primary is offline and keeps primary',
        () async {
      final client = MockClient((request) async {
        if (request.url.host == 'primary.example') {
          throw http.ClientException('Connection refused');
        }
        return http.Response(appEnvelope, 200);
      });
      final preferences =
          Preferences(serverUrlResolver: ServerUrlResolver(client: client));
      final service =
          ServerStatusService(preferences: preferences, client: client);
      final qr = base64Encode(utf8.encode(jsonEncode({
        'server_url': 'https://primary.example/',
        'server_fallback_url': 'https://backup.example/',
      })));
      final result = await service.switchServer(qr);
      expect(result.isConnected, isTrue);
      expect(result.url, 'https://backup.example/');
      expect(
          await preferences.getConfiguredAppUrl(), 'https://primary.example/');
      expect(await preferences.getAppUrl(), 'https://backup.example/');
      expect(
          (await service.checkCurrentServer()).url, 'https://backup.example/');
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
  });
}
