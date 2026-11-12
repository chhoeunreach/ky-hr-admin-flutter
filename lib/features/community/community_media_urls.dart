import 'package:cnattendance/config/backend_server_defaults.dart';

/// Rebase our uploaded media when an API server changes address. Provider/CDN
/// links and signed URLs retain their original host and credentials.
String communityUploadUrl(String value, Uri server) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !['http', 'https'].contains(uri.scheme) ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      !RegExp(r'^/storage/(?:community|stories|video-streams)/[A-Za-z0-9._/-]+$')
          .hasMatch(uri.path) ||
      uri.pathSegments.any((part) => part == '..' || part == '.')) return value;
  final host = uri.host.toLowerCase();
  final known = {
    server.host.toLowerCase(),
    Uri.parse(BackendServerDefaults.primaryUrl).host.toLowerCase(),
    if (BackendServerDefaults.fallbackUrl != null)
      Uri.parse(BackendServerDefaults.fallbackUrl!).host.toLowerCase(),
  };
  final local = host == 'localhost' ||
      host == '::1' ||
      RegExp(r'^(?:127\.|10\.|192\.168\.|169\.254\.|172\.(?:1[6-9]|2[0-9]|3[01])\.)')
          .hasMatch(host) ||
      (host.contains(':') && RegExp(r'^(?:fc|fd|fe[89ab])').hasMatch(host));
  if (!local && !known.contains(host)) return value;
  return server.resolve(uri.path.substring(1)).toString();
}

Map<String, dynamic> communityResponseMediaUrls(
    Map<String, dynamic> body, Uri server) {
  dynamic visit(dynamic value) {
    if (value is List) return value.map(visit).toList();
    if (value is Map)
      return value.map<String, dynamic>((key, item) => MapEntry(
          key.toString(),
          ['media_url', 'thumbnail_url', 'playback_url'].contains(key) &&
                  item is String
              ? communityUploadUrl(item, server)
              : visit(item)));
    return value;
  }

  return visit(body) as Map<String, dynamic>;
}
