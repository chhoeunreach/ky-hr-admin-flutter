import 'dart:convert';
import 'dart:io';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/services/server_configuration.dart';
import 'package:cnattendance/services/server_status_service.dart';
import 'package:cnattendance/services/server_url_resolver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class _LiveHttp extends HttpOverrides {}

void main() {
  const qr = String.fromEnvironment('SERVER_QR');
  test('backend QR selects live backup with primary offline', () async {
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
        expect(scanResult.isConnected, isTrue);
        expect(scanResult.url, configuration.fallbackUrl);
        expect(
            await preferences.getConfiguredAppUrl(), configuration.primaryUrl);
        final status = await service.checkCurrentServer();
        expect(status.isConnected, isTrue);
        expect(status.message, contains('backup'));
        final selected = await preferences.getAppUrl();
        expect(selected, configuration.fallbackUrl);
        final response =
            await client.get(Uri.parse('${selected}api/app-version'));
        expect(response.statusCode, 200);
        expect(jsonDecode(response.body)['status'], isTrue);
      } finally {
        client.close();
      }
    }, _LiveHttp());
  },
      skip: qr.isEmpty
          ? 'Provide --dart-define=SERVER_QR=<backend QR payload> with primary offline.'
          : false);
}
