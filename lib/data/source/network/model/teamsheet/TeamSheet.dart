import 'Employee.dart';
import 'package:cnattendance/model/chat_contact.dart';

class TeamSheet {
  TeamSheet({
    required this.id,
    required this.name,
    required this.employee,
    required this.chatContacts,
  });

  factory TeamSheet.fromJson(dynamic json) {
    final map = json is Map<String, dynamic> ? json : <String, dynamic>{};
    final contactsJson = _contactListJson(map);
    return TeamSheet(
        id: _intValue(map['id']),
        name: (map['name'] ?? '').toString(),
        employee:
            List<Employee>.from(contactsJson.map((x) => Employee.fromJson(x))),
        chatContacts: List<ChatContact>.from(
            contactsJson.map((x) => ChatContact.fromJson(x))));
  }

  int id;
  String name;
  List<Employee> employee;
  List<ChatContact> chatContacts;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['id'] = id;
    map['name'] = name;
    map['employee'] = employee.map((v) => v.toJson()).toList();
    return map;
  }

  static List<dynamic> _contactListJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      return [];
    }

    final contacts = json['contacts'] ??
        json['directory'] ??
        json['employees'] ??
        json['employee'];

    return contacts is List ? contacts : [];
  }

  static int _intValue(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse((value ?? '').toString()) ?? 0;
  }
}
