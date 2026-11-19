import 'dart:async';
import 'dart:io';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:http/http.dart' as http;

enum DeviceClockStatus { correct, incorrect, unavailable }

class DeviceClockCheck {
  const DeviceClockCheck({
    required this.status,
    this.deviceTime,
    this.serverTime,
    this.offset,
  });

  final DeviceClockStatus status;
  final DateTime? deviceTime;
  final DateTime? serverTime;

  /// Positive means the server clock is ahead of this device.
  final Duration? offset;
}

/// Compares the device clock with the `Date` header from the selected HR server.
class DeviceClockService {
  DeviceClockService({
    Preferences? preferences,
    http.Client? client,
    DateTime Function()? now,
    this.allowedDrift = const Duration(minutes: 2),
    this.timeout = const Duration(seconds: 10),
  })  : _preferences = preferences ?? Preferences(),
        _ownsClient = client == null,
        _client = client ?? http.Client(),
        _now = now ?? DateTime.now;

  final Preferences _preferences;
  final http.Client _client;
  final bool _ownsClient;
  final DateTime Function() _now;
  final Duration allowedDrift;
  final Duration timeout;

  void dispose() {
    if (_ownsClient) _client.close();
  }

  Future<DeviceClockCheck> check() async {
    try {
      final baseUrl = await _preferences.getAppUrl(forceCheck: true);
      final uri = Uri.parse('$baseUrl${Constant.APP_VERSION_URL}').replace(
        queryParameters: {
          'clock_check': _now().microsecondsSinceEpoch.toString()
        },
      );
      final startedAt = _now().toUtc();
      final response = await _client.get(uri, headers: const {
        'Accept': 'application/json',
        'Cache-Control': 'no-cache, no-store, max-age=0',
        'Pragma': 'no-cache',
      }).timeout(timeout);
      final elapsed = _now().toUtc().difference(startedAt);
      if (response.statusCode < 200 || response.statusCode >= 400) {
        return const DeviceClockCheck(status: DeviceClockStatus.unavailable);
      }

      final dateHeader = response.headers['date'];
      if (dateHeader == null || dateHeader.trim().isEmpty) {
        return const DeviceClockCheck(status: DeviceClockStatus.unavailable);
      }
      final serverHeaderTime = HttpDate.parse(dateHeader).toUtc();
      final midpointOffset =
          Duration(microseconds: elapsed.inMicroseconds ~/ 2);
      final estimatedServerTime = serverHeaderTime.add(midpointOffset);
      final deviceTimeAtMidpoint = startedAt.add(midpointOffset);
      final offset = estimatedServerTime.difference(deviceTimeAtMidpoint);

      return DeviceClockCheck(
        status: offset.abs() <= allowedDrift
            ? DeviceClockStatus.correct
            : DeviceClockStatus.incorrect,
        deviceTime: deviceTimeAtMidpoint,
        serverTime: estimatedServerTime,
        offset: offset,
      );
    } on SocketException {
      return const DeviceClockCheck(status: DeviceClockStatus.unavailable);
    } on HttpException {
      return const DeviceClockCheck(status: DeviceClockStatus.unavailable);
    } on FormatException {
      return const DeviceClockCheck(status: DeviceClockStatus.unavailable);
    } on TimeoutException {
      return const DeviceClockCheck(status: DeviceClockStatus.unavailable);
    } catch (_) {
      return const DeviceClockCheck(status: DeviceClockStatus.unavailable);
    }
  }
}
