import 'dart:convert';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/data/source/network/connect.dart';
import 'package:cnattendance/data/source/network/model/asssetlistresponse/assetlistresponse.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:flutter/material.dart';

class AssetRepository {
  Future<AssetListResponse> getAssets(int page) async {
    final Preferences preferences = Preferences();
    final String token = await preferences.getToken();

    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token'
    };

    try {
      final response = await Connect().getResponse(
          "${Constant.ASSETS_URL}?page=$page&per_page=100", headers);
      debugPrint(response.body.toString());

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        final dashboardResponse = AssetListResponse.fromJson(responseData);
        return dashboardResponse;
      } else {
        final errorMessage = responseData['message'];
        throw errorMessage;
      }
    } catch (e) {
      throw unknownError(e);
    }
  }

  Future<(bool, String)> writeResponse(
      String id, String userResponse, bool isWorking) async {
    final Preferences preferences = Preferences();
    final String token = await preferences.getToken();

    final Map<String, String> headers = {'Authorization': 'Bearer $token'};

    try {
      final response = await Connect().postResponse(
          "${Constant.ASSETS_RETURN_URL}$id",
          headers,
          {"notes": userResponse, "is_working": isWorking ? "yes" : "no"});

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return (true, responseData["message"].toString());
      } else {
        return (false, responseData["message"].toString());
      }
    } catch (e) {
      return (false, unknownError(e));
    }
  }
}
