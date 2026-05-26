import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class FcmToken {
  static bool isValid(String? token) {
    if (token == null) {
      return false;
    }

    final trimmed = token.trim();
    if (trimmed.isEmpty) {
      return false;
    }

    if (trimmed == 'await FirebaseMessaging.instance.getToken()') {
      return false;
    }

    return true;
  }

  static Future<String?> get({int retries = 3}) async {
    for (int attempt = 0; attempt < retries; attempt++) {
      try {
        if (Platform.isIOS) {
          await FirebaseMessaging.instance.getAPNSToken();
        }

        final token = await FirebaseMessaging.instance.getToken();
        if (isValid(token)) {
          final trimmed = token!.trim();
          debugPrint('FCM token ready: ${mask(trimmed)}');
          return trimmed;
        }
      } catch (e) {
        debugPrint('FCM token fetch failed: $e');
      }

      if (attempt < retries - 1) {
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    return null;
  }

  static String mask(String? token) {
    if (!isValid(token)) {
      return 'missing';
    }

    final trimmed = token!.trim();
    if (trimmed.length <= 12) {
      return trimmed;
    }

    return '${trimmed.substring(0, 6)}...${trimmed.substring(trimmed.length - 6)}';
  }
}
