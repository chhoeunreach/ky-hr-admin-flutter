class NotifiactionDomain {
  NotifiactionDomain({
    required this.id,
    required this.notificationTitle,
    required this.description,
    required this.notificationPublishedDate,
    required this.isRead,
  });

  factory NotifiactionDomain.fromJson(dynamic json) {
    return NotifiactionDomain(
      id: json['id'],
      notificationTitle: json['notification_title']?.toString() ?? "",
      description: json['description']?.toString() ?? "",
      notificationPublishedDate:
          json['notification_published_date']?.toString() ?? "",
      isRead: _parseIsRead(json['is_read']),
    );
  }

  int id;
  String notificationTitle;
  String description;
  String notificationPublishedDate;
  bool isRead;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['id'] = id;
    map['notification_title'] = notificationTitle;
    map['description'] = description;
    map['notification_published_date'] = notificationPublishedDate;
    map['is_read'] = isRead;
    return map;
  }

  static bool _parseIsRead(dynamic value) {
    if (value is bool) {
      return value;
    }

    final normalized = value?.toString().trim().toLowerCase();
    return normalized == '1' || normalized == 'true';
  }
}
