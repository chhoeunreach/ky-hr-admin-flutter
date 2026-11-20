import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android app identity and Keystore security bridge work', (
    tester,
  ) async {
    const security = MethodChannel('kneayerng/ky_security');
    const integrity = MethodChannel('cnattendance/app_integrity');

    final identity =
        await security.invokeMapMethod<String, dynamic>('identity');
    expect(identity, isNotNull);
    expect(identity!['packageName'], 'com.kneayerng.hrms');
    expect(identity['signingSha256'], isA<String>());
    expect(identity['versionName'], isA<String>());
    expect(identity['versionCode'], isA<int>());
    expect(identity['androidSdk'], greaterThanOrEqualTo(28));

    final integrityResult =
        await integrity.invokeMapMethod<String, dynamic>('verify');
    expect(integrityResult, isNotNull);
    expect(integrityResult!['tampered'], isFalse);
    expect(integrityResult['packageOk'], isTrue);
    expect(integrityResult['certOk'], isTrue);

    const alias = 'kneayerng_device_key_u987654321';
    final installationId = await security.invokeMethod<String>(
      'installationIdentity',
      {'keyAlias': alias},
    );
    final repeatedInstallationId = await security.invokeMethod<String>(
      'installationIdentity',
      {'keyAlias': alias},
    );
    expect(installationId, isNotNull);
    expect(installationId, repeatedInstallationId);

    final keyInfo = await security.invokeMapMethod<String, dynamic>(
      'ensureKey',
      {'keyAlias': alias, 'forceNew': false},
    );
    expect(keyInfo, isNotNull);
    final publicKey = base64Decode(keyInfo!['publicKey'] as String);
    expect(publicKey, isNotEmpty);

    final fingerprint = sha256.convert(publicKey).toString().toUpperCase();
    final selectedAlias = await security.invokeMethod<String>(
      'selectKeyAlias',
      {'preferredAlias': alias, 'publicKeyFingerprint': fingerprint},
    );
    expect(selectedAlias, alias);

    final payload = utf8.encode('kneayerng-android-keystore-smoke-test');
    final signature = await security.invokeMethod<String>(
      'sign',
      {'keyAlias': alias, 'payload': payload},
    );
    expect(base64Decode(signature!), isNotEmpty);

    final unknownAlias = await security.invokeMethod<String>(
      'selectKeyAlias',
      {
        'preferredAlias': 'kneayerng_device_key_u987654322',
        'publicKeyFingerprint': fingerprint,
      },
    );
    expect(unknownAlias, isNull);
  });
}
