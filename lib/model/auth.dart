import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/data/source/network/model/login/Loginresponse.dart';
import 'package:cnattendance/utils/app_device_info.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:cnattendance/utils/fcm_token.dart';
import 'package:cnattendance/services/server_status_service.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cnattendance/core/ky_security/ky_http.dart';
import 'package:cnattendance/core/ky_security/ky_security_manager.dart';
import 'package:cnattendance/core/ky_security/ky_pairing_message.dart';
import 'package:flutter/foundation.dart';
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
    const headers = {'Accept': 'application/json; charset=UTF-8'};

    final fcm = await FcmToken.get().timeout(
      const Duration(seconds: 15),
      onTimeout: () => null,
    );
    if (!FcmToken.isValid(fcm)) {
      throw 'Unable to get device notification token. Please try again.';
    }

    if (kDebugMode) debugPrint('Login: preparing device details');
    final deviceDetails = await AppDeviceInfo.getDetails().timeout(
      const Duration(seconds: 5),
      onTimeout: () =>
          throw 'Could not read device details. Reopen the app and try again.',
    );
    final body = <String, String>{
      'username': username,
      'password': password,
      'fcm_token': fcm!,
      ...deviceDetails.toMap(),
    };

    final position = await _loginPosition().timeout(
      const Duration(seconds: 4),
      onTimeout: () => null,
    );
    if (position != null) {
      body['latitude'] = position.latitude.toString();
      body['longitude'] = position.longitude.toString();
    }

    if (kDebugMode) debugPrint('Login: resolving HR server');
    // Resolve before sending credentials to use the configured backup if needed.
    final server = Uri.parse(await preferences.getAppUrl());
    if (KySecurityManager.shared.securityApplies) {
      final problem = KySecurityManager.pairingTransportProblem(server);
      if (problem != null) throw kyPairingMessage(problem);
    }
    final uri = Uri.parse('$server${Constant.LOGIN_URL}');
    if (kDebugMode) debugPrint('Login: sending request to ${uri.host}');
    final http.Response response;
    try {
      response = await KyHttp.post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      if (kDebugMode) debugPrint('Login: request timed out');
      throw 'The HR server took too long to respond. Please try again.';
    } on TlsException {
      if (kDebugMode) debugPrint('Login: TLS verification failed');
      throw kyPairingMessage('tls_verification_failed');
    } on IOException catch (error) {
      if (kDebugMode)
        debugPrint('Login: connection failed (${error.runtimeType})');
      throw translate('connection_error.message');
    } on http.ClientException {
      if (kDebugMode) debugPrint('Login: HTTP connection failed');
      throw translate('connection_error.message');
    }

    final status = response.statusCode;
    if (kDebugMode) debugPrint('Login: HR server responded with HTTP $status');
    if (status >= 500) {
      throw 'The HR server could not complete sign-in (HTTP $status). Contact your administrator.';
    }

    const invalidResponse =
        'The HR server returned an invalid sign-in response.';
    final Object? responseData;
    try {
      responseData = jsonDecode(response.body);
    } on FormatException {
      throw '$invalidResponse (HTTP $status)';
    }
    if (responseData is! Map<String, dynamic>) {
      throw '$invalidResponse (HTTP $status)';
    }
    if (status != 200 || responseData['status'] != true) {
      final message = responseData['message'];
      if (message is String && message.trim().isNotEmpty) {
        throw message;
      }
      throw '$invalidResponse (HTTP $status)';
    }

    final Loginresponse loginResponse;
    try {
      loginResponse = Loginresponse.fromJson(responseData);
    } on TypeError {
      throw '$invalidResponse (HTTP $status)';
    } on NoSuchMethodError {
      throw '$invalidResponse (HTTP $status)';
    }
    await preferences.saveUser(loginResponse.data);
    if (kDebugMode) debugPrint('Login: credentials accepted and session saved');
    return loginResponse;
  }

  Future<Position?> _loginPosition() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        return await Geolocator.getLastKnownPosition() ??
            await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.medium,
                timeLimit: Duration(seconds: 3),
              ),
            );
      }
    } catch (error) {
      if (kDebugMode)
        debugPrint('Login: location unavailable (${error.runtimeType})');
    }
    return null;
  }
}
