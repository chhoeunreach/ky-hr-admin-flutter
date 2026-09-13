import 'dart:convert';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/models/id_card_profile.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:http/http.dart' as http;

class IdCardApiService {
  final Preferences _preferences = Preferences();

  Future<IdCardProfile> fetchMyCard() async {
    final token = await _preferences.getToken();
    final baseUrl = await _preferences.getAppUrl();

    final response = await http.get(
      Uri.parse('$baseUrl${Constant.HR_KY_ADMIN_D_CARD_ME_URL}'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final decoded = json.decode(response.body);
    if (response.statusCode == 200 && decoded is Map) {
      final data = decoded['data'] ?? decoded;
      if (data is Map) {
        final cardJson = Map<String, dynamic>.from(data);
        _normalizeImageUrls(cardJson, baseUrl);
        return IdCardProfile.fromJson(cardJson);
      }
    }

    final message = decoded is Map ? decoded['message'] : null;
    throw Exception(message?.toString() ?? 'Unable to load card');
  }

  void _normalizeImageUrls(Map<String, dynamic> json, String baseUrl) {
    const keys = [
      'photo_url',
      'profile_photo_url',
      'branch_logo_url',
      'branchLogoUrl',
      'branch_logo',
      'logo_url',
      'company_logo_url',
      'company_logo',
    ];

    for (final key in keys) {
      json[key] = _absoluteUrl(json[key], baseUrl);
    }

    final branch = json['branch'];
    if (branch is Map) {
      final branchJson = Map<String, dynamic>.from(branch);
      branchJson['logo_url'] = _absoluteUrl(branchJson['logo_url'], baseUrl);
      branchJson['logo'] = _absoluteUrl(branchJson['logo'], baseUrl);
      json['branch'] = branchJson;
    }
  }

  String _absoluteUrl(dynamic value, String baseUrl) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.startsWith(RegExp(r'https?://'))) {
      return text;
    }

    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final normalizedPath = text.startsWith('/') ? text : '/$text';
    return '$normalizedBase$normalizedPath';
  }
}
