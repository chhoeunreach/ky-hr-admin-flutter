import 'dart:convert';
import 'dart:io';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/model/group_chat.dart';
import 'package:cnattendance/model/group_chat_detail.dart';
import 'package:cnattendance/model/group_chat_member.dart';
import 'package:cnattendance/model/group_chat_message.dart';
import 'package:cnattendance/provider/chatbadgecontroller.dart';
import 'package:cnattendance/repositories/group_chat_repository.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:cnattendance/services/chat_media_upload_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

class GroupChatController extends GetxController {
  final GroupChatRepository _repository = GroupChatRepository();

  final chatController = TextEditingController();
  final scrollController = ScrollController();

  var isLoading = false.obs;
  var isSending = false.obs;
  var groups = <GroupChat>[].obs;
  var chatMessages = <GroupChatMessage>[].obs;
  var currentGroup = Rx<GroupChatDetail?>(null);

  var currentGroupId = 0.obs;
  var currentGroupName = "".obs;

  String sender = "";
  Preferences pref = Preferences();

  @override
  Future<void> onReady() async {
    sender = await pref.getUsername();
    super.onReady();
  }

  Future<void> loadGroups() async {
    try {
      isLoading.value = true;
      final result = await _repository.getGroups();
      groups.value = result;
    } catch (e) {
      showToast(e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadGroupDetail(int groupId) async {
    try {
      isLoading.value = true;
      currentGroupId.value = groupId;
      final detail = await _repository.getGroupDetail(groupId);
      currentGroup.value = detail;
      currentGroupName.value = detail.name;
    } catch (e) {
      showToast(e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadMessages(int groupId) async {
    try {
      isLoading.value = true;
      currentGroupId.value = groupId;
      final messages = await _repository.getMessages(groupId);
      chatMessages.value = messages;
      await ChatBadgeController.ensureRegistered()
          .setActiveConversation('group_$groupId');
      _scrollToBottom();
    } catch (e) {
      showToast(e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> sendTextMessage(int groupId, String text) async {
    if (text.trim().isEmpty) return;
    try {
      isSending.value = true;
      final message = await _repository.sendMessage(groupId, text);
      chatMessages.add(message);
      chatController.clear();
      _scrollToBottom();
    } catch (e) {
      showToast(e.toString());
    } finally {
      isSending.value = false;
    }
  }

  Future<void> sendImageMessage(int groupId, String filePath) async {
    try {
      isSending.value = true;
      final upload = await _repository.uploadMedia(filePath, 'image');
      final message = await _repository.sendMediaMessage(
        groupId,
        type: 'image',
        mediaUrl: upload['url'] ?? '',
        mediaPath: upload['path'],
        mediaWidth: upload['width'] as int?,
        mediaHeight: upload['height'] as int?,
      );
      chatMessages.add(message);
      _scrollToBottom();
    } catch (e) {
      showToast(e.toString());
    } finally {
      isSending.value = false;
    }
  }

  Future<void> sendVoiceMessage(int groupId, String filePath,
      {int? durationSeconds}) async {
    try {
      isSending.value = true;
      final upload = await _repository.uploadMedia(filePath, 'voice');
      final message = await _repository.sendMediaMessage(
        groupId,
        type: 'voice',
        mediaUrl: upload['url'] ?? '',
        mediaPath: upload['path'],
        durationSeconds: durationSeconds,
      );
      chatMessages.add(message);
      _scrollToBottom();
    } catch (e) {
      showToast(e.toString());
    } finally {
      isSending.value = false;
    }
  }

  Future<void> sendFileMessage(int groupId, String filePath,
      {String? fileName}) async {
    try {
      isSending.value = true;
      final upload = await _repository.uploadMedia(filePath, 'file');
      final message = await _repository.sendMediaMessage(
        groupId,
        type: 'file',
        mediaUrl: upload['url'] ?? '',
        mediaPath: upload['path'],
        fileName: fileName,
      );
      chatMessages.add(message);
      _scrollToBottom();
    } catch (e) {
      showToast(e.toString());
    } finally {
      isSending.value = false;
    }
  }

  Future<void> sendLocationMessage(
      int groupId, double latitude, double longitude) async {
    try {
      isSending.value = true;
      final message = await _repository.sendLocation(
        groupId,
        latitude: latitude,
        longitude: longitude,
      );
      chatMessages.add(message);
      _scrollToBottom();
    } catch (e) {
      showToast(e.toString());
    } finally {
      isSending.value = false;
    }
  }

  Future<void> addMembers(int groupId, List<int> userIds) async {
    try {
      await _repository.addMembers(groupId, userIds);
      await loadGroupDetail(groupId);
      showToast('Members added successfully');
    } catch (e) {
      showToast(e.toString());
    }
  }

  Future<void> removeMember(int groupId, int userId) async {
    try {
      await _repository.removeMember(groupId, userId);
      await loadGroupDetail(groupId);
      showToast('Member removed');
    } catch (e) {
      showToast(e.toString());
    }
  }

  Future<void> promoteToAdmin(int groupId, int userId) async {
    try {
      await _repository.updateMemberRole(groupId, userId, 'admin');
      await loadGroupDetail(groupId);
      showToast('Member promoted to admin');
    } catch (e) {
      showToast(e.toString());
    }
  }

  Future<void> demoteToMember(int groupId, int userId) async {
    try {
      await _repository.updateMemberRole(groupId, userId, 'member');
      await loadGroupDetail(groupId);
      showToast('Member demoted to member');
    } catch (e) {
      showToast(e.toString());
    }
  }

  Future<void> leaveGroup(int groupId) async {
    try {
      await _repository.leaveGroup(groupId);
      groups.removeWhere((g) => g.id == groupId);
      Get.back();
      showToast('You left the group');
    } catch (e) {
      showToast(e.toString());
    }
  }

  Future<void> deleteGroup(int groupId) async {
    try {
      await _repository.deleteGroup(groupId);
      groups.removeWhere((g) => g.id == groupId);
      Get.back();
      showToast('Group deleted');
    } catch (e) {
      showToast(e.toString());
    }
  }

  String? get chatMessagePreview {
    if (chatMessages.isEmpty) return null;
    final last = chatMessages.last;
    switch (last.messageType) {
      case 'image':
        return 'Sent a photo';
      case 'voice':
        return 'Sent a voice message';
      case 'file':
        return 'Sent a file';
      case 'location':
        return 'Sent a location';
      default:
        return last.message;
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300)).then((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void onClose() {
    ChatBadgeController.ensureRegistered()
        .clearActiveConversation('group_${currentGroupId.value}');
    chatController.dispose();
    scrollController.dispose();
    super.onClose();
  }
}
