class AdminAsset {
  final int id;
  final String name;
  final String assetCode;
  final String assetSerialNo;
  final int? typeId;
  final String typeName;
  final int? branchId;
  final String branchName;
  final String purchasedDate;
  final bool isAvailable;
  final String isWorking;
  final bool warrantyAvailable;
  final String? warrantyEndDate;
  final String note;
  final String phoneNumbers;
  final String icloud;
  final String? imageUrl;
  final List<String> images;
  final String status;
  final AdminAssetAssignee? assignedTo;
  final List<AdminAssetAssignmentHistory> assignmentHistory;

  AdminAsset({
    required this.id,
    required this.name,
    required this.assetCode,
    required this.assetSerialNo,
    this.typeId,
    required this.typeName,
    this.branchId,
    required this.branchName,
    required this.purchasedDate,
    required this.isAvailable,
    required this.isWorking,
    required this.warrantyAvailable,
    this.warrantyEndDate,
    required this.note,
    required this.phoneNumbers,
    required this.icloud,
    this.imageUrl,
    this.images = const [],
    required this.status,
    this.assignedTo,
    this.assignmentHistory = const [],
  });

  factory AdminAsset.fromJson(Map<String, dynamic> json) {
    return AdminAsset(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      name: json['name']?.toString() ?? '',
      assetCode: json['asset_code']?.toString() ?? '',
      assetSerialNo: json['asset_serial_no']?.toString() ?? '',
      typeId: json['type_id'] is int
          ? json['type_id']
          : int.tryParse('${json['type_id']}'),
      typeName: json['type_name']?.toString() ?? 'N/A',
      branchId: json['branch_id'] is int
          ? json['branch_id']
          : int.tryParse('${json['branch_id']}'),
      branchName: json['branch_name']?.toString() ?? 'N/A',
      purchasedDate: json['purchased_date']?.toString() ?? '',
      isAvailable: json['is_available'] == 1 ||
          json['is_available'] == true ||
          json['is_available'] == '1' ||
          json['is_available'] == 'yes' ||
          json['is_available'] == 'true',
      isWorking: json['is_working']?.toString() ?? 'yes',
      warrantyAvailable: json['warranty_available'] == 1 ||
          json['warranty_available'] == true ||
          json['warranty_available'] == '1' ||
          json['warranty_available'] == 'yes' ||
          json['warranty_available'] == 'true',
      warrantyEndDate: json['warranty_end_date']?.toString(),
      note: json['note']?.toString() ?? '',
      phoneNumbers: json['phone_numbers']?.toString() ?? '',
      icloud: json['icloud']?.toString() ?? '',
      imageUrl: json['image_url']?.toString(),
      images: json['images'] is List
          ? (json['images'] as List)
              .where((e) => e != null)
              .map((e) => e.toString())
              .where((s) => s.isNotEmpty && s != 'null')
              .toList()
          : [],
      status: json['status']?.toString() ?? 'Available',
      assignedTo: json['assigned_to'] is Map<String, dynamic>
          ? AdminAssetAssignee.fromJson(
              json['assigned_to'] as Map<String, dynamic>)
          : null,
      assignmentHistory: json['assignment_history'] is List
          ? (json['assignment_history'] as List)
              .whereType<Map>()
              .map((e) => AdminAssetAssignmentHistory.fromJson(
                  Map<String, dynamic>.from(e)))
              .toList()
          : [],
    );
  }
}

class AdminAssetAssignee {
  final int id;
  final String name;
  final String? avatar;
  final String assignedDate;

  AdminAssetAssignee({
    required this.id,
    required this.name,
    this.avatar,
    required this.assignedDate,
  });

  factory AdminAssetAssignee.fromJson(Map<String, dynamic> json) {
    return AdminAssetAssignee(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      name: json['name']?.toString() ?? '',
      avatar: json['avatar']?.toString(),
      assignedDate: json['assigned_date']?.toString() ?? '',
    );
  }
}

class AdminAssetAssignmentHistory {
  final int id;
  final int userId;
  final String employeeName;
  final String assignedDate;
  final String? returnedDate;
  final String status;
  final String? returnCondition;
  final String? notes;

  AdminAssetAssignmentHistory({
    required this.id,
    required this.userId,
    required this.employeeName,
    required this.assignedDate,
    this.returnedDate,
    required this.status,
    this.returnCondition,
    this.notes,
  });

  factory AdminAssetAssignmentHistory.fromJson(Map<String, dynamic> json) {
    return AdminAssetAssignmentHistory(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      userId: json['user_id'] is int
          ? json['user_id']
          : int.tryParse('${json['user_id']}') ?? 0,
      employeeName: json['employee_name']?.toString() ?? '',
      assignedDate: json['assigned_date']?.toString() ?? '',
      returnedDate: json['returned_date']?.toString(),
      status: json['status']?.toString() ?? '',
      returnCondition: json['return_condition']?.toString(),
      notes: json['notes']?.toString(),
    );
  }
}

class AssetDropdownItem {
  final int id;
  final String name;

  AssetDropdownItem({required this.id, required this.name});

  factory AssetDropdownItem.fromJson(Map<String, dynamic> json) {
    return AssetDropdownItem(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      name: json['name']?.toString() ?? '',
    );
  }
}

class AssetEmployeeItem {
  final int id;
  final String name;
  final String? employeeCode;
  final int? branchId;
  final String? avatar;

  AssetEmployeeItem({
    required this.id,
    required this.name,
    this.employeeCode,
    this.branchId,
    this.avatar,
  });

  factory AssetEmployeeItem.fromJson(Map<String, dynamic> json) {
    return AssetEmployeeItem(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      name: json['name']?.toString() ?? '',
      employeeCode: json['employee_code']?.toString(),
      branchId: json['branch_id'] is int
          ? json['branch_id']
          : int.tryParse('${json['branch_id']}'),
      avatar: json['avatar']?.toString(),
    );
  }
}

class AdminAssetFormData {
  final List<AssetDropdownItem> types;
  final List<AssetDropdownItem> branches;
  final List<AssetEmployeeItem> employees;

  AdminAssetFormData({
    required this.types,
    required this.branches,
    required this.employees,
  });

  factory AdminAssetFormData.fromJson(Map<String, dynamic> json) {
    final typesList = json['types'] is List
        ? (json['types'] as List)
            .whereType<Map>()
            .map((e) => AssetDropdownItem.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <AssetDropdownItem>[];

    final branchesList = json['branches'] is List
        ? (json['branches'] as List)
            .whereType<Map>()
            .map((e) => AssetDropdownItem.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <AssetDropdownItem>[];

    final employeesList = json['employees'] is List
        ? (json['employees'] as List)
            .whereType<Map>()
            .map((e) => AssetEmployeeItem.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <AssetEmployeeItem>[];

    return AdminAssetFormData(
      types: typesList,
      branches: branchesList,
      employees: employeesList,
    );
  }
}
