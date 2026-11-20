import 'package:cnattendance/utils/app_update_payload.dart';

class NotifiactionDomain {
  NotifiactionDomain({
    required this.id,
    required this.notificationTitle,
    required this.description,
    required this.notificationPublishedDate,
    required this.isRead,
    required this.type,
    required this.notificationForId,
    this.appUpdate = const {},
  });

  factory NotifiactionDomain.fromJson(dynamic json) {
    final htmlDescription = json['description_html']?.toString();
    final plainDescription = json['description']?.toString();
    final type = json['type']?.toString() ?? '';
    final update = json['app_update'];

    return NotifiactionDomain(
      id: json['id'],
      notificationTitle: json['notification_title']?.toString() ?? "",
      description: type == 'app_update' || type == 'version_update'
          ? (plainDescription ?? '')
          : (htmlDescription != null && htmlDescription.isNotEmpty)
              ? htmlDescription
              : (plainDescription ?? ""),
      notificationPublishedDate:
          json['notification_published_date']?.toString() ?? "",
      isRead: _parseIsRead(json['is_read']),
      type: type,
      appUpdate: update is Map ? appUpdateMetadata(update) : const {},
      notificationForId: _parseInt(json['notification_for_id']),
    );
  }

  int id;
  String notificationTitle;
  String description;
  String notificationPublishedDate;
  bool isRead;
  String type;
  int notificationForId;
  final Map<String, String> appUpdate;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['id'] = id;
    map['notification_title'] = notificationTitle;
    map['description'] = description;
    map['notification_published_date'] = notificationPublishedDate;
    map['is_read'] = isRead;
    map['type'] = type;
    map['notification_for_id'] = notificationForId;
    if (appUpdate.isNotEmpty) map['app_update'] = appUpdate;
    return map;
  }

  static bool _parseIsRead(dynamic value) {
    if (value is bool) {
      return value;
    }

    final normalized = value?.toString().trim().toLowerCase();
    return normalized == '1' || normalized == 'true';
  }

  static int _parseInt(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
