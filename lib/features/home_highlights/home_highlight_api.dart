import '../community/community_media_urls.dart';
import 'dart:convert';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/models/home_highlight.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:http/http.dart' as http;
import 'package:cnattendance/core/ky_security/ky_http.dart';

class HomeHighlightException implements Exception {
  const HomeHighlightException(this.message);

  final String message;

  @override
  String toString() => message;
}

class HomeHighlightApi {
  HomeHighlightApi({Preferences? preferences, http.Client? client})
      : _preferences = preferences ?? Preferences(),
        _client = client ?? http.Client();

  final Preferences _preferences;
  final http.Client _client;

  void dispose() => _client.close();

  Future<List<HomeHighlight>> index() async => (await feed()).items;

  Future<HomeHighlightFeed> feed() async {
    final body = await _get('home-highlights');
    return HomeHighlightFeed(
        items: _items(body['data']),
        settings:
            HomeHighlightDisplaySettings.fromJson(body['display_settings']));
  }

  Future<HomeHighlightPage> history({int page = 1, int perPage = 20}) async {
    final body = await _get('home-highlights/history',
        query: {'page': '$page', 'per_page': '$perPage'});
    final items = _items(body['data']);
    final meta = body['meta'] is Map
        ? Map<String, dynamic>.from(body['meta'] as Map)
        : const <String, dynamic>{};
    final current = int.tryParse('${meta['current_page'] ?? page}') ?? page;
    final last = int.tryParse('${meta['last_page'] ?? page}') ?? page;
    final total =
        int.tryParse('${meta['total'] ?? items.length}') ?? items.length;
    return HomeHighlightPage(
      items: items,
      currentPage: current,
      lastPage: last,
      total: total,
    );
  }

  Future<HomeHighlight> show(int id) async {
    final body = await _get('home-highlights/$id');
    final data = body['data'];
    if (data is! Map || int.tryParse('${data['id']}') != id) {
      throw const HomeHighlightException('This highlight is unavailable.');
    }
    return HomeHighlight.fromJson(Map<String, dynamic>.from(data));
  }

  List<HomeHighlight> _items(dynamic data) {
    if (data is! List)
      throw const HomeHighlightException(
          'The server returned an invalid highlights response.');
    return data
        .whereType<Map>()
        .map((item) => HomeHighlight.fromJson(Map<String, dynamic>.from(item)))
        .where((item) => item.id > 0)
        .toList();
  }

  Future<Map<String, dynamic>> _get(String path,
      {Map<String, String>? query}) async {
    final base = await _preferences.getAppUrl();
    final token = await _preferences.getToken();
    final uri = Uri.parse('$base${Constant.API_URL}/$path')
        .replace(queryParameters: query);
    final response = await KyHttp.getWithClient(_client, uri, headers: {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    }).timeout(const Duration(seconds: 30));

    final raw = response.body.trim();
    dynamic decoded;
    if (raw.isNotEmpty) {
      try {
        decoded = jsonDecode(raw);
      } catch (_) {
        decoded = null;
      }
    }
    final body = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HomeHighlightException((response.statusCode == 404
              ? 'This highlight is unavailable.'
              : body['message']?.toString()) ??
          'Unable to load highlights.');
    }
    if (decoded is! Map || !body.containsKey('data')) {
      throw const HomeHighlightException(
          'The server returned an invalid highlights response.');
    }
    dynamic normalize(dynamic value) {
      if (value is List) return value.map(normalize).toList();
      if (value is Map)
        return value.map<String, dynamic>((key, item) => MapEntry(
            key.toString(),
            key == 'image_url' && item is String
                ? communityUploadUrl(item, Uri.parse(base))
                : normalize(item)));
      return value;
    }

    return normalize(body) as Map<String, dynamic>;
  }
}
