import 'dart:io';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/config/backend_server_defaults.dart';
import 'package:cnattendance/services/server_configuration.dart';
import 'package:cnattendance/services/server_status_service.dart';
import 'package:cnattendance/services/server_url_resolver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _LiveHttp extends HttpOverrides {}

void main() {
  const publicFailover = bool.fromEnvironment('TEST_PUBLIC_FAILOVER');
  test(
      'configured public backup responds when primary connection fails before login',
      () async {
    await HttpOverrides.runWithHttpOverrides(() async {
      SharedPreferences.setMockInitialValues({});
      final liveClient = http.Client();
      final client = MockClient((request) async {
        if (request.url.host ==
            Uri.parse(BackendServerDefaults.primaryUrl).host) {
          throw http.ClientException(
              'Connection refused (simulated primary outage)');
        }
        expect(request.url.host, 'hr.rvstechsolution.com');
        return liveClient.get(request.url, headers: request.headers);
      });
      try {
        final preferences =
            Preferences(serverUrlResolver: ServerUrlResolver(client: client));
        expect(
            await preferences.getAppUrl(), 'https://hr.rvstechsolution.com/');
        final status =
            await ServerStatusService(preferences: preferences, client: client)
                .checkCurrentServer();
        expect(status.isConnected, isTrue);
        expect(status.url, 'https://hr.rvstechsolution.com/');
        expect(status.message, contains('backup'));
      } finally {
        client.close();
        liveClient.close();
      }
    }, _LiveHttp());
  },
      skip: publicFailover
          ? false
          : 'Enable TEST_PUBLIC_FAILOVER for the live backup network check.');

  const liveDefaults = bool.fromEnvironment('TEST_BACKEND_ENV');
  test('fresh app selects backup before login when primary is offline',
      () async {
    await HttpOverrides.runWithHttpOverrides(() async {
      SharedPreferences.setMockInitialValues({});
      final client = http.Client();
      try {
        final preferences =
            Preferences(serverUrlResolver: ServerUrlResolver(client: client));
        expect(await preferences.getConfiguredAppUrl(),
            BackendServerDefaults.primaryUrl);
        expect(
            await preferences.getAppUrl(), BackendServerDefaults.fallbackUrl);
        final status =
            await ServerStatusService(preferences: preferences, client: client)
                .checkCurrentServer();
        expect(status.isConnected, isTrue);
        expect(status.url, BackendServerDefaults.fallbackUrl);
      } finally {
        client.close();
      }
    }, _LiveHttp());
  },
      skip: liveDefaults
          ? false
          : 'Enable TEST_BACKEND_ENV with primary offline and backup online.');

  const qr = String.fromEnvironment('SERVER_QR');
  test('backend QR does not verify via backup before login', () async {
    await HttpOverrides.runWithHttpOverrides(() async {
      SharedPreferences.setMockInitialValues({});
      final configuration = ServerConfiguration.parse(qr);
      final client = http.Client();
      try {
        final preferences =
            Preferences(serverUrlResolver: ServerUrlResolver(client: client));
        final service =
            ServerStatusService(preferences: preferences, client: client);
        final scanResult = await service.switchServer(qr);
        expect(scanResult.isConnected, isFalse);
        expect(scanResult.url, configuration.primaryUrl);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('app_url'), isNull);
        expect(prefs.getString('verified_company_server'), isNull);
        expect(prefs.getString('login_server'), isNull);
      } finally {
        client.close();
      }
    }, _LiveHttp());
  },
      skip: qr.isEmpty
          ? 'Provide --dart-define=SERVER_QR=<backend QR payload> with primary offline.'
          : false);
}
