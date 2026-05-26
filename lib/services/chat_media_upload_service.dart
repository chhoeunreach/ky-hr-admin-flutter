import 'dart:convert';
import 'dart:io';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class ChatMediaUpload {
  final String url;
  final String type;
  final String path;
  final int? width;
  final int? height;

  const ChatMediaUpload({
    required this.url,
    required this.type,
    required this.path,
    this.width,
    this.height,
  });

  factory ChatMediaUpload.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final source = data is Map ? Map<String, dynamic>.from(data) : json;

    return ChatMediaUpload(
      url: _readString(source, [
        'url',
        'media_url',
        'file_url',
        'attachment_url',
        'full_url',
      ]),
      type: source['type']?.toString() ?? '',
      path: _readString(source, ['path', 'media_path', 'file_path']),
      width: _readInt(source['width']),
      height: _readInt(source['height']),
    );
  }

  static String _readString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return '';
  }

  static int? _readInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    return int.tryParse(value.toString());
  }
}

class ChatMediaUploadException implements Exception {
  final String message;

  const ChatMediaUploadException(this.message);

  @override
  String toString() => message;
}

class ChatMediaUploadService {
  final Preferences _preferences;

  ChatMediaUploadService({Preferences? preferences})
      : _preferences = preferences ?? Preferences();

  Future<ChatMediaUpload> upload({
    required File file,
    required String type,
  }) async {
    final appUrl = await _preferences.getAppUrl();
    final uri = Uri.parse('$appUrl${Constant.CHAT_MEDIA_UPLOAD}');
    final token = await _preferences.getToken();
    final extension = _extensionFromPath(file.path);
    final uploadType = _uploadTypeFor(type);
    final mimeType = mimeTypeForPath(file.path, mediaType: type);

    debugPrint('[CHAT_UPLOAD] selected file path=${file.path}');
    debugPrint('[CHAT_UPLOAD] extension=$extension');
    debugPrint('[CHAT_UPLOAD] requested type=$type');
    debugPrint('[CHAT_UPLOAD] upload type=$uploadType');
    debugPrint('[CHAT_UPLOAD] mime type=$mimeType');
    debugPrint('[CHAT_UPLOAD] endpoint=$uri');

    final response = await _sendUploadRequest(
      uri: uri,
      token: token,
      file: file,
      type: uploadType,
      mimeType: mimeType,
    );
    var responseData = _decodeBody(response.body);

    if ((response.statusCode == 422 || response.statusCode == 400) &&
        uploadType == 'document' &&
        _isInvalidTypeError(responseData)) {
      debugPrint('[CHAT_UPLOAD] retrying document upload as file');
      final retryResponse = await _sendUploadRequest(
        uri: uri,
        token: token,
        file: file,
        type: 'file',
        mimeType: mimeType,
      );
      responseData = _decodeBody(retryResponse.body);
      if (retryResponse.statusCode != 200 && retryResponse.statusCode != 201) {
        throw ChatMediaUploadException(_backendMessage(responseData));
      }
      return _validatedUpload(responseData, appUrl: appUrl);
    }

    if ((response.statusCode == 422 || response.statusCode == 400) &&
        uploadType == 'audio' &&
        _isInvalidTypeError(responseData)) {
      debugPrint('[CHAT_UPLOAD] retrying audio upload as voice');
      final retryResponse = await _sendUploadRequest(
        uri: uri,
        token: token,
        file: file,
        type: 'voice',
        mimeType: mimeType,
      );
      responseData = _decodeBody(retryResponse.body);
      if (retryResponse.statusCode != 200 && retryResponse.statusCode != 201) {
        throw ChatMediaUploadException(_backendMessage(responseData));
      }
      return _validatedUpload(responseData, appUrl: appUrl);
    }

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw ChatMediaUploadException(_backendMessage(responseData));
    }

