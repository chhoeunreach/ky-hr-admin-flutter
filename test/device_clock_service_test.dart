import 'dart:io';

import 'package:cnattendance/data/source/datastore/preferences.dart';
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

  test('accepts device clock within the configured drift', () async {
    final now = DateTime.parse(deviceTime);
    final service = DeviceClockService(
      preferences: _TestPreferences(),
      now: () => now,
      client: MockClient((_) async => http.Response(
            '{}',
            200,
            headers: {'date': HttpDate.format(now)},
          )),
    );

    final result = await service.check();

    expect(result.status, DeviceClockStatus.correct);
    service.dispose();
  });

  test('rejects device clock more than two minutes from server', () async {
    final now = DateTime.parse(deviceTime);
    final service = DeviceClockService(
      preferences: _TestPreferences(),
      now: () => now,
      client: MockClient((_) async => http.Response(
            '{}',
            200,
            headers: {
              'date': HttpDate.format(now.add(const Duration(minutes: 5))),
            },
          )),
    );

    final result = await service.check();

    expect(result.status, DeviceClockStatus.incorrect);
    expect(result.offset?.inMinutes, 5);
    service.dispose();
  });

  test('requires a server Date header to verify the clock', () async {
    final service = DeviceClockService(
      preferences: _TestPreferences(),
      now: () => DateTime.parse(deviceTime),
      client: MockClient((_) async => http.Response('{}', 200)),
    );

    final result = await service.check();

    expect(result.status, DeviceClockStatus.unavailable);
    service.dispose();
  });
}
