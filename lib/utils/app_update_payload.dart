import 'dart:io';

import 'package:cnattendance/utils/app_device_info.dart';

const _androidFallbackUrl = 'https://hr.kneayerng.com';
const _iosFallbackUrl = 'https://testflight.apple.com/join/hPG4ZA38';
const _androidKeys = ['android_url', 'android_download_url', 'play_store_url'];
const _iosKeys = [
  'ios_url',
  'ios_download_url',
  'app_store_url',
  'apple_store_url'
];
const _genericKeys = ['download_url', 'url'];

Map<String, String> appUpdateMetadata(Map data) {
  final metadata = <String, String>{};
  for (final key in const [
    'action',
    'target_version',
    'latest_version',
    'min_required_version',
    'min_version',
    'force_update',
    ..._androidKeys,
    ..._iosKeys,
    ..._genericKeys,
  ]) {
    final value = data[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) metadata[key] = value;
  }
  return metadata;
}

bool isAppUpdateNotification(Map data, {String legacyText = ''}) {
  final type = data['type']?.toString().trim().toLowerCase() ?? '';
  if (type == 'app_update' || type == 'version_update') return true;
  if (data['action']?.toString().trim().toLowerCase() == 'app_update')
    return true;
  if (['target_version', 'latest_version'].any(
    (key) => data[key]?.toString().trim().isNotEmpty ?? false,
  )) {
    return true;
  }
  if (type.isNotEmpty && type != 'general') return false;
  final text = legacyText.toLowerCase();
  return [
    'app update',
    'new version',
    'update available',
    'អាប់ដេត',
    'កំណែថ្មី'
  ].any(text.contains);
}

String appUpdateTargetVersion(Map data) =>
    (data['target_version'] ?? data['latest_version'] ?? '').toString().trim();

String appUpdateMinimumVersion(Map data) =>
    (data['min_required_version'] ?? data['min_version'] ?? '')
        .toString()
        .trim();

bool isForcedAppUpdate(Map data, String currentVersion) {
  final minimum = appUpdateMinimumVersion(data);
  if (minimum.isNotEmpty &&
      AppDeviceInfo.isVersionOlder(currentVersion, minimum)) {
    return true;
  }
  final flag = data['force_update']?.toString().trim().toLowerCase();
  final target = appUpdateTargetVersion(data);
  return (flag == '1' || flag == 'true' || flag == 'yes') &&
      (target.isEmpty || AppDeviceInfo.isVersionOlder(currentVersion, target));
}

Uri? _httpUri(String? value) {
  final uri = Uri.tryParse(value?.trim() ?? '');
  return uri != null &&
          (uri.scheme == 'https' || uri.scheme == 'http') &&
          uri.host.isNotEmpty
      ? uri
      : null;
}

Uri? configuredAppUpdateUri(Map data, {bool? isIOS}) {
  final keys =
      (isIOS ?? Platform.isIOS) ? _iosKeys : [..._androidKeys, ..._genericKeys];
  for (final key in keys) {
    final uri = _httpUri(data[key]?.toString());
    if (uri != null) return uri;
  }
  return null;
}

Uri appUpdateDownloadUri(String? url, {bool? isIOS}) =>
    _httpUri(url) ??
    Uri.parse(
        (isIOS ?? Platform.isIOS) ? _iosFallbackUrl : _androidFallbackUrl);
