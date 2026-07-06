class SellOutReportLine {
  int? id;
  String productName;
  String sku;
  String imei;
  String imei2;
  String serialNumber;
  String modelNumber;
  String color;
  String storage;
  int qty;
  double unitPrice;
  List<String> photoUrls;
  List<int?> photoIds;

  /// Local file paths picked on-device, pending upload. Never populated
  /// from the server.
  List<String> photoPaths;

  SellOutReportLine({
    this.id,
    this.productName = '',
    this.sku = '',
    this.imei = '',
    this.imei2 = '',
    this.serialNumber = '',
    this.modelNumber = '',
    this.color = '',
    this.storage = '',
    this.qty = 1,
    this.unitPrice = 0.0,
    List<String>? photoUrls,
    List<int?>? photoIds,
    List<String>? photoPaths,
  })  : photoUrls = photoUrls ?? [],
        photoIds = photoIds ?? [],
        photoPaths = photoPaths ?? [];

  factory SellOutReportLine.fromJson(Map<String, dynamic> json) {
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

    return SellOutReportLine(
      id: _asInt(json['id']),
      productName: _asString(json['product_name']),
      sku: _asString(json['sku']),
      imei: _asString(json['imei']),
      imei2: _asString(json['imei2']),
      serialNumber: _asString(json['serial_number']),
      modelNumber: _asString(json['model_number']),
      color: _asString(json['color']),
      storage: _asString(json['storage']),
      qty: _asInt(json['qty']) ?? 1,
      unitPrice: _asDouble(json['unit_price']),
      photoUrls: photoEntries.map((entry) => entry.value).toList(),
      photoIds: photoEntries.map((entry) => entry.key).toList(),
    );
  }

  double get subtotal => qty * unitPrice;

  String get identifierType {
    if (imei.isNotEmpty) return 'imei';
    if (serialNumber.isNotEmpty) return 'serial';
    return 'sku';
  }

  String get primaryIdentifier {
    if (imei.isNotEmpty) return imei;
    if (serialNumber.isNotEmpty) return serialNumber;
    return sku;
  }

  SellOutReportLine copyWith({
    int? id,
    String? productName,
    String? sku,
    String? imei,
    String? imei2,
    String? serialNumber,
    String? modelNumber,
    String? color,
    String? storage,
    int? qty,
    double? unitPrice,
    List<String>? photoUrls,
    List<int?>? photoIds,
    List<String>? photoPaths,
  }) {
    return SellOutReportLine(
      id: id ?? this.id,
      productName: productName ?? this.productName,
      sku: sku ?? this.sku,
      imei: imei ?? this.imei,
      imei2: imei2 ?? this.imei2,
      serialNumber: serialNumber ?? this.serialNumber,
      modelNumber: modelNumber ?? this.modelNumber,
      color: color ?? this.color,
      storage: storage ?? this.storage,
      qty: qty ?? this.qty,
      unitPrice: unitPrice ?? this.unitPrice,
      photoUrls: photoUrls ?? List<String>.from(this.photoUrls),
      photoIds: photoIds ?? List<int?>.from(this.photoIds),
      photoPaths: photoPaths ?? List<String>.from(this.photoPaths),
    );
  }

  Map<String, dynamic> toMap(int index) {
    return {
      'lines[$index][product_name]': productName,
      'lines[$index][sku]': sku,
      'lines[$index][imei]': imei,
      'lines[$index][imei2]': imei2,
      'lines[$index][serial_number]': serialNumber,
      'lines[$index][model_number]': modelNumber,
      'lines[$index][color]': color,
      'lines[$index][storage]': storage,
      'lines[$index][qty]': qty.toString(),
      'lines[$index][unit_price]': unitPrice.toStringAsFixed(2),
    };
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

  static double _asDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }
}
