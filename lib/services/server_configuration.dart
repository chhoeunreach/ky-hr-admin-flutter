import 'dart:convert';

import 'server_url_resolver.dart';

/// Accepts old URL QR codes and the backend's backup-enabled QR payload.
class ServerConfiguration {
  const ServerConfiguration(this.primaryUrl,
      {this.fallbackUrl, this.hasFallback = false});

  final String primaryUrl;
  final String? fallbackUrl;
  final bool hasFallback;

  factory ServerConfiguration.parse(String scannedValue) {
    var value = scannedValue.trim();
    try {
      value = utf8.decode(base64.decode(value)).trim();
    } catch (_) {}

    String? primary;
    String? fallback;
    var hasFallback = false;
    if (value.startsWith('{')) {
      try {
        final data = jsonDecode(value);
        if (data is! Map || data['server_url'] is! String) {
          throw const FormatException();
        }
        primary = ServerUrlResolver.normalize(data['server_url'] as String);
        hasFallback = data.containsKey('server_fallback_url');
        final backup = data['server_fallback_url'];
        if (backup != null && backup != '') {
          fallback =
              backup is String ? ServerUrlResolver.normalize(backup) : null;
          if (fallback == null) throw const FormatException();
        }
      } catch (_) {
        throw const FormatException('Invalid server QR code or URL.');
      }
    } else {
      primary = ServerUrlResolver.normalize(value);
    }
    if (primary == null) {
      throw const FormatException('Invalid server QR code or URL.');
    }
    return ServerConfiguration(primary,
        fallbackUrl: fallback == primary ? null : fallback,
        hasFallback: hasFallback);
  }
}
