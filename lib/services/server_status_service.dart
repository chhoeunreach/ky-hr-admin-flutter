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

  Future<ServerCheckResult> checkServer(String serverUrl) async {
    try {
      final normalizedUrl = normalizeScannedServer(serverUrl);
      final token = await _preferences.getToken();
      final uri = Uri.parse('$normalizedUrl${Constant.DASHBOARD_URL}');

      final headers = <String, String>{
        'Accept': 'application/json; charset=UTF-8',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final response = await _client
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        return ServerCheckResult(
          url: normalizedUrl,
          isConnected: true,
          statusCode: response.statusCode,
          message: 'Connected. Your account can use this server.',
        );
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        return ServerCheckResult(
          url: normalizedUrl,
          isConnected: false,
          statusCode: response.statusCode,
          message:
              'Server reached, but this login token is not accepted there.',
        );
      }

      return ServerCheckResult(
        url: normalizedUrl,
        isConnected: false,
        statusCode: response.statusCode,
        message: _serverMessage(response.body) ??
            'Server reached, but returned HTTP ${response.statusCode}.',
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

  Future<ServerCheckResult> switchServer(String scannedValue) async {
    final result = await checkServer(scannedValue);
    if (result.isConnected) {
      await _preferences.saveAppUrl(result.url);
    }
    return result;
  }

  String? _serverMessage(String body) {
    try {
      final decoded = json.decode(body);
      if (decoded is Map && decoded['message'] != null) {
        return decoded['message'].toString();
      }
    } catch (_) {}
    return null;
  }
}
