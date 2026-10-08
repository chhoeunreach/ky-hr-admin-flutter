class User {
  User({
    required this.id,
    required this.name,
    required this.email,
    required this.username,
    required this.avatar,
    required this.onlineStatus,
    required this.department,
    required this.branch,
    required this.paymentQrCodes,
    required this.dob,
    required this.gender,
    required this.workspace_type,
  });

  factory User.fromJson(dynamic json) {
    final data = json is Map ? json : {};
    final paymentQrCodes = data['payment_qr_codes'];
    return User(
        id: data['id'] ?? 0,
        name: (data['name'] ?? "").toString(),
        email: (data['email'] ?? "").toString(),
        username: (data['username'] ?? "").toString(),
        avatar: (data['avatar'] ?? "").toString(),
        onlineStatus: data['online_status'] ?? false,
        department: data['department'] ?? "",
        branch: data['branch'] ?? "",
        paymentQrCodes: paymentQrCodes is List
            ? paymentQrCodes
                .map((item) => PaymentQrCode.fromJson(item))
                .where((item) => item.qrCodeUrl.isNotEmpty)
                .toList()
            : [],
        dob: data['dob'] ?? "",
        gender: data['gender'] ?? "",
        workspace_type: (data['workspace_type'] ?? "").toString());
  }

  int id;
  String name;
  String email;
  String username;
  String avatar;
  bool onlineStatus;
  String workspace_type;
  String department;
  String branch;
  List<PaymentQrCode> paymentQrCodes;
  String dob;
  String gender;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['id'] = id;
    map['name'] = name;
    map['email'] = email;
    map['username'] = username;
    map['avatar'] = avatar;
    map['online_status'] = onlineStatus;
    map['department'] = department;
    map['branch'] = branch;
    map['payment_qr_codes'] =
        paymentQrCodes.map((item) => item.toJson()).toList();
    map['dob'] = dob;
    map['gender'] = gender;
    map['workspace_type'] = workspace_type;
    return map;
  }
}

class PaymentQrCode {
  PaymentQrCode({
    required this.paymentName,
    required this.qrCodeUrl,
    required this.link,
  });

  factory PaymentQrCode.fromJson(dynamic json) {
    final data = json is Map ? json : {};
    return PaymentQrCode(
      paymentName: (data['payment_name'] ?? '').toString(),
      qrCodeUrl: (data['qr_code_url'] ?? data['qr_code'] ?? '').toString(),
      link: (data['payment_link'] ??
              data['payment_url'] ??
              data['link_url'] ??
              data['link'] ??
              data['url'] ??
              '')
          .toString(),
    );
  }

  final String paymentName;
  final String qrCodeUrl;
  final String link;

  Map<String, dynamic> toJson() {
    return {
      'payment_name': paymentName,
      'qr_code_url': qrCodeUrl,
      'payment_link': link,
    };
  }
}
