import 'community_media_urls.dart';
import 'package:cnattendance/core/ky_security/ky_http.dart';
import 'dart:convert';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'package:cnattendance/utils/constant.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class CommunityApi {
  CommunityApi({Preferences? preferences, http.Client? client})
      : _preferences = preferences ?? Preferences(),
        _client = client ?? http.Client();
  final Preferences _preferences;
  final http.Client _client;
  void dispose() => _client.close();

  Future<Map<String, dynamic>> request(String method, String path,
      {Map<String, dynamic>? data,
      String? filePath,
      String? fileMime,
      List<String>? filePaths,
      List<String>? fileMimes}) async {
    return _request(method, path,
        data: data,
        filePath: filePath,
        fileMime: fileMime,
        filePaths: filePaths,
        fileMimes: fileMimes);
  }

  Future<Map<String, dynamic>> requestWithThumbnail(String method, String path,
      {Map<String, dynamic>? data,
      String? filePath,
      String? fileMime,
      List<String>? filePaths,
      List<String>? fileMimes,
      List<int>? thumbnailBytes,
      String? thumbnailFileName,
      String? thumbnailMime}) async {
    return _request(method, path,
        data: data,
        filePath: filePath,
        fileMime: fileMime,
        filePaths: filePaths,
        fileMimes: fileMimes,
        thumbnailBytes: thumbnailBytes,
        thumbnailFileName: thumbnailFileName,
        thumbnailMime: thumbnailMime);
  }

  Future<Map<String, dynamic>> _request(String method, String path,
      {Map<String, dynamic>? data,
      String? filePath,
      String? fileMime,
      List<String>? filePaths,
      List<String>? fileMimes,
      List<int>? thumbnailBytes,
      String? thumbnailFileName,
      String? thumbnailMime}) async {
    final base = await _preferences.getAppUrl();
    final token = await _preferences.getToken();
    final uri = Uri.parse('$base${Constant.API_URL}/$path');
    final headers = {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token'
    };
    late http.BaseRequest request;
    if (filePath != null || (filePaths != null && filePaths.isNotEmpty)) {
      final upload = http.MultipartRequest(method, uri)
        ..headers.addAll(headers);
      upload.fields
          .addAll((data ?? {}).map((key, value) => MapEntry(key, '$value')));
      if (filePath != null) {
        upload.files.add(await http.MultipartFile.fromPath('media', filePath,
            contentType: fileMime == null ? null : MediaType.parse(fileMime)));
      }
      if (filePaths != null) {
        for (var index = 0; index < filePaths.length; index++) {
          final mime = fileMimes != null && index < fileMimes.length
              ? fileMimes[index]
              : null;
          upload.files.add(await http.MultipartFile.fromPath(
              'media_files[]', filePaths[index],
              contentType: mime == null ? null : MediaType.parse(mime)));
        }
      }
      if (thumbnailBytes != null && thumbnailBytes.isNotEmpty) {
        upload.files.add(http.MultipartFile.fromBytes(
          'thumbnail',
          thumbnailBytes,
          filename: thumbnailFileName ?? 'thumbnail.jpg',
          contentType: thumbnailMime == null
              ? MediaType('image', 'jpeg')
              : MediaType.parse(thumbnailMime),
        ));
      }
      request = upload;
    } else {
      request = http.Request(method, uri)
        ..headers.addAll({...headers, 'Content-Type': 'application/json'})
        ..body = jsonEncode(data ?? {});
    }
    final response = await KyHttp.sendRequest(request, client: _client)
        .then(http.Response.fromStream)
        .timeout(const Duration(seconds: 120));
    final rawBody = response.body.trim();
    final isSuccess = response.statusCode >= 200 && response.statusCode < 300;
    dynamic decoded;
    if (rawBody.isNotEmpty) {
      try {
        // Large feed payloads are decoded on a worker isolate so a full page of
        // posts cannot block the frame that delivers it. Small API responses
        // stay inline to avoid isolate start-up overhead.
        decoded = rawBody.length >= 64 * 1024 && !kIsWeb
            ? await compute(_decodeCommunityJson, rawBody)
            : jsonDecode(rawBody);
      } catch (_) {
        decoded = null;
      }
    }
    Map<String, dynamic> body;
    if (decoded is Map) {
      body = Map<String, dynamic>.from(decoded);
    } else if (decoded is List) {
      // Some endpoints return a bare JSON array. Normalise it so callers can
      // keep reading `data` consistently.
      body = {'data': decoded};
    } else if (decoded != null) {
      body = {'data': decoded};
    } else if (isSuccess) {
      if (rawBody.isNotEmpty) {
        throw Exception(
            'The server returned an invalid response. Please try again.');
      }
      body = {'data': <dynamic>[]};
    } else {
      throw Exception(_responseError(response.statusCode));
    }
    if (!isSuccess) {
      final errors = body['errors'];
      final firstError =
          errors is Map && errors.isNotEmpty ? errors.values.first : null;
      final detail = firstError is List
          ? firstError.join('\n')
          : firstError ?? body['message'] ?? body['error'];
      throw Exception('${detail ?? _responseError(response.statusCode)}');
    }
    return communityResponseMediaUrls(body, Uri.parse(base));
  }
}

dynamic _decodeCommunityJson(String body) => jsonDecode(body);

String _responseError(int status) {
  if (status == 401) return 'Your session has expired. Please sign in again.';
  if (status == 403) return 'You do not have permission to do that.';
  if (status == 404) return 'This content is no longer available.';
  if (status == 408 || status == 504) {
    return 'The server took too long to respond. Please try again.';
  }
  if (status == 413) return 'The file is too large to upload.';
  if (status == 429) {
    return 'Too many requests. Please wait a moment and try again.';
  }
  if (status >= 500) {
    return 'The server is temporarily unavailable ($status). Please try again.';
  }
  return 'The request failed ($status). Please try again.';
}

String communityError(Object error) =>
    error.toString().replaceFirst('Exception: ', '');
