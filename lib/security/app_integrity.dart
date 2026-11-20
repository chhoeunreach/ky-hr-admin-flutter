import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// APK clone / re-sign / repackage detection.
///
/// Native side compares the installed signing-cert SHA-256 and package name
/// against values baked into `BuildConfig` at build time. If verification
/// fails (or cannot run), the app treats itself as tampered and must not
/// start any network, push, background-sync, or session services.
class AppIntegrity {
  AppIntegrity._();

  static const MethodChannel _channel = MethodChannel('cnattendance/app_integrity');

  static bool? _tampered;

  /// Last verify reason for diagnostics (`ok`, `signature_mismatch`,
  /// `package_mismatch`, `no_signature`, `verify_failed`).
  static String lastReason = 'unknown';

  /// True when the APK must be treated as cloned/tampered.
  /// Fails closed: any verification error on Android counts as tampered.
  static Future<bool> isTampered() async {
    if (!Platform.isAndroid) {
      lastReason = 'ios_skip';
      return false;
    }
    final cached = _tampered;
    if (cached != null) return cached;

    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('verify');
      if (result == null) {
        _tampered = true;
        lastReason = 'verify_failed';
        return true;
      }
      final packageOk = result['packageOk'] == true;
      final certOk = result['certOk'] == true;
      _tampered = result['tampered'] == true || !packageOk || !certOk;
      if (!_tampered!) {
        lastReason = 'ok';
      } else if (!packageOk) {
        lastReason = 'package_mismatch';
      } else if (!certOk) {
        lastReason = 'signature_mismatch';
      } else {
        lastReason = 'tampered';
      }
    } catch (_) {
      _tampered = true;
      lastReason = 'verify_failed';
    }
    return _tampered!;
  }

  /// Wipes any stored session so a blocked install cannot resume auth.
  static Future<void> wipeSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (_) {
      // SharedPreferences may not be ready yet; ignore.
    }
  }
}
