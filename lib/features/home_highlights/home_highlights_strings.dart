import 'package:flutter_translate/flutter_translate.dart';

String homeHighlightsText(String fallback) {
  final key =
      'home_highlights.${fallback.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_|_$'), '')}';
  final value = translate(key);
  return value == key ? fallback : value;
}
