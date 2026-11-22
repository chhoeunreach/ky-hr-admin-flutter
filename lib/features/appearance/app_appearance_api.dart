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
    return AppAppearanceConfig.fromJson(Map<String, dynamic>.from(data));
  }
}
