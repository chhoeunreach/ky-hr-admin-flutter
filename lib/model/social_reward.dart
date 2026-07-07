class SocialReward {
  SocialReward({
    required this.id,
    required this.existingEmployeeId,
    required this.logDate,
    required this.fbPostUrl,
    required this.fbStoryUrl,
    required this.tiktokUrl,
    required this.fbPostPhotoUrl,
    required this.fbStoryPhotoUrl,
    required this.tiktokPhotoUrl,
    required this.rewardPoints,
    required this.isLocked,
    required this.createdAt,
    required this.updatedAt,
    this.employeeName = '',
    this.employeeCode = '',
  });

  factory SocialReward.fromJson(Map<String, dynamic> json) {
    return SocialReward(
      id: _asInt(json['id']),
      existingEmployeeId: _asInt(json['existing_employee_id']),
      logDate: _asString(json['log_date']),
      fbPostUrl: _asString(json['fb_post_url']),
      fbStoryUrl: _asString(json['fb_story_url']),
      tiktokUrl: _asString(json['tiktok_url']),
      fbPostPhotoUrl: _asString(
        json['fb_post_photo_url'] ?? json['fb_post_photo'],
      ),
      fbStoryPhotoUrl: _asString(
        json['fb_story_photo_url'] ?? json['fb_story_photo'],
      ),
      tiktokPhotoUrl: _asString(
        json['tiktok_photo_url'] ?? json['tiktok_photo'],
      ),
      rewardPoints: _asInt(json['reward_points'], fallback: 1),
      isLocked: _asBool(json['is_locked'], fallback: true),
      createdAt: _asString(json['created_at']),
      updatedAt: _asString(json['updated_at']),
      employeeName: _asString(json['employee_name'] ?? json['name']),
      employeeCode: _asString(json['employee_code'] ?? json['code']),
    );
  }

  final int id;
  final int existingEmployeeId;
  final String logDate;
  final String fbPostUrl;
  final String fbStoryUrl;
  final String tiktokUrl;
  final String fbPostPhotoUrl;
  final String fbStoryPhotoUrl;
  final String tiktokPhotoUrl;
  final int rewardPoints;
  final bool isLocked;
  final String createdAt;
  final String updatedAt;
  final String employeeName;
  final String employeeCode;

  String get displayEmployee {
    if (employeeName.isNotEmpty && employeeCode.isNotEmpty) {
      return '$employeeName ($employeeCode)';
    }
    if (employeeName.isNotEmpty) {
      return employeeName;
    }
    return 'Employee #$existingEmployeeId';
  }

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static bool _asBool(dynamic value, {bool fallback = false}) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    final normalized = value?.toString().toLowerCase();
    if (normalized == 'true' || normalized == '1') {
      return true;
    }
    if (normalized == 'false' || normalized == '0') {
      return false;
    }
    return fallback;
  }

  static String _asString(dynamic value) => value?.toString() ?? '';
}

class SocialRewardListResponse {
  SocialRewardListResponse({
    required this.status,
    required this.message,
    required this.data,
  });

  factory SocialRewardListResponse.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final rows = rawData is Map<String, dynamic> ? rawData['data'] : rawData;
    final records = rows is List ? rows : const [];

    return SocialRewardListResponse(
      status: json['status'] ?? true,
      message: json['message']?.toString() ?? '',
      data: records
          .whereType<Map<String, dynamic>>()
          .map(SocialReward.fromJson)
          .toList(),
    );
  }

  final bool status;
  final String message;
  final List<SocialReward> data;
}
