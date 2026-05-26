import 'package:cnattendance/data/source/network/model/teamsheet/Branch.dart';
import 'package:cnattendance/data/source/network/model/teamsheet/TeamSheet.dart';
import 'package:cnattendance/model/chat_contact.dart';

class Data {
  Data({
    required this.companyDetail,
    required this.branch,
    required this.chatContacts,
  });

  factory Data.fromJson(dynamic json) {
    final map = json is Map<String, dynamic> ? json : <String, dynamic>{};
    final branches = map['branches'];
    final contactsJson = _contactListJson(map);
    return Data(
        companyDetail: TeamSheet.fromJson(map['companyDetail']),
        branch: branches is List
            ? List<Branch>.from(branches.map((x) => Branch.fromJson(x)))
            : [],
        chatContacts: List<ChatContact>.from(
            contactsJson.map((x) => ChatContact.fromJson(x))));
  }

  TeamSheet companyDetail;
  List<Branch> branch;
  List<ChatContact> chatContacts;

  static List<dynamic> _contactListJson(Map<String, dynamic> json) {
    final contacts = json['contacts'] ??
        json['directory'] ??
        json['employees'] ??
        json['employee'];

    return contacts is List ? contacts : [];
  }
}
