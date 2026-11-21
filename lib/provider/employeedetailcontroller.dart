import 'dart:convert';

import 'package:cnattendance/core/ky_security/ky_http.dart';
import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/data/source/network/model/employeedetailresponse/Data.dart';
import 'package:cnattendance/data/source/network/model/employeedetailresponse/employeedetailresponse.dart';
import 'package:cnattendance/repositories/teamsheetrepository.dart';
import 'package:cnattendance/utils/constant.dart';

typedef EmployeeDetail = ({
  String employeeId,
  Data profile,
  bool canViewPrivateDetails,
});

class EmployeeDetailController {
  EmployeeDetailController({
    Preferences? preferences,
    TeamSheetRepository? teamRepository,
  })  : _preferences = preferences ?? Preferences(),
        _teamRepository = teamRepository ?? TeamSheetRepository();

  final Preferences _preferences;
  final TeamSheetRepository _teamRepository;

  Future<EmployeeDetail> getEmployeeDetail(
    String employeeId, {
    String username = '',
  }) async {
    final id =
        employeeId.isEmpty ? await _findEmployeeId(username) : employeeId;
    final url = await _preferences.getAppUrl();
    final token = await _preferences.getToken();
    final uri = Uri.parse(
      '$url${Constant.EMPLOYEE_PROFILE_URL}/${Uri.encodeComponent(id)}',
    );

    final response = await KyHttp.get(uri, headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token',
    });
    if (response.statusCode != 200) {
      throw StateError(
          'Employee profile request failed (${response.statusCode})');
    }
    final result = employeedetailresponse.fromJson(jsonDecode(response.body));
    if (!result.status) {
      throw StateError('Employee profile is unavailable');
    }

    return (
      employeeId: id,
      profile: result.data,
      canViewPrivateDetails: (await _preferences.getUserId()).toString() == id,
    );
  }

  Future<String> _findEmployeeId(String username) async {
    if (username.isNotEmpty) {
      final directory = await _teamRepository.getChatContacts();
      for (final contact in [
        ...directory.contacts,
        ...directory.onlineContacts
      ]) {
        if (contact.usesAdminThread || contact.username.trim() != username) {
          continue;
        }
        final id = contact.id.trim();
        final sourceId = contact.sourceId.trim();
        if (id.isNotEmpty) return id;
        if (sourceId.isNotEmpty) return sourceId;
      }
    }
    throw StateError('Employee was not found in the chat directory');
  }
}
