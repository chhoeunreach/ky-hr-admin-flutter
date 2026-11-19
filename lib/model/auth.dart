import 'dart:convert';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/data/source/network/model/login/Loginresponse.dart';
import 'package:cnattendance/utils/app_device_info.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:cnattendance/utils/fcm_token.dart';
import 'package:cnattendance/services/server_status_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class Auth with ChangeNotifier {
  String appUrl = "";
  Preferences preferences = Preferences();

  Future<void> saveAppUrl(String value) async {
    try {
      final result = await ServerStatusService(preferences: preferences)
          .switchServer(value);
      if (!result.isConnected) {
        showToast(result.message);
        return;
      }
      await preferences.setCompanyVerifyRequired(false);
      appUrl = await preferences.getAppUrl();
      notifyListeners();
    } catch (e) {
      showToast(translate('alerts.invalid_qr'));
    }
  }

  Future<void> resetAppUrl() async {
    await preferences.saveAppUrl("");
    await preferences.setCompanyVerifyRequired(true);
    appUrl = "";
    notifyListeners();
  }

  Future<void> skipAppUrl() async {
    await preferences.saveAppUrl(Constant.appUrl);
    await preferences.setCompanyVerifyRequired(false);
    appUrl = await preferences.getAppUrl();
    notifyListeners();
  }

  Future<void> getAppUrl() async {
    if (await preferences.getCompanyVerifyRequired()) {
      appUrl = "";
      notifyListeners();
      return;
    }
    appUrl = await preferences.getAppUrl();
    notifyListeners();
  }

  Future<Loginresponse> login(String username, String password) async {
    Map<String, String> headers = {"Accept": "application/json; charset=UTF-8"};

    try {
      final fcm = await FcmToken.get();
      if (!FcmToken.isValid(fcm)) {
        throw "Unable to get device notification token. Please try again.";
      }

      debugPrint('Login FCM token: ${FcmToken.mask(fcm)}');
      debugPrint('Uploading login FCM token for user: $username');
      final deviceDetails = await AppDeviceInfo.getDetails();
      final body = <String, String>{
        'username': username,
        'password': password,
        'fcm_token': fcm!,
        'device_type': deviceDetails.deviceType,
        'uuid': deviceDetails.uuid,
        'device_name': deviceDetails.deviceName,
        'device_model': deviceDetails.deviceModel,
        'os_version': deviceDetails.osVersion,
        'app_name': deviceDetails.appName,
        'app_version': deviceDetails.appVersion,
        'app_build': deviceDetails.appBuild,
      };

      try {
        final permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse) {
          final position = await Geolocator.getLastKnownPosition() ??
              await Geolocator.getCurrentPosition(
                locationSettings: const LocationSettings(
                  accuracy: LocationAccuracy.medium,
                  timeLimit: Duration(seconds: 3),
                ),
              );
          body['latitude'] = position.latitude.toString();
          body['longitude'] = position.longitude.toString();
        }
      } catch (_) {}

      // Resolve immediately before sending credentials so an unavailable primary
      // does not prevent login through the company's configured backup.
      final uri = Uri.parse(await preferences.getAppUrl() + Constant.LOGIN_URL);
      final response = await http.post(uri, headers: headers, body: body);

      final responseData = json.decode(response.body);
      if (response.statusCode == 200 && responseData['status'] == true) {
        debugPrint('Login success and FCM token submitted for user: $username');

        final responseJson = Loginresponse.fromJson(responseData);
        await preferences.saveUser(responseJson.data);

        return responseJson;
      } else {
        var errorMessage = responseData['message'];
        throw errorMessage;
      }
    } catch (error) {
      throw error;
    }
  }
}
