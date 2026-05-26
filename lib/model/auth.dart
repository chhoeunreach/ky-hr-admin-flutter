import 'dart:convert';
import 'dart:io';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/data/source/network/model/login/Loginresponse.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cnattendance/utils/deviceuuid.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:cnattendance/utils/fcm_token.dart';

class Auth with ChangeNotifier {
  String appUrl = "";
  Preferences preferences = Preferences();

  Future<void> saveAppUrl(String value) async {
    try {
      String decoded = utf8.decode(base64.decode(value));

      if (!decoded.contains("http")) {
        showToast("Invalid QR Code");
        return;
      }
      preferences.saveAppUrl(decoded);
      appUrl = await preferences.getAppUrl();
      notifyListeners();
    } catch (e) {
      showToast("Invalid QR Code, Try again");
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
      final response = await http.post(uri, headers: headers, body: {
        'username': username,
        'password': password,
        'fcm_token': fcm!,
        'device_type': Platform.isIOS ? 'ios' : 'android',
        'uuid': await DeviceUUid().getUniqueDeviceId(),
      });

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
