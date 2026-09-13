import 'package:cnattendance/model/profile.dart' as user_profile;

class IdCardProfile {
  const IdCardProfile({
    required this.employeeCode,
    required this.name,
    required this.englishName,
    required this.positionKhmer,
    required this.positionEnglish,
    required this.position,
    required this.department,
    required this.branch,
    required this.phone,
    required this.email,
    required this.photoUrl,
    required this.branchLogoUrl,
    required this.companyWebsite,
    required this.websiteQrUrl,
    required this.telegramQrUrl,
  });

  final String employeeCode;
  final String name;
  final String englishName;
  final String positionKhmer;
  final String positionEnglish;
  final String position;
  final String department;
  final String branch;
  final String phone;
  final String email;
  final String photoUrl;
  final String branchLogoUrl;
  final String companyWebsite;
  final String websiteQrUrl;
  final String telegramQrUrl;

  String get companyWebsiteDisplay {
    final website = companyWebsite.trim().isEmpty
        ? 'www.kneayerng.com'
        : companyWebsite.trim();
    return website
        .replaceFirst(RegExp(r'^https?://', caseSensitive: false), '')
        .replaceFirst(RegExp(r'/$'), '');
  }

  String get websiteQrData {
    return _firstString([
      _qrDataFromUrl(websiteQrUrl),
      _normalizeUrl(companyWebsiteDisplay),
    ]);
  }

  String get telegramQrData {
    return _qrDataFromUrl(telegramQrUrl) ?? 'https://t.me/kneayerng';
  }

  factory IdCardProfile.fromJson(Map<String, dynamic> json) {
    final positionKhmer = _string(json['position_khmer']);
    final positionEnglish = _string(json['position_english']);
    final websiteQrData = _string(json['website_qr_data']);
    final telegramQrData = _string(json['telegram_qr_data']);

    return IdCardProfile(
      employeeCode: _string(json['employee_code']),
      name: _firstString([
        json['name'],
        json['name_khmer'],
        json['khmer_name'],
        json['nameKhmer'],
      ]),
      englishName: _firstString([
        json['english_name'],
        json['name_english'],
        json['englishName'],
        json['nameEnglish'],
        json['latin_name'],
      ]),
      positionKhmer: positionKhmer,
      positionEnglish: positionEnglish,
      position: _firstString([
        positionKhmer,
        positionEnglish,
        json['post'],
      ]),
      department: _firstString([
        json['department'],
        json['department_name'],
        json['departmentName'],
        _mapString(json['department'], 'dept_name'),
        _mapString(json['department'], 'name'),
      ]),
      branch: _firstString([
        json['branch_name'],
        json['branchName'],
        _mapString(json['branch'], 'name'),
        json['branch'],
      ]),
      phone: _firstString([
        json['phone'],
        json['phone_number'],
        json['phoneNumber'],
        json['mobile'],
      ]),
      email: _string(json['email']),
      photoUrl: _firstString([
        json['profile_photo_url'],
        json['profilePhotoUrl'],
        json['photo_url'],
        json['photoUrl'],
        json['avatar'],
      ]),
      branchLogoUrl: _firstString([
        json['branch_logo_url'],
        json['branchLogoUrl'],
        json['branch_logo'],
        json['logo_url'],
        _mapString(json['branch'], 'logo_url'),
        _mapString(json['branch'], 'logo'),
        json['company_logo_url'],
        json['company_logo'],
      ]),
      companyWebsite: _string(json['company_website']),
      websiteQrUrl: _firstString([
        websiteQrData,
        json['website_qr_url'],
        _qrUrl('https://www.kneayerng.com'),
      ]),
      telegramQrUrl: _firstString([
        telegramQrData,
        json['telegram_qr_url'],
        _qrUrl('https://t.me/kneayerng'),
      ]),
    );
  }

  factory IdCardProfile.fromProfile(user_profile.Profile profile) {
    final employeeCode = profile.username.trim().isNotEmpty
        ? profile.username.trim().toUpperCase()
        : 'KY-${profile.id.toString().padLeft(5, '0')}';

    return IdCardProfile(
      employeeCode: employeeCode,
      name: profile.name,
      englishName: '',
      positionKhmer: profile.post,
      positionEnglish: profile.post,
      position: profile.post,
      department: profile.department,
      branch: profile.branch,
      phone: profile.phone,
      email: profile.email,
      photoUrl: profile.avatar,
      branchLogoUrl: '',
      companyWebsite: 'www.kneayerng.com',
      websiteQrUrl: _qrUrl('https://www.kneayerng.com'),
      telegramQrUrl: _qrUrl('https://t.me/kneayerng'),
    );
  }

  static String _string(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  static String _firstString(List<dynamic> values) {
    for (final value in values) {
      final text = _string(value).trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static String _mapString(dynamic value, String key) {
    if (value is Map) {
      return _string(value[key]);
    }
    return '';
  }

  static String _qrUrl(String data) {
    return Uri.https(
      'api.qrserver.com',
      '/v1/create-qr-code/',
      {'size': '180x180', 'data': data},
    ).toString();
  }

  static String _normalizeUrl(String value) {
    final text = value.trim();
    if (text.isEmpty) return 'https://www.kneayerng.com';
    if (text.startsWith(RegExp(r'https?://', caseSensitive: false))) {
      return text;
    }
    return 'https://$text';
  }

  static String? _qrDataFromUrl(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;

    final uri = Uri.tryParse(text);
    final data = uri?.queryParameters['data'];
    if (data != null && data.trim().isNotEmpty) {
      return data.trim();
    }

    return text;
  }
}
