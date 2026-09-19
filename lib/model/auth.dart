import 'dart:convert';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/data/source/network/model/login/Loginresponse.dart';
import 'package:cnattendance/utils/app_device_info.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:cnattendance/utils/fcm_token.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class Auth with ChangeNotifier {
  String appUrl = "";
  Preferences preferences = Preferences();

  Future<void> saveAppUrl(String value) async {
    try {
      String decoded = utf8.decode(base64.decode(value));

      if (!decoded.contains("http")) {
        showToast(translate('alerts.invalid_qr'));
        return;
      }
      preferences.saveAppUrl(decoded);
      appUrl = await preferences.getAppUrl();
      notifyListeners();
    } catch (e) {
      showToast(translate('alerts.invalid_qr'));
    }
  }

  Future<void> resetAppUrl() async {
    preferences.saveAppUrl("");
    appUrl = await preferences.getAppUrl();
    notifyListeners();
  }

  Future<void> skipAppUrl() async {
    preferences.saveAppUrl(Constant.appUrl);
    appUrl = await preferences.getAppUrl();
    notifyListeners();
  }

  Future<void> getAppUrl() async {
    appUrl = await preferences.getAppUrl();
    notifyListeners();
  }

  Future<Loginresponse> login(String username, String password) async {
    var uri = Uri.parse(await preferences.getAppUrl() + Constant.LOGIN_URL);
    print(uri);

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

      final response = await http.post(uri, headers: headers, body: body);

      final responseData = json.decode(response.body);
      if (response.statusCode == 200) {
        debugPrint('Login success and FCM token submitted for user: $username');

        Preferences preferences = Preferences();
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
