import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:flutter/material.dart';
import 'package:cnattendance/data/source/network/model/login/Login.dart';
import 'package:cnattendance/data/source/network/model/login/User.dart';

class PrefProvider with ChangeNotifier {
  var _userName = '';
  var _userId = '';
  var _fullname = '';
  var _avatar = '';
  var _auth = false;
  var _attendanceType = "Default";

  String get userName {
    return _userName;
  }

  String get userId {
    return _userId;
  }

  String get fullname {
    return _fullname;
  }

  String get avatar {
    return _avatar;
  }

  String get attendanceType {
    return _attendanceType;
  }

  bool get auth {
    return _auth;
  }

  void getUser() async {
    Preferences preferences = Preferences();

    _userId = (await preferences.getUserId()).toString();
    _userName = await preferences.getUsername();
    _fullname = await preferences.getFullName();
    _avatar = await preferences.getAvatar();
    notifyListeners();
  }

  Future<bool> getUserAuth() async {
    Preferences preferences = Preferences();
    return await preferences.getUserAuth();
  }

  void saveUser(Login data) async {
    Preferences preferences = Preferences();
    preferences.saveUser(data);
    notifyListeners();
  }

  void saveBasicUser(User user) async {
    Preferences preferences = Preferences();
    preferences.saveBasicUser(user);
    notifyListeners();
  }

  void saveEngDateEnabled(bool value) async {
    Preferences preferences = Preferences();
    preferences.saveAppEng(value);
  }

  Future<bool> getIsAd() async {
    Preferences preferences = Preferences();
    return await preferences.getEnglishDate();
  }

  Future<String> getAttendanceType(List<String> attedanceMethod) async {
    Preferences preferences = Preferences();
    final storedType = await preferences.getAttendanceType();
    final available =
        attedanceMethod.map((method) => method.toLowerCase()).toList();
    final storedLower = storedType.toLowerCase();
    final isUserSet = await preferences.getAttendanceTypeUserSet();

    String desiredType;

    // If the user explicitly chose a method and backend still allows it, keep it.
    if (isUserSet && available.contains(storedLower)) {
      desiredType = storedType;
    }
    // Legacy behavior: keep a previously-saved non-default method if allowed.
    else if (available.contains(storedLower) && storedLower != "default") {
      desiredType = storedType;
    }
    // QR is primary by default when backend includes it.
    else if (available.contains("qr")) {
      desiredType = "QR";
    } else {
      desiredType = "Default";
    }

    if (desiredType != storedType) {
      // This is an auto-selection, not an explicit user choice.
      await preferences.saveAttendanceTypeUserSet(false);
      await preferences.saveAttendanceType(desiredType);
    }

    final previous = _attendanceType;
    _attendanceType = desiredType;
    if (previous != _attendanceType) {
      notifyListeners();
    }
    return desiredType;
  }

  void saveAuth(bool value) async {
    Preferences preferences = Preferences();
    preferences.saveUserAuth(value);

    _auth = await preferences.getUserAuth();
    notifyListeners();
  }

  void saveAttendanceType(String type) async {
    Preferences preferences = Preferences();
    await preferences.saveAttendanceTypeAsUserChoice(type);

    _attendanceType = await preferences.getAttendanceType();
    notifyListeners();
  }
}
