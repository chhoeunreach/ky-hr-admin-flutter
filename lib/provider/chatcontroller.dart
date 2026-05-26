import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/model/chat.dart';
import 'package:cnattendance/provider/chatbadgecontroller.dart';
import 'package:cnattendance/services/chat_media_upload_service.dart';
import 'package:cnattendance/services/voice_recorder_service.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:http_interceptor_plus/http_interceptor_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;

class ChatController extends GetxController {
  var host = "".obs;
  var hostUsername = "";
  var hostImage = "";
  var hostEmployeeId = "";
  var currentUsername = "";
  var convoId = "";
  final chatController = TextEditingController();
  final scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final ChatMediaUploadService _mediaUploadService = ChatMediaUploadService();
  final VoiceRecorderService _voiceRecorderService = VoiceRecorderService();
  Timer? _recordingTimer;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _chatSubscription;
  VoiceRecordingResult? _pendingVoiceRecording;

  var chatList = <Chat>[].obs;
  var isUploading = false.obs;
  var isRecording = false.obs;
  var recordingSeconds = 0.obs;
  var hasPendingVoiceRecording = false.obs;

  Preferences pref = Preferences();

  @override
  Future<void> onReady() async {
    host.value = Get.arguments["name"];
    hostImage = Get.arguments["avatar"];
    hostUsername = Get.arguments["username"];
    hostEmployeeId = Get.arguments["employeeId"]?.toString() ?? "";
    currentUsername = await pref.getUsername();

    setConversationDetail(hostUsername, currentUsername);
    await ChatBadgeController.ensureRegistered().setActiveConversation(convoId);
    super.onReady();
  }

  void setConversationDetail(String user1, String user2) {
    int result = user1.compareTo(user2);
    if (result < 0) {
      convoId = user1 + user2;
    } else if (result > 0) {
      convoId = user2 + user1;
    } else {
      convoId = user1 + user2;
    }

    FirebaseFirestore.instance.collection('conversations').doc(convoId).set({
      'id': convoId,
      'user1': user1,
      'user2': user2,
    });

    listenChat();
  }

  Future<void> sendMessage(String message) async {
    try {
      var fcm = await FirebaseMessaging.instance.getToken();
      print(fcm);

      final senderUsername = await pref.getUsername();

      chatController.clear();
      await FirebaseFirestore.instance
          .collection('messages')
          .doc(Uuid().v4())
          .set({
        "id": convoId,
        "date": DateTime.now(),
        "message": base64.encode(utf8.encode(message)),
        "type": "text",
        "media_url": "",
        "sender": senderUsername,
        "reciever": hostUsername
      });

      unawaited(_sendPushNotificationSafely(
        senderUsername,
        message,
        convoId,
        "chat",
        "",
        hostUsername,
        messageType: "text",
      ));
    } catch (e) {
      showToast(e.toString());
    }
  }

