import 'package:cnattendance/data/source/network/model/dashboard/Feature.dart';
import 'package:cnattendance/data/source/network/model/dashboard/RecentAward.dart';
import 'package:cnattendance/data/source/network/model/eventlistresponse/eventdetailresponse.dart';
import 'package:cnattendance/data/source/network/model/hollidays/Holidays.dart';
import 'package:cnattendance/data/source/network/model/teamsheet/Employee.dart'
    as employees;
import 'package:cnattendance/data/source/network/model/trainingresponse/trainingresponse.dart';

import 'User.dart';
import 'EmployeeTodayAttendance.dart';
import 'Overview.dart';
import 'OfficeTime.dart';
import 'Company.dart';

class Dashboard {
  Dashboard({
    required this.user,
    required this.employeeTodayAttendance,
    required this.overview,
    required this.officeTime,
    required this.company,
    required this.employeeWeeklyReport,
    required this.shift_dates,
    required this.attedanceMethod,
    required this.dateInAd,
    required this.addNfc,
    required this.attendance_note,
    required this.attendance_selfie,
    required this.attendance_map,
    required this.attendance_map_url,
    required this.attendance_location_radius_enabled,
    required this.employee_location,
    required this.employee,
    required this.features,
    required this.holiday,
    required this.recentAward,
    this.recentTraining,
    this.recentEvent,
    this.appVersionInfo,
  });

  factory Dashboard.fromJson(dynamic json) {
    return Dashboard(
      user: User.fromJson(json['user']),
      employeeTodayAttendance:
          EmployeeTodayAttendance.fromJson(json['employee_today_attendance']),
      overview: Overview.fromJson(json['overview']),
      officeTime: OfficeTime.fromJson(json['office_time']),
      company: Company.fromJson(json['company']),
      employeeWeeklyReport: json['employee_weekly_report'],
      shift_dates: List.from(json['shift_dates']),
      attedanceMethod: List.from(json['attendance_method']),
      dateInAd: json['date_in_ad'],
      addNfc: json['add_nfc'] ?? true,
      attendance_note: json['attendance_note'] ?? false,
      attendance_selfie: json['attendance_selfie'] ?? false,
      attendance_map: json['attendance_map'] ?? true,
      attendance_map_url: (json['attendance_map_url'] ?? '').toString(),
      attendance_location_radius_enabled: _readRadiusEnabled(
          json['attendance_location_radius_enabled'] ??
              json['workspace_location']?['radius_enabled'] ??
              json['workspace_location']
                  ?['attendance_location_radius_enabled']),
      employee: json["teamMembers"] != null
          ? List<employees.Employee>.from(
              json['teamMembers'].map((x) => employees.Employee.fromJson(x)))
          : [],
      features:
          (json['features'] as List).map((i) => Feature.fromJson(i)).toList(),
      holiday: json["recent_holiday"] != null
          ? Holidays.fromJson(json["recent_holiday"])
          : null,
      employee_location:
          json["employee_location"] != null ? json["employee_location"] : false,
      recentAward: json["recent_award"] != null
          ? RecentAward.fromJson(json['recent_award'])
          : null,
      recentTraining: json["recent_training"] != null
          ? Training.fromMap(json['recent_training'])
          : null,
      recentEvent: json["recent_event"] != null
          ? EventApi.fromMap(json['recent_event'])
          : null,
      appVersionInfo: json['app_version'] != null
          ? AppVersionInfo.fromJson(json['app_version'])
          : null,
    );
  }

  User user;
  List<Feature> features;
  EmployeeTodayAttendance employeeTodayAttendance;
  Overview overview;
  OfficeTime officeTime;
  Company company;
  List<dynamic> employeeWeeklyReport;
  List<String> shift_dates;
  List<String> attedanceMethod;
  bool dateInAd;
  bool addNfc;
  bool attendance_note;
  bool attendance_selfie;
  bool attendance_map;
  String attendance_map_url;
  bool attendance_location_radius_enabled;
  bool employee_location;
  List<employees.Employee> employee;
  Holidays? holiday;
  RecentAward? recentAward;
  Training? recentTraining;
  EventApi? recentEvent;
  AppVersionInfo? appVersionInfo;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['user'] = user.toJson();
    map['employee_today_attendance'] = employeeTodayAttendance.toJson();
    map['overview'] = overview.toJson();
    map['office_time'] = officeTime.toJson();
    map['company'] = company.toJson();
    map['employee_weekly_report'] =
        employeeWeeklyReport.map((v) => v.toJson()).toList();
    return map;
  }
}

class AppVersionInfo {
  final String latestVersion;
  final String minVersion;
  final String downloadUrl;
  final String releaseNotes;
  final String alertTitle;
  final bool isForceUpdate;
  final bool showAlert;
  final bool isUpdateAvailable;

  AppVersionInfo({
    required this.latestVersion,
    required this.minVersion,
    required this.downloadUrl,
    required this.releaseNotes,
    this.alertTitle = '',
    required this.isForceUpdate,
    this.showAlert = false,
    this.isUpdateAvailable = false,
  });

  factory AppVersionInfo.fromJson(dynamic json) {
    if (json == null || json is! Map) {
      return AppVersionInfo(
        latestVersion: '',
        minVersion: '',
        downloadUrl: 'https://hr.kneayerng.com',
        releaseNotes: '',
        alertTitle: '',
        isForceUpdate: false,
        showAlert: false,
        isUpdateAvailable: false,
      );
    }
    return AppVersionInfo(
      latestVersion: (json['latest_version'] ?? json['target_version'] ?? json['version'] ?? '').toString(),
      minVersion: (json['min_required_version'] ?? json['min_version'] ?? '').toString(),
      downloadUrl: (json['download_url'] ?? json['android_url'] ?? json['url'] ?? 'https://hr.kneayerng.com').toString(),
      releaseNotes: (json['update_message'] ?? json['alert_message'] ?? json['release_notes'] ?? '').toString(),
      alertTitle: (json['alert_title'] ?? '').toString(),
      isForceUpdate: json['is_force_update'] == true ||
          json['force_update'] == true ||
          json['is_update_required'] == true ||
          json['force_update'] == 1 ||
          json['is_force_update'] == 1 ||
          json['is_force_update'] == '1',
      showAlert: json['show_alert'] == true ||
          json['is_update_available'] == true ||
          json['is_update_required'] == true,
      isUpdateAvailable: json['is_update_available'] == true,
    );
  }
}

bool _readRadiusEnabled(dynamic value) {
  if (value == null) return true;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = value.toString().toLowerCase().trim();
  return normalized == '1' || normalized == 'true' || normalized == 'yes';
}
