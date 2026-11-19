import 'repair_brand.dart';

class RepairDeviceType {
  final int id;
  final String name;
  final String slug;
  final String icon;

  const RepairDeviceType({
    required this.id,
    required this.name,
    required this.slug,
    this.icon = '',
  });

  factory RepairDeviceType.fromJson(Map<String, dynamic> json) {
    return RepairDeviceType(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      name: '${json['name'] ?? ''}',
      slug: '${json['slug'] ?? ''}',
      icon: '${json['icon'] ?? ''}',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'icon': icon,
    };
  }

  RepairDeviceType copyWith({
    int? id,
    String? name,
    String? slug,
    String? icon,
  }) {
    return RepairDeviceType(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      icon: icon ?? this.icon,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RepairDeviceType &&
          runtimeType == other.runtimeType &&
          id == other.id);

  @override
  int get hashCode => id.hashCode;
}

class RepairDeviceSeries {
  final int id;
  final String name;
  final String slug;
  final int brandId;
  final int deviceTypeId;

  const RepairDeviceSeries({
    required this.id,
    required this.name,
    required this.slug,
    this.brandId = 0,
    this.deviceTypeId = 0,
  });

  factory RepairDeviceSeries.fromJson(Map<String, dynamic> json) {
    return RepairDeviceSeries(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      name: '${json['name'] ?? ''}',
      slug: '${json['slug'] ?? ''}',
      brandId:
          int.tryParse('${json['repair_brand_id'] ?? json['brand_id'] ?? 0}') ??
              0,
      deviceTypeId: int.tryParse(
              '${json['repair_device_type_id'] ?? json['device_type_id'] ?? 0}') ??
          0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'repair_brand_id': brandId,
      'repair_device_type_id': deviceTypeId,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RepairDeviceSeries &&
          runtimeType == other.runtimeType &&
          id == other.id);

  @override
  int get hashCode => id.hashCode;
}

class RepairDevice {
  final int id;
  final String name;
  final String modelNumber;
  final String image;
  final RepairBrand? brand;
  final RepairDeviceType? deviceType;
  final RepairDeviceSeries? series;

  const RepairDevice({
    required this.id,
    required this.name,
    this.modelNumber = '',
    this.image = '',
    this.brand,
    this.deviceType,
    this.series,
  });

  factory RepairDevice.fromJson(Map<String, dynamic> json) {
    return RepairDevice(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      name: '${json['name'] ?? ''}',
      modelNumber: '${json['model_number'] ?? ''}',
      image: '${json['image'] ?? ''}',
      brand: json['brand'] is Map
          ? RepairBrand.fromJson(Map<String, dynamic>.from(json['brand']))
          : null,
      deviceType: json['device_type'] is Map
          ? RepairDeviceType.fromJson(
              Map<String, dynamic>.from(json['device_type']))
          : null,
      series: json['series'] is Map
          ? RepairDeviceSeries.fromJson(
              Map<String, dynamic>.from(json['series']))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'model_number': modelNumber,
      'image': image,
      if (brand != null) 'repair_brand_id': brand!.id,
      if (deviceType != null) 'repair_device_type_id': deviceType!.id,
      'repair_device_series_id': series?.id,
    };
  }

  RepairDevice copyWith({
    int? id,
    String? name,
    String? modelNumber,
    String? image,
    RepairBrand? brand,
    RepairDeviceType? deviceType,
    RepairDeviceSeries? series,
  }) {
    return RepairDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      modelNumber: modelNumber ?? this.modelNumber,
      image: image ?? this.image,
      brand: brand ?? this.brand,
      deviceType: deviceType ?? this.deviceType,
      series: series ?? this.series,
    );
  }
}
