import 'sell_out_report_line.dart';

class SellOutReport {
  static const double commissionPerItem = 0.25;

  /// Service type labels are stored on the report exactly as the translated
  /// label shown in the UI at creation time. Since the app's language can
  /// change after a report is saved (and translations have changed over
  /// time, e.g. "Iron" was briefly mistranslated as "Scots"), comparisons
  /// must go through [canonicalServiceType] instead of matching raw strings.
  static const Map<String, Set<String>> _serviceTypeAliases = {
    'sell': {'Sell', 'លក់'},
    'material': {'Material', 'សម្ភារ'},
    'iron': {'Iron', 'Scots', 'អ៊ុត'},
    'repair': {'Repair', 'ជួសជុល'},
    'buy_in': {'Buy In', 'ទិញចូល', 'ទិញ', 'Buy'},
    'icloud_cus': {'iCloud Cus'},
  };

  static const Set<String> commissionableCanonicalTypes = {'sell', 'iron'};
  static const Set<String> serialNumberRequiredCanonicalTypes = {
    'sell',
    'buy_in',
  };
  static final RegExp serialNumberPattern = RegExp(r'^[A-Za-z0-9]+$');

  static String canonicalServiceType(String raw) {
    final trimmed = raw.trim();
    for (final entry in _serviceTypeAliases.entries) {
      if (entry.value.contains(trimmed)) return entry.key;
    }
    return trimmed;
  }

  int? id;
  String invoiceNo;
  String originalInvoiceNo;
  String sellerName;
  String branchName;
  String customerName;
  String customerPhone;
  String serviceType;
  String paymentMethod;
  String note;
  String extractedText;
  double? serverTotalAmount;
  String createdAt;
  int? linesCount;
  int? photosCount;
  List<SellOutReportLine> lines;
  List<String> photoPaths;
  List<String> photoUrls;
  List<int?> photoIds;

  SellOutReport({
    this.id,
    this.invoiceNo = '',
    this.originalInvoiceNo = '',
    this.sellerName = '',
    this.branchName = '',
    this.customerName = '',
    this.customerPhone = '',
    this.serviceType = '',
    this.paymentMethod = '',
    this.note = '',
    this.extractedText = '',
    this.serverTotalAmount,
    this.createdAt = '',
    this.linesCount,
    this.photosCount,
    List<SellOutReportLine>? lines,
    List<String>? photoPaths,
    List<String>? photoUrls,
    List<int?>? photoIds,
  })  : lines = lines ?? [SellOutReportLine()],
        photoPaths = photoPaths ?? [],
        photoUrls = photoUrls ?? [],
        photoIds = photoIds ?? [];

  factory SellOutReport.fromJson(Map<String, dynamic> json) {
    final lineItems = _asList(json['lines'])
        .whereType<Map>()
        .map((line) =>
            SellOutReportLine.fromJson(Map<String, dynamic>.from(line)))
        .toList();
    final photoEntries = _asList(json['photos'])
        .whereType<Map>()
        .map((photo) {
          final url = _asString(photo['photo_url']).isNotEmpty
              ? _asString(photo['photo_url'])
              : _asString(photo['photo_path']);
          return MapEntry(_asInt(photo['id']), url);
        })
        .where((entry) => entry.value.isNotEmpty)
        .toList();
    final photoItems = photoEntries.map((entry) => entry.value).toList();
    final photoIdItems = photoEntries.map((entry) => entry.key).toList();

    return SellOutReport(
      id: _asInt(json['id']),
      invoiceNo: _asString(json['invoice_no']),
      originalInvoiceNo: _asString(json['original_invoice_no']),
      sellerName: _asString(json['seller_name']),
      branchName: _asString(json['branch_name']),
      customerName: _asString(json['customer_name']),
      customerPhone: _asString(json['customer_phone']),
      serviceType: _asString(json['service_type']),
      paymentMethod: _asString(json['payment_method']),
      note: _asString(json['note']),
      extractedText: _asString(json['extracted_text']),
      serverTotalAmount: _asNullableDouble(json['total_amount']),
      createdAt: _asString(json['created_at']),
      linesCount: _asInt(json['lines_count']),
      photosCount: _asInt(json['photos_count']),
      lines: lineItems.isEmpty ? [SellOutReportLine()] : lineItems,
      photoUrls: photoItems,
      photoIds: photoIdItems,
    );
  }

  double get totalAmount {
    if (serverTotalAmount != null) return serverTotalAmount!;
    double sum = 0;
    for (final line in lines) {
      sum += line.subtotal;
    }
    return sum;
  }

  int get itemCount => linesCount ?? lines.length;

  int get totalQty {
    return lines.fold<int>(0, (sum, line) => sum + line.qty);
  }

  bool get isCommissionable {
    return commissionableCanonicalTypes
        .contains(canonicalServiceType(serviceType));
  }

  bool get requiresSerialNumberValidation {
    return serialNumberRequiredCanonicalTypes
        .contains(canonicalServiceType(serviceType));
  }

  double get commission {
    if (!isCommissionable) return 0;
    return totalQty * commissionPerItem;
  }

  static String? validateSerialNumber(String value) {
    final serialNumber = value.trim();
    if (serialNumber.isEmpty) {
      return 'Serial Number is required.';
    }
    if (serialNumber.length < 6 || serialNumber.length > 16) {
      return 'Serial Number must be 6-16 characters.';
    }
    if (!serialNumberPattern.hasMatch(serialNumber)) {
      return 'Serial Number must contain only letters and numbers.';
    }
    return null;
  }

  String? validateSerialNumbers() {
    if (!requiresSerialNumberValidation) return null;
    for (int i = 0; i < lines.length; i++) {
      final message = validateSerialNumber(lines[i].serialNumber);
      if (message != null) {
        return 'Product #${i + 1}: $message';
      }
    }
    return null;
  }

  void reset() {
    id = null;
    invoiceNo = '';
    originalInvoiceNo = '';
    sellerName = '';
    branchName = '';
    customerName = '';
    customerPhone = '';
    serviceType = '';
    paymentMethod = '';
    note = '';
    extractedText = '';
    serverTotalAmount = null;
    createdAt = '';
    linesCount = null;
    photosCount = null;
    lines = [SellOutReportLine()];
    photoPaths = [];
    photoUrls = [];
    photoIds = [];
  }

  static List<dynamic> _asList(dynamic value) {
    return value is List ? value : const [];
  }

  static String _asString(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static double? _asNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
