import 'dart:async';
import 'dart:io';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/model/admin_chat_message.dart';
import 'package:cnattendance/provider/chatbadgecontroller.dart';
import 'package:cnattendance/repositories/admin_chat_repository.dart';
import 'package:cnattendance/services/chat_media_upload_service.dart';
import 'package:cnattendance/services/voice_recorder_service.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

class AdminChatController extends GetxController {
  final AdminChatRepository _repository;
  final ChatMediaUploadService _mediaUploadService;
  final VoiceRecorderService _voiceRecorderService;
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController chatController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  Timer? _recordingTimer;
  VoiceRecordingResult? _pendingVoiceRecording;

  final adminName = ''.obs;
  final adminAvatar = ''.obs;
  final conversationId = ''.obs;
  final adminId = ''.obs;
  final adminUsername = ''.obs;
  final internalConversationId = ''.obs;
  final messages = <AdminChatMessage>[].obs;
  final isLoading = false.obs;
  final isSending = false.obs;
  final isRecording = false.obs;
  final recordingSeconds = 0.obs;
  final hasPendingVoiceRecording = false.obs;

  AdminChatController({
    AdminChatRepository? repository,
    ChatMediaUploadService? mediaUploadService,
    VoiceRecorderService? voiceRecorderService,
  })  : _repository = repository ?? AdminChatRepository(),
        _mediaUploadService = mediaUploadService ?? ChatMediaUploadService(),
        _voiceRecorderService = voiceRecorderService ?? VoiceRecorderService();

  @override
  Future<void> onReady() async {
    final arguments = Get.arguments is Map ? Get.arguments as Map : {};
    adminName.value = arguments['name']?.toString() ?? 'Admin';
    adminAvatar.value = arguments['avatar']?.toString() ?? '';
    final incomingConversationId =
        arguments['conversationId']?.toString() ?? '';
    conversationId.value = incomingConversationId;
    adminId.value = arguments['adminId']?.toString() ?? '';
    adminUsername.value = arguments['adminUsername']?.toString() ??
        arguments['username']?.toString() ??
        '';
    internalConversationId.value =
        arguments['internalConversationId']?.toString() ?? '';
    if (internalConversationId.value.trim().isEmpty &&
        incomingConversationId.trim().isNotEmpty &&
        !incomingConversationId.trim().startsWith('employee_admin_')) {
      internalConversationId.value = incomingConversationId.trim();
    }
    await _normalizeConversationId();
    debugPrint(
      '[ADMIN_CHAT] open thread'
      ' | name=${adminName.value}'
      ' | conversation_id=${conversationId.value}'
      ' | admin_id=${adminId.value}'
      ' | admin_username=${adminUsername.value}'
      ' | internal_conversation_id=${internalConversationId.value}',
    );
    await ChatBadgeController.ensureRegistered()
        .setActiveConversation(_chatKey);
    await _clearLegacyUnreadKeys();
    await loadMessages();
    super.onReady();
  }

