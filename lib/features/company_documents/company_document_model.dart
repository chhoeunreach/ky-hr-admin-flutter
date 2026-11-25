class CompanyDocumentAttachment {
  final int id;
  final String fileUrl;
  final String? fileName;
  final String? fileType;
  final int fileSize;
  final bool isPdf;
  final bool isImage;

  CompanyDocumentAttachment({
    required this.id,
    required this.fileUrl,
    this.fileName,
    this.fileType,
    required this.fileSize,
    required this.isPdf,
    required this.isImage,
  });

  factory CompanyDocumentAttachment.fromJson(Map<String, dynamic> json) {
    return CompanyDocumentAttachment(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      fileUrl: json['file_url']?.toString() ?? '',
      fileName: json['file_name']?.toString(),
      fileType: json['file_type']?.toString(),
      fileSize: json['file_size'] is int ? json['file_size'] : int.tryParse('${json['file_size']}') ?? 0,
      isPdf: json['is_pdf'] == true || json['is_pdf'] == 1,
      isImage: json['is_image'] == true || json['is_image'] == 1,
    );
  }
}

class CompanyDocumentItem {
  final int id;
  final String categoryCode;
  final String categoryName;
  final String categoryIcon;
  final String categoryColor;
  final String? docSubType;
  final int? branchId;
  final String branchName;
  final String? docNumber;
  final String title;
  final String? holderName;
  final String? issuingAuthority;
  final String? issueDate;
  final String? expiryDate;
  final int alertBeforeDays;
  final String status;
  final String calculatedStatus; // valid, expiring_soon, expired, archived
  final int? daysRemaining;
  final double? costAmount;
  final String currency;
  final String? formattedCost;
  final String? receiptNumber;
  final String fileUrl;
  final String? fileName;
  final String? fileType;
  final int fileSize;
  final bool isPdf;
  final bool isImage;
  final List<CompanyDocumentAttachment> attachments;
  final String confidentialityLevel;
  final String? description;
  final String? createdAt;
  final String? createdBy;

  CompanyDocumentItem({
    required this.id,
    required this.categoryCode,
    required this.categoryName,
    required this.categoryIcon,
    required this.categoryColor,
    this.docSubType,
    this.branchId,
    required this.branchName,
    this.docNumber,
    required this.title,
    this.holderName,
    this.issuingAuthority,
    this.issueDate,
    this.expiryDate,
    required this.alertBeforeDays,
    required this.status,
    required this.calculatedStatus,
    this.daysRemaining,
    this.costAmount,
    required this.currency,
    this.formattedCost,
    this.receiptNumber,
    required this.fileUrl,
    this.fileName,
    this.fileType,
    required this.fileSize,
    required this.isPdf,
    required this.isImage,
    required this.attachments,
    required this.confidentialityLevel,
    this.description,
    this.createdAt,
    this.createdBy,
  });

  factory CompanyDocumentItem.fromJson(Map<String, dynamic> json) {
    final rawAttachments = json['attachments'] as List? ?? [];
    List<CompanyDocumentAttachment> parsedAttachments = rawAttachments
        .map((item) => CompanyDocumentAttachment.fromJson(item as Map<String, dynamic>))
        .toList();

    final mainFileUrl = json['file_url']?.toString() ?? '';
    if (parsedAttachments.isEmpty && mainFileUrl.isNotEmpty) {
      parsedAttachments = [
        CompanyDocumentAttachment(
          id: 0,
          fileUrl: mainFileUrl,
          fileName: json['file_name']?.toString(),
          fileType: json['file_type']?.toString(),
          fileSize: json['file_size'] is int ? json['file_size'] : int.tryParse('${json['file_size']}') ?? 0,
          isPdf: json['is_pdf'] == true || json['is_pdf'] == 1,
          isImage: json['is_image'] == true || json['is_image'] == 1,
        )
      ];
    }

    return CompanyDocumentItem(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      categoryCode: json['category_code']?.toString() ?? 'other',
      categoryName: json['category_name']?.toString() ?? 'Document',
      categoryIcon: json['category_icon']?.toString() ?? 'file-text',
      categoryColor: json['category_color']?.toString() ?? '#0f766e',
      docSubType: json['doc_sub_type']?.toString(),
      branchId: json['branch_id'] is int ? json['branch_id'] : int.tryParse('${json['branch_id']}'),
      branchName: json['branch_name']?.toString() ?? 'All Branches',
      docNumber: json['doc_number']?.toString(),
      title: json['title']?.toString() ?? 'Untitled Document',
      holderName: json['holder_name']?.toString(),
      issuingAuthority: json['issuing_authority']?.toString(),
      issueDate: json['issue_date']?.toString(),
      expiryDate: json['expiry_date']?.toString(),
      alertBeforeDays: json['alert_before_days'] is int ? json['alert_before_days'] : int.tryParse('${json['alert_before_days']}') ?? 30,
      status: json['status']?.toString() ?? 'valid',
      calculatedStatus: json['calculated_status']?.toString() ?? 'valid',
      daysRemaining: json['days_remaining'] is int ? json['days_remaining'] : int.tryParse('${json['days_remaining']}'),
      costAmount: json['cost_amount'] != null ? double.tryParse('${json['cost_amount']}') : null,
      currency: json['currency']?.toString() ?? 'USD',
      formattedCost: json['formatted_cost']?.toString(),
      receiptNumber: json['receipt_number']?.toString(),
      fileUrl: mainFileUrl,
      fileName: json['file_name']?.toString(),
      fileType: json['file_type']?.toString(),
      fileSize: json['file_size'] is int ? json['file_size'] : int.tryParse('${json['file_size']}') ?? 0,
      isPdf: json['is_pdf'] == true || json['is_pdf'] == 1,
      isImage: json['is_image'] == true || json['is_image'] == 1,
      attachments: parsedAttachments,
      confidentialityLevel: json['confidentiality_level']?.toString() ?? 'internal',
      description: json['description']?.toString(),
      createdAt: json['created_at']?.toString(),
      createdBy: json['created_by']?.toString(),
    );
  }
}

