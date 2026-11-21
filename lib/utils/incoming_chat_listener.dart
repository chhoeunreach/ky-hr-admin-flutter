import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/provider/chatbadgecontroller.dart';
import 'package:cnattendance/screen/profile/chatscreen.dart';
import 'package:cnattendance/security/app_integrity.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:cnattendance/utils/chat/chat_message_preview.dart';
import 'package:cnattendance/utils/chat/chat_sender_name.dart';
import 'package:cnattendance/utils/navigationservice.dart';
import 'package:get/get.dart';

class IncomingChatListener {
  IncomingChatListener._();

  static final IncomingChatListener instance = IncomingChatListener._();

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  String _activeUsername = '';
  bool _isPrimed = false;

  Future<void> start() async {
    if (await AppIntegrity.isTampered()) {
      return;
    }
    final preferences = Preferences();
    final username = (await preferences.getUsername()).trim();

    if (username.isEmpty) {
      return;
    }

    if (_subscription != null && _activeUsername == username) {
      return;
    }

    await _subscription?.cancel();
    _activeUsername = username;
    _isPrimed = false;

    _subscription = FirebaseFirestore.instance
        .collection('messages')
        .where('reciever', isEqualTo: username)
        .snapshots()
        .listen((snapshot) async {
      if (!_isPrimed) {
        _isPrimed = true;
        return;
      }

      for (final change in snapshot.docChanges) {
        if (change.type != DocumentChangeType.added) {
          continue;
        }

        final data = change.doc.data();
        if (data == null) {
          continue;
        }

        final sender = (data['sender'] ?? '').toString().trim();
        if (sender.isEmpty || sender == _activeUsername) {
          continue;
        }

        final conversationId = (data['id'] ?? '').toString().trim();
        final type = (data['type'] ?? '').toString().trim();
        final encodedMessage = (data['message'] ?? '').toString();
        final message =
            chatMessagePreview(type, _decodeMessage(encodedMessage));
        final senderName = await incomingChatSenderName(
          username: sender,
          savedName: data['sender_name'],
        );

        if (conversationId.isNotEmpty) {
          await ChatBadgeController.ensureRegistered().handleIncomingMessage(
            conversationId: conversationId,
            messageKey: 'firestore:${change.doc.id}',
            title: senderName,
          );
        }

        showToast(
          message.isEmpty ? senderName : '$senderName\n$message',
          onTap: () => _openChat(sender, senderName),
        );

        NavigationService().showSnackBar(
          senderName,
          message,
          onTap: () => _openChat(sender, senderName),
        );
      }
    });
  }

  String _decodeMessage(String value) {
    try {
      return utf8.decode(base64.decode(value));
    } catch (_) {
      return value;
    }
  }

  void _openChat(String senderUsername, String senderName) {
    Get.to(
      ChatScreen(),
      arguments: {
        'name': senderName,
        'avatar': '',
        'username': senderUsername,
      },
    );
  }
}
