import 'dart:convert';

import 'package:cnattendance/core/ky_security/ky_offline_authorization_lease.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const identity = {
    'packageName': 'com.kneayerng.hrms',
    'versionCode': 18,
    'signingSha256': 'AA:BB:CC',
  };
  const installationUuid = 'install-uuid';

  Map<String, dynamic> claims({
    int userId = 42,
    String installId = installationUuid,
    int leaseSeconds = 300,
    int expiresAt = 1300,
    String signer = 'AABBCC',
  }) =>
      {
        'version': 1,
        'lease_id': 'lease-uuid',
        'user_id': userId,
        'device_id': 'device-uuid',
        'installation_uuid': installId,
        'public_key_fingerprint': 'key-fingerprint',
        'package_name': 'com.kneayerng.hrms',
        'signing_sha256': signer,
        'version_code': 18,
        'session_id': 'session-uuid',
        'device_status': 'approved',
        'scope': 'offline_app_access',
        'issued_at': 1000,
        'expires_at': expiresAt,
        'lease_seconds': leaseSeconds,
      };

  test('decodes a base64url JSON lease payload', () {
    final encoded = base64Url.encode(utf8.encode(jsonEncode(claims())));
    expect(KyOfflineAuthorizationLease.decodePayload(encoded), claims());
  });

  test('binds lease to account, installation, package, signer and release', () {
    final valid = claims();
    bool matches(Map<String, dynamic> value) =>
        KyOfflineAuthorizationLease.matchesInstallation(
          value,
          userId: 42,
          installationUuid: installationUuid,
          identity: identity,
          maximumAllowedSeconds: 600,
        );

    expect(matches(valid), isTrue);
    expect(matches(claims(userId: 7)), isFalse);
    expect(matches(claims(installId: 'another-install')), isFalse);
    expect(matches(claims(signer: 'DDEEFF')), isFalse);
    expect(matches(claims(expiresAt: 1500)), isFalse);
    expect(matches(claims(leaseSeconds: 601, expiresAt: 1601)), isFalse);
  });
}