class CompanyDocumentSummary {
  final int totalCount;
  final int masterCount;
  final int taxCount;
  final int businessCount;
  final int nssfCount;
  final int contractCount;
  final int utilityCount;
  final int expiredCount;
  final int expiringSoonCount;
  final double totalCostUsd;
  final double totalCostKhr;

  CompanyDocumentSummary({
    required this.totalCount,
    required this.masterCount,
    required this.taxCount,
    required this.businessCount,
    required this.nssfCount,
    required this.contractCount,
    required this.utilityCount,
    required this.expiredCount,
    required this.expiringSoonCount,
    required this.totalCostUsd,
    required this.totalCostKhr,
  });

  factory CompanyDocumentSummary.fromJson(Map<String, dynamic> json) {
    return CompanyDocumentSummary(
      totalCount: int.tryParse('${json['total_count']}') ?? 0,
      masterCount: int.tryParse('${json['master_count']}') ?? 0,
      taxCount: int.tryParse('${json['tax_count']}') ?? 0,
      businessCount: int.tryParse('${json['business_count']}') ?? 0,
      nssfCount: int.tryParse('${json['nssf_count']}') ?? 0,
      contractCount: int.tryParse('${json['contract_count']}') ?? 0,
      utilityCount: int.tryParse('${json['utility_count']}') ?? 0,
      expiredCount: int.tryParse('${json['expired_count']}') ?? 0,
      expiringSoonCount: int.tryParse('${json['expiring_soon_count']}') ?? 0,
      totalCostUsd: double.tryParse('${json['total_cost_usd']}') ?? 0.0,
      totalCostKhr: double.tryParse('${json['total_cost_khr']}') ?? 0.0,
    );
  }

  factory CompanyDocumentSummary.empty() {
    return CompanyDocumentSummary(
      totalCount: 0,
      masterCount: 0,
      taxCount: 0,
      businessCount: 0,
      nssfCount: 0,
      contractCount: 0,
      utilityCount: 0,
      expiredCount: 0,
      expiringSoonCount: 0,
      totalCostUsd: 0.0,
      totalCostKhr: 0.0,
    );
  }
}

class CompanyDocumentCategoryItem {
  final String code;
  final String nameKm;
  final String nameEn;
  final String name;
  final String icon;
  final String color;
  final int order;

  CompanyDocumentCategoryItem({
    required this.code,
    required this.nameKm,
    required this.nameEn,
    required this.name,
    required this.icon,
    required this.color,
    required this.order,
  });

  factory CompanyDocumentCategoryItem.fromJson(Map<String, dynamic> json) {
    return CompanyDocumentCategoryItem(
      code: json['code']?.toString() ?? '',
      nameKm: json['name_km']?.toString() ?? '',
      nameEn: json['name_en']?.toString() ?? '',
      name: json['name']?.toString() ?? json['name_en']?.toString() ?? '',
      icon: json['icon']?.toString() ?? 'folder',
      color: json['color']?.toString() ?? '#0f766e',
      order: int.tryParse('${json['order']}') ?? 0,
    );
  }
}

class CompanyDocumentBranchItem {
  final int id;
  final String name;

  CompanyDocumentBranchItem({required this.id, required this.name});

  factory CompanyDocumentBranchItem.fromJson(Map<String, dynamic> json) {
    return CompanyDocumentBranchItem(
      id: int.tryParse('${json['id']}') ?? 0,
      name: json['name']?.toString() ?? '',
    );
  }
}

class CompanyDocumentSubTypeItem {
  final String code;
  final String name;

  CompanyDocumentSubTypeItem({required this.code, required this.name});

  factory CompanyDocumentSubTypeItem.fromJson(Map<String, dynamic> json) {
    return CompanyDocumentSubTypeItem(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }
}
