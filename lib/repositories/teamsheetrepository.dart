
import 'dart:convert';
import 'dart:developer';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/data/source/network/connect.dart';
import 'package:cnattendance/data/source/network/model/teamsheet/Teamsheetresponse.dart';
import 'package:cnattendance/model/chat_contact.dart';
import 'package:cnattendance/utils/constant.dart';

class ChatContactsPayload {
  final List<ChatContact> contacts;
  final List<ChatContact> onlineContacts;

  const ChatContactsPayload({
    required this.contacts,
    required this.onlineContacts,
  });
}

class TeamSheetRepository{
  Future<Teamsheetresponse> getTeam() async {
    Preferences preferences = Preferences();

    String token = await preferences.getToken();

    Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token'
    };

    try {
      final response = await Connect().getResponse(Constant.TEAM_SHEET_URL, headers);
      print(response.body);

      final responseData = json.decode(response.body);
      if (response.statusCode == 200) {
        log(responseData.toString());

        final responseJson = Teamsheetresponse.fromJson(responseData);
        return responseJson;
      } else {
        var errorMessage = responseData['message'];
        throw errorMessage;
      }
    } catch (error) {
      throw unknownError(error);
    }
  }

  Future<ChatContactsPayload> getChatContacts() async {
    Preferences preferences = Preferences();

    String token = await preferences.getToken();

    Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token'
    };

    try {
      final response =
          await Connect().getResponse(Constant.CHAT_CONTACTS, headers);

      final responseData = json.decode(response.body);
      if (response.statusCode == 200) {
        final data =
            responseData['data'] is Map<String, dynamic> ? responseData['data'] : {};
        final contactsJson = data['contacts'];
        final onlineContactsJson = data['online_contacts'];

        final contacts = contactsJson is List
            ? contactsJson
                .map<ChatContact>((item) => ChatContact.fromJson(item))
                .toList()
            : <ChatContact>[];
        final onlineContacts = onlineContactsJson is List
            ? onlineContactsJson
                .map<ChatContact>((item) => ChatContact.fromJson(item))
                .toList()
            : <ChatContact>[];

        return ChatContactsPayload(
          contacts: contacts,
          onlineContacts: onlineContacts,
        );
      } else {
        var errorMessage = responseData['message'];
        throw errorMessage;
      }
    } catch (error) {
      throw unknownError(error);
    }
  }
}
