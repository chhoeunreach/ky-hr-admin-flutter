import 'dart:convert';

import 'package:cnattendance/data/source/network/model/generalresponse.dart';
import 'package:cnattendance/data/source/network/model/leaveissue/IssueLeaveResponse.dart';
import 'package:cnattendance/data/source/network/model/leavetype/LeaveType.dart';
import 'package:cnattendance/data/source/network/model/leavetype/Leavetyperesponse.dart';
import 'package:cnattendance/data/source/network/model/leavetypedetail/LeaveTypeDetail.dart';
import 'package:cnattendance/data/source/network/model/leavetypedetail/Leavetypedetailreponse.dart';
import 'package:cnattendance/data/source/network/model/resignationresponse/resignationresponse.dart';
import 'package:cnattendance/model/LeaveDetail.dart';
import 'package:cnattendance/model/leave.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:cnattendance/core/ky_security/ky_http.dart';
import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:flutter/foundation.dart';

class LeaveProvider with ChangeNotifier {
  final List<Leave> _leaveList = [];
  final List<Leave> filterLeaveList = [];
  final List<LeaveDetail> _leaveDetailList = [];

  var _selectedMonth = 0;
  var _selectedType = -1;

  int get selectedMonth {
    return _selectedMonth;
  }

  void setMonth(int value) {
    _selectedMonth = value;
  }

  int get selectedType {
    return _selectedType;
  }

  void setType(int value) {
    _selectedType = value;
  }

  List<Leave> get leaveList {
    return [..._leaveList];
  }

  List<LeaveDetail> get leaveDetailList {
    return [..._leaveDetailList];
  }

  Future<bool> isAd() async {
    final Preferences preferences = Preferences();
    final value = await preferences.getEnglishDate();

    return value;
  }

  Future<Leavetyperesponse> getLeaveType() async {
    final Preferences preferences = Preferences();
    final uri =
        Uri.parse(await preferences.getAppUrl() + Constant.LEAVE_TYPE_URL);

    final String token = await preferences.getToken();

    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token'
    };

    final response = await KyHttp.get(uri, headers: headers);

    final responseData = json.decode(response.body);
    debugPrint(responseData.toString());

    final responseJson = Leavetyperesponse.fromJson(responseData);
    makeLeaveList(responseJson.data);

