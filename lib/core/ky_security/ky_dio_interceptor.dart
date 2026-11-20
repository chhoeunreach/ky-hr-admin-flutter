import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import 'ky_security_manager.dart';
import 'package:flutter/foundation.dart';

/// Adds signed device-session headers to Dio requests. FormData is cloned,
/// serialized to temporary disk storage, and hashed before its exact bytes are
/// streamed to the server. It avoids memory buffering for photo uploads.
class KyDioSecurityInterceptor extends Interceptor {
  KyDioSecurityInterceptor({KySecurityManager? security})
      : _security = security ?? KySecurityManager.shared;

  final KySecurityManager _security;

  @override
  Future<void> onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final headers = <String, String>{
      for (final entry in options.headers.entries)
        entry.key: entry.value.toString(),
    };
    File? bodyFile;
    Directory? bodyDirectory;
    try {
      if (options.data is FormData) {
        if (!await _security.enforcementRequired(headers, uri: options.uri)) {
          handler.next(options);
          return;
        }
        final form = (options.data as FormData).clone();
        final bodyStream = form.finalize();
        bodyDirectory = await Directory.systemTemp.createTemp('ky-dio-');
        bodyFile = File('${bodyDirectory.path}/body');
        await bodyFile.openWrite().addStream(bodyStream);
        final digest = await sha256.bind(bodyFile.openRead()).first;
        final signed = await _security.authorizeRequest(
          method: options.method,
          uri: options.uri,
          body: '',
          bodySha256: digest.toString(),
          existingHeaders: headers,
        );
        options.headers.addAll(signed ?? const {});
        options.headers[Headers.contentTypeHeader] =
            'multipart/form-data; boundary=${form.boundary}';
        options.headers[Headers.contentLengthHeader] =
            (await bodyFile.length()).toString();
        options.extra['kySecurityBodyDirectory'] = bodyDirectory.path;
        options.data = bodyFile.openRead().map(Uint8List.fromList);
        handler.next(options);
        return;
      }

      if (options.data != null &&
          options.data is! String &&
          options.data is! Map) {
        if (await _security.enforcementRequired(headers, uri: options.uri)) {
          throw const KySecurityAccessException('unsupportedRequestBody');
        }
        handler.next(options);
        return;
      }
      final bytes = options.data == null
          ? <int>[]
          : options.data is String
              ? utf8.encode(options.data as String)
              : utf8.encode(jsonEncode(options.data));
      final body = options.data is String ? options.data as String : '';
      final signed = await _security.authorizeRequest(
        method: options.method,
        uri: options.uri,
        body: body,
        bodySha256: sha256.convert(bytes).toString(),
        existingHeaders: headers,
      );
      if (signed != null) options.headers.addAll(signed);
      handler.next(options);
    } on KySecurityAccessException catch (error) {
      if (bodyDirectory != null) await _deleteDirectory(bodyDirectory.path);
      handler.reject(DioException(requestOptions: options, error: error));
    } catch (error) {
      if (bodyDirectory != null) await _deleteDirectory(bodyDirectory.path);
      handler.reject(DioException(requestOptions: options, error: error));
    }
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _security.handleProtectedApiStatus(response.statusCode ?? 0);
    final path =
        response.requestOptions.extra.remove('kySecurityBodyDirectory');
    if (path is String) _deleteDirectory(path);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final statusCode = err.response?.statusCode;
    if (statusCode != null) _security.handleProtectedApiStatus(statusCode);
    final path = err.requestOptions.extra.remove('kySecurityBodyDirectory');
    if (path is String) _deleteDirectory(path);
    handler.next(err);
  }

  Future<void> _deleteDirectory(String path) async {
    try {
      final directory = Directory(path);
      if (await directory.exists()) await directory.delete(recursive: true);
    } catch (error) { if (kDebugMode) debugPrint('KyDioInterceptor: failed to delete temp directory: $error'); }
  }
}
