import 'dart:convert';

import 'package:cnattendance/data/source/network/model/login/Loginresponse.dart';
import 'package:http/http.dart' as http;

Future<void> main() async {
  const baseUrl = 'https://hr.kneayerng.com';
  const username = 'KY0549';
  const password = 'KY0549';

  final uri = Uri.parse('$baseUrl/api/login');

  final body = <String, String>{
    'username': username,
    'password': password,
    'fcm_token': 'test-token-1234567890123456',
    'device_type': 'android',
    'uuid': 'test-uuid',
    'device_name': 'MacBook',
    'device_model': 'Pixel 8',
    'os_version': 'Android 14',
    'app_name': 'Digital HR',
    'app_version': '1.0.0',
    'app_build': '1',
    'latitude': '11.5564',
    'longitude': '104.9282',
  };

  print('=> POST $uri');
  print('=> body keys: ${body.keys.toList()}');

  try {
    final response = await http
        .post(
          uri,
          headers: {'Accept': 'application/json; charset=UTF-8', 'Content-Type': 'application/x-www-form-urlencoded'},
          body: body,
        )
        .timeout(const Duration(seconds: 30));

    print('\n=> HTTP ${response.statusCode}');
    print('=> Raw body:\n${response.body}');

    try {
      final json = jsonDecode(response.body);
      final parsed = Loginresponse.fromJson(json);
      print('\n=> PARSED OK: status=${parsed.status} message=${parsed.message}');
      if (json['data'] != null) {
        print(json['data']);
      }
    } catch (e) {
      print('\n=> PARSE ERROR: $e');
    }
  } catch (e) {
    print('\n=> NETWORK ERROR: $e');
  }
}