import 'dart:convert';

import 'package:cnattendance/services/server_configuration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads legacy URL and base64 URL codes', () {
    for (final value in [
      'https://primary.example',
      base64Encode(utf8.encode('https://primary.example/')),
    ]) {
      final configuration = ServerConfiguration.parse(value);
      expect(configuration.primaryUrl, 'https://primary.example/');
      expect(configuration.hasFallback, isFalse);
    }
  });

  test('reads backend backup QR format', () {
    final configuration = ServerConfiguration.parse(
        base64Encode(utf8.encode('{"server_url":"http://192.168.0.113:8000/",'
            '"server_fallback_url":"http://192.168.0.113:8001/"}')));
    expect(configuration.primaryUrl, 'http://192.168.0.113:8000/');
    expect(configuration.fallbackUrl, 'http://192.168.0.113:8001/');
    expect(configuration.hasFallback, isTrue);
  });

  test('rejects malformed payloads and URLs with credentials or fragments', () {
    for (final value in [
      'not a server',
      'ftp://primary.example',
      'https://user:password@primary.example',
      'https://primary.example/#path',
      '{"server_url":7}',
      '{"server_url":"https://primary.example","server_fallback_url":7}',
    ]) {
      expect(() => ServerConfiguration.parse(value), throwsFormatException);
    }
  });
}
