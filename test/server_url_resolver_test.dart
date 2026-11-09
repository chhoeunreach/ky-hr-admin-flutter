import 'dart:async';
import 'dart:convert';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/services/server_url_resolver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const primary = 'https://primary.example/';
  const backup = 'https://backup.example/';
  http.Response envelope([String? fallback = backup]) => http.Response(
        jsonEncode({
          'status': true,
          'message': 'Data found',
          'data': {'server_fallback_url': fallback},
        }),
        200,
      );

  setUp(() => SharedPreferences.setMockInitialValues({'app_url': primary}));

  test(
      'remembers backup, switches on failure, and returns to recovered primary',
      () async {
    var failed = false;
    final resolver = ServerUrlResolver(
      client: MockClient((request) async {
        if (request.url.host == 'primary.example' && failed) {
          throw http.ClientException('Connection refused');
        }
        return envelope();
      }),
    );
    final preferences = Preferences(serverUrlResolver: resolver);
    expect(await preferences.getAppUrl(), primary);
    failed = true;
    expect(await preferences.getAppUrl(), backup);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_url'), primary);
    failed = false;
    expect(await preferences.getAppUrl(forceCheck: true), primary);
  });

  for (final failure in ['timeout', '503']) {
    test('persisted backup survives restart and handles $failure', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('server_fallback:$primary', backup);
      final resolver = ServerUrlResolver(client: MockClient((request) async {
        if (request.url.host == 'primary.example') {
          if (failure == 'timeout') throw TimeoutException('Timed out');
          return http.Response('Unavailable', 503);
        }
        return envelope();
      }));
      expect(await resolver.resolve(primary, prefs), backup);
    });
  }

  test('does not switch for authentication or validation errors', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_fallback:$primary', backup);
    final resolver = ServerUrlResolver(client: MockClient((request) async {
      expect(request.url.host, 'primary.example');
      return http.Response('Unauthorized', 401);
    }));
    expect(await resolver.resolve(primary, prefs), primary);
  });

  test('cached backup going offline triggers a fresh primary check', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_fallback:$primary', backup);
    var primaryDown = true;
    var backupDown = false;
    final resolver = ServerUrlResolver(client: MockClient((request) async {
      if ((request.url.host == 'primary.example' && primaryDown) ||
          (request.url.host == 'backup.example' && backupDown)) {
        throw http.ClientException('Connection refused');
      }
      return envelope();
    }));
    expect(await resolver.resolve(primary, prefs), backup);
    primaryDown = false;
    backupDown = true;
    expect(await resolver.resolve(primary, prefs), primary);
  });

  test('rejects non-backend backup and keeps configured server when both fail',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_fallback:$primary', backup);
    final resolver = ServerUrlResolver(client: MockClient((request) async {
      return request.url.host == 'primary.example'
          ? http.Response('Unavailable', 503)
          : http.Response('<html>Wrong site</html>', 200);
    }));
    expect(await resolver.resolve(primary, prefs), primary);
  });

  test('backup is scoped to primary and cleared when server disables it',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_fallback:$primary', backup);
    final resolver = ServerUrlResolver(client: MockClient((request) async {
      if (request.url.host == 'primary.example') return envelope(null);
      return http.Response('Unavailable', 503);
    }));
    expect(await resolver.resolve(primary, prefs), primary);
    expect(prefs.getString('server_fallback:$primary'), isNull);
    expect(await resolver.resolve('https://other.example/', prefs),
        'https://other.example/');
  });

  test('concurrent callers share one check, next request rechecks primary',
      () async {
    var count = 0;
    final resolver = ServerUrlResolver(client: MockClient((request) async {
      count++;
      return envelope();
    }));
    final prefs = await SharedPreferences.getInstance();
    expect(
        await Future.wait(
            List.generate(10, (_) => resolver.resolve(primary, prefs))),
        everyElement(primary));
    expect(count, 1);
    expect(await resolver.resolve(primary, prefs), primary);
    expect(count, 2);
  });
}
