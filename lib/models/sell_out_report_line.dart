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
  });

  factory SellOutReportLine.fromJson(Map<String, dynamic> json) {
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
