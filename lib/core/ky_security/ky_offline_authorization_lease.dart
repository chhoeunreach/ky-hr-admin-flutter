import 'dart:convert';

/// Parses and binds signed lease claims to this user and installed APK.
/// Cryptographic verification and encrypted persistence happen in Android.
class KyOfflineAuthorizationLease {
  const KyOfflineAuthorizationLease._();

  static const maximumLeaseSeconds = 86400;

  static Map<String, dynamic>? decodePayload(String payload) {
    try {
      final bytes = base64Url.decode(base64Url.normalize(payload));
      if (bytes.length > 8192) return null;
      final value = jsonDecode(utf8.decode(bytes));
      return value is Map<String, dynamic> ? value : null;
    } catch (_) {
      return null;
    }
  }

  static bool matchesInstallation(
    Map<String, dynamic> claims, {
    required int userId,
    required String installationUuid,
    required Map<String, dynamic> identity,
    required int maximumAllowedSeconds,
  }) {
    final issuedAt = claims['issued_at'];
    final expiresAt = claims['expires_at'];
    final leaseSeconds = claims['lease_seconds'];
    if (issuedAt is! int || expiresAt is! int || leaseSeconds is! int) {
      return false;
    }
    final signingSha256 = '${identity['signingSha256'] ?? ''}'
        .replaceAll(RegExp(r'[^A-Fa-f0-9]'), '')
        .toUpperCase();
    final leaseSigningSha256 = '${claims['signing_sha256'] ?? ''}'
        .replaceAll(RegExp(r'[^A-Fa-f0-9]'), '')
        .toUpperCase();
    return claims['version'] == 1 &&
        claims['scope'] == 'offline_app_access' &&
        claims['device_status'] == 'approved' &&
        claims['user_id'] == userId &&
        claims['installation_uuid'] == installationUuid &&
        claims['package_name'] == identity['packageName'] &&
        claims['version_code'] == identity['versionCode'] &&
        signingSha256.isNotEmpty &&
        signingSha256 == leaseSigningSha256 &&
        claims['device_id'] is String &&
        (claims['device_id'] as String).isNotEmpty &&
        claims['session_id'] is String &&
        claims['lease_id'] is String &&
        leaseSeconds > 0 &&
        leaseSeconds <= maximumLeaseSeconds &&
        leaseSeconds <= maximumAllowedSeconds &&
        expiresAt - issuedAt == leaseSeconds;
  }
}