  Future<void> loadMessages() async {
    try {
      isLoading.value = true;
      final loadedMessages = await _repository.getMessages(
        conversationId: _chatKey,
        adminId: adminId.value,
        adminUsername: adminUsername.value,
        internalConversationId: internalConversationId.value,
      );
      _replaceMessages(loadedMessages);
    } catch (error) {
      debugPrint('[ADMIN_CHAT] load failed: $error');
      _replaceMessages([]);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> sendMessage(String message) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final localMessage = await _localMessage(
      message: trimmed,
      type: 'text',
    );
    try {
      isSending.value = true;
      chatController.clear();
      _appendLocalMessage(localMessage);
      final loadedMessages = await _repository.sendMessage(
        trimmed,
        conversationId: _chatKey,
        adminId: adminId.value,
        adminUsername: adminUsername.value,
        internalConversationId: internalConversationId.value,
      );
      await _replaceAfterSend(loadedMessages);
    } catch (error) {
      _removeLocalMessage(localMessage.id);
      showToast(error.toString());
    } finally {
      isSending.value = false;
    }
  }

  Future<void> pickAndSendPhoto() async {
    String localMessageId = '';
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image == null) {
        return;
      }

      isSending.value = true;
      final upload = await _mediaUploadService.upload(
        file: File(image.path),
        type: 'image',
      );
      final localMessage = await _localMessage(
        message: '',
        type: 'image',
        mediaUrl: upload.url,
        mediaPath: upload.path,
        mediaWidth: upload.width,
        mediaHeight: upload.height,
      );
      _appendLocalMessage(localMessage);
      localMessageId = localMessage.id;
      final loadedMessages = await _repository.sendMediaMessage(
        type: 'image',
        upload: upload,
        conversationId: _chatKey,
        adminId: adminId.value,
        adminUsername: adminUsername.value,
        internalConversationId: internalConversationId.value,
      );
      await _replaceAfterSend(loadedMessages);
    } catch (error) {
      if (localMessageId.isNotEmpty) {
        _removeLocalMessage(localMessageId);
      }
      showToast(error.toString());
    } finally {
      isSending.value = false;
    }
  }

  Future<void> pickAndSendFile() async {
    String localMessageId = '';
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: false,
      );
      final pickedFile = result?.files.single;
      final path = pickedFile?.path;
      if (path == null || path.trim().isEmpty) {
        return;
      }

      isSending.value = true;
      final upload = await _mediaUploadService.upload(
        file: File(path),
        type: 'file',
      );
      final localMessage = await _localMessage(
        message: '',
        type: 'file',
        mediaUrl: upload.url,
        mediaPath: upload.path,
        fileName: pickedFile?.name ?? _fileNameFromPath(path),
      );
      _appendLocalMessage(localMessage);
      localMessageId = localMessage.id;
      final loadedMessages = await _repository.sendMediaMessage(
        type: 'file',
        upload: upload,
        fileName: pickedFile?.name ?? _fileNameFromPath(path),
        conversationId: _chatKey,
        adminId: adminId.value,
        adminUsername: adminUsername.value,
        internalConversationId: internalConversationId.value,
      );
      await _replaceAfterSend(loadedMessages);
    } catch (error) {
      if (localMessageId.isNotEmpty) {
        _removeLocalMessage(localMessageId);
      }
      showToast(error.toString());
    } finally {
      isSending.value = false;
    }
  }

  Future<void> startVoiceRecording() async {
    try {
      final hasPermission = await _voiceRecorderService.hasPermission();
      if (!hasPermission) {
        showToast('Microphone permission is required to send voice messages');
        return;
      }

      _pendingVoiceRecording = null;
      hasPendingVoiceRecording.value = false;
      recordingSeconds.value = 0;
      isRecording.value = true;
      _startRecordingTimer();
      await _voiceRecorderService.start();
    } catch (error) {
      await _resetRecordingState(deletePendingFile: true);
      showToast(error.toString());
    }
  }

  Future<void> stopVoiceRecording() async {
    try {
      final result = await _voiceRecorderService.stop();
      _stopRecordingTimer();
      isRecording.value = false;

      if (result == null) {
        await _resetRecordingState(deletePendingFile: false);
        return;
      }

      _pendingVoiceRecording = result;
      hasPendingVoiceRecording.value = true;
      recordingSeconds.value = _durationSeconds(result.duration);
    } catch (error) {
      await _resetRecordingState(deletePendingFile: true);
      showToast(error.toString());
    }
  }

  Future<void> cancelVoiceRecording() async {
    try {
      if (isRecording.value) {
        await _voiceRecorderService.cancel();
      }
      await _resetRecordingState(deletePendingFile: true);
    } catch (error) {
      await _resetRecordingState(deletePendingFile: true);
      showToast(error.toString());
    }
  }

  Future<void> sendVoiceRecording() async {
    isSending.value = true;
    String localMessageId = '';

    if (isRecording.value) {
      await stopVoiceRecording();
    }

    final recording = _pendingVoiceRecording;
    if (recording == null) {
      await _resetRecordingState(deletePendingFile: false);
      isSending.value = false;
      return;
    }

    try {
      final upload = await _mediaUploadService.upload(
        file: File(recording.path),
        type: 'voice',
      );
      final localMessage = await _localMessage(
        message: '',
        type: 'voice',
        mediaUrl: upload.url,
        mediaPath: upload.path,
        durationSeconds: _durationSeconds(recording.duration),
      );
      _appendLocalMessage(localMessage);
      localMessageId = localMessage.id;
      final loadedMessages = await _repository.sendMediaMessage(
        type: 'voice',
        upload: upload,
        durationSeconds: _durationSeconds(recording.duration),
        conversationId: _chatKey,
        adminId: adminId.value,
        adminUsername: adminUsername.value,
        internalConversationId: internalConversationId.value,
      );
      await _replaceAfterSend(loadedMessages);
      await _resetRecordingState(deletePendingFile: true);
    } catch (error) {
      if (localMessageId.isNotEmpty) {
        _removeLocalMessage(localMessageId);
      }
      await _resetRecordingState(deletePendingFile: true);
      showToast(error.toString());
    } finally {
      isSending.value = false;
    }
  }

  Future<void> sendCurrentLocation() async {
    String localMessageId = '';
    try {
      isSending.value = true;
      final position = await _determineCurrentPosition();
      final localMessage = await _localMessage(
        message: '',
        type: 'location',
        mediaUrl: _mapsUrl(position.latitude, position.longitude),
        latitude: position.latitude,
        longitude: position.longitude,
      );
      _appendLocalMessage(localMessage);
      localMessageId = localMessage.id;
      final loadedMessages = await _repository.sendLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        conversationId: _chatKey,
        adminId: adminId.value,
        adminUsername: adminUsername.value,
        internalConversationId: internalConversationId.value,
      );
      await _replaceAfterSend(loadedMessages);
    } catch (error) {
      if (localMessageId.isNotEmpty) {
        _removeLocalMessage(localMessageId);
      }
      showToast(error.toString());
    } finally {
      isSending.value = false;
    }
  }

  void _replaceMessages(List<AdminChatMessage> loadedMessages) {
    loadedMessages.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    messages.value = loadedMessages;
    debugPrint(
      '[ADMIN_CHAT] screen rendered messages count=${loadedMessages.length}',
    );
    _scrollToBottom();
  }

  Future<void> _replaceAfterSend(List<AdminChatMessage> loadedMessages) async {
    if (loadedMessages.isNotEmpty) {
      _replaceMessages(loadedMessages);
      return;
    }

    try {
      final refreshedMessages = await _repository.getMessages(
        conversationId: _chatKey,
        adminId: adminId.value,
        adminUsername: adminUsername.value,
        internalConversationId: internalConversationId.value,
      );
      if (refreshedMessages.isNotEmpty) {
        _replaceMessages(refreshedMessages);
        return;
      }
    } catch (error) {
      debugPrint('[ADMIN_CHAT] refresh after send failed: $error');
    }

    debugPrint('[ADMIN_CHAT] keeping local sent message until server sync');
  }

  Future<AdminChatMessage> _localMessage({
    required String message,
    required String type,
    String mediaUrl = '',
    String mediaPath = '',
    String fileName = '',
    int? mediaWidth,
    int? mediaHeight,
    int? durationSeconds,
    double? latitude,
    double? longitude,
  }) async {
    return AdminChatMessage(
      id: 'local:${DateTime.now().microsecondsSinceEpoch}',
      message: message,
      sender: 'employee',
      senderName: await Preferences().getFullName(),
      conversationId: _chatKey,
      adminId: adminId.value,
      adminUsername: adminUsername.value,
      dateTime: DateTime.now(),
      type: type,
      mediaUrl: mediaUrl,
      mediaPath: mediaPath,
      fileName: fileName,
      mediaWidth: mediaWidth,
      mediaHeight: mediaHeight,
      durationSeconds: durationSeconds,
      latitude: latitude,
      longitude: longitude,
    );
  }

  void _appendLocalMessage(AdminChatMessage message) {
    messages.add(message);
    messages.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    messages.refresh();
    _scrollToBottom();
  }

  void _removeLocalMessage(String messageId) {
    messages.removeWhere((message) => message.id == messageId);
    messages.refresh();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 250), () {
      if (!scrollController.hasClients) {
        return;
      }
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _startRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      recordingSeconds.value += 1;
    });
  }

  void _stopRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
  }

  Future<void> _resetRecordingState({required bool deletePendingFile}) async {
    _stopRecordingTimer();
    isRecording.value = false;

    final pendingRecording = _pendingVoiceRecording;
    _pendingVoiceRecording = null;
    hasPendingVoiceRecording.value = false;
    recordingSeconds.value = 0;

    if (deletePendingFile && pendingRecording != null) {
      await _voiceRecorderService.delete(pendingRecording.path);
    }
  }

  int _durationSeconds(Duration duration) {
    final seconds = duration.inSeconds;
    return seconds <= 0 ? 1 : seconds;
  }

  Future<Position> _determineCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw 'Please enable your location, it seems to be turned off.';
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw 'Location permissions are denied';
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw 'Location permissions are permanently denied. Please enable permission and try again.';
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
        distanceFilter: 0,
      ),
    );
  }

  String _fileNameFromPath(String path) {
    return path.split(Platform.pathSeparator).last;
  }

  String _mapsUrl(double latitude, double longitude) {
    return 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
  }

  String get _chatKey {
    return conversationId.value.trim();
  }

  Future<void> _normalizeConversationId() async {
    final currentConversationId = conversationId.value.trim();
    final currentAdminId = adminId.value.trim();
    if (currentAdminId.isEmpty) {
      return;
    }

    final employeeId = await Preferences().getUserId();
    if (employeeId <= 0) {
      return;
    }

    final expectedConversationId =
        'employee_admin_${employeeId}_$currentAdminId';
    final shouldUseExpected = currentConversationId.isEmpty ||
        !_isPublicAdminConversationId(currentConversationId) ||
        _adminIdFromConversationId(currentConversationId) != currentAdminId;

    if (!shouldUseExpected) {
      return;
    }

    debugPrint(
      '[ADMIN_CHAT] normalized conversation_id'
      ' | from=$currentConversationId'
      ' | to=$expectedConversationId'
      ' | admin_id=$currentAdminId',
    );
    conversationId.value = expectedConversationId;
  }

  bool _isPublicAdminConversationId(String value) {
    return value.trim().startsWith('employee_admin_');
  }

  String _adminIdFromConversationId(String value) {
    final parts = value.trim().split('_');
    if (parts.length < 4) {
      return '';
    }
    return parts.last.trim();
  }

  Future<void> _clearLegacyUnreadKeys() async {
    final badgeController = ChatBadgeController.ensureRegistered();
    final currentKey = _chatKey;
    final legacyKeys = <String>{
      if (adminId.value.trim().isNotEmpty) 'admin:${adminId.value.trim()}',
      if (adminUsername.value.trim().isNotEmpty)
        'admin:${adminUsername.value.trim()}',
      if (adminName.value.trim().isNotEmpty) 'admin:${adminName.value.trim()}',
      if (internalConversationId.value.trim().isNotEmpty)
        internalConversationId.value.trim(),
    }..remove(currentKey);

    for (final key in legacyKeys) {
      await badgeController.markConversationAsRead(key);
    }
  }

  @override
  void onClose() {
    ChatBadgeController.ensureRegistered().clearActiveConversation(_chatKey);
    _recordingTimer?.cancel();
    _voiceRecorderService.dispose();
    chatController.dispose();
    scrollController.dispose();
    super.onClose();
  }
}
