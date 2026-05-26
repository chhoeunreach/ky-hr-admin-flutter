import 'NotifiactionDomain.dart';

class NotificationResponse {
  NotificationResponse({
    required this.data,
    required this.status,
    required this.statusCode,
    this.unreadCount,
  });

  factory NotificationResponse.fromJson(dynamic json) {
    return NotificationResponse(
        status: json['status'],
        statusCode: json['status_code'],
        unreadCount: _parseUnreadCount(json['unread_count']),
        data: List<NotifiactionDomain>.from(
            json['data'].map((x) => NotifiactionDomain.fromJson(x))));
  }

  List<NotifiactionDomain> data;
  bool status;
  int statusCode;
  int? unreadCount;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['data'] = data.map((v) => v.toJson()).toList();
    map['status'] = status;
    map['status_code'] = statusCode;
    map['unread_count'] = unreadCount;
    return map;
  }

  static int? _parseUnreadCount(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    return int.tryParse(value.toString());
  }
}
