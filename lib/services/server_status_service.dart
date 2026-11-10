import 'dart:async';
import 'dart:convert';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:cnattendance/services/server_url_resolver.dart';
import 'package:cnattendance/services/server_configuration.dart';
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
      : _preferences = preferences ??
            Preferences(
              serverUrlResolver:
                  client == null ? null : ServerUrlResolver(client: client),
            ),
        _client = client ?? http.Client();

  final Preferences _preferences;
  final http.Client _client;

  Future<String> currentServerUrl() => _preferences.getAppUrl();

  String normalizeScannedServer(String value) {
    return ServerConfiguration.parse(value).primaryUrl;
  }

  Future<ServerCheckResult> checkCurrentServer() async {
    final configuredUrl = await _preferences.getConfiguredAppUrl();
    final selectedUrl = await _preferences.getAppUrl(forceCheck: true);
    final result = await checkServer(selectedUrl);
    if (result.isConnected &&
        ServerUrlResolver.normalize(configuredUrl) !=
            ServerUrlResolver.normalize(selectedUrl)) {
      return ServerCheckResult(
        url: result.url,
        isConnected: true,
        statusCode: result.statusCode,
        message: 'Connected to backup server. Primary server is unavailable.',
      );
    }
    return result;
  }

  Future<ServerCheckResult> checkServer(String serverUrl) {
    return _probe(serverUrl, requireAppBackend: false);
  }

  Future<ServerCheckResult> switchServer(String scannedValue) async {
    late final ServerConfiguration configuration;
    try {
      configuration = ServerConfiguration.parse(scannedValue);
    } on FormatException catch (e) {
      return ServerCheckResult(
          url: scannedValue, isConnected: false, message: e.message);
    }
    final result =
        await _probe(configuration.primaryUrl, requireAppBackend: true);
    if (result.isConnected) {
      await _preferences.saveServerConfiguration(configuration, verified: true);
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

      final response = await _client.get(uri, headers: const {
        'Accept': 'application/json; charset=UTF-8'
      }).timeout(const Duration(seconds: 15));

      final appBackend =
          response.statusCode == 200 && _looksLikeAppBackend(response.body);

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
          decoded['status'] == true &&
          decoded.containsKey('message');
    } catch (_) {
      return false;
    }
  }
}
