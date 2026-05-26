import 'dart:convert';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/data/source/network/connect.dart';
import 'package:cnattendance/data/source/network/model/advancesalarycreate/adavancesalarycreateresponse.dart';
import 'package:cnattendance/data/source/network/model/advancesalarylist/adavancesalaryresponse.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:flutter/material.dart';

class AdminAdvanceSalaryRepository {
  Future<AdavanceSalaryResponse> getAdminAdvanceList() async {
    Preferences preferences = Preferences();
    String token = await preferences.getToken();

    Map<String, String> headers = {
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token'
    };

    try {
      final response = await Connect()
          .getResponse(Constant.ADMIN_ADVANCE_SALARY_LIST_URL, headers);
      debugPrint(response.body.toString());

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return AdavanceSalaryResponse.fromJson(responseData);
      } else {
        var errorMessage = responseData['message'];
        throw errorMessage;
      }
    } catch (e) {
      throw unknownError(e);
    }
  }

  Future<AdavanceSalaryCreateResponse> createAdminAdvanceSalary({
    required String reqAmt,
    required String desc,
  }) async {
    Preferences preferences = Preferences();
    String token = await preferences.getToken();

    Map<String, String> headers = {
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token'
    };

    try {
      final response = await Connect()
          .postResponse(Constant.ADMIN_ADVANCE_SALARY_CREATE_URL, headers, {
        "requested_amount": reqAmt,
        "description": desc,
      });

      debugPrint(response.body.toString());
      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return AdavanceSalaryCreateResponse.fromJson(responseData);
      } else {
        var errorMessage = responseData['message'];
        throw errorMessage;
      }
    } catch (e) {
      throw unknownError(e);
    }
  }
}