  Future<void> pickAndSendPhoto() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image == null) {
        return;
      }

      isUploading.value = true;
      final upload = await _mediaUploadService.upload(
        file: File(image.path),
        type: "image",
      );
      await _sendMediaMessage(
        type: "image",
        upload: upload,
        pushMessage: "Sent a photo",
      );
    } catch (e) {
      final message = e is TimeoutException
          ? "Photo upload took too long. Please try again."
          : e.toString();
      showToast(message);
    } finally {
      isUploading.value = false;
    }
  }

  Future<void> pickAndSendFile() async {
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

      isUploading.value = true;
      final upload = await _mediaUploadService.upload(
        file: File(path),
        type: "file",
      );
      await _sendMediaMessage(
        type: "file",
        upload: upload,
        pushMessage: "Sent a file",
      );
    } catch (e) {
      showToast(e.toString());
    } finally {
      isUploading.value = false;
    }
  }

  Future<void> toggleVoiceRecording() async {
    if (isRecording.value) {
      await stopVoiceRecording();
      return;
    }
    await startVoiceRecording();
  }

  Future<void> startVoiceRecording() async {
    try {
      final hasPermission = await _voiceRecorderService.hasPermission();
      if (!hasPermission) {
        showToast("Microphone permission is required to send voice messages");
        return;
      }

      _pendingVoiceRecording = null;
      recordingSeconds.value = 0;
      isRecording.value = true;
      _startRecordingTimer();
      await _voiceRecorderService.start();
    } catch (e) {
      await _resetRecordingState(deletePendingFile: true);
      showToast(e.toString());
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
    } catch (e) {
      await _resetRecordingState(deletePendingFile: true);
      showToast(e.toString());
    }
  }

  Future<void> cancelVoiceRecording() async {
    try {
      if (isRecording.value) {
        await _voiceRecorderService.cancel();
      }
      await _resetRecordingState(deletePendingFile: true);
    } catch (e) {
      await _resetRecordingState(deletePendingFile: true);
      showToast(e.toString());
    }
  }

  Future<void> sendVoiceRecording() async {
    isUploading.value = true;

    if (isRecording.value) {
      await stopVoiceRecording();
    }

    final recording = _pendingVoiceRecording;
    if (recording == null) {
      await _resetRecordingState(deletePendingFile: false);
      isUploading.value = false;
      return;
    }

    try {
      final upload = await _mediaUploadService.upload(
        file: File(recording.path),
        type: "voice",
      );
      await _sendMediaMessage(
        type: "voice",
        upload: upload,
        pushMessage: "Sent a voice message",
        durationSeconds: _durationSeconds(recording.duration),
      );
      _clearPendingVoiceUi();
      unawaited(_deleteRecordingFile(recording.path));
    } catch (e) {
      await _resetRecordingState(deletePendingFile: true);
      showToast(e.toString());
    } finally {
      isUploading.value = false;
    }
  }

  Future<void> sendCurrentLocation() async {
    try {
      isUploading.value = true;
      final position = await _determineCurrentPosition();
      final senderUsername = await pref.getUsername();
      final latitude = position.latitude;
      final longitude = position.longitude;
      final mapsUrl = _mapsUrl(latitude, longitude);

      debugPrint('[CHAT_LOCATION] latitude=$latitude longitude=$longitude');
      debugPrint('[CHAT_LOCATION] maps_url=$mapsUrl');

      await FirebaseFirestore.instance
          .collection('messages')
          .doc(Uuid().v4())
          .set({
        "id": convoId,
        "date": DateTime.now(),
        "message": "",
        "type": "location",
        "media_url": mapsUrl,
        "latitude": latitude,
        "longitude": longitude,
        "sender": senderUsername,
        "reciever": hostUsername
      });

      unawaited(_sendPushNotificationSafely(
        senderUsername,
        "Shared a location",
        convoId,
        "chat",
        "",
        hostUsername,
        messageType: "location",
        mediaUrl: mapsUrl,
      ));
    } catch (e) {
      showToast(e.toString());
    } finally {
      isUploading.value = false;
    }
  }

  Future<void> _sendMediaMessage({
    required String type,
    required ChatMediaUpload upload,
    required String pushMessage,
    int? durationSeconds,
  }) async {
    final senderUsername = await pref.getUsername();

    await FirebaseFirestore.instance
        .collection('messages')
        .doc(Uuid().v4())
        .set({
      "id": convoId,
      "date": DateTime.now(),
      "message": "",
      "type": type,
      "media_url": upload.url,
      "media_path": upload.path,
      "media_width": upload.width,
      "media_height": upload.height,
      "duration_seconds": durationSeconds,
      "sender": senderUsername,
      "reciever": hostUsername
    });

    unawaited(_sendPushNotificationSafely(
      senderUsername,
      pushMessage,
      convoId,
      "chat",
      "",
      hostUsername,
      messageType: type,
      mediaUrl: upload.url,
    ));
  }

  Future<void> _sendPushNotificationSafely(
    String title,
    String message,
    String conversationId,
    String type,
    String projectId,
    String username, {
    String messageType = "text",
    String mediaUrl = "",
  }) async {
    try {
      await sendPushNotifiation(
        title,
        message,
        conversationId,
        type,
        projectId,
        username,
        messageType: messageType,
        mediaUrl: mediaUrl,
      ).timeout(const Duration(seconds: 12));
    } catch (error) {
      debugPrint('[CHAT_PUSH] skipped after message sent: $error');
    }
  }

  Future<void> listenChat() async {
    await _chatSubscription?.cancel();

    final docRef = FirebaseFirestore.instance
        .collection("messages")
        .where("id", isEqualTo: convoId)
        .snapshots();

    _chatSubscription = docRef.listen(
      (event) {
        final justSentByCurrentUser = event.docChanges.any((change) {
          if (change.type != DocumentChangeType.added) {
            return false;
          }
          final data = change.doc.data();
          if (data == null) {
            return false;
          }
          return (data["sender"]?.toString().trim() ?? "") ==
              currentUsername.trim();
        });

        if (justSentByCurrentUser) {
          isUploading.value = false;
          if (!isRecording.value && hasPendingVoiceRecording.value) {
            _clearPendingVoiceUi();
          }
        }

        print("triiger");
        final chatDb = <Chat>[];
        for (var item in event.docs) {
          Timestamp firebaseTimestamp = item["date"];
          final encodedMessage = _readString(item.data(), "message");
          chatDb.add(
            Chat.fromFirestore(
              item.data(),
              dateTime: firebaseTimestamp.toDate(),
              decodedMessage: _decodeMessage(encodedMessage),
            ),
          );
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

  Future<void> sendPushNotifiation(String title, String message,
      String converstion_id, String type, String project_id, String username,
      {String messageType = "text", String mediaUrl = ""}) async {
    Preferences preferences = Preferences();

    var uri = Uri.parse(
        "${await preferences.getAppUrl()}${Constant.SEND_PUSH_NOTIFICATION}");

    String token = await preferences.getToken();

    Map<String, String> headers = {
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token'
    };
    var users = <String>[];
    users.add(username);

    final http.Client client = LoggingMiddleware(http.Client());

    final body = {
      "title": title,
      "message": message,
      "conversation_id": converstion_id,
      "type": type,
      "project_id": project_id,
      "usernames": jsonEncode(users),
      "message_type": messageType,
      "media_url": mediaUrl,
    };

    var response = await client.post(uri, headers: headers, body: body);

    var responseData = _decodeResponseBody(response.body);
    var responseMessage = responseData['message']?.toString() ?? "";

    if (response.statusCode != 200 &&
        _isReservedMessageTypeError(responseMessage)) {
      print("Push retry without reserved message_type: $responseMessage");
      final retryBody = Map<String, String>.from(body)
        ..remove("message_type")
        ..["chat_message_type"] = messageType;
      response = await client.post(uri, headers: headers, body: retryBody);
      responseData = _decodeResponseBody(response.body);
      responseMessage = responseData['message']?.toString() ?? "";
    }

    if (response.statusCode == 200) {
      print(response.body.toString());
    } else if (_isMissingRegistrationTokenError(responseMessage)) {
      print("Push skipped: $responseMessage");
    } else {
      var errorMessage = responseData['message'];
      print(errorMessage);
      throw errorMessage;
    }
  }

  bool _isMissingRegistrationTokenError(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains("no registration tokens provided");
  }

  bool _isReservedMessageTypeError(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains("message_type") &&
        normalized.contains("reserved");
  }

  Map<String, dynamic> _decodeResponseBody(String body) {
    if (body.trim().isEmpty) {
      return {"message": "Empty server response"};
    }

    try {
      final decoded = json.decode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return {"message": decoded.toString()};
    } catch (_) {
      return {"message": body};
    }
  }

  String _readString(
    Map<String, dynamic> data,
    String key, {
    String fallback = "",
  }) {
    return data[key]?.toString() ?? fallback;
  }

  String _decodeMessage(String value) {
    if (value.trim().isEmpty) {
      return "";
    }

    try {
      return utf8.decode(base64.decode(value));
    } catch (_) {
      return value;
    }
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
    _clearPendingVoiceUi();

    if (deletePendingFile && pendingRecording != null) {
      await _deleteRecordingFile(pendingRecording.path);
    }
  }

  void _clearPendingVoiceUi() {
    _pendingVoiceRecording = null;
    hasPendingVoiceRecording.value = false;
    recordingSeconds.value = 0;
    isRecording.value = false;
  }

  Future<void> _deleteRecordingFile(String path) async {
    try {
      await _voiceRecorderService.delete(path);
    } catch (error) {
      debugPrint('[VOICE_RECORD] delete failed: $error');
    }
  }

  int _durationSeconds(Duration duration) {
    final seconds = duration.inSeconds;
    return seconds <= 0 ? 1 : seconds;
  }

  Future<Position> _determineCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw "Please enable your location, it seems to be turned off.";
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw "Location permissions are denied";
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw "Location permissions are permanently denied. Please enable permission and try again.";
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
        distanceFilter: 0,
      ),
    );
  }

  String _mapsUrl(double latitude, double longitude) {
    return "https://www.google.com/maps/search/?api=1&query=$latitude,$longitude";
  }

  @override
  void onClose() {
    ChatBadgeController.ensureRegistered().clearActiveConversation(convoId);
    _chatSubscription?.cancel();
    _recordingTimer?.cancel();
    _voiceRecorderService.dispose();
    chatController.dispose();
    scrollController.dispose();
    super.onClose();
  }
}