    return responseJson;
  }

  void makeLeaveList(List<LeaveType> leaveList) {
    _leaveList.clear();
    filterLeaveList.clear();

    for (var leave in leaveList) {
      _leaveList.add(Leave(
          id: int.tryParse(leave.leaveTypeId) ?? 0,
          name: leave.leaveTypeName,
          allocated: leave.leaveTaken,
          total: int.tryParse(leave.totalLeaveAllocated) ?? 0,
          status: leave.leaveTypeStatus,
          isEarlyLeave: leave.earlyExit));
    }

    filterLeaveList.add(Leave(
        id: -1,
        name: "All",
        allocated: "0",
        total: 0,
        status: true,
        isEarlyLeave: false));
    filterLeaveList.add(Leave(
        id: 0,
        name: "Time Leave",
        allocated: "0",
        total: 0,
        status: true,
        isEarlyLeave: false));
    filterLeaveList.addAll(_leaveList.where((element) => element.id != 0));

    notifyListeners();
  }

  Future<Leavetypedetailreponse> getLeaveTypeDetail() async {
    final Preferences preferences = Preferences();
    final queryParameters = <String, String>{};
    if (_selectedMonth != 0) {
      queryParameters['month'] = _selectedMonth.toString();
    }
    if (_selectedType != -1) {
      queryParameters['leave_type'] = _selectedType.toString();
    }

    final uri = Uri.parse(
            await preferences.getAppUrl() + Constant.LEAVE_TYPE_DETAIL_URL)
        .replace(
            queryParameters: queryParameters.isEmpty ? null : queryParameters);

    final String token = await preferences.getToken();

    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token'
    };

    try {
      final response = await KyHttp.get(uri, headers: headers);

      final responseData = json.decode(response.body);
      if (response.statusCode == 200) {
        debugPrint(responseData.toString());

        final responseJson = Leavetypedetailreponse.fromJson(responseData);

        makeLeaveTypeList(responseJson.data);

        return responseJson;
      } else {
        final errorMessage = responseData['message'];
        if (kDebugMode) debugPrint(errorMessage.toString());
        throw errorMessage;
      }
    } catch (error) {
      if (kDebugMode) debugPrint(error.toString());
      throw unknownError(error);
    }
  }

  void makeLeaveTypeList(List<LeaveTypeDetail> leaveList) {
    _leaveDetailList.clear();

    for (var leave in leaveList) {
      _leaveDetailList.add(LeaveDetail(
          id: leave.id,
          leavetypeId: leave.leaveTypeId,
          name: leave.leaveTypeName,
          leave_from: leave.leaveFrom,
          leave_to: leave.leaveTo,
          requested_date: leave.leaveRequestedDate,
          authorization: leave.statusUpdatedBy,
          status: leave.status));
    }

    notifyListeners();
  }

  Future<IssueLeaveResponse> issueLeave(String date, String from, String to,
      String reason, int leaveId, int earlyLeave) async {
    final Preferences preferences = Preferences();
    final uri = Uri.parse(await preferences.getAppUrl() + Constant.ISSUE_LEAVE);

    final String token = await preferences.getToken();

    final Map<String, String> headers = {
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token'
    };

    try {
      final response = await KyHttp.post(uri, headers: headers, body: {
        'issue_date': date,
        'leave_from': from,
        'leave_to': to,
        'leave_type_id': leaveId.toString(),
        'reasons': reason,
        'early_exit': earlyLeave.toString(),
      });

      final responseData = json.decode(response.body);
      if (response.statusCode == 200) {
        final responseJson = IssueLeaveResponse.fromJson(responseData);

        debugPrint(responseJson.toString());
        return responseJson;
      } else {
        final errorMessage = responseData['message'];
        throw errorMessage;
      }
    } catch (error) {
      throw unknownError(error);
    }
  }

  Future<IssueLeaveResponse> issueTimeLeave(
      String date, String from, String to, String reason) async {
    final Preferences preferences = Preferences();
    final uri =
        Uri.parse(await preferences.getAppUrl() + Constant.ISSUE_TIME_LEAVE);

    final String token = await preferences.getToken();

    final Map<String, String> headers = {
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token'
    };

    try {
      final response = await KyHttp.post(uri, headers: headers, body: {
        'issue_date': date,
        'leave_from': from,
        'leave_to': to,
        'reasons': reason,
      });

      final responseData = json.decode(response.body);
      if (response.statusCode == 200) {
        final responseJson = IssueLeaveResponse.fromJson(responseData);

        debugPrint(responseJson.toString());
        return responseJson;
      } else {
        final errorMessage = responseData['message'];
        debugPrint(errorMessage.toString());
        throw errorMessage;
      }
    } catch (error) {
      debugPrint(error.toString());
      throw unknownError(error);
    }
  }

  Future<GeneralResponse> issueResignation(String from, String reason) async {
    final Preferences preferences = Preferences();
    final uri = Uri.parse(
        await preferences.getAppUrl() + Constant.APPLY_RESIGNATION_URL);

    final String token = await preferences.getToken();

    final Map<String, String> headers = {
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token'
    };

    try {
      final response = await KyHttp.post(uri, headers: headers, body: {
        'last_working_day': from,
        'reason': reason,
      });

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        final responseJson = GeneralResponse.fromJson(responseData);

        debugPrint(responseJson.toString());
        return responseJson;
      } else {
        final errorMessage = responseData['message'];
        throw errorMessage;
      }
    } catch (error) {
      throw unknownError(error);
    }
  }

  Future<ResignationRepsonse> getResignation() async {
    final Preferences preferences = Preferences();
    final uri =
        Uri.parse(await preferences.getAppUrl() + Constant.RESIGNATION_URL);

    final String token = await preferences.getToken();

    final Map<String, String> headers = {
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token'
    };

    try {
      final response = await KyHttp.get(uri, headers: headers);

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        final responseJson = ResignationRepsonse.fromMap(responseData);

        debugPrint(responseJson.toString());
        return responseJson;
      } else {
        final errorMessage = responseData['message'];
        throw errorMessage;
      }
    } catch (error) {
      throw unknownError(error);
    }
  }

  Future<IssueLeaveResponse> cancelLeave(
      int leaveId, String leaveTypeId) async {
    final Preferences preferences = Preferences();
    late Uri uri;

    if (leaveTypeId == "0") {
      uri = Uri.parse(await preferences.getAppUrl() +
          Constant.CANCEL_TIME_LEAVE +
          "/$leaveId");
    } else {
      uri = Uri.parse(
          await preferences.getAppUrl() + Constant.CANCEL_LEAVE + "/$leaveId");
    }

    final String token = await preferences.getToken();

    final Map<String, String> headers = {
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token'
    };

    try {
      final response = await KyHttp.get(uri, headers: headers);

      final responseData = json.decode(response.body);
      if (response.statusCode == 200) {
        final responseJson = IssueLeaveResponse.fromJson(responseData);

        debugPrint(responseJson.toString());
        return responseJson;
      } else {
        final errorMessage = responseData['message'];
        throw errorMessage;
      }
    } catch (error) {
      throw unknownError(error);
    }
  }
}
