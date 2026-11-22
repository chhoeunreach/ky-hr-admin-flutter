import 'dart:convert';

import 'package:cnattendance/core/ky_security/ky_http.dart';
import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/model/remote_theme_mode.dart';
import 'package:cnattendance/utils/constant.dart';

class ThemeModesApi {
  ThemeModesApi({Preferences? preferences})
      : _preferences = preferences ?? Preferences();

  final Preferences _preferences;

  Future<List<RemoteThemeMode>> fetch() async {
    final base = await _preferences.getAppUrl();
    final token = await _preferences.getToken();
    final uri = Uri.parse('$base${Constant.API_URL}/theme-modes');
    final response = await KyHttp.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Unable to load theme modes (status ${response.statusCode}).');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final data = decoded is Map ? decoded['data'] : null;
    if (data is! List) {
      throw const FormatException('Invalid theme modes response format.');
    }

    return data
        .whereType<Map>()
        .map((item) => RemoteThemeMode.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }
}
