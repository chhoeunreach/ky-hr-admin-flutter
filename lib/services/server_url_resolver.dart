import 'dart:convert';
import 'package:cnattendance/config/backend_server_defaults.dart';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Resolves the server before sending business requests, so writes are never
/// automatically replayed against another server after an uncertain failure.
class ServerUrlResolver {
  ServerUrlResolver({
    http.Client? client,
    this.checkInterval = const Duration(seconds: 15),
    this.timeout = const Duration(seconds: 5),
    this.healthyCacheTtl = Duration.zero,
  }) : _client = client ?? http.Client();

  static final shared = ServerUrlResolver();

  /// How long a successful primary-server health check may be reused without
  /// probing again. Zero preserves the strict "probe before every request"
  /// contract (used by tests and callers that need it). The running app opts
  /// into a short window to halve the round-trips on every screen, while still
  /// re-checking often enough to fail over quickly. Writes are never replayed
  /// against another server: a stale selection only causes that single request
  /// to fail, and the next call re-resolves.
  Duration healthyCacheTtl;

  /// Notified when the configured primary server and its backup are both
  /// unreachable, so the app can show a blocking "need to connect" alert.
  /// The app wires this in main(); tests leave it null.
  static void Function(String primary, String? fallback)? onAllServersUnreachable;

  final http.Client _client;
  final Duration checkInterval;
  final Duration timeout;
  final _pending = <String, Future<String>>{};
  final _cached = <String, ({String url, DateTime checkedAt})>{};

  void invalidate(String url) {
    _cached.remove(normalize(url));
  }

  Future<void> seedDefaults(String url, SharedPreferences prefs) async {
    final primary = normalize(url);
    if (primary != normalize(BackendServerDefaults.primaryUrl)) return;
    final backup = normalize(BackendServerDefaults.fallbackUrl) ?? '';
    final marker = 'server_defaults:$primary';
    if (prefs.getString(marker) != backup) {
      await prefs.setString('server_fallback:$primary', backup);
      await prefs.setString(marker, backup);
      _cached.remove(primary);
    }
  }

  static String? normalize(String? value) {
    final uri = Uri.tryParse(value?.trim() ?? '');
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      return null;
    }
    return '${uri.toString().replaceFirst(RegExp(r'/+$'), '')}/';
  }

  Future<String> resolve(String configuredUrl, SharedPreferences prefs,
      {bool forceCheck = false}) async {
    final primary = normalize(configuredUrl);
    if (primary == null) return configuredUrl;
    await seedDefaults(primary, prefs);
    final cached = _cached[primary];
    if (!forceCheck && cached != null) {
      final age = DateTime.now().difference(cached.checkedAt);
      if (cached.url == primary) {
        // Reuse a recently verified healthy primary without another probe.
        if (age < healthyCacheTtl) return primary;
      } else if (age < checkInterval) {
        // A cached backup can go offline too. Verify it before using it again.
        if (_isBackend(await _probe(cached.url))) {
          return cached.url;
        }
        _cached.remove(primary);
      }
    }
    final selected =
        await (_pending[primary] ??= _resolve(primary, prefs).whenComplete(() {
      _pending.remove(primary);
    }));
    return selected;
  }

  Future<String> _resolve(String primary, SharedPreferences prefs) async {
    final key = 'server_fallback:$primary';
    final response = await _probe(primary);
    var selected = primary;
    if (_isBackend(response)) {
      // Only accept configuration from a successful HR backend envelope.
      if (response != null) {
        try {
          final envelope = jsonDecode(response.body);
          final data = envelope is Map && envelope['status'] == true
              ? envelope['data']
              : null;
          if (data is Map && data.containsKey('server_fallback_url')) {
            final value = data['server_fallback_url'];
            final fallback = normalize(value is String ? value : null);
            if (fallback == null || fallback == primary) {
              // An empty value explicitly disables even the bundled backup.
              await prefs.setString(key, '');
            } else {
              await prefs.setString(key, fallback);
            }
          }
        } catch (_) {
          // Older servers may not expose backup configuration yet.
        }
      }
    } else {
      final fallback = normalize(prefs.containsKey(key)
          ? prefs.getString(key)
          : primary == normalize(BackendServerDefaults.primaryUrl)
              ? BackendServerDefaults.fallbackUrl
              : null);
      if (fallback != null && fallback != primary) {
        final backupResponse = await _probe(fallback);
        if (_isBackend(backupResponse)) {
          selected = fallback;
        } else {
          onAllServersUnreachable?.call(primary, fallback);
        }
      } else {
        onAllServersUnreachable?.call(primary, null);
      }
    }
    // Remember the last verified selection. A healthy primary is reused for
    // [healthyCacheTtl]; a backup is briefly cached to avoid repeatedly probing
    // an outage. After the window expires the next call probes again, so a
    // recovered primary is picked up and a dead one is still detected.
    _cached[primary] = (url: selected, checkedAt: DateTime.now());
    return selected;
  }

  Future<http.Response?> _probe(String url) async {
    try {
      return await _client.get(
        Uri.parse('${url}api/app-version'),
        headers: const {'Accept': 'application/json'},
      ).timeout(timeout);
    } catch (_) {
      return null;
    }
  }

  bool _isBackend(http.Response? response) {
    if (response == null || response.statusCode != 200) return false;
    try {
      final data = jsonDecode(response.body);
      return data is Map &&
          data['status'] == true &&
          data.containsKey('message');
    } catch (_) {
      return false;
    }
  }
}
