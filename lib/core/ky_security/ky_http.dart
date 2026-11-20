import 'dart:convert';
import 'dart:io';

import 'package:cnattendance/core/ky_security/ky_security_manager.dart';
import 'package:crypto/crypto.dart';
import 'package:cnattendance/core/ky_security/ky_certificate_pinning.dart';
import 'package:http/http.dart' as http;

/// Drop-in top-level HTTP helpers for authenticated, buffered API calls.
/// Multipart streaming must use a separate streaming-signing implementation.
class KyHttp {
  static Future<http.Response> get(Uri url, {Map<String, String>? headers}) =>
      _send('GET', url, headers: headers);

  static Future<http.Response> post(Uri url,
          {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
      _send('POST', url, headers: headers, body: body, encoding: encoding);

  static Future<http.Response> put(Uri url,
          {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
      _send('PUT', url, headers: headers, body: body, encoding: encoding);

  static Future<http.Response> patch(Uri url,
          {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
      _send('PATCH', url, headers: headers, body: body, encoding: encoding);

  static Future<http.Response> delete(Uri url,
          {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
      _send('DELETE', url, headers: headers, body: body, encoding: encoding);

  static Future<http.Response> head(Uri url, {Map<String, String>? headers}) =>
      _send('HEAD', url, headers: headers);

  /// Signs logout when the device session is usable, but still lets an
  /// authenticated blocked/revoked user revoke their Passport token. Laravel
  /// keeps the account logout endpoint outside device authorization checks.
  static Future<http.Response> accountLogout(Uri url,
      {Map<String, String>? headers, http.Client? client}) async {
    final requestHeaders = Map<String, String>.from(headers ?? const {});
    try {
      final signed = await KySecurityManager.shared.authorizeRequest(
        method: 'GET',
        uri: url,
        body: '',
        existingHeaders: requestHeaders,
      );
      if (signed != null) {
        requestHeaders
          ..clear()
          ..addAll(signed);
      }
    } catch (_) {
      // Signing failure must not strand an authenticated user on the gate.
    }
    final selectedClient = KyCertificatePinning.clientFor(
      url,
      client,
      authenticatedApi:
          (requestHeaders['Authorization'] ?? '').startsWith('Bearer '),
    );
    final response = await selectedClient.get(url, headers: requestHeaders);
    KySecurityManager.shared.handleProtectedApiStatus(response.statusCode);
    return response;
  }

  static Future<http.Response> getWithClient(http.Client client, Uri url,
          {Map<String, String>? headers}) =>
      _send('GET', url, headers: headers, client: client);

  static Future<http.Response> postWithClient(http.Client client, Uri url,
          {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
      _send('POST', url,
          headers: headers, body: body, encoding: encoding, client: client);

  static Future<http.Response> putWithClient(http.Client client, Uri url,
          {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
      _send('PUT', url,
          headers: headers, body: body, encoding: encoding, client: client);

  static Future<http.Response> patchWithClient(http.Client client, Uri url,
          {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
      _send('PATCH', url,
          headers: headers, body: body, encoding: encoding, client: client);

  static Future<http.Response> deleteWithClient(http.Client client, Uri url,
          {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
      _send('DELETE', url,
          headers: headers, body: body, encoding: encoding, client: client);

  /// Applies the signing policy to an existing buffered request while
  /// preserving the caller's configured HTTP transport.
  static Future<http.StreamedResponse> sendRequest(
    http.BaseRequest request, {
    http.Client? client,
  }) async {
    if (request is http.MultipartRequest)
      return sendMultipart(request, client: client);
    if (request is http.Request) {
      try {
        final secured = await KySecurityManager.shared.authorizeRequest(
          method: request.method,
          uri: request.url,
          body: '',
          bodySha256: sha256.convert(request.bodyBytes).toString(),
          existingHeaders: request.headers,
        );
        if (secured != null) {
          request.headers
            ..clear()
            ..addAll(secured);
        }
      } on KySecurityAccessException catch (error) {
        return _streamDenied(request.url, error, method: request.method);
      }
    }
    final response = await KyCertificatePinning.clientFor(
      request.url,
      client,
      authenticatedApi:
          (request.headers['Authorization'] ?? '').startsWith('Bearer '),
    ).send(request);
    KySecurityManager.shared.handleProtectedApiStatus(response.statusCode);
    return response;
  }

  /// Signs and streams multipart uploads without holding the complete file
  /// payload in memory. The request is written to a temporary file so its hash
  /// is known before sending the signed request; the temporary file is removed
  /// after transmission.
  static Future<http.StreamedResponse> sendMultipart(
    http.MultipartRequest request, {
    http.Client? client,
  }) async {
    try {
      if (!await KySecurityManager.shared
          .enforcementRequired(request.headers, uri: request.url)) {
        return KyCertificatePinning.clientFor(request.url, client)
            .send(request);
      }
    } on KySecurityAccessException catch (error) {
      return _streamDenied(request.url, error);
    }

    final temporaryDirectory =
        await Directory.systemTemp.createTemp('ky-request-');
    final temporary = File('${temporaryDirectory.path}/body');
    try {
      await temporary.openWrite().addStream(request.finalize());
      final digest = await sha256.bind(temporary.openRead()).first;
      final headers = await KySecurityManager.shared.authorizeRequest(
        method: request.method,
        uri: request.url,
        body: '',
        bodySha256: digest.toString(),
        existingHeaders: request.headers,
      );
      final upload = http.StreamedRequest(request.method, request.url)
        ..headers.addAll(headers ?? request.headers)
        ..contentLength = await temporary.length();
      final response = KyCertificatePinning.clientFor(
        upload.url,
        client,
        authenticatedApi:
            (upload.headers['Authorization'] ?? '').startsWith('Bearer '),
      ).send(upload);
      await temporary.openRead().pipe(upload.sink);
      final streamedResponse = await response;
      KySecurityManager.shared
          .handleProtectedApiStatus(streamedResponse.statusCode);
      return streamedResponse;
    } on KySecurityAccessException catch (error) {
      return _streamDenied(request.url, error);
    } finally {
      try {
        if (await temporaryDirectory.exists()) {
          await temporaryDirectory.delete(recursive: true);
        }
      } catch (_) {}
    }
  }

  static http.StreamedResponse _streamDenied(
      Uri uri, KySecurityAccessException error,
      {String method = 'POST'}) {
    final bytes = utf8
        .encode(jsonEncode({'error': 'app_security', 'message': error.state}));
    return http.StreamedResponse(
      Stream<List<int>>.value(bytes),
      423,
      request: http.Request(method, uri),
      contentLength: bytes.length,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  }

  static Future<http.Response> _send(
    String method,
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
    http.Client? client,
  }) async {
    final requestEncoding = encoding ?? utf8;
    final request = http.Request(method, url)..encoding = requestEncoding;
    if (body is Map) {
      request.bodyFields = body.map<String, String>(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    } else if (body is String) {
      request.body = body;
    } else if (body is List<int>) {
      request.bodyBytes = body;
    }
    final bytes = request.bodyBytes;
    final currentHeaders = Map<String, String>.from(headers ?? const {});
    final selectedClient = KyCertificatePinning.clientFor(
      url,
      client,
      authenticatedApi:
          (currentHeaders['Authorization'] ?? '').startsWith('Bearer '),
    );
    try {
      final signed = await KySecurityManager.shared.authorizeRequest(
        method: method,
        uri: url,
        body: '',
        bodySha256: sha256.convert(bytes).toString(),
        existingHeaders: currentHeaders,
      );
      final finalHeaders = signed ?? currentHeaders;
      final response = await switch (method) {
        'GET' => selectedClient.get(url, headers: finalHeaders),
        'POST' => selectedClient.post(url,
            headers: finalHeaders, body: body, encoding: encoding),
        'PUT' => selectedClient.put(url,
            headers: finalHeaders, body: body, encoding: encoding),
        'PATCH' => selectedClient.patch(url,
            headers: finalHeaders, body: body, encoding: encoding),
        'DELETE' => selectedClient.delete(url,
            headers: finalHeaders, body: body, encoding: encoding),
        'HEAD' => selectedClient.head(url, headers: finalHeaders),
        _ => throw UnsupportedError('Unsupported HTTP method: $method'),
      };
      KySecurityManager.shared.handleProtectedApiStatus(response.statusCode);
      return response;
    } on KySecurityAccessException catch (error) {
      return http.Response(
        jsonEncode({'error': 'app_security', 'message': error.state}),
        423,
        headers: const {'content-type': 'application/json; charset=utf-8'},
      );
    }
  }
}
