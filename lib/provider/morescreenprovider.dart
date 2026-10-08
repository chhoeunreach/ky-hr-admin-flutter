import 'dart:convert';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/data/source/network/model/logout/Logoutresponse.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:http_interceptor_plus/http_interceptor_plus.dart';

class MoreScreenProvider with ChangeNotifier {
  Map<String, String> features = {
    "project-management": "1",
    "meeting": "1",
    "tada": "1",
    "payroll-management": "1",
    "advance-salary": "1",
    "advance-salary-approve": "0",
    "advance-salary-admin": "0",
    "support": "1",
    "dark-mode": "1",
    "attendance": "1",
    "leave-request": "1",
    "time-leave": "1",
    "holiday": "1",
    "notice": "1",
    "sell-staff-report": "1",
    "nfc-qr": "1",
    "award": "1",
    "training": "1",
    "loan": "1",
    "event": "1",
    "complaint": "1",
    "warning": "1",
    "resignation": "1",
    "assets": "1",
    "social-rewards": "0",
    "social-rewards-admin": "0",
  };
  bool showNfc = true;

  void changeAttendanceMethod(String type) {
    Preferences preferences = Preferences();
    preferences.saveAttendanceType(type);
    notifyListeners();
  }

  Future<void> getFeatures() async {
    try {
      Preferences preferences = Preferences();
      final loadedFeatures = await preferences.getFeatures();
      if (loadedFeatures.isNotEmpty) {
        features = loadedFeatures;
      }
      showNfc = await preferences.getShowNfc();
      notifyListeners();
    } catch (e) {
      debugPrint('getFeatures error: $e');
    }
  }

  Future<Logoutresponse> logout() async {
    Preferences preferences = Preferences();
    var uri = Uri.parse(await preferences.getAppUrl()+Constant.LOGOUT_URL);

    String token = await preferences.getToken();

    Map<String, String> headers = {
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token'
    };

    try {
      final response = await http.get(uri, headers: headers);
      debugPrint(response.body.toString());

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 || response.statusCode == 401) {
        final jsonResponse = Logoutresponse.fromJson(responseData);

        preferences.clearPrefs();
        return jsonResponse;
      } else {
        var errorMessage = responseData['message'];
        throw errorMessage;
      }
    } catch (e) {
      throw e;
    }
  }

  Future<String> getDeviceName() async {
    Map deviceInfo = (await DeviceInfoPlugin().deviceInfo).data;
    String? brand = deviceInfo['brand'];
    String? model = deviceInfo['model'];
    String? name = deviceInfo['name'];

    return ("${name??""} ${brand??""} ${model??""}");
  }

  Future<void> addNfcApi(String title, String identifier) async {
    Preferences preferences = Preferences();
    var uri = Uri.parse(await preferences.getAppUrl()+Constant.ADD_NFC_URL);

    String token = await preferences.getToken();

    Map<String, String> headers = {
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token'
    };

    final http.Client client = LoggingMiddleware(http.Client());

    final response = await client.post(uri, headers: headers, body: {
      'title': await getDeviceName(),
      'identifier': identifier,
    });

    final responseData = json.decode(response.body);

    if (response.statusCode == 200) {
    } else {
      var errorMessage = responseData['message'];
      throw errorMessage;
    }
  }
}
