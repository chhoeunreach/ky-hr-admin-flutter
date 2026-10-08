import 'dart:async';
import 'dart:convert';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:http/http.dart' as http;

class ServerCheckResult {
  const ServerCheckResult({
    required this.url,
    required this.isConnected,
    required this.message,
    this.statusCode,
  });

  final String url;
  final bool isConnected;
  final String message;
  final int? statusCode;
}

class ServerStatusService {
  ServerStatusService({Preferences? preferences, http.Client? client})
      : _preferences = preferences ?? Preferences(),
        _client = client ?? http.Client();

  final Preferences _preferences;
  final http.Client _client;

  Future<String> currentServerUrl() => _preferences.getAppUrl();

  String normalizeScannedServer(String value) {
    var candidate = value.trim();

    try {
      final decoded = utf8.decode(base64.decode(candidate)).trim();
      if (decoded.isNotEmpty) {
        candidate = decoded;
      }
    } catch (_) {}

    final uri = Uri.tryParse(candidate);
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.trim().isEmpty) {
      throw const FormatException('Invalid server QR code or URL.');
    }

    return candidate.endsWith('/') ? candidate : '$candidate/';
  }

  Future<ServerCheckResult> checkCurrentServer() async {
    return checkServer(await _preferences.getAppUrl());
  }

  Future<ServerCheckResult> checkServer(String serverUrl) {
    return _probe(serverUrl, requireAppBackend: false);
  }

  Future<ServerCheckResult> switchServer(String scannedValue) async {
    final result = await _probe(scannedValue, requireAppBackend: true);
    if (result.isConnected) {
      await _preferences.saveAppUrl(result.url);
    }
    return result;
  }

  Future<ServerCheckResult> _probe(
    String serverUrl, {
    required bool requireAppBackend,
  }) async {
    try {
      final normalizedUrl = normalizeScannedServer(serverUrl);
      final uri = Uri.parse('$normalizedUrl${Constant.APP_VERSION_URL}');

      final response = await _client
          .get(uri, headers: const {'Accept': 'application/json; charset=UTF-8'})
          .timeout(const Duration(seconds: 15));

      final appBackend = response.statusCode == 200 &&
          _looksLikeAppBackend(response.body);

      if (requireAppBackend && !appBackend) {
        return ServerCheckResult(
          url: normalizedUrl,
          isConnected: false,
          statusCode: response.statusCode,
          message: response.statusCode >= 500
              ? 'Server reached, but it returned HTTP ${response.statusCode}.'
              : 'Server reached, but it does not look like an HR attendance server.',
        );
      }

      if (response.statusCode >= 500) {
        return ServerCheckResult(
          url: normalizedUrl,
          isConnected: false,
          statusCode: response.statusCode,
          message:
              'Server is online, but returned HTTP ${response.statusCode}. It may be having problems.',
        );
      }

      return ServerCheckResult(
        url: normalizedUrl,
        isConnected: true,
        statusCode: response.statusCode,
        message: response.statusCode == 200
            ? 'Connected. Server is reachable.'
            : 'Server is reachable (HTTP ${response.statusCode}).',
      );
    } on TimeoutException {
      return ServerCheckResult(
        url: serverUrl,
        isConnected: false,
        message: 'Connection timed out. Check internet or server address.',
      );
    } on FormatException catch (e) {
      return ServerCheckResult(
        url: serverUrl,
        isConnected: false,
        message: e.message,
      );
    } on http.ClientException catch (e) {
      return ServerCheckResult(
        url: serverUrl,
        isConnected: false,
        message: e.message,
      );
    } catch (e) {
      return ServerCheckResult(
        url: serverUrl,
        isConnected: false,
        message: 'Cannot connect to server. $e',
      );
    }
  }

  bool _looksLikeAppBackend(String body) {
    try {
      final decoded = json.decode(body);
      return decoded is Map &&
          decoded.containsKey('status') &&
          decoded.containsKey('message');
    } catch (_) {
      return false;
    }
  }
}
