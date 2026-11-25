import 'dart:convert';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/model/banner_slideshow_config.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:cnattendance/core/ky_security/ky_http.dart';

class BannerSlideshowApi {
  BannerSlideshowApi({Preferences? preferences})
      : _preferences = preferences ?? Preferences();

  final Preferences _preferences;

  Future<BannerSlideshowConfig> fetch() async {
    final base = await _preferences.getAppUrl();
    final body = await _request('GET');
    return _parseConfig(body, baseUrl: base);
  }

  Future<BannerSlideshowConfig> save(BannerSlideshowConfig config) async {
    final base = await _preferences.getAppUrl();
    return _parseConfig(await _request('PUT', payload: config.toJson()),
        baseUrl: base);
  }

  Future<BannerSlideshowConfig> reset() async {
    final base = await _preferences.getAppUrl();
    return _parseConfig(await _request('POST', path: 'reset'), baseUrl: base);
  }

  BannerSlideshowConfig _parseConfig(Map<String, dynamic> body,
      {String? baseUrl}) {
    final data = body['data'];
    if (data is! Map) throw const FormatException('Invalid banner response.');
    final map = Map<String, dynamic>.from(data);
    if (baseUrl != null && baseUrl.isNotEmpty) {
      final rawSlides = map['slides'];
      if (rawSlides is List) {
        final normalizedSlides = <Map<String, dynamic>>[];
        for (final item in rawSlides) {
          if (item is Map) {
            final slideMap = Map<String, dynamic>.from(item);
            final img = slideMap['imageUrl']?.toString().trim();
            if (img != null &&
                img.isNotEmpty &&
                !img.startsWith('http://') &&
                !img.startsWith('https://') &&
                !img.startsWith('assets/')) {
              final cleanBase = baseUrl.endsWith('/')
                  ? baseUrl.substring(0, baseUrl.length - 1)
                  : baseUrl;
              final cleanPath = img.startsWith('/') ? img : '/$img';
              slideMap['imageUrl'] = '$cleanBase$cleanPath';
            }
            normalizedSlides.add(slideMap);
          }
        }
        map['slides'] = normalizedSlides;
      }
    }
    return BannerSlideshowConfig.fromJson(map);
  }

  Future<Map<String, dynamic>> _request(String method,
      {String path = '', Map<String, dynamic>? payload}) async {
    final base = await _preferences.getAppUrl();
    final token = await _preferences.getToken();
    final uri = Uri.parse('${base}${Constant.API_URL}/banner-slideshow/$path');
    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final response = switch (method) {
      'GET' => await KyHttp.get(uri, headers: headers),
      'PUT' => await KyHttp.put(uri, headers: headers, body: jsonEncode(payload)),
      'POST' => await KyHttp.post(uri, headers: headers),
      _ => throw ArgumentError.value(method, 'method'),
    };
    dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      decoded = null;
    }
    final body = decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        body == null) {
      throw Exception(
          body?['message']?.toString() ?? 'Unable to update banner.');
    }
    return body;
  }
}
