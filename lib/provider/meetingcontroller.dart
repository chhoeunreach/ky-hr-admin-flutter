import 'dart:convert';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/data/source/network/model/meeting/MeetingDomain.dart';
import 'package:cnattendance/data/source/network/model/meeting/MeetingReponse.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';
import 'package:cnattendance/core/ky_security/ky_http.dart';

class MeetingController extends GetxController {
  static int per_page = 10;
  int page = 1;

  var _meetingList = <MeetingDomain>[].obs;

  List<MeetingDomain> get meetingList {
    return [..._meetingList];
  }

  Future<MeetingReponse> getMeetingList() async {
    final Preferences preferences = Preferences();
    final uri = Uri.parse(await preferences.getAppUrl()+Constant.MEETING_URL).replace(queryParameters: {
      'page': page.toString(),
      'per_page': per_page.toString(),
    });

    final String token = await preferences.getToken();

    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token'
    };

    try {
      EasyLoading.show(status: translate('loader.loading'),maskType: EasyLoadingMaskType.black);
      final response = await KyHttp.get(uri, headers: headers);
      EasyLoading.dismiss(animation: true);
      final responseData = json.decode(response.body);
      if (response.statusCode == 200) {
        debugPrint(responseData.toString());

        final responseJson = MeetingReponse.fromJson(responseData);

        makeMeetingList(responseJson.data);
        return responseJson;
      } else {
        final errorMessage = responseData['message'];
        throw errorMessage;
      }
    } catch (error) {
      EasyLoading.dismiss(animation: true);
      throw error;
    }
  }

  void makeMeetingList(List<MeetingDomain> data) {
    if (page == 1) {
      _meetingList.clear();
    }

    if (data.isNotEmpty) {
      for (var item in data) {
        _meetingList.add(item);
      }

      page += page;
    }
  }

  @override
  void onReady() {
    getMeetingList();
    super.onReady();
  }
}
