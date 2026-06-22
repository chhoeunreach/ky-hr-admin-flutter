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
    addRow('Model Number', fields['model_number'] ?? '');
    addRow(
      'Serial Number',
      fields['serial_number']!.isNotEmpty
          ? fields['serial_number']!
          : _extractDisplaySerialNumber(text),
    );
    addRow('Coverage', _extractDisplayLabeledValue(text, 'coverage'));
    if (_containsLabel(text, 'parts & service history')) {
      rows.add('Parts & Service History');
    }
    addRow('Songs', _extractDisplayLabeledValue(text, 'songs'));
    addRow('Videos', _extractDisplayLabeledValue(text, 'videos'));
    addRow('Photos', _extractDisplayLabeledValue(text, 'photos'));
    addRow('Applications', _extractDisplayLabeledValue(text, 'applications'));
    addRow('Capacity', fields['storage'] ?? '');
    addRow('Available', _extractDisplayLabeledValue(text, 'available'));
    addRow('IMEI', fields['imei'] ?? '');
    addRow('IMEI2', fields['imei2'] ?? '');

    if (rows.isEmpty) {
      return text
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .join('\n');
    }

    return rows.toSet().join('\n');
  }

  Map<String, String> autoDetectICloudFields(String extractedText) {
    final text = extractedText.trim();
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final fields = <String, String>{
      'account_name': '',
      'apple_id': '',
      'icloud_storage': '',
      'trusted_phone': '',
      'devices': '',
    };

    fields['apple_id'] = _extractEmail(text);
    fields['trusted_phone'] = _extractPhoneNumber(text);
    fields['icloud_storage'] = _extractICloudStorage(lines);
    fields['account_name'] = _extractAppleAccountName(lines, fields['apple_id']!);
    fields['devices'] = _extractICloudDevices(lines);

    return fields;
  }

  String formatICloudOcrText(String extractedText) {
    final fields = autoDetectICloudFields(extractedText);
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

    if (rows.isNotEmpty) return rows.join('\n');
    return extractedText
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .join('\n');
  }

  Map<String, String> autoDetectFields(String extractedText) {
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

    final lines = extractedText.split('\n');
    fields['phone_number'] = _extractPhoneNumberNearLabel(lines);
    fields['model_number'] = _extractModelNumberNearLabel(lines);
    fields['serial_number'] = _extractSerialNumberNearLabel(lines);

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (fields['invoice_no']!.isEmpty) {
        fields['invoice_no'] = _extractInvoiceNo(trimmed);
      }

      if (fields['seller_name']!.isEmpty) {
        fields['seller_name'] = _extractLabeledValue(
          trimmed,
          ['seller', 'sales', 'cashier', 'staff'],
        );
      }

      if (fields['customer_name']!.isEmpty) {
        fields['customer_name'] = _extractLabeledValue(
          trimmed,
          ['customer', 'client'],
        );
      }

      if (fields['branch_name']!.isEmpty) {
        fields['branch_name'] = _extractLabeledValue(
          trimmed,
          ['branch', 'shop', 'store'],
        );
      }

      if (fields['phone_number']!.isEmpty) {
        fields['phone_number'] = _extractPhoneNumber(trimmed);
      }

      final modelName = _extractModelName(trimmed);
      if (modelName.isNotEmpty &&
          (fields['product_name']!.isEmpty ||
              fields['product_name']!.toLowerCase() == 'iphone' ||
              fields['product_name']!.length < modelName.length)) {
        fields['product_name'] = modelName;
      }

      if (fields['model_number']!.isEmpty) {
        fields['model_number'] = _extractModelNumber(trimmed);
      }

      if (fields['serial_number']!.isEmpty) {
        fields['serial_number'] = _extractSerialNumber(trimmed);
      }

      if (fields['storage']!.isEmpty) {
        fields['storage'] = _extractCapacity(trimmed);
      }

      final hasImeiLabel = _hasImeiLabel(trimmed);
      _extractLabeledImeis(trimmed, fields);

      if (!hasImeiLabel && fields['imei']!.isEmpty && _isImei(trimmed)) {
        fields['imei'] = _cleanImei(trimmed);
        continue;
      }

      if (!hasImeiLabel &&
          fields['imei2']!.isEmpty &&
          fields['imei']!.isNotEmpty &&
          _isImei(trimmed)) {
        fields['imei2'] = _cleanImei(trimmed);
        continue;
      }

      if (fields['serial_number']!.isEmpty && _isSerialNumber(trimmed)) {
        fields['serial_number'] = trimmed;
        continue;
      }

      if (fields['model_number']!.isEmpty && _isModelNumber(trimmed)) {
        fields['model_number'] = trimmed;
        continue;
      }

      if (fields['storage']!.isEmpty && _isStorage(trimmed)) {
        fields['storage'] = _extractStorage(trimmed);
        continue;
      }

      if (fields['color']!.isEmpty && _isColor(trimmed)) {
        fields['color'] = trimmed;
        continue;
      }

      if (fields['price']!.isEmpty && _isPrice(trimmed)) {
        fields['price'] = _extractPrice(trimmed);
        continue;
      }

      if (fields['price']!.isEmpty && _looksLikeTotalLine(trimmed)) {
        fields['price'] = _extractPrice(trimmed);
        continue;
      }

      if (fields['product_name']!.isEmpty &&
          _looksLikeProductName(trimmed) &&
          trimmed.length > 2 &&
          trimmed.contains(RegExp(r'[a-zA-Z]')) &&
          trimmed.length < 60) {
        fields['product_name'] = _cleanProductName(trimmed);
      }
    }

    fields['price'] = fields['price']!.isNotEmpty
        ? fields['price']!
        : _extractBestAmount(extractedText);
    fields['product_name'] = fields['product_name']!.isNotEmpty
        ? fields['product_name']!
        : _extractInvoiceProduct(lines);
    fields['serial_number'] = fields['serial_number']!.isNotEmpty
        ? fields['serial_number']!
        : _extractSerialFromInvoiceText(extractedText);
    fields['storage'] = fields['storage']!.isNotEmpty
        ? fields['storage']!
        : _extractStorage(extractedText);
    fields['color'] = fields['color']!.isNotEmpty
        ? fields['color']!
        : _extractColor(extractedText);
    fields['phone_number'] = fields['phone_number']!.isNotEmpty
        ? fields['phone_number']!
        : _extractPhoneNumber(extractedText);

    return fields;
  }

  String _extractInvoiceNo(String text) {
    final patterns = [
      r'\b(?:invoice|inv)\s*(?:no\.?|number|#)\s*[:\-]?\s*([A-Za-z0-9][A-Za-z0-9\-]{3,})',
      r'\b(?:invoice|inv)\s*[:\-]\s*([A-Za-z0-9][A-Za-z0-9\-]{3,})',
      r'\b(?:no\.?|number|#)\s*[:\-]\s*([A-Za-z0-9][A-Za-z0-9\-]{3,})',
    ];

    for (final pattern in patterns) {
      final match = RegExp(pattern, caseSensitive: false).firstMatch(text);
      final value = match?.group(1)?.trim() ?? '';
      if (value.isNotEmpty) return value;
    }

    return '';
  }

  String _extractLabeledValue(String text, List<String> labels) {
    final labelPattern = labels.map(RegExp.escape).join('|');
    final match = RegExp(
      '(?:$labelPattern)\\s*[:\\-]?\\s*(.+)',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) return '';

    final value = match.group(1)?.trim() ?? '';
    if (value.isEmpty || value.length > 40) return '';
    return value.replaceAll(RegExp(r'^[\s:.-]+|[\s:.-]+$'), '');
  }

  String _extractPhoneNumber(String text) {
    final matches = RegExp(
      r'(^|[^\d])((?:\+?855|0)[\s.-]?\d(?:[\s.-]?\d){6,8})(?!\d)',
    )
        .allMatches(text)
        .map((m) => m.group(2)!.replaceAll(RegExp(r'[^0-9+]'), ''))
        .where(_isCambodianPhoneNumber)
        .toList();
    return matches.isEmpty ? '' : matches.first;
  }

  String _extractEmail(String text) {
    final match = RegExp(
      r'\b[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}\b',
      caseSensitive: false,
    ).firstMatch(text);
    return match?.group(0)?.trim() ?? '';
  }

  bool _isCambodianPhoneNumber(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (_isImei(digits) || RegExp(r'^(19|20)\d{6,}').hasMatch(digits)) {
      return false;
    }

    final localNumber =
        digits.startsWith('855') ? '0${digits.substring(3)}' : digits;
    if (localNumber.length < 8 || localNumber.length > 10) return false;

    const mobilePrefixes = {
      '010',
      '011',
      '012',
      '015',
      '016',
      '017',
      '018',
      '060',
      '061',
      '066',
      '067',
      '068',
      '069',
      '070',
      '071',
      '076',
      '077',
      '078',
      '079',
      '081',
      '085',
      '086',
      '087',
      '088',
      '089',
      '092',
      '093',
      '095',
      '096',
      '097',
      '098',
      '099',
    };

    return mobilePrefixes.contains(localNumber.substring(0, 3));
  }

  String _extractPhoneNumberNearLabel(List<String> lines) {
    const phoneLabels = [
      'ទូរសព្ទ',
      'ទូរស័ព្ទ',
      'លេខទូរសព្ទ',
      'លេខទូរស័ព្ទ',
      'លេខអតិថិជន',
      'phone',
      'tel',
      'mobile',
      'contact',
    ];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      final lower = line.toLowerCase();
      final compactLower = lower.replaceAll(RegExp(r'\s+'), '');
      final hasPhoneLabel = phoneLabels.any((label) {
        final compactLabel = label.toLowerCase().replaceAll(RegExp(r'\s+'), '');
        return lower.contains(label.toLowerCase()) ||
            compactLower.contains(compactLabel);
      });
      if (!hasPhoneLabel) continue;

      final nearbyText = [
        line,
        if (i + 1 < lines.length) lines[i + 1],
        if (i + 2 < lines.length) lines[i + 2],
        if (i > 0) lines[i - 1],
      ].join(' ');

      final phone = _extractPhoneNumber(nearbyText);
      if (phone.isNotEmpty) return phone;
    }

    return '';
  }

  String _extractAppleAccountName(List<String> lines, String email) {
    final ignored = {
      'apple account',
      'personal information',
      'sign-in & security',
      'payment & shipping',
      'subscriptions',
      'icloud',
      'family',
      'find my',
      'media & purchases',
      'sign in with apple',
      'two-factor authentication',
      'verify using',
      'trusted phone number',
      'add a trusted phone number',
    };

    for (final line in lines) {
      final lower = line.toLowerCase();
      if (line == email ||
          lower.contains('@') ||
          ignored.any((value) => lower.contains(value)) ||
          lower.contains(RegExp(r'\biphone|\bipad|\bmacbook')) ||
          _extractPhoneNumber(line).isNotEmpty ||
          RegExp(r'^\d+\s*(gb|tb)$', caseSensitive: false).hasMatch(line)) {
        continue;
      }
      if (line.length >= 3 && line.length <= 40) return line;
    }
    return '';
  }

  String _extractICloudStorage(List<String> lines) {
    for (final line in lines) {
      final match = RegExp(
        r'\bicloud\b\s*(\d+(?:\.\d+)?\s*(?:GB|TB))',
        caseSensitive: false,
      ).firstMatch(line);
      if (match != null) return match.group(1)!.trim();
    }
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].toLowerCase() != 'icloud') continue;
      for (int j = i + 1; j < lines.length && j <= i + 2; j++) {
        final match =
            RegExp(r'\b\d+(?:\.\d+)?\s*(?:GB|TB)\b', caseSensitive: false)
                .firstMatch(lines[j]);
        if (match != null) return match.group(0)!.trim();
      }
    }
    return '';
  }

  String _extractICloudDevices(List<String> lines) {
    final devices = <String>[];
    final devicePattern = RegExp(
      r'\b(iPhone|iPad|MacBook|iMac|Apple Watch|AirPods)\b',
      caseSensitive: false,
    );

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lower = line.toLowerCase();
      if (!devicePattern.hasMatch(line) ||
          lower.contains('apple account') ||
          lower.contains('two-factor authentication')) {
        continue;
      }

      final next = i + 1 < lines.length ? lines[i + 1] : '';
      final combined = next.isNotEmpty &&
              devicePattern.hasMatch(next) &&
              !devicePattern.hasMatch(line)
          ? '$line - $next'
          : line;
      if (!devices.contains(combined)) devices.add(combined);
    }

    return devices.join('\n');
  }

  String _extractModelName(String text) {
    final labeled = RegExp(
      r'(?:model name)\s*[:\-]?\s*((?:iPhone|iPad|MacBook|Samsung|Galaxy|Oppo|Vivo|Xiaomi|Redmi|Huawei|Honor|Pixel).*)',
      caseSensitive: false,
    ).firstMatch(text);
    if (labeled != null) return _cleanProductName(labeled.group(1)!);

    final inline = RegExp(
      r'\b(?:iPhone\s*\d{1,2}\s*(?:Pro Max|Pro|Plus|Mini)?|iPhone\d{1,2}\s*(?:Pro Max|Pro|Plus|Mini)?|iPad\b.*|MacBook\b.*|Samsung\b.*|Galaxy\b.*|Oppo\b.*|Vivo\b.*|Xiaomi\b.*|Redmi\b.*|Huawei\b.*|Honor\b.*|Pixel\b.*)',
      caseSensitive: false,
    ).firstMatch(text);
    if (inline == null) return '';

    return _cleanProductName(inline.group(0)!);
  }

  String _extractModelNumber(String text) {
    final labeled = RegExp(
      r'(?:model number|model)\s*[:\-]?\s*([A-Z0-9]{4,8}(?:[A-Z0-9])?(?:/[A-Z])?|A\d{4})',
      caseSensitive: false,
    ).firstMatch(text);
    if (labeled != null) {
      final value = labeled.group(1)!.trim();
      if (!_isBadLabeledIdentifier(value)) return _normalizeModelNumber(value);
    }

    final applePart = RegExp(r'\b[A-Z0-9]{5,8}/[A-Z]\b').firstMatch(text);
    if (applePart != null) return _normalizeModelNumber(applePart.group(0)!);

    final applePartMissingSlash =
        RegExp(r'\b[A-Z0-9]{7}[J1I][A-Z]\b').firstMatch(text.toUpperCase());
    if (applePartMissingSlash != null) {
      return _normalizeModelNumber(applePartMissingSlash.group(0)!);
    }

    final appleModel = RegExp(r'\bA\d{4}\b').firstMatch(text);
    return appleModel?.group(0) ?? '';
  }

  String _extractSerialNumber(String text) {
    final labeled = RegExp(
      r'(?:serial\s+(?:number|no\.?)|\([s5]\)\s*serial\s*no\.?|s\/n|sn|serial(?!\s*(?:number|no\.?)))\s*[:\(\-]?\s*([A-Za-z0-9]{6,25})',
      caseSensitive: false,
    ).firstMatch(text);
    final value = labeled?.group(1)?.trim() ?? '';
    if (value.isEmpty || !_isLabeledSerialValue(value)) {
      return '';
    }
    return _normalizeSerialNumber(value);
  }

  String _extractModelNumberNearLabel(List<String> lines) {
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (!RegExp(r'^model\s+number$', caseSensitive: false).hasMatch(line)) {
        continue;
      }

      for (int j = i + 1; j < lines.length && j <= i + 3; j++) {
        final value = lines[j].trim();
        if (_isBadLabeledIdentifier(value)) continue;
        final modelNumber = _extractModelNumber(value);
        if (modelNumber.isNotEmpty) return modelNumber;
        if (_isModelNumber(value)) return _normalizeModelNumber(value);
      }
    }
    return '';
  }

  String _extractSerialNumberNearLabel(List<String> lines) {
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (!_hasSerialLabel(line)) {
        continue;
      }

      final inlineSerial = _extractSerialNumber(line);
      if (inlineSerial.isNotEmpty) return inlineSerial;

      final nearbyIndexes = <int>[
        for (int j = i + 1; j < lines.length && j <= i + 3; j++) j,
        for (int j = i - 1; j >= 0 && j >= i - 3; j--) j,
      ];

      for (final j in nearbyIndexes) {
        final serialNumber = _serialCandidate(lines[j]);
        if (serialNumber.isNotEmpty) return serialNumber;
      }
    }
    return '';
  }

  String _serialCandidate(String text) {
    final value = text.trim();
    if (!_isSerialCandidate(value, highConfidence: true)) {
      return '';
    }
    final serialNumber = _extractSerialNumber(value);
    if (serialNumber.isNotEmpty) return serialNumber;
    return _normalizeSerialNumber(value);
  }

  String _normalizeModelNumber(String value) {
    final normalized = value.trim().toUpperCase();
    final missingSlash =
        RegExp(r'^([A-Z0-9]{7})[J1I]([A-Z])$').firstMatch(normalized);
    if (missingSlash != null) {
      return '${missingSlash.group(1)!}/${missingSlash.group(2)!}';
    }
    return normalized;
  }

  String _normalizeSerialNumber(String value) {
    return value
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '')
        .replaceAllMapped(RegExp(r'(?<=[A-Z])O(?=\d{2})'), (_) => '0');
  }

  bool _isBadLabeledIdentifier(String value) {
    final lower = value.trim().toLowerCase();
    return lower.isEmpty ||
        lower == 'name' ||
        lower == 'number' ||
        lower == 'model name' ||
        lower == 'model number' ||
        lower == 'serial number';
  }

  bool _hasSerialLabel(String text) {
    final lower = text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    return RegExp(r'(^|[^a-z0-9])serial\s*(number|no\.?|#)?([^a-z0-9]|$)')
            .hasMatch(lower) ||
        RegExp(r'(^|[^a-z0-9])s\s*/\s*n([^a-z0-9]|$)').hasMatch(lower) ||
        RegExp(r'^\([s5]\)\s*serial').hasMatch(lower);
  }

  String _extractDisplaySerialNumber(String text) {
    final labeled = RegExp(
      r'(?:serial\s+(?:number|no\.?)|\([s5]\)\s*serial\s*no\.?|s\/n|sn|serial(?!\s*(?:number|no\.?)))\s*[:\(\-]?\s*([A-Za-z0-9]{6,25})',
      caseSensitive: false,
    ).firstMatch(text);
    final value = labeled?.group(1)?.trim() ?? '';
    return _isLabeledSerialValue(value) ? _normalizeSerialNumber(value) : '';
  }

  bool _containsLabel(String text, String label) {
    final compactText = text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final compactLabel = label.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    return compactText.contains(compactLabel);
  }

  String _extractDisplayLabeledValue(String text, String label) {
    final escapedLabel = RegExp.escape(label).replaceAll(r'\ ', r'\s+');
    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      final match = RegExp(
        '^$escapedLabel\\s*[:\\-]?\\s*(.+)\$',
        caseSensitive: false,
      ).firstMatch(trimmed);
      final value = match?.group(1)?.trim() ?? '';
      if (value.isNotEmpty && value.toLowerCase() != label.toLowerCase()) {
        return value;
      }
    }
    return '';
  }

  String _extractCapacity(String text) {
    final labeled = RegExp(
      r'(?:capacity|storage)\s*[:\-]?\s*(\d+\s*(?:GB|TB|gb|tb))',
      caseSensitive: false,
    ).firstMatch(text);
    if (labeled != null) return labeled.group(1)!.trim();
    return '';
  }

  void _extractLabeledImeis(String text, Map<String, String> fields) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ');
    final imei2 = RegExp(
      r'(?:^|[^A-Z0-9])IMEI\s*(?:2|II)\b\D*([0-9]{14,15})',
      caseSensitive: false,
    ).firstMatch(normalized);
    if (imei2 != null && fields['imei2']!.isEmpty) {
      fields['imei2'] = imei2.group(1)!;
    }

    final imei = RegExp(
      r'(?:^|[^A-Z0-9])IMEI(?:/MEID)?\b(?!\s*(?:2|II)\b)\D*([0-9]{14,15})',
      caseSensitive: false,
    ).firstMatch(normalized);
    if (imei != null && fields['imei']!.isEmpty) {
      fields['imei'] = imei.group(1)!;
    }
  }

  bool _hasImeiLabel(String text) {
    return RegExp(r'(^|[^A-Z0-9])IMEI(?:\s*(?:2|II)|/MEID)?\b',
            caseSensitive: false)
        .hasMatch(text);
  }

  bool _isImei(String text) {
    final digitsOnly = text.replaceAll(RegExp(r'[^0-9]'), '');
    return digitsOnly.length == 15 || digitsOnly.length == 14;
  }

  String _cleanImei(String text) {
    return text.replaceAll(RegExp(r'[^0-9]'), '');
  }

  bool _isSerialNumber(String text) {
    return _isSerialCandidate(text);
  }

  bool _isLabeledSerialValue(String text) {
    final normalized = _normalizeSerialNumber(text);
    return RegExp(r'^[A-Z0-9]{6,25}$').hasMatch(normalized) &&
        normalized.contains(RegExp(r'[A-Z]')) &&
        !_looksLikeAppleModelNumber(normalized) &&
        !_isImei(normalized);
  }

  bool _isSerialCandidate(String text, {bool highConfidence = false}) {
    if (_looksLikeProductInfoLabel(text)) return false;

    final normalized = _normalizeSerialNumber(text);
    if (_isBadLabeledIdentifier(normalized) ||
        _looksLikeAppleModelNumber(normalized) ||
        _isImei(normalized) ||
        RegExp(r'^\d+$').hasMatch(normalized)) {
      return false;
    }

    if (highConfidence) {
      return RegExp(r'^[A-Z0-9]{10}$').hasMatch(normalized) &&
          normalized.contains(RegExp(r'[A-Z]'));
    }

    return RegExp(r'^[A-Z0-9]{10}$').hasMatch(normalized) &&
        normalized.contains(RegExp(r'[A-Z]')) &&
        normalized.contains(RegExp(r'[0-9]'));
  }

  bool _looksLikeProductInfoLabel(String text) {
    final lower = text.toLowerCase();
    const labels = [
      'model name',
      'model number',
      'coverage',
      'parts',
      'service history',
      'songs',
      'videos',
      'photos',
      'applications',
      'capacity',
      'available',
      'imei',
      'meid',
      'upc',
      'eid',
    ];
    return labels.any(lower.contains);
  }

  bool _looksLikeAppleModelNumber(String text) {
    final normalized = text.trim().toUpperCase();
    return RegExp(r'^[A-Z0-9]{5,8}/[A-Z]$').hasMatch(normalized) ||
        RegExp(r'^[A-Z0-9]{7}[J1I][A-Z]$').hasMatch(normalized) ||
        RegExp(r'^A\d{4}$').hasMatch(normalized);
  }

  bool _isModelNumber(String text) {
    return text.contains(RegExp(r'^[A-Za-z0-9\-_\/]{4,20}$')) &&
        text.contains(RegExp(r'[A-Z]')) &&
        text.contains(RegExp(r'[0-9]'));
  }

  bool _isStorage(String text) {
    return text.contains(RegExp(r'\d+\s*(GB|TB|gb|tb|g|t)\b'));
  }

  String _extractStorage(String text) {
    final match = RegExp(r'(\d+\s*(GB|TB|gb|tb))').firstMatch(text);
    if (match != null) {
      return match.group(1)!.trim();
    }
    return text;
  }

  bool _isColor(String text) {
    final colors = [
      'black',
      'white',
      'red',
      'blue',
      'green',
      'yellow',
      'purple',
      'pink',
      'gray',
      'grey',
      'gold',
      'silver',
      'space gray',
      'space grey',
      'midnight',
      'starlight',
      'graphite',
      'sierra blue',
      'alpine green',
      'deep purple',
      'titanium',
      'natural titanium',
      'blue titanium',
      'white titanium',
      'black titanium',
      'rose gold',
      'coral',
      'orange',
      'brown',
      'navy',
    ];
    final lower = text.toLowerCase().trim();
    return colors.any((c) => lower == c || lower.startsWith(c));
  }

  bool _isPrice(String text) {
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 7 || _extractPhoneNumber(text).isNotEmpty) return false;
    return text.contains(RegExp(r'^[\$\€\£\¥]?\s*[\d,]+\.?\d{0,2}$')) ||
        text.contains(RegExp(r'^\d+\.\d{2}$')) ||
        (text.contains(RegExp(r'^[\$\€\£\¥]')) && text.contains(RegExp(r'\d')));
  }

  String _extractPrice(String text) {
    final matches = RegExp(r'[\$\€\£\¥]?\s*[\d,]+(?:\.\d{1,2})?')
        .allMatches(text)
        .where((m) =>
            (m.group(0) ?? '').replaceAll(RegExp(r'[^0-9]'), '').length <= 8)
        .toList();
    final match = matches.isEmpty ? null : matches.last;
    if (match != null) {
      return match.group(0)!.replaceAll(RegExp(r'[^\d.]'), '');
    }
    return text;
  }

  bool _looksLikeTotalLine(String text) {
    final lower = text.toLowerCase();
    return lower.contains('total') ||
        lower.contains('amount') ||
        lower.contains('price') ||
        lower.contains('grand') ||
        lower.contains('subtotal') ||
        lower.contains('unit price') ||
        text.contains(RegExp(r'\$\s*\d+'));
  }

  String _extractBestAmount(String text) {
    final totalLines = text
        .split('\n')
        .where((line) => _looksLikeTotalLine(line))
        .map(_extractPrice)
        .where((value) => double.tryParse(value) != null)
        .toList();
    if (totalLines.isNotEmpty) return totalLines.last;

    final values = RegExp(r'[\$]?\s*\d{2,6}(?:\.\d{1,2})?')
        .allMatches(text)
        .map((m) => _extractPrice(m.group(0)!))
        .where((value) => double.tryParse(value) != null)
        .toList();
    if (values.isEmpty) return '';

    values.sort(
      (a, b) => (double.tryParse(a) ?? 0).compareTo(double.tryParse(b) ?? 0),
    );
    return values.last;
  }

  bool _looksLikeProductName(String text) {
    final lower = text.toLowerCase();
    final ignored = [
      'invoice',
      'customer',
      'seller',
      'total',
      'quantity',
      'unit price',
      'amount',
      'date',
      'phone',
      'tel',
      'imei',
      'serial',
      'capacity',
      'available',
      'wi-fi',
      'wifi',
      'free',
      'coverage',
      'expired',
      'parts & service',
      'service history',
      'songs',
      'videos',
      'photos',
    ];
    return !ignored.any(lower.contains);
  }

  String _cleanProductName(String text) {
    return text
        .replaceAll(RegExp(r'^\d+\s*[.)-]?\s*'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _extractInvoiceProduct(List<String> lines) {
    final productPattern = RegExp(
      r'\b(?:iphone|ipad|macbook|samsung|galaxy|oppo|vivo|xiaomi|redmi|huawei|honor|pixel)\b.*',
      caseSensitive: false,
    );
    for (final line in lines) {
      final match = productPattern.firstMatch(line.trim());
      if (match != null) return _cleanProductName(match.group(0)!);
    }
    return '';
  }

  String _extractSerialFromInvoiceText(String text) {
    final labeled = RegExp(
      r'(?:serial\s+(?:number|no\.?)|\([s5]\)\s*serial\s*no\.?|s\/n|sn|serial(?!\s*(?:number|no\.?)))\s*[:\(\-]?\s*([A-Za-z0-9]{6,25})',
      caseSensitive: false,
    ).firstMatch(text);
    final labeledValue = labeled?.group(1)?.trim() ?? '';
    if (_isSerialCandidate(labeledValue, highConfidence: true)) {
      return _normalizeSerialNumber(labeledValue);
    }

    final matches = RegExp(r'\b[A-Z0-9]{8,20}\b')
        .allMatches(text.toUpperCase())
        .map((m) => m.group(0)!)
        .where((value) => _isSerialCandidate(value))
        .toList();
    if (matches.isEmpty) return '';
    return _normalizeSerialNumber(matches.last);
  }

  String _extractColor(String text) {
    final colors = [
      'natural titanium',
      'blue titanium',
      'white titanium',
      'black titanium',
      'space gray',
      'space grey',
      'rose gold',
      'sierra blue',
      'alpine green',
      'deep purple',
      'graphite',
      'midnight',
      'starlight',
      'titanium',
      'black',
      'white',
      'red',
      'blue',
      'green',
      'yellow',
      'purple',
      'pink',
      'gray',
      'grey',
      'gold',
      'silver',
      'coral',
      'orange',
      'brown',
      'navy',
    ];
    final lower = text.toLowerCase();
    for (final color in colors) {
      final escaped = RegExp.escape(color).replaceAll(r'\ ', r'\s+');
      if (RegExp('(^|[^a-z])$escaped([^a-z]|\$)', caseSensitive: false)
          .hasMatch(lower)) {
        return color;
      }
    }
    return '';
  }

  void dispose() {
    _recognizer.close();
  }
}
