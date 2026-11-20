import 'dart:io';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/services/device_clock_monitor.dart';
import 'package:cnattendance/services/device_clock_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _TestPreferences extends Preferences {
  @override
  Future<String> getAppUrl({bool forceCheck = false}) async =>
      'https://hr.example/';
}

void main() {
  const deviceTime = '2026-11-18T04:00:00Z';

  test('caches the first result and skips the server while fresh', () async {
    var calls = 0;
    final now = DateTime.parse(deviceTime);
    final monitor = DeviceClockMonitor(
      service: DeviceClockService(
        preferences: _TestPreferences(),
        now: () => now,
        client: MockClient((_) async {
          calls++;
          return http.Response(
            '{}',
            200,
            headers: {'date': HttpDate.format(now)},
          );
        }),
      ),
      freshWindow: const Duration(minutes: 5),
    );

    final first = await monitor.refresh();
    final second = await monitor.refresh();

    expect(first?.status, DeviceClockStatus.correct);
    expect(identical(first, second), isTrue);
    expect(calls, 1);
    expect(monitor.isFresh(), isTrue);

    await monitor.dispose();
  });

  test('force re-checks the server even when the cache is fresh', () async {
    var calls = 0;
    final now = DateTime.parse(deviceTime);
    final monitor = DeviceClockMonitor(
      service: DeviceClockService(
        preferences: _TestPreferences(),
        now: () => now,
        client: MockClient((_) async {
          calls++;
          return http.Response(
            '{}',
            200,
            headers: {'date': HttpDate.format(now)},
          );
        }),
      ),
      freshWindow: const Duration(minutes: 5),
    );

    await monitor.refresh();
    await monitor.checkNow();

    expect(calls, 2);
    await monitor.dispose();
  });

  test('serves a stale cache when a smaller max age is requested', () async {
    var calls = 0;
    final now = DateTime.parse(deviceTime);
    final monitor = DeviceClockMonitor(
      service: DeviceClockService(
        preferences: _TestPreferences(),
        now: () => now,
        client: MockClient((_) async {
          calls++;
          return http.Response(
            '{}',
            200,
            headers: {'date': HttpDate.format(now)},
          );
        }),
      ),
      freshWindow: const Duration(minutes: 5),
    );

    await monitor.refresh();
    // Zero max age: the cached result can never be young enough.
    await monitor.refresh(staleAfter: Duration.zero);

    expect(calls, 2);
    await monitor.dispose();
  });
}
