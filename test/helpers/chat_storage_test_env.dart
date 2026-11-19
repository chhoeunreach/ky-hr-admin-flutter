import 'dart:io';

import 'package:cnattendance/utils/chat_unread_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';

class ChatStorageTestEnv {
  ChatStorageTestEnv._();

  static Directory? _tempDir;

  static Future<void> install() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final tempDir = await Directory.systemTemp.createTemp('chat_storage_test');
    _tempDir = tempDir;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async {
        if (call.method == 'getApplicationDocumentsDirectory') {
          return tempDir.path;
        }
        return null;
      },
    );
    await GetStorage().initStorage;
    ChatUnreadStore.markStorageReady();
  }

  static Future<void> uninstall() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    final tempDir = _tempDir;
    _tempDir = null;
    if (tempDir != null && tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  }
}