    return _validatedUpload(responseData, appUrl: appUrl);
  }

  Future<http.Response> _sendUploadRequest({
    required Uri uri,
    required String token,
    required File file,
    required String type,
    required String mimeType,
  }) async {
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll({
        'Accept': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      })
      ..fields['type'] = type
      ..files.add(await http.MultipartFile.fromPath(
        'file',
        file.path,
        contentType: MediaType.parse(mimeType),
      ));

    final streamedResponse =
        await request.send().timeout(const Duration(seconds: 45));
    final response = await http.Response.fromStream(streamedResponse);

    debugPrint('[CHAT_UPLOAD] response status=${response.statusCode}');
    debugPrint('[CHAT_UPLOAD] response body=${response.body}');
    return response;
  }

  ChatMediaUpload _validatedUpload(
    Map<String, dynamic> responseData, {
    required String appUrl,
  }) {
    final upload = _normalizeUploadUrl(
      ChatMediaUpload.fromJson(responseData),
      appUrl: appUrl,
    );
    if (upload.url.trim().isEmpty) {
      if (upload.path.trim().isNotEmpty) {
        return ChatMediaUpload(
          url: _absoluteUrl(
            upload.path,
            appUrl: appUrl,
            preferStoragePath: true,
          ),
          type: upload.type,
          path: upload.path,
          width: upload.width,
          height: upload.height,
        );
      }
      throw const ChatMediaUploadException(
        'Media upload did not return a file URL',
      );
    }

    return upload;
  }

  ChatMediaUpload _normalizeUploadUrl(
    ChatMediaUpload upload, {
    required String appUrl,
  }) {
    var resolvedUrl = _absoluteUrl(upload.url, appUrl: appUrl);
    final resolvedPath = _absoluteUrl(
      upload.path,
      appUrl: appUrl,
      preferStoragePath: true,
    );

    if (_looksLikeAppShellUrl(resolvedUrl) && resolvedPath.trim().isNotEmpty) {
      resolvedUrl = resolvedPath;
    }

    return ChatMediaUpload(
      url: resolvedUrl,
      type: upload.type,
      path: upload.path,
      width: upload.width,
      height: upload.height,
    );
  }

  String _absoluteUrl(
    String value, {
    required String appUrl,
    bool preferStoragePath = false,
  }) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
      return trimmed;
    }

    final base = Uri.tryParse(appUrl);
    if (base == null) {
      return trimmed;
    }

    final normalized = preferStoragePath
        ? _normalizeStoragePath(trimmed)
        : trimmed;
    return base.resolve(normalized).toString();
  }

  String _normalizeStoragePath(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    if (trimmed.startsWith('/storage/')) {
      return trimmed;
    }
    if (trimmed.startsWith('storage/')) {
      return '/$trimmed';
    }
    if (trimmed.startsWith('/')) {
      return trimmed;
    }
    return '/storage/$trimmed';
  }

  bool _looksLikeAppShellUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return false;
    }

    final path = uri.path.trim().toLowerCase();
    return path.isEmpty || path == '/' || path.endsWith('.html');
  }

  static String _uploadTypeFor(String type) {
    final normalized = type.trim().toLowerCase();
    if (normalized == 'voice') {
      return 'audio';
    }
    if (normalized == 'file') {
      return 'document';
    }
    return normalized;
  }

  static String mimeTypeForPath(String path, {String mediaType = ''}) {
    final extension = _extensionFromPath(path).toLowerCase();

    const mimeByExtension = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'heic': 'image/heic',
      'mp4': 'audio/mp4',
      'm4a': 'audio/mp4',
      'mp3': 'audio/mpeg',
      'wav': 'audio/wav',
      'aac': 'audio/aac',
      'webm': 'audio/webm',
      'ogg': 'audio/ogg',
    };

    return mimeByExtension[extension] ??
        (mediaType == 'voice' ? 'audio/mp4' : 'application/octet-stream');
  }

  static String _extensionFromPath(String path) {
    final fileName = path.split(Platform.pathSeparator).last;
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == fileName.length - 1) {
      return '';
    }
    return fileName.substring(dotIndex + 1);
  }

  static Map<String, dynamic> _decodeBody(String body) {
    if (body.trim().isEmpty) {
      return {};
    }

    try {
      final decoded = json.decode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return {'message': decoded.toString()};
    } catch (_) {
      return {'message': body};
    }
  }

  static String _backendMessage(Map<String, dynamic> responseData) {
    final message = responseData['message'];
    if (message != null && message.toString().trim().isNotEmpty) {
      return message.toString();
    }

    final errors = responseData['errors'];
    if (errors != null && errors.toString().trim().isNotEmpty) {
      return errors.toString();
    }

    return 'Media upload failed';
  }

  static bool _isInvalidTypeError(Map<String, dynamic> responseData) {
    final message = _backendMessage(responseData).toLowerCase();
    return message.contains('selected type is invalid') ||
        message.contains('type') && message.contains('invalid');
  }
}
