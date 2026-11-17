import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/data/source/network/model/profile/Profile.dart';
import 'package:cnattendance/data/source/network/model/profile/Profileresponse.dart';
import 'package:cnattendance/model/profile.dart' as up;
import 'package:cnattendance/utils/constant.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:nepali_date_picker/nepali_date_picker.dart';

class ProfileProvider with ChangeNotifier {
  ProfileProvider({Preferences? preferences, http.Client? client})
      : _preferences = preferences ?? Preferences(),
        _client = client;

  final Preferences _preferences;
  final http.Client? _client;
  Future<Profileresponse>? _profileFuture;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  final up.Profile _profile = up.Profile(
    id: 0,
    avatar: '',
    name: '',
    username: '',
    email: '',
    post: '',
    phone: '',
    dob: '',
    gender: '',
    address: '',
    bankName: '',
    bankNumber: '',
    joinedDate: '',
    department: '',
    branch: '',
    bank_type: '',
    employment_type: '',
  );

  up.Profile get profile {
    return _profile;
  }

  Future<bool> isAd() async {
    final preferences = Preferences();
    final value = await preferences.getEnglishDate();

    return value;
  }

  Future<Profileresponse> getProfile() => _profileFuture ??=
      _loadProfile().whenComplete(() => _profileFuture = null);

  Future<Profileresponse> _loadProfile() async {
    final preferences = _preferences;
    final uri = Uri.parse(await preferences.getAppUrl() + Constant.PROFILE_URL);

    await checkValueInPref(preferences);

    final token = await preferences.getToken();

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token'
    };

    try {
      final response = await (_client?.get(uri, headers: headers) ??
          http.get(uri, headers: headers));

      final responseData = json.decode(response.body);
      if (response.statusCode == 200) {
        final responseJson = Profileresponse.fromJson(responseData);
        await parseUser(responseJson.data);

        return responseJson;
      } else {
        final errorMessage = responseData['message'];
        throw errorMessage;
      }
    } catch (error) {
      throw unknownError(error);
    }
  }

  Future<void> parseUser(Profile profile) async {
    final isAD = await _preferences.getEnglishDate();
    if (_disposed) return;

    _profile.id = profile.id;
    _profile.avatar = profile.avatar;
    _profile.name = profile.name;
    _profile.username = profile.username;
    _profile.email = profile.email;
    _profile.post = profile.post;
    _profile.phone = profile.phone;
    _profile.gender = profile.gender;
    _profile.address = profile.address;
    _profile.bankName = profile.bankName;
    _profile.bankNumber = profile.bankAccountNo;
    _profile.department = profile.department;
    _profile.branch = profile.branch;
    _profile.bank_type = profile.bankAccountType;
    _profile.employment_type = profile.employmentType;

    String displayDate(String value) {
      if (isAD || value.isEmpty) return value;
      final date = DateTime.tryParse(value);
      if (date == null) return '';
      return NepaliDateFormat('yyyy-MM-dd').format(date.toNepaliDateTime());
    }

    _profile.dob = displayDate(profile.dob);
    _profile.joinedDate = displayDate(profile.joiningDate);

    notifyListeners();
  }

  Future<void> checkValueInPref(Preferences preferences) async {
    final user = await preferences.getUser();
    if (_disposed) return;
    _profile.name = user.name;
    _profile.username = user.username;
    _profile.email = user.email;
    _profile.avatar = user.avatar;
    notifyListeners();
  }

  Future<Profileresponse> updateProfile(
      String name,
      String email,
      String address,
      String dob,
      String gender,
      String phone,
      File avatar) async {
    final preferences = Preferences();
    final uri =
        Uri.parse(await preferences.getAppUrl() + Constant.EDIT_PROFILE_URL);

    final token = await preferences.getToken();

    var formattedDob = "";
    if (dob != "") {
      formattedDob = (await isAd())
          ? dob
          : DateFormat("yyyy-MM-dd")
              .format(NepaliDateTime.parse(dob).toDateTime());
    }

    dynamic response;
    try {
      if (avatar.path != '') {
        final requests = http.MultipartRequest('POST', uri);

        final headers = <String, String>{
          'Accept': 'application/json; charset=UTF-8',
          'Content-type': 'multipart/form-data',
          'Authorization': 'Bearer $token'
        };

        final img.Image capturedImage =
            img.decodeImage(await File(avatar.path).readAsBytes())!;
        final img.Image orientedImage = img.bakeOrientation(capturedImage);
        final file =
            await File(avatar.path).writeAsBytes(img.encodeJpg(orientedImage));

        requests.files.add(
          http.MultipartFile(
            'avatar',
            file.readAsBytes().asStream(),
            await avatar.length(),
            filename: Random().hashCode.toString(),
          ),
        );

        requests.headers.addAll(headers);

        response = await requests.send();

        final responseBody =
            await response.stream.transform(utf8.decoder).join();
        final responseJson =
            Profileresponse.fromJson(json.decode(responseBody));
        if (responseJson.statusCode == 200) {
          await parseUser(responseJson.data);
          return responseJson;
        } else {
          final errorMessage = responseJson.message;
          throw errorMessage;
        }
      } else {
        final headers = <String, String>{
          'Accept': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token'
        };

        response = await http.post(uri, headers: headers, body: {
          'name': name,
          'email': email,
          'address': address,
          'dob': formattedDob,
          'gender': gender,
          'phone': phone,
        });

        final responseData = json.decode(response.body);
        if (response.statusCode == 200) {
          debugPrint(responseData.toString());
          final responseJson = Profileresponse.fromJson(responseData);

          await parseUser(responseJson.data);
          return responseJson;
        } else {
          final errorMessage = responseData['message'];
          throw errorMessage;
        }
      }
    } catch (error) {
      throw unknownError(error);
    }
  }
}
