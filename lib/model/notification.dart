class Notification {
  int id;
  String title;
  String description;
  String month;
  String day;
  DateTime date;
  String? localKey;
  bool isRead;
  String type;
  int notificationForId;
  final Map<String, String> appUpdate;

  Notification(
      {required this.id,
      required this.title,
      required this.description,
      required this.month,
      required this.day,
      required this.date,
      this.localKey,
      this.isRead = true,
      this.type = '',
      this.notificationForId = 0,
      this.appUpdate = const {}});
}
