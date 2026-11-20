import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'deviceuuid.dart';
import 'package:flutter/foundation.dart';

class AppDeviceDetails {
  final String appName;
  final String appVersion;
  final String appBuild;
  final String deviceModel;
  final String osVersion;
  final String deviceName;
  final String deviceType;
  final String uuid;

  const AppDeviceDetails({
    required this.appName,
    required this.appVersion,
    required this.appBuild,
    required this.deviceModel,
    required this.osVersion,
    required this.deviceName,
    required this.deviceType,
    required this.uuid,
  });

  Map<String, String> toMap() {
    return {
      'app_name': appName,
      'app_version': appVersion,
      'app_build': appBuild,
      'device_model': deviceModel,
      'os_version': osVersion,
      'device_name': deviceName,
      'device_type': deviceType,
      'uuid': uuid,
    };
  }
}

class AppDeviceInfo {
  static AppDeviceDetails? _cachedDetails;

  static Future<AppDeviceDetails> getDetails() async {
    if (_cachedDetails != null) {
      return _cachedDetails!;
    }

    String appName = 'Digital HR';
    String appVersion = '1.0.0';
    String appBuild = '1';

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (packageInfo.appName.trim().isNotEmpty) {
        appName = packageInfo.appName.trim();
      }
      if (packageInfo.version.trim().isNotEmpty) {
        appVersion = packageInfo.version.trim();
      }
      if (packageInfo.buildNumber.trim().isNotEmpty) {
        appBuild = packageInfo.buildNumber.trim();
      }
    } catch (error) { if (kDebugMode) debugPrint('DeviceInfo: failed to read package info: $error'); }

    String deviceModel = 'Unknown Model';
    String osVersion = 'Unknown OS';
    String deviceName = 'Unknown Device';
    final deviceType = Platform.isIOS ? 'ios' : 'android';

    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        final brand = androidInfo.brand.trim();
        final model = androidInfo.model.trim();
        deviceModel = brand.isNotEmpty && !model.toLowerCase().contains(brand.toLowerCase())
            ? '$brand $model'
            : model;
        osVersion = 'Android ${androidInfo.version.release} (SDK ${androidInfo.version.sdkInt})';
        deviceName = deviceModel;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceModel = iosInfo.utsname.machine.isNotEmpty
            ? iosInfo.utsname.machine
            : (iosInfo.model.isNotEmpty ? iosInfo.model : 'iPhone');
        osVersion = '${iosInfo.systemName} ${iosInfo.systemVersion}';
        deviceName = iosInfo.name.isNotEmpty ? iosInfo.name : deviceModel;
      }
    } catch (error) { if (kDebugMode) debugPrint('DeviceInfo: failed to read platform info: $error'); }

    String uuid = '';
    try {
      uuid = await DeviceUUid().getUniqueDeviceId();
    } catch (error) { if (kDebugMode) debugPrint('DeviceInfo: failed to read device uuid: $error'); }

    _cachedDetails = AppDeviceDetails(
      appName: appName,
      appVersion: appVersion,
      appBuild: appBuild,
      deviceModel: deviceModel,
      osVersion: osVersion,
      deviceName: deviceName,
      deviceType: deviceType,
      uuid: uuid,
    );

    return _cachedDetails!;
  }

  /// Compare two semantic version strings (e.g., "1.0.2" vs "1.1.0").
  /// Returns true if [current] is older than [latest].
  static bool isVersionOlder(String current, String latest) {
    try {
      final curClean = current.trim().split('+').first.split('-').first;
      final latClean = latest.trim().split('+').first.split('-').first;

      if (curClean.isEmpty || latClean.isEmpty) return false;

      final curParts = curClean.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final latParts = latClean.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      final maxLen = curParts.length > latParts.length ? curParts.length : latParts.length;
      while (curParts.length < maxLen) {
        curParts.add(0);
      }
      while (latParts.length < maxLen) {
        latParts.add(0);
      }

      for (int i = 0; i < maxLen; i++) {
        if (curParts[i] < latParts[i]) {
          return true;
        } else if (curParts[i] > latParts[i]) {
          return false;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
