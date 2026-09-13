import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

Future<void> exportPngFile({
  required Uint8List bytes,
  required String fileName,
  required String text,
  required Rect sharePositionOrigin,
}) async {
  final anchor = web.HTMLAnchorElement()
    ..href = 'data:image/png;base64,${base64Encode(bytes)}'
    ..download = fileName
    ..style.display = 'none';

  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
}
