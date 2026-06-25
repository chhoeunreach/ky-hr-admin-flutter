import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/model/chat.dart';
import 'package:cnattendance/model/member.dart';
import 'package:cnattendance/provider/chatbadgecontroller.dart';
import 'package:http/http.dart' as http;
import 'package:cnattendance/utils/constant.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:http_interceptor_plus/http_interceptor_plus.dart';
import 'package:uuid/uuid.dart';

class OldGroupChatController extends GetxController {
  var host = "".obs;
  var convoId = "";
  final chatController = TextEditingController();
  final scrollController = ScrollController();
  var projectId = 0;

  var chatList = <Chat>[].obs;
  var sender = "";

  List<Member> leaders = [];
  List<Member> members = [];

  Preferences pref = Preferences();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _chatSubscription;

  @override
  Future<void> onReady() async {
    host.value = Get.arguments["projectName"];
    convoId = Get.arguments["projectSlug"];
    leaders = Get.arguments["leader"] ?? [];
    members = Get.arguments["member"] ?? [];
    projectId = Get.arguments["projectId"] ?? 0;

    sender = await pref.getUsername();
    listenChat();
    await ChatBadgeController.ensureRegistered().setActiveConversation(convoId);
    super.onReady();
  }

  Future<void> sendMessage(String message) async {
    try {
      await FirebaseFirestore.instance
          .collection('messages')
          .doc(Uuid().v4())
          .set({
        "id": convoId,
        "date": DateTime.now(),
        "message": base64.encode(utf8.encode(message)),
        "sender": sender,
        "reciever": convoId
      });

      final currentUser = await pref.getUser();
      var users = <int>[];
      for (var member in members) {
        if (member.id != currentUser.id) {
          users.add(member.id);
        }
      }

      await sendPushNotifiation("New message recieved in ${host.value}",
          message, convoId, "group_chat", projectId.toString(), users);

      chatController.clear();
    } catch (e) {
      showToast(e.toString());
    }
  }

  Future<void> listenChat() async {
    final docRef = FirebaseFirestore.instance
        .collection("messages")
        .where("id", isEqualTo: convoId)
        .snapshots();

    await _chatSubscription?.cancel();
    _chatSubscription = docRef.listen(
      (event) {
        final chatDb = <Chat>[];
        for (var item in event.docs) {
          Timestamp firebaseTimestamp = item["date"];
          chatDb.add(Chat(
              item["id"],
              utf8.decode(base64.decode(item["message"])),
              item["sender"],
              item["reciever"],
              firebaseTimestamp.toDate()));
        }

        chatDb.sort((a, b) => a.dateTime.compareTo(b.dateTime));
        chatList.value = chatDb;

        Future.delayed(Duration(milliseconds: 500)).then((_) {
          if (!scrollController.hasClients) {
            return;
          }
          scrollController.animateTo(
            scrollController.position.maxScrollExtent,
            duration: Duration(milliseconds: 1000),
            curve: Curves.fastOutSlowIn,
          );
        });
      },
      onError: (error) => print("Listen failed: $error"),
    );
  }

  Future<void> sendPushNotifiation(
      String title,
      String message,
      String converstion_id,
      String type,
      String project_id,
      List<int> usernames) async {
    Preferences preferences = Preferences();
    var uri = Uri.parse(
        await preferences.getAppUrl() + Constant.SEND_PUSH_NOTIFICATION);

    String token = await preferences.getToken();

    Map<String, String> headers = {
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token'
    };

    final http.Client client = LoggingMiddleware(http.Client());

    final response = await client.post(uri, headers: headers, body: {
      "title": title,
      "message": message,
      "conversation_id": converstion_id,
      "type": type,
      "project_id": project_id,
      "usernames": jsonEncode(usernames),
    });

    final responseData = json.decode(response.body);
    final responseMessage = responseData['message']?.toString() ?? "";

    if (response.statusCode == 200) {
    } else if (_isMissingRegistrationTokenError(responseMessage)) {
      print("Push skipped: $responseMessage");
    } else {
      var errorMessage = responseData['message'];
      throw errorMessage;
    }
  }

  bool _isMissingRegistrationTokenError(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains("no registration tokens provided");
  }

  @override
  void onClose() {
    ChatBadgeController.ensureRegistered().clearActiveConversation(convoId);
    _chatSubscription?.cancel();
    chatController.dispose();
    scrollController.dispose();
    super.onClose();
  }
}
