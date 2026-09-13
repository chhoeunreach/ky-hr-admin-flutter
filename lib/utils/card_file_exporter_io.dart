import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

Future<void> exportPngFile({
  required Uint8List bytes,
  required String fileName,
  required String text,
  required Rect sharePositionOrigin,
}) {
  return Share.shareXFiles(
    [
      XFile.fromData(
        bytes,
        name: fileName,
        mimeType: 'image/png',
      ),
    ],
    text: text,
    sharePositionOrigin: sharePositionOrigin,
  );
}
