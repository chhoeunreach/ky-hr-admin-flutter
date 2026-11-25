import 'dart:async';
import 'dart:convert';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/config/backend_server_defaults.dart';
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

  setUp(() => SharedPreferences.setMockInitialValues({
        'app_url': primary,
        'verified_company_server': primary,
        'login_server': primary,
        'user_token': 'token',
        'user_id': 42,
      }));

  tearDown(() => ServerUrlResolver.onAllServersUnreachable = null);

  test(
      'remembers backup, strictly keeps primary on failure and notifies prompt',
      () async {
    var failed = false;
    (String, String?)? notified;
    ServerUrlResolver.onAllServersUnreachable = (p, f) => notified = (p, f);
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
    // Strict binding: never secretly connects to backup
    expect(await preferences.getAppUrl(), primary);
    expect(notified, (primary, backup));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_url'), primary);
    failed = false;
    expect(await preferences.getAppUrl(forceCheck: true), primary);
  });

  for (final failure in ['timeout', '503']) {
    test(
        'persisted backup survives restart and handles $failure without auto-failover',
        () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('server_fallback:$primary', backup);
      (String, String?)? notified;
      ServerUrlResolver.onAllServersUnreachable = (p, f) => notified = (p, f);
      final resolver = ServerUrlResolver(client: MockClient((request) async {
        if (request.url.host == 'primary.example') {
          if (failure == 'timeout') throw TimeoutException('Timed out');
          return http.Response('Unavailable', 503);
        }
        return envelope();
      }));
      expect(await resolver.resolve(primary, prefs), primary);
      expect(notified, (primary, backup));
    });
  }

  test(
      'failed health check keeps primary and notifies prompt even if primary returns HTTP 401',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_fallback:$primary', backup);
    (String, String?)? notified;
    ServerUrlResolver.onAllServersUnreachable = (p, f) => notified = (p, f);
    final resolver = ServerUrlResolver(client: MockClient((request) async {
      return request.url.host == 'primary.example'
          ? http.Response('Unauthorized', 401)
          : envelope();
    }));
    expect(await resolver.resolve(primary, prefs), primary);
    expect(notified, (primary, backup));
  });

  for (final response in [
    http.Response('Not Found', 404),
    http.Response('<html>Server error</html>', 200),
    http.Response('{"status":false,"message":"Unavailable"}', 200),
    http.Response('Bad gateway', 502),
  ]) {
    test(
        'unusable primary health response ${response.statusCode}: ${response.body} keeps primary',
        () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('server_fallback:$primary', backup);
      (String, String?)? notified;
      ServerUrlResolver.onAllServersUnreachable = (p, f) => notified = (p, f);
      final resolver = ServerUrlResolver(
          client: MockClient((request) async =>
              request.url.host == 'primary.example' ? response : envelope()));
      expect(await resolver.resolve(primary, prefs), primary);
      expect(notified, (primary, backup));
    });
  }

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
    expect(prefs.getString('server_fallback:$primary'), '');
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

  test('healthy primary is reused within the cache window and rechecks after',
      () async {
    var count = 0;
    final resolver = ServerUrlResolver(
      healthyCacheTtl: const Duration(seconds: 30),
      client: MockClient((request) async {
        count++;
        return envelope();
      }),
    );
    final prefs = await SharedPreferences.getInstance();
    expect(await resolver.resolve(primary, prefs), primary);
    expect(await resolver.resolve(primary, prefs), primary);
    expect(count, 1);
    expect(await resolver.resolve(primary, prefs, forceCheck: true), primary);
    expect(count, 2);
  });

  test(
      'a cached healthy primary detects outage once window expires without auto-failover',
      () async {
    var primaryDown = false;
    (String, String?)? notified;
    ServerUrlResolver.onAllServersUnreachable = (p, f) => notified = (p, f);
    final resolver = ServerUrlResolver(
      healthyCacheTtl: const Duration(milliseconds: 1),
      client: MockClient((request) async {
        if (request.url.host == 'primary.example' && primaryDown) {
          throw http.ClientException('Connection refused');
        }
        return envelope();
      }),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_fallback:$primary', backup);
    expect(await resolver.resolve(primary, prefs), primary);
    primaryDown = true;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(await resolver.resolve(primary, prefs), primary);
    expect(notified, (primary, backup));
  });

  test(
      'fresh app keeps configured server on outage and prompts instead of auto-failover',
      () async {
    SharedPreferences.setMockInitialValues({});
    (String, String?)? notified;
    ServerUrlResolver.onAllServersUnreachable = (p, f) => notified = (p, f);
    final resolver = ServerUrlResolver(client: MockClient((request) async {
      if (request.url.toString().startsWith(BackendServerDefaults.primaryUrl)) {
        throw http.ClientException('Connection refused');
      }
      return envelope();
    }));
    final preferences = Preferences(serverUrlResolver: resolver);
    expect(await preferences.getAppUrl(), BackendServerDefaults.primaryUrl);
    expect(notified,
        (BackendServerDefaults.primaryUrl, BackendServerDefaults.fallbackUrl));
  });

  for (final missing in [
    'verified_company_server',
    'login_server',
    'user_token',
    'user_id'
  ]) {
    test('missing $missing keeps configured server and notifies prompt',
        () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('server_fallback:$primary', backup);
      (String, String?)? notified;
      ServerUrlResolver.onAllServersUnreachable = (p, f) => notified = (p, f);
      var calls = 0;
      final resolver = ServerUrlResolver(client: MockClient((request) async {
        calls++;
        if (request.url.host == 'primary.example') {
          throw http.ClientException('Connection refused');
        }
        return envelope();
      }));
      expect(await resolver.resolve(primary, prefs), primary);
      expect(notified, (primary, backup));
      final previousCalls = calls;
      await prefs.remove(missing);
      expect(await resolver.resolve(primary, prefs), primary);
      expect(calls, greaterThan(previousCalls));
    });
  }

  test('explicit backend disable overrides bundled fallback on later failure',
      () async {
    SharedPreferences.setMockInitialValues({
      'verified_company_server': BackendServerDefaults.primaryUrl,
      'login_server': BackendServerDefaults.primaryUrl,
      'user_token': 'token',
      'user_id': 42,
    });
    var down = false;
    final resolver = ServerUrlResolver(client: MockClient((request) async {
      expect(request.url.toString(),
          '${BackendServerDefaults.primaryUrl}api/app-version');
      if (down) throw http.ClientException('Connection refused');
      return envelope(null);
    }));
    final preferences = Preferences(serverUrlResolver: resolver);
    expect(await preferences.getAppUrl(), BackendServerDefaults.primaryUrl);
    down = true;
    expect(await preferences.getAppUrl(), BackendServerDefaults.primaryUrl);
  });

  test('new build env defaults replace old saved fallback once', () async {
    final prefs = await SharedPreferences.getInstance();
    const key = 'server_fallback:${BackendServerDefaults.primaryUrl}';
    await prefs.setString(key, 'https://old-backup.example/');
    final resolver =
        ServerUrlResolver(client: MockClient((request) async => envelope()));
    await resolver.seedDefaults(BackendServerDefaults.primaryUrl, prefs);
    expect(prefs.getString(key), BackendServerDefaults.fallbackUrl);
    await prefs.setString(key, 'https://runtime-backup.example/');
    await resolver.seedDefaults(BackendServerDefaults.primaryUrl, prefs);
    expect(prefs.getString(key), 'https://runtime-backup.example/');
  });

  group('onAllServersUnreachable', () {
    tearDown(() => ServerUrlResolver.onAllServersUnreachable = null);

    test('notified with backup when primary is down and backup is configured',
        () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('server_fallback:$primary', backup);
      (String, String?)? notified;
      ServerUrlResolver.onAllServersUnreachable =
          (p, f) => notified = (p, f);
      final resolver = ServerUrlResolver(
          client: MockClient((request) async =>
              throw http.ClientException('Connection refused')));
      expect(await resolver.resolve(primary, prefs), primary);
      expect(notified, (primary, backup));
    });

    test('notified without backup when no backup is configured', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('server_fallback:$primary'), isFalse);
      (String, String?)? notified;
      ServerUrlResolver.onAllServersUnreachable =
          (p, f) => notified = (p, f);
      final resolver = ServerUrlResolver(
          client: MockClient((request) async =>
              throw http.ClientException('Connection refused')));
      expect(await resolver.resolve(primary, prefs), primary);
      expect(notified, (primary, null));
    });

    test('notified even when backup is reachable because primary is down',
        () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('server_fallback:$primary', backup);
      (String, String?)? notified;
      ServerUrlResolver.onAllServersUnreachable = (p, f) => notified = (p, f);
      final resolver = ServerUrlResolver(client: MockClient((request) async {
        if (request.url.host == 'primary.example') {
          throw http.ClientException('Connection refused');
        }
        return envelope();
      }));
      // Never auto-failover: strictly returns primary and prompts user
      expect(await resolver.resolve(primary, prefs), primary);
      expect(notified, (primary, backup));
    });

    test('not notified when the primary is reachable', () async {
      final prefs = await SharedPreferences.getInstance();
      var notified = false;
      ServerUrlResolver.onAllServersUnreachable = (_, __) => notified = true;
      final resolver =
          ServerUrlResolver(client: MockClient((request) async => envelope()));
      expect(await resolver.resolve(primary, prefs), primary);
      expect(notified, isFalse);
    });
  });
}
