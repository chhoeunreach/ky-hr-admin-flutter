import 'package:flutter_test/flutter_test.dart';
import 'package:cnattendance/data/source/network/model/dashboard/Dashboard.dart';
import 'package:cnattendance/utils/app_device_info.dart';

void main() {
  group('App Version & Alert Tests', () {
    test('AppDeviceInfo.isVersionOlder compares versions correctly', () {
      expect(AppDeviceInfo.isVersionOlder('1.2.9', '1.3.0'), isTrue);
      expect(AppDeviceInfo.isVersionOlder('1.2.9+13', '1.3.0+14'), isTrue);
      expect(AppDeviceInfo.isVersionOlder('1.3.0', '1.3.0'), isFalse);
      expect(AppDeviceInfo.isVersionOlder('1.3.1', '1.3.0'), isFalse);
      expect(AppDeviceInfo.isVersionOlder('1.0.0', '2.0.0'), isTrue);
      expect(AppDeviceInfo.isVersionOlder('2.0.0', '1.0.0'), isFalse);
    });

    test('AppVersionInfo.fromJson parses API response with alert fields', () {
      final apiResponse = {
        'latest_version': '1.3.0',
        'min_required_version': '1.2.0',
        'download_url': 'https://hr.kneayerng.com',
        'force_update': false,
        'update_message': 'មានកំណែថ្មីនៃកម្មវិធី (1.3.0)។ សូមធ្វើបច្ចុប្បន្នភាពដើម្បីរីករាយជាមួយមុខងារថ្មីៗ និងការកែលម្អ។',
        'version_check_enabled': true,
        'target_version': '1.3.0',
        'current_version': '1.2.9',
        'normalized_version': '1.2.9',
        'is_update_available': true,
        'is_update_required': false,
        'show_alert': true,
        'alert_title': 'មានកំណែអាប់ដេតថ្មី',
        'alert_message': 'មានកំណែថ្មីនៃកម្មវិធី (1.3.0)។ សូមធ្វើបច្ចុប្បន្នភាពដើម្បីរីករាយជាមួយមុខងារថ្មីៗ និងការកែលម្អ។',
        'android_url': 'https://hr.kneayerng.com',
        'ios_url': 'https://apps.apple.com'
      };

      final info = AppVersionInfo.fromJson(apiResponse);

      expect(info.latestVersion, equals('1.3.0'));
      expect(info.minVersion, equals('1.2.0'));
      expect(info.downloadUrl, equals('https://hr.kneayerng.com'));
      expect(info.releaseNotes, contains('មានកំណែថ្មីនៃកម្មវិធី (1.3.0)'));
      expect(info.alertTitle, equals('មានកំណែអាប់ដេតថ្មី'));
      expect(info.isForceUpdate, isFalse);
      expect(info.showAlert, isTrue);
      expect(info.isUpdateAvailable, isTrue);
    });

    test('Alert trigger condition triggers for old client and ignores updated client', () {
      // 1. Old client 1.2.9 with API show_alert: true
      final apiResponseOld = {
        'latest_version': '1.3.0',
        'download_url': 'https://hr.kneayerng.com',
        'show_alert': true,
        'is_update_available': true,
        'force_update': false,
      };
      final infoOld = AppVersionInfo.fromJson(apiResponseOld);
      final currentVersionOld = '1.2.9';

      final shouldShowOld = infoOld.showAlert ||
          (infoOld.latestVersion.isNotEmpty &&
              AppDeviceInfo.isVersionOlder(currentVersionOld, infoOld.latestVersion));
      expect(shouldShowOld, isTrue);

      // 2. Updated client 1.3.0 with API show_alert: false
      final apiResponseNew = {
        'latest_version': '1.3.0',
        'download_url': 'https://hr.kneayerng.com',
        'show_alert': false,
        'is_update_available': false,
        'force_update': false,
      };
      final infoNew = AppVersionInfo.fromJson(apiResponseNew);
      final currentVersionNew = '1.3.0';

      final shouldShowNew = infoNew.showAlert ||
          (infoNew.latestVersion.isNotEmpty &&
              AppDeviceInfo.isVersionOlder(currentVersionNew, infoNew.latestVersion));
      expect(shouldShowNew, isFalse);

      // 3. Force update condition blocks dismissal
      final apiResponseForce = {
        'latest_version': '1.3.0',
        'force_update': true,
        'is_update_required': true,
        'show_alert': true,
      };
      final infoForce = AppVersionInfo.fromJson(apiResponseForce);
      expect(infoForce.isForceUpdate, isTrue);
    });

    test('AppVersionInfo parses forced update flags sent as strings', () {
      expect(AppVersionInfo.fromJson({'force_update': '1'}).isForceUpdate,
          isTrue);
      expect(AppVersionInfo.fromJson({'force_update': '0'}).isForceUpdate,
          isFalse);
    });

    test('Push notification update payload detection correctly identifies update alerts', () {
      final fcmPayload = {
        'type': 'app_update',
        'target_version': '1.3.0',
        'download_url': 'https://hr.kneayerng.com',
        'force_update': '0',
      };
      final titleKm = 'មានកំណែអាប់ដេតថ្មី';
      final bodyKm = 'មានកំណែថ្មីនៃកម្មវិធី (1.3.0)។ សូមធ្វើបច្ចុប្បន្នភាពដើម្បីរីករាយជាមួយមុខងារថ្មីៗ និងការកែលម្អ។';

      final isUpdate = fcmPayload['type'] == 'app_update' ||
          fcmPayload.containsKey('target_version') ||
          titleKm.contains('អាប់ដេត') ||
          titleKm.toLowerCase().contains('update') ||
          bodyKm.contains('អាប់ដេត') ||
          bodyKm.toLowerCase().contains('update');

      expect(isUpdate, isTrue);
      expect(fcmPayload['download_url'], equals('https://hr.kneayerng.com'));
      expect(fcmPayload['target_version'], equals('1.3.0'));
    });
  });
}
