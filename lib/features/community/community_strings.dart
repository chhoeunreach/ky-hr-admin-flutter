import 'package:flutter_translate/flutter_translate.dart';

String communityText(String fallback) {
  final key =
      'community.${fallback.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_|_$'), '')}';
  final value = translate(key);
  return value == key ? fallback : value;
}
