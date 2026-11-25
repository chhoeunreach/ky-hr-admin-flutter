class DeliveryModel {
  final int id;
  final int userId;
  final int? branchId;
  final int? destinationBranchId;
  final String? destinationBranchName;
  final String deliveryType;
  final String trackingCode;
  final String trackingToken;
  final String? invoiceNumber;
  final String customerName;
  final String customerPhone;
  final String? destinationAddress;
  final double? destinationLatitude;
  final double? destinationLongitude;
  final String? originAddress;
  final double? originLatitude;
  final double? originLongitude;
  final double? currentLatitude;
  final double? currentLongitude;
  final double? heading;
  final double? speed;
  final String status;
  final String statusLabel;
  final bool isActive;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? formattedDuration;
  final String? notes;
  final String? proofPhotoUrl;
  final String? driverSelfieUrl;
  final String? completionSelfieUrl;
  final List<String> productPhotoUrls;
  final String? trackingUrl;
  final String? driverName;
  final String? driverPhone;
  final String? driverAvatar;

  DeliveryModel({
    required this.id,
    required this.userId,
    this.branchId,
    this.destinationBranchId,
    this.destinationBranchName,
    this.deliveryType = 'customer',
    required this.trackingCode,
    required this.trackingToken,
    this.invoiceNumber,
    required this.customerName,
    required this.customerPhone,
    this.destinationAddress,
    this.destinationLatitude,
    this.destinationLongitude,
    this.originAddress,
    this.originLatitude,
    this.originLongitude,
    this.currentLatitude,
    this.currentLongitude,
    this.heading,
    this.speed,
    required this.status,
    required this.statusLabel,
    required this.isActive,
    this.startedAt,
    this.completedAt,
    this.formattedDuration,
    this.notes,
    this.proofPhotoUrl,
    this.driverSelfieUrl,
    this.completionSelfieUrl,
    this.productPhotoUrls = const [],
    this.trackingUrl,
    this.driverName,
    this.driverPhone,
    this.driverAvatar,
  });

  static double? _parseDouble(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toDouble();
    return double.tryParse('$val');
  }

  factory DeliveryModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      return DateTime.tryParse('$v');
    }

    final driver =
        json['driver'] is Map<String, dynamic> ? json['driver'] : null;
    final user = json['user'] is Map<String, dynamic> ? json['user'] : null;
    final destBranch = json['destination_branch'] is Map<String, dynamic>
        ? json['destination_branch']
        : null;

    final statusStr = json['status']?.toString() ??
        json['delivery_status']?.toString() ??
        'pending';

    List<String> parsePhotos(dynamic val) {
      if (val is List) {
        return val.map((e) => e.toString()).toList();
      }
      return [];
    }

    return DeliveryModel(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      userId: json['user_id'] is int
          ? json['user_id']
          : int.tryParse('${json['user_id']}') ?? 0,
      branchId: json['branch_id'] is int
          ? json['branch_id']
          : int.tryParse('${json['branch_id']}'),
      destinationBranchId: json['destination_branch_id'] is int
          ? json['destination_branch_id']
          : int.tryParse('${json['destination_branch_id']}'),
      destinationBranchName: destBranch?['name']?.toString() ??
          json['destination_branch_name']?.toString(),
      deliveryType: json['delivery_type']?.toString() ?? 'customer',
      trackingCode: json['tracking_code']?.toString() ?? '',
      trackingToken: json['tracking_token']?.toString() ?? '',
      invoiceNumber: json['invoice_number']?.toString(),
      customerName: json['customer_name']?.toString() ?? '',
      customerPhone: json['customer_phone']?.toString() ?? '',
      destinationAddress: json['destination_address']?.toString(),
      destinationLatitude: _parseDouble(json['destination_latitude']),
      destinationLongitude: _parseDouble(json['destination_longitude']),
      originAddress: json['origin_address']?.toString(),
      originLatitude: _parseDouble(json['origin_latitude']),
      originLongitude: _parseDouble(json['origin_longitude']),
      currentLatitude: _parseDouble(json['current_latitude']),
      currentLongitude: _parseDouble(json['current_longitude']),
      heading: _parseDouble(json['heading']),
      speed: _parseDouble(json['speed']),
      status: statusStr,
      statusLabel: json['status_label']?.toString() ?? statusStr,
      isActive: json['is_active'] == true ||
          json['is_active'] == 1 ||
          ['pending', 'in_transit', 'arrived'].contains(statusStr),
      startedAt: parseDate(json['started_at']),
      completedAt: parseDate(json['completed_at']),
      formattedDuration: json['formatted_duration']?.toString(),
      notes: json['notes']?.toString(),
      proofPhotoUrl: json['proof_photo_url']?.toString(),
      driverSelfieUrl: json['driver_selfie_url']?.toString(),
      completionSelfieUrl: json['completion_selfie_url']?.toString(),
      productPhotoUrls: parsePhotos(json['product_photo_urls']),
      trackingUrl: json['tracking_url']?.toString(),
      driverName: driver?['name']?.toString() ?? user?['name']?.toString(),
      driverPhone: driver?['phone']?.toString() ?? user?['phone']?.toString(),
      driverAvatar:
          driver?['avatar']?.toString() ?? user?['avatar']?.toString(),
    );
  }

  DeliveryModel copyWith({
    int? id,
    int? userId,
    int? branchId,
    int? destinationBranchId,
    String? destinationBranchName,
    String? deliveryType,
    String? trackingCode,
    String? trackingToken,
    String? invoiceNumber,
    String? customerName,
    String? customerPhone,
    String? destinationAddress,
    double? destinationLatitude,
    double? destinationLongitude,
    String? originAddress,
    double? originLatitude,
    double? originLongitude,
    double? currentLatitude,
    double? currentLongitude,
    double? heading,
    double? speed,
    String? status,
    String? statusLabel,
    bool? isActive,
    DateTime? startedAt,
    DateTime? completedAt,
    String? formattedDuration,
    String? notes,
    String? proofPhotoUrl,
    String? driverSelfieUrl,
    String? completionSelfieUrl,
    List<String>? productPhotoUrls,
    String? trackingUrl,
    String? driverName,
    String? driverPhone,
    String? driverAvatar,
  }) {
    return DeliveryModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      branchId: branchId ?? this.branchId,
      destinationBranchId: destinationBranchId ?? this.destinationBranchId,
      destinationBranchName:
          destinationBranchName ?? this.destinationBranchName,
      deliveryType: deliveryType ?? this.deliveryType,
      trackingCode: trackingCode ?? this.trackingCode,
      trackingToken: trackingToken ?? this.trackingToken,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      destinationAddress: destinationAddress ?? this.destinationAddress,
      destinationLatitude: destinationLatitude ?? this.destinationLatitude,
      destinationLongitude: destinationLongitude ?? this.destinationLongitude,
      originAddress: originAddress ?? this.originAddress,
      originLatitude: originLatitude ?? this.originLatitude,
      originLongitude: originLongitude ?? this.originLongitude,
      currentLatitude: currentLatitude ?? this.currentLatitude,
      currentLongitude: currentLongitude ?? this.currentLongitude,
      heading: heading ?? this.heading,
      speed: speed ?? this.speed,
      status: status ?? this.status,
      statusLabel: statusLabel ?? this.statusLabel,
      isActive: isActive ?? this.isActive,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      formattedDuration: formattedDuration ?? this.formattedDuration,
      notes: notes ?? this.notes,
      proofPhotoUrl: proofPhotoUrl ?? this.proofPhotoUrl,
      driverSelfieUrl: driverSelfieUrl ?? this.driverSelfieUrl,
      completionSelfieUrl: completionSelfieUrl ?? this.completionSelfieUrl,
      productPhotoUrls: productPhotoUrls ?? this.productPhotoUrls,
      trackingUrl: trackingUrl ?? this.trackingUrl,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      driverAvatar: driverAvatar ?? this.driverAvatar,
    );
  }
}
