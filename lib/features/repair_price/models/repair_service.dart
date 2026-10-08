import '../utils/repair_price_helper.dart';
import 'repair_category.dart';

class RepairService {
  final int id;
  final int? repairPriceId;
  final String name;
  final String nameKh;
  final String description;
  final RepairCategory? category;
  final String partName;
  final String partType;
  final num? partCost;
  final num? serviceFee;
  final num sellingPrice;
  final int? warrantyDays;
  final int? estimatedMinutes;
  final String note;
  final String availabilityStatus;
  final bool canViewCost;

  const RepairService({
    required this.id,
    required this.name,
    required this.sellingPrice,
    this.repairPriceId,
    this.nameKh = '',
    this.description = '',
    this.category,
    this.partName = '',
    this.partType = '',
    this.partCost,
    this.serviceFee,
    this.warrantyDays,
    this.estimatedMinutes,
    this.note = '',
    this.availabilityStatus = 'available',
    this.canViewCost = false,
  });

  num? get profit {
    if (partCost == null || serviceFee == null) return null;
    return sellingPrice - partCost! - serviceFee!;
  }

  String get warrantyLabel => RepairPriceHelper.warranty(warrantyDays);
  String get timeLabel => RepairPriceHelper.repairTime(estimatedMinutes);

  factory RepairService.fromJson(Map<String, dynamic> json) {
    num? cost(String key) => json.containsKey(key) && json[key] != null
        ? num.tryParse('${json[key]}')
        : null;

    return RepairService(
      id: int.tryParse('${json['id'] ?? json['repair_service_id'] ?? 0}') ?? 0,
      repairPriceId: int.tryParse('${json['repair_price_id'] ?? ''}'),
      name: '${json['name'] ?? json['service_name'] ?? ''}',
      nameKh: '${json['name_kh'] ?? json['service_name_kh'] ?? ''}',
      description: '${json['description'] ?? ''}',
      category: json['category'] is Map
          ? RepairCategory.fromJson(Map<String, dynamic>.from(json['category']))
          : null,
      partName: '${json['part_name'] ?? ''}',
      partType: '${json['part_type'] ?? ''}',
      partCost: cost('part_cost'),
      serviceFee: cost('service_fee'),
      sellingPrice: cost('selling_price') ?? 0,
      warrantyDays: int.tryParse('${json['warranty_days'] ?? ''}'),
      estimatedMinutes: int.tryParse('${json['estimated_minutes'] ?? ''}'),
      note: '${json['note'] ?? ''}',
      availabilityStatus: '${json['availability_status'] ?? 'available'}',
      canViewCost:
          json.containsKey('part_cost') || json['can_view_cost'] == true,
    );
  }

  Map<String, dynamic> toPriceUpdateJson({required int deviceId}) {
    return {
      'repair_device_id': deviceId,
      'repair_service_id': id,
      'part_name': partName,
      'part_type': partType,
      'part_cost': partCost ?? 0,
      'service_fee': serviceFee ?? 0,
      'selling_price': sellingPrice,
      'warranty_days': warrantyDays,
      'estimated_minutes': estimatedMinutes,
      'note': note,
      'availability_status': availabilityStatus,
    };
  }
}
