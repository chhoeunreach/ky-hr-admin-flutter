import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cnattendance/core/ky_security/ky_certificate_pinning.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('release pin set needs two distinct canonical SHA-256 values', () {
    const primary = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=';
    const backup = 'AQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQE=';

    expect(KyCertificatePinning.isUsablePinSet([primary, backup]), isTrue);
    expect(KyCertificatePinning.isUsablePinSet([primary]), isFalse);
    expect(KyCertificatePinning.isUsablePinSet([primary, primary]), isFalse);
    expect(KyCertificatePinning.isUsablePinSet([primary, 'bad-pin']), isFalse);
    expect(
      KyCertificatePinning.isUsablePinSet([
        primary,
        base64Encode(List<int>.filled(33, 1)),
      ]),
      isFalse,
    );
  });

  test('release pin policy trusts only explicitly configured hostnames', () {
    if (!KyCertificatePinning.enabled) return;

    for (final host in KyCertificatePinning.hosts) {
      expect(KyCertificatePinning.protectsHost(host), isTrue);
      expect(KyCertificatePinning.protectsHost('child.$host'), isFalse);
      expect(
          KyCertificatePinning.protectsHost('$host.attacker.invalid'), isFalse);
      expect(
        () => KyCertificatePinning.clientFor(
          Uri.https('child.$host', '/api'),
          null,
          authenticatedApi: true,
        ),
        throwsA(isA<HttpException>()),
      );
    }
  });

  test('configured official hosts select the shared pinned HTTP client', () {
    if (!KyCertificatePinning.enabled ||
        !KyCertificatePinning.hasUsablePinSet) {
      return;
    }

    final injectedClient = http.Client();
    addTearDown(injectedClient.close);
    for (final host in KyCertificatePinning.hosts) {
      expect(
        KyCertificatePinning.clientFor(
          Uri.https(host, '/api/app-version'),
          injectedClient,
        ),
        same(KyCertificatePinning.sharedClient),
      );
    }
    expect(
      KyCertificatePinning.clientFor(
        Uri.https('unlisted.example', '/api/app-version'),
        injectedClient,
      ),
      same(injectedClient),
    );
  });

  test('extracts the subject public key info pin from X.509 DER', () {
    final certificate = Uint8List.fromList([
      0x30,
      0x1c,
      0x30,
      0x15,
      0xa0,
      0x03,
      0x02,
      0x01,
      0x02,
      0x02,
      0x01,
      0x01,
      0x30,
      0x00,
      0x30,
      0x00,
      0x30,
      0x00,
      0x30,
      0x00,
      0x30,
      0x03,
      0x03,
      0x01,
      0x00,
      0x30,
      0x00,
      0x03,
      0x01,
      0x00,
    ]);
    final spki = Uint8List.fromList([0x30, 0x03, 0x03, 0x01, 0x00]);

    expect(KyCertificatePinning.subjectPublicKeyPinFromDer(certificate),
        base64Encode(sha256.convert(spki).bytes));
  });

  test(
      'release pin policy rejects the official API without a primary and backup',
      () {
    if (KyCertificatePinning.enabled && !KyCertificatePinning.hasUsablePinSet) {
      final host = KyCertificatePinning.hosts.first;
      expect(
        () => KyCertificatePinning.clientFor(Uri.https(host, '/api'), null),
        throwsA(isA<HttpException>()),
      );
    }
  });

  test('release pin policy rejects HTTP fallback for the official API', () {
    if (KyCertificatePinning.enabled) {
      final host = KyCertificatePinning.hosts.first;
      expect(
        () => KyCertificatePinning.clientFor(Uri.http(host, '/api'), null),
        throwsA(isA<HttpException>()),
      );
    }
  });

  test('rejects malformed certificate DER', () {
    expect(
      () => KyCertificatePinning.subjectPublicKeyPinFromDer(
          Uint8List.fromList([0x30, 0x01, 0x00])),
      throwsFormatException,
    );
  });
}
