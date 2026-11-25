import 'dart:convert';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/model/app_appearance_config.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:cnattendance/core/ky_security/ky_http.dart';

class AppAppearanceApi {
  AppAppearanceApi({Preferences? preferences})
      : _preferences = preferences ?? Preferences();

  final Preferences _preferences;

  Future<AppAppearanceConfig> fetch() async {
    final base = await _preferences.getAppUrl();
    final token = await _preferences.getToken();
    final uri = Uri.parse('${base}${Constant.API_URL}/app-appearance');
    final response = await KyHttp.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 8));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Unable to load app appearance.');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final data = decoded is Map ? decoded['data'] : null;
    if (data is! Map) throw const FormatException('Invalid appearance response.');
    final map = Map<String, dynamic>.from(data);
    final rawUrl = map['background_url']?.toString().trim();
    if (rawUrl != null &&
        rawUrl.isNotEmpty &&
        !rawUrl.startsWith('http://') &&
        !rawUrl.startsWith('https://') &&
        !rawUrl.startsWith('assets/')) {
      final cleanBase =
          base.endsWith('/') ? base.substring(0, base.length - 1) : base;
      final cleanPath = rawUrl.startsWith('/') ? rawUrl : '/$rawUrl';
      map['background_url'] = '$cleanBase$cleanPath';
    }
    return AppAppearanceConfig.fromJson(map);
  }
}
