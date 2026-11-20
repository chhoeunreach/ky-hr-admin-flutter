import 'dart:convert';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/model/banner_slideshow_config.dart';
import 'package:cnattendance/model/home_banner_config.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:cnattendance/core/ky_security/ky_http.dart';

class MobileQuoteItem {
  final String id;
  final String text;
  final String? author;
  final String? translation;
  final QuoteStyle? style;

  const MobileQuoteItem({
    required this.id,
    required this.text,
    this.author,
    this.translation,
    this.style,
  });

  factory MobileQuoteItem.fromJson(Map<String, dynamic> json) {
    return MobileQuoteItem(
      id: json['id']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      author: json['author']?.toString(),
      translation: json['translation']?.toString(),
      style: json['style'] is Map
          ? QuoteStyle.fromJson(Map<String, dynamic>.from(json['style'] as Map))
          : null,
    );
  }
}

class MobileQuoteApi {
  MobileQuoteApi({Preferences? preferences})
      : _preferences = preferences ?? Preferences();

  final Preferences _preferences;

  Future<MobileQuotePlayback> fetchActive() async {
    final base = await _preferences.getAppUrl();
    final token = await _preferences.getToken();
    final uri = Uri.parse('${base}${Constant.API_URL}/quotes');
    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final response = await KyHttp.get(uri, headers: headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to fetch quotes: ${response.statusCode}');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final data = decoded is Map ? decoded['data'] : null;
    if (data is! Map)
      throw const FormatException('Invalid mobile quotes response');
    return MobileQuotePlayback.fromJson(Map<String, dynamic>.from(data));
  }
}

class MobileQuotePlayback {
  const MobileQuotePlayback({
    this.quotes = const [],
    this.settings = const BannerSlideshowConfig(autoplay: false),
  });

  final List<MobileQuoteItem> quotes;
  final BannerSlideshowConfig settings;

  factory MobileQuotePlayback.fromJson(Map<String, dynamic> json) {
    final list = json['quotes'];
    if (list is! List)
      throw const FormatException('Invalid mobile quotes response');
    final settings = json['playback'];
    return MobileQuotePlayback(
      quotes: list
          .whereType<Map>()
          .map((item) =>
              MobileQuoteItem.fromJson(Map<String, dynamic>.from(item)))
          .where((quote) => quote.text.isNotEmpty)
          .toList(),
      settings: settings is Map
          ? BannerSlideshowConfig.fromJson({
              ...Map<String, dynamic>.from(settings),
              'autoplay': settings['autoplay'] == true,
            })
          : const BannerSlideshowConfig(autoplay: false),
    );
  }
}
