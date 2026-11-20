import 'dart:convert';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/data/source/network/model/logout/Logoutresponse.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:cnattendance/core/ky_security/ky_http.dart';
import 'package:cnattendance/core/ky_security/ky_security_manager.dart';
import 'package:http_interceptor_plus/http_interceptor_plus.dart';

class MoreScreenProvider with ChangeNotifier {
  Map<String, String> features = {};
  bool showNfc = false;

  void changeAttendanceMethod(String type) {
    final Preferences preferences = Preferences();
    preferences.saveAttendanceType(type);
    notifyListeners();
  }

  Future<void> getFeatures() async {
    try {
      final Preferences preferences = Preferences();
      final loadedFeatures = await preferences.getFeatures();
      features = loadedFeatures;
      showNfc = await preferences.getShowNfc();
      notifyListeners();
    } catch (e) {
      debugPrint('getFeatures error: $e');
    }
  }

  Future<Logoutresponse> logout() async {
    final Preferences preferences = Preferences();
    final uri = Uri.parse(await preferences.getAppUrl() + Constant.LOGOUT_URL);

    final String token = await preferences.getToken();

    final Map<String, String> headers = {
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token'
    };

    try {
      final response = await KyHttp.accountLogout(uri, headers: headers);
      debugPrint(response.body.toString());

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 || response.statusCode == 401) {
        final jsonResponse = Logoutresponse.fromJson(responseData);

        KySecurityManager.shared.clearLocalSession();
        await preferences.clearPrefs();
        await preferences.setCompanyVerifyRequired(true);
        features = {};
        showNfc = false;
        notifyListeners();
        return jsonResponse;
      } else {
        final errorMessage = responseData['message'];
        throw errorMessage;
      }
    } catch (e) {
      throw e;
    }
  }

  Future<String> getDeviceName() async {
    final Map deviceInfo = (await DeviceInfoPlugin().deviceInfo).data;
    final String? brand = deviceInfo['brand'];
    final String? model = deviceInfo['model'];
    final String? name = deviceInfo['name'];

    return ("${name ?? ""} ${brand ?? ""} ${model ?? ""}");
  }

  Future<void> addNfcApi(String title, String identifier) async {
    final Preferences preferences = Preferences();
    final uri = Uri.parse(await preferences.getAppUrl() + Constant.ADD_NFC_URL);

    final String token = await preferences.getToken();

    final Map<String, String> headers = {
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token'
    };

    final http.Client client = LoggingMiddleware(http.Client());

    final response = await KyHttp.postWithClient(client, uri, headers: headers, body: {
      'title': await getDeviceName(),
      'identifier': identifier,
    });

    final responseData = json.decode(response.body);

    if (response.statusCode == 200) {
    } else {
      final errorMessage = responseData['message'];
      throw errorMessage;
    }
  }
}
