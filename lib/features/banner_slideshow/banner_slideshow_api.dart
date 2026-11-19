import 'dart:convert';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/model/banner_slideshow_config.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:http/http.dart' as http;

class BannerSlideshowApi {
  BannerSlideshowApi({Preferences? preferences})
      : _preferences = preferences ?? Preferences();

  final Preferences _preferences;

  Future<BannerSlideshowConfig> fetch() async {
    final body = await _request('GET');
    return _parseConfig(body);
  }

  Future<BannerSlideshowConfig> save(BannerSlideshowConfig config) async {
    return _parseConfig(await _request('PUT', payload: config.toJson()));
  }

  Future<BannerSlideshowConfig> reset() async {
    return _parseConfig(await _request('POST', path: 'reset'));
  }

  BannerSlideshowConfig _parseConfig(Map<String, dynamic> body) {
    final data = body['data'];
    if (data is! Map) throw const FormatException('Invalid banner response.');
    return BannerSlideshowConfig.fromJson(Map<String, dynamic>.from(data));
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
      'GET' => await http.get(uri, headers: headers),
      'PUT' => await http.put(uri, headers: headers, body: jsonEncode(payload)),
      'POST' => await http.post(uri, headers: headers),
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
