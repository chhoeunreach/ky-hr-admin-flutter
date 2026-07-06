import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  final TextRecognizer _recognizer = TextRecognizer();

  Future<String> extractTextFromImage(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText =
          await _recognizer.processImage(inputImage);
      return recognizedText.text;
    } catch (e) {
      return 'OCR failed for $imagePath: $e';
    }
  }

  Future<String> extractTextFromMultipleImages(List<String> imagePaths) async {
    StringBuffer combined = StringBuffer();
    for (int i = 0; i < imagePaths.length; i++) {
      final text = await extractTextFromImage(imagePaths[i]);
      if (text.isNotEmpty && !text.startsWith('OCR failed')) {
        combined.writeln('--- Photo ${i + 1} ---');
        combined.writeln(text);
        combined.writeln();
      }
    }
    return combined.toString().trim();
  }

  String formatProductOcrText(String extractedText) {
    final text = extractedText.trim();
    if (text.isEmpty) return '';

    final fields = autoDetectFields(text);
    final rows = <String>[];

    void addRow(String label, String value) {
      final cleanedValue = value.trim();
      if (cleanedValue.isEmpty) return;
      rows.add('$label: $cleanedValue');
    }

    addRow('Model Name', fields['product_name'] ?? '');
    addRow(
      'Serial Number',
      fields['serial_number']!.isNotEmpty
          ? fields['serial_number']!
          : _extractDisplaySerialNumber(text),
    );
    addRow('IMEI', fields['imei'] ?? '');
    addRow('IMEI2', fields['imei2'] ?? '');
    addRow('Color', fields['color'] ?? '');
    addRow('Storage', fields['storage'] ?? '');
    addRow('Price', fields['price'] ?? '');

    return rows.join('\n');
  }

  String _extractDisplaySerialNumber(String text) {
    final match = RegExp(r'\b(\d{6,10})\b').firstMatch(text);
    return match?.group(1) ?? '';
  }

  Map<String, String> autoDetectFields(String extractedText) {
    final text = extractedText.trim();
    final fields = <String, String>{
      'invoice_no': '',
      'seller_name': '',
      'customer_name': '',
      'branch_name': '',
      'phone_number': '',
      'product_name': '',
      'model_number': '',
      'imei': '',
      'imei2': '',
      'serial_number': '',
      'color': '',
      'storage': '',
      'price': '',
    };

    final lines = text.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Model Name: "Model Name iPhone 13 Pro Max"
      if (fields['product_name']!.isEmpty) {
        final modelNameMatch = RegExp(
          r'Model\s*Name\s*(.+)',
          caseSensitive: false,
        ).firstMatch(trimmed);
        if (modelNameMatch != null) {
          fields['product_name'] = modelNameMatch.group(1)!.trim();
        } else if (_isProductName(trimmed)) {
          fields['product_name'] = trimmed;
        }
      }

      // IMEI: handle spaced digits like "354667 221 484221"
      if (fields['imei']!.isEmpty || fields['imei2']!.isEmpty) {
        final stripped = trimmed.replaceAll(RegExp(r'\s+'), '');
        final imeiMatch = RegExp(r'\b(\d{15})\b').firstMatch(stripped);
        if (imeiMatch != null) {
          final imei = imeiMatch.group(1)!;
          if (fields['imei']!.isEmpty) {
            fields['imei'] = imei;
          } else if (fields['imei2']!.isEmpty && imei != fields['imei']) {
            fields['imei2'] = imei;
          }
        }
      }

      // Serial Number: handle various serial labels
      // Labeled matches always run (for length-heuristic redirect);
      // fallback only runs if serial_number is still empty.
      String? serial;
      bool isLabeledMatch = false;

      // Apple: "Serial Number N7FXFTH5CX", "(S) Serial No. H39VT6FQJJ", "Serial # ABC123"
      final appleSerial = RegExp(
        r'(?:\(S\)\s*)?Serial\s*(?:No\.?|Number|#)\s*:?\s*([A-Z0-9]{6,16})(?![A-Z0-9])',
        caseSensitive: false,
      ).firstMatch(trimmed);
      if (appleSerial != null) {
        serial = appleSerial.group(1);
        isLabeledMatch = true;
      }

      // Samsung/OPPO: "S/N : R5GL14G69KE"
      if (serial == null) {
        final snSlash = RegExp(
          r'S\s*/\s*N\s*:?\s*([A-Z0-9]{6,16})(?![A-Z0-9])',
          caseSensitive: false,
        ).firstMatch(trimmed);
        if (snSlash != null) {
          serial = snSlash.group(1);
          isLabeledMatch = true;
        }
      }

      // Standalone "SN:" or "SN :" prefix (without slash)
      if (serial == null) {
        final snPrefix = RegExp(
          r'\bSN\s*:?\s*([A-Z0-9]{6,16})(?![A-Z0-9])',
          caseSensitive: false,
        ).firstMatch(trimmed);
        if (snPrefix != null) {
          serial = snPrefix.group(1);
          isLabeledMatch = true;
        }
      }

      // Labeled serial match: always fill serial_number
      if (serial != null && isLabeledMatch && fields['serial_number']!.isEmpty) {
        fields['serial_number'] = serial;
      }

      // Fallback: standalone alphanumeric 6-16 chars that isn't an IMEI
      // Only run if serial_number is still empty.
      if (fields['serial_number']!.isEmpty) {
        // First try on lines that have any serial-like keyword (broader match)
        if (RegExp(r'\bSN\b|serial|S/N', caseSensitive: false).hasMatch(trimmed)) {
          final loose = RegExp(
            r'(?<![A-Z0-9])([A-Z0-9]{6,16})(?![A-Z0-9])',
          ).firstMatch(trimmed);
          if (loose != null && !RegExp(r'^\d{15}$').hasMatch(loose.group(1)!)) {
            fields['serial_number'] = loose.group(1)!;
          }
        } else {
          // Generic fallback: standalone uppercase alphanumeric >= 10 chars
          final fallback = RegExp(
            r'(?<![A-Z0-9/])([A-Z0-9]{10,16})(?![A-Z0-9/])',
          ).firstMatch(trimmed);
          if (fallback != null) {
            final candidate = fallback.group(1)!;
            if (!RegExp(r'^\d{15}$').hasMatch(candidate)) {
              fields['serial_number'] = candidate;
            }
          }
        }
      }

      // "Model Number" label: value >= 10 chars is likely a serial
      // (boxes often print "Model Number" next to the actual serial)
      if (fields['serial_number']!.isEmpty) {
        final labeledModel = RegExp(
          r'Model\s+(?:Number|No\.?)\s*:?\s*([A-Za-z0-9][A-Za-z0-9\/\-]{2,20})|Model\s*:\s*([A-Za-z0-9][A-Za-z0-9\/\-]{2,20})',
          caseSensitive: false,
        ).firstMatch(trimmed);
        if (labeledModel != null) {
          final captured = (labeledModel.group(1) ?? labeledModel.group(2))!;
          if (!captured.contains(RegExp(r'[/\-]')) &&
              captured.length >= 10 &&
              captured.length <= 16) {
            fields['serial_number'] = captured;
          }
        }
      }

      // Storage/Capacity: 256GB, 128 GB, Capacity128 GB, 1TB
      if (fields['storage']!.isEmpty) {
        // Labeled: "Capacity128 GB", "Capacity: 128 GB", "Storage: 256GB"
        final labeledCap = RegExp(
          r'(?:Capacity|Storage)\s*:?\s*(\d+)\s*(GB|TB)',
          caseSensitive: false,
        ).firstMatch(trimmed);
        if (labeledCap != null) {
          fields['storage'] = '${labeledCap.group(1)}${labeledCap.group(2)!.toUpperCase()}';
        } else {
          // Standalone: "128GB", "128 GB"
          final storageMatch = RegExp(
            r'\b(\d+)\s*(GB|TB)\b',
            caseSensitive: false,
          ).firstMatch(trimmed);
          if (storageMatch != null) {
            fields['storage'] = '${storageMatch.group(1)}${storageMatch.group(2)!.toUpperCase()}';
          }
        }
      }

      // Color: extract from product lines like "Galaxy S24 Ultra Titanium Gray 512GB"
      if (fields['color']!.isEmpty) {
        final colorWords = _colorPattern.allMatches(trimmed).map((m) => m.group(0)!.trim()).toList();
        if (colorWords.isNotEmpty) {
          fields['color'] = colorWords.join(' ');
        }
      }

      // Trim product_name when color and storage were extracted from it
      if (fields['product_name']!.isNotEmpty &&
          fields['storage']!.isNotEmpty &&
          fields['product_name']!.contains(fields['storage']!)) {
        final name = fields['product_name']!;
        int trimIdx = name.indexOf(fields['storage']!);
        if (trimIdx > 0) {
          fields['product_name'] = name.substring(0, trimIdx).trim();
        }
      }
      if (fields['product_name']!.isNotEmpty &&
          fields['color']!.isNotEmpty &&
          fields['product_name']!.contains(fields['color']!)) {
        final name = fields['product_name']!;
        final colorIdx = name.indexOf(fields['color']!);
        if (colorIdx > 0) {
          fields['product_name'] = name.substring(0, colorIdx).trim();
        }
      }

      // Price
      if (trimmed.contains(RegExp(r'\d+\.\d{2}')) && fields['price']!.isEmpty) {
        final priceMatch = RegExp(r'(\d+\.\d{2})').firstMatch(trimmed);
        if (priceMatch != null) {
          fields['price'] = priceMatch.group(1)!;
        }
      }
    }

    // Post-processing: if serial_number is still empty, double-check
    // the entire text for any serial-like pattern that was missed.
    if (fields['serial_number']!.isEmpty) {
      final globalSerial = RegExp(
        r'(?:Serial\s*(?:No\.?|Number|#|:)\s*|S\s*/\s*N\s*:?\s*|SN\s*:?\s*)([A-Z0-9]{6,16})(?![A-Z0-9])',
        caseSensitive: false,
      ).firstMatch(text);
      if (globalSerial != null) {
        fields['serial_number'] = globalSerial.group(1)!;
      }
    }

    // Cleanup: strip identified field values from product_name
    if (fields['product_name']!.isNotEmpty) {
      for (final value in [
        fields['serial_number'],
        fields['imei'],
        fields['imei2'],
      ]) {
        if (value!.isNotEmpty && fields['product_name']!.contains(value)) {
          fields['product_name'] =
              fields['product_name']!.replaceAll(value, '').trim();
        }
      }
    }

    return fields;
  }

  static const _colorWords = [
    'Titanium', 'Gray', 'Black', 'White', 'Silver', 'Gold',
    'Purple', 'Blue', 'Green', 'Red', 'Pink', 'Natural',
    'Space', 'Deep', 'Midnight', 'Starlight', 'Graphite',
    'Rose', 'Alpine', 'Arctic', 'Cream', 'Violet', 'Navy',
    'Mint', 'Coral', 'Yellow', 'Orange', 'Sierra',
  ];

  static final _colorPattern = RegExp(
    '(${_colorWords.join('|')})\\s*(${_colorWords.join('|')})?',
    caseSensitive: false,
  );

  bool _isProductName(String text) {
    if (text.length < 4) return false;
    if (RegExp(r'^\d+$').hasMatch(text)) return false;
    if (text.contains(RegExp(r'price|\$|imei|serial|model|color|storage|S\s*/\s*N|\bSN\b',
        caseSensitive: false))) return false;
    if (text.startsWith('---')) return false;
    if (RegExp(r'Photo\s+\d', caseSensitive: false).hasMatch(text)) return false;
    if (text.length > 50) return false;
    final hasBrand = RegExp(
      r'iPhone|iPad|Galaxy|OPPO|Realme|Xiaomi|Redmi|Huawei|Nokia|Google|Pixel',
      caseSensitive: false,
    ).hasMatch(text);
    final hasNumber = RegExp(r'\d').hasMatch(text);
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(text);
    return hasBrand || (hasNumber && hasLetter);
  }

  String formatICloudOcrText(String extractedText) {
    final text = extractedText.trim();
    if (text.isEmpty) return '';

    final fields = autoDetectICloudFields(text);
    final rows = <String>[];

    void addRow(String label, String value) {
      final cleanedValue = value.trim();
      if (cleanedValue.isEmpty) return;
      rows.add('$label: $cleanedValue');
    }

    addRow('Account Name', fields['account_name'] ?? '');
    addRow('Apple ID', fields['apple_id'] ?? '');
    addRow('iCloud Storage', fields['icloud_storage'] ?? '');
    addRow('Trusted Phone', fields['trusted_phone'] ?? '');
    addRow('Devices', fields['devices'] ?? '');

    return rows.join('\n');
  }

  Map<String, String> autoDetectICloudFields(String extractedText) {
    final text = extractedText.trim();
    final fields = <String, String>{
      'account_name': '',
      'apple_id': '',
      'icloud_storage': '',
      'trusted_phone': '',
      'devices': '',
    };

    final lines = text.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.contains('@') && fields['apple_id']!.isEmpty) {
        final emailMatch = RegExp(r'[\w.+-]+@[\w-]+\.[\w.-]+').firstMatch(trimmed);
        if (emailMatch != null) {
          fields['apple_id'] = emailMatch.group(0)!;
        }
      }

      if (RegExp(r'\b\d{10}\b').hasMatch(trimmed) &&
          fields['trusted_phone']!.isEmpty) {
        fields['trusted_phone'] = trimmed;
      }

      if (trimmed.contains(RegExp(r'\d+\s*GB|\d+\s*TB', caseSensitive: false)) &&
          fields['icloud_storage']!.isEmpty) {
        fields['icloud_storage'] = trimmed;
      }
    }

    return fields;
  }

  void dispose() {
    _recognizer.close();
  }
}
