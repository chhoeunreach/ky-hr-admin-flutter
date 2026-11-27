import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Direct TLS transport that keeps the platform CA validation and also checks
/// a build-time SPKI pin set for the official Laravel API host.
class KyCertificatePinning {
  KyCertificatePinning._();

  static const enabled = bool.fromEnvironment(
    'KY_SECURITY_PINNING_ENABLED',
    defaultValue: false,
  );
  static const _rawPins = String.fromEnvironment('KY_SECURITY_SPKI_PINS');
  static const _rawHosts = String.fromEnvironment(
    'KY_SECURITY_PINNED_HOSTS',
    defaultValue: 'kneayerng.com,hr.kytech.info,hr.rvstechsolution.com',
  );

  static final pins = _rawPins
      .split(',')
      .map((pin) => pin.trim().replaceFirst(RegExp(r'^sha256/'), ''))
      .where((pin) => pin.isNotEmpty)
      .toSet();
  static final hosts = _rawHosts
      .split(',')
      .map((host) => host.trim().toLowerCase())
      .where((host) => host.isNotEmpty)
      .toSet();
  static bool get hasUsablePinSet => isUsablePinSet(pins);
  static final http.Client sharedClient =
      _KyPinnedHttpClient(IOClient(createHttpClient()));
  static http.Client? _defaultClient;
  static Zone? _defaultClientZone;

  /// Unpinned traffic reuses one client per zone so `http.runWithClient`
  /// test overrides still apply while production keeps a single pooled client.
  static http.Client _fallbackClient() {
    final zone = Zone.current;
    final cached = _defaultClient;
    if (cached != null && identical(zone, _defaultClientZone)) return cached;
    final client = http.Client();
    _defaultClient = client;
    _defaultClientZone = zone;
    return client;
  }

  static bool protectsHost(String host) {
    if (!enabled) return false;
    final normalized = host.toLowerCase();
    return hosts.contains(normalized);
  }

  @visibleForTesting
  static bool isUsablePinSet(Iterable<String> values) {
    final unique = values.toSet();
    if (unique.length < 2) return false;
    return unique.every((pin) {
      try {
        final decoded = base64Decode(pin);
        return decoded.length == 32 && base64Encode(decoded) == pin;
      } on FormatException {
        return false;
      }
    });
  }

  static http.Client clientFor(Uri uri, http.Client? supplied,
      {bool authenticatedApi = false}) {
    if (enabled && authenticatedApi && !protectsHost(uri.host)) {
      throw const HttpException(
          'Authenticated API traffic is restricted to configured pinned hosts.');
    }
    if (!protectsHost(uri.host)) return supplied ?? _fallbackClient();
    if (uri.scheme != 'https') {
      throw const HttpException('HTTPS is required for the pinned API host.');
    }
    if (!hasUsablePinSet) {
      throw const HttpException(
          'The release does not have a valid primary and backup API pin set.');
    }
    return sharedClient;
  }

  static HttpClient createHttpClient() {
    final client = HttpClient();
    client.findProxy = (_) => 'DIRECT';
    client.connectionFactory = _openSocket;
    return client;
  }

  static Future<ConnectionTask<Socket>> _openSocket(
    Uri uri,
    String? proxyHost,
    int? proxyPort,
  ) async {
    if (proxyHost != null || proxyPort != null) {
      throw const HttpException(
          'Proxy transport is disabled for App Security API traffic.');
    }
    if (protectsHost(uri.host)) {
      if (uri.scheme != 'https')
        throw const HttpException('HTTPS is required for the pinned API host.');
      if (!hasUsablePinSet)
        throw const HttpException(
            'The release does not have a valid primary and backup API pin set.');
    }
    if (uri.scheme == 'http') return Socket.startConnect(uri.host, uri.port);
    if (uri.scheme != 'https')
      throw const HttpException('Unsupported API transport.');

    final task = await SecureSocket.startConnect(uri.host, uri.port);
    final socket = task.socket.then<Socket>((secureSocket) {
      if (protectsHost(uri.host)) {
        final certificate = secureSocket.peerCertificate;
        if (certificate == null || !matchesCertificate(certificate)) {
          secureSocket.destroy();
          throw const TlsException(
              'The API certificate does not match the pinned key set.');
        }
      }
      return secureSocket;
    });
    return ConnectionTask.fromSocket(socket, task.cancel);
  }

  @visibleForTesting
  static String subjectPublicKeyPinFromDer(Uint8List der) =>
      base64Encode(sha256.convert(_subjectPublicKeyInfo(der)).bytes);

  @visibleForTesting
  static bool matchesCertificate(X509Certificate certificate) {
    try {
      final spki = _subjectPublicKeyInfo(certificate.der);
      final digest = sha256.convert(spki);
      return pins.contains(base64Encode(digest.bytes));
    } catch (_) {
      return false;
    }
  }

  static Uint8List _subjectPublicKeyInfo(Uint8List der) {
    final outer = _readTlv(der, 0);
    if (outer.tag != 0x30)
      throw const FormatException('Invalid X.509 certificate.');
    final tbs = _readTlv(der, outer.contentStart);
    if (tbs.tag != 0x30)
      throw const FormatException('Invalid X.509 TBS certificate.');
    var offset = tbs.contentStart;
    var field = _readTlv(der, offset);
    if (field.tag == 0xa0) {
      offset = field.end;
      field = _readTlv(der, offset);
    }
    // serial, signature algorithm, issuer, validity, and subject
    for (var skipped = 0; skipped < 5; skipped++) {
      offset = field.end;
      field = _readTlv(der, offset);
    }
    if (field.tag != 0x30 || field.end > tbs.end) {
      throw const FormatException('X.509 public key info is missing.');
    }
    return Uint8List.fromList(der.sublist(field.start, field.end));
  }

  static _DerTlv _readTlv(Uint8List bytes, int offset) {
    if (offset < 0 || offset + 2 > bytes.length)
      throw const FormatException('Invalid DER.');
    final tag = bytes[offset];
    final firstLength = bytes[offset + 1];
    var contentStart = offset + 2;
    var length = 0;
    if ((firstLength & 0x80) == 0) {
      length = firstLength;
    } else {
      final lengthBytes = firstLength & 0x7f;
      if (lengthBytes == 0 ||
          lengthBytes > 4 ||
          contentStart + lengthBytes > bytes.length) {
        throw const FormatException('Invalid DER length.');
      }
      for (var i = 0; i < lengthBytes; i++) {
        length = (length << 8) | bytes[contentStart + i];
      }
      contentStart += lengthBytes;
    }
    final end = contentStart + length;
    if (end > bytes.length)
      throw const FormatException('Truncated DER object.');
    return _DerTlv(tag, offset, contentStart, end);
  }
}

class _KyPinnedHttpClient extends http.BaseClient {
  _KyPinnedHttpClient(this._inner);
  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (KyCertificatePinning.protectsHost(request.url.host)) {
      if (request.url.scheme != 'https' ||
          !KyCertificatePinning.hasUsablePinSet) {
        throw const HttpException('Pinned HTTPS transport is not configured.');
      }
      request.followRedirects = false;
    }
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}

class _DerTlv {
  const _DerTlv(this.tag, this.start, this.contentStart, this.end);
  final int tag;
  final int start;
  final int contentStart;
  final int end;
}
