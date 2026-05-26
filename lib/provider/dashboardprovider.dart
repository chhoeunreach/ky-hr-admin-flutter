import 'dart:convert';
import 'dart:core';
import 'dart:developer';
import 'dart:math' as Random;

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/data/source/network/model/attendancestatus/AttendanceStatusResponse.dart';
import 'package:cnattendance/data/source/network/model/dashboard/Dashboardresponse.dart';
import 'package:cnattendance/data/source/network/model/dashboard/EmployeeTodayAttendance.dart';
import 'package:cnattendance/data/source/network/model/dashboard/Feature.dart';
import 'package:cnattendance/data/source/network/model/dashboard/Overview.dart';
import 'package:cnattendance/data/source/network/model/eventlistresponse/eventdetailresponse.dart';
import 'package:cnattendance/data/source/network/model/teamsheet/Employee.dart'
    as employees;
import 'package:cnattendance/data/source/network/model/trainingresponse/trainingresponse.dart';
import 'package:cnattendance/model/award.dart';
import 'package:cnattendance/model/holiday.dart';
import 'package:cnattendance/screen/auth/login_screen.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:cnattendance/utils/fcm_token.dart';
import 'package:cnattendance/utils/locationstatus.dart';
import 'package:cnattendance/utils/wifiinfo.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:http/http.dart' as http;
import 'package:http_interceptor_plus/http_interceptor_plus.dart';
import 'package:intl/intl.dart';
import 'package:nepali_date_picker/nepali_date_picker.dart';

class DashboardProvider with ChangeNotifier {
  final Map<String, String> _overviewList = {
    'present': '0',
    'holiday': '0',
    'leave': '0',
    'request': '0',
    'total_project': '0',
    'total_task': '0',
    'total_awards': '0',
    'active_training': '0',
    'active_event': '0',
  };

  late Map<String, String> features = {};

  final Map<String, double> locationStatus = {
    'latitude': 0.0,
    'longitude': 0.0,
  };

  static const Duration _locationCacheTtl = Duration(seconds: 10);
  static const double _defaultWorkspaceRadiusMeters = 100;
  static const double scanAttendanceMaxDistanceMeters = 100;
  DateTime? _lastLocationRefreshAt;
  final Map<String, String> _addressCache = {};

  var department = "";
  var branch = "";

  Map<String, String> get overviewList {
    return _overviewList;
  }

  final Map<String, dynamic> _attendanceList = {
    'check-in': '-',
    'check-out': '-',
    'production_hour': '0 hr 0 min',
    'production-time': 0.0
  };

  List<employees.Employee> employeeList = [];

  bool isAD = true;
  bool isNoteEnabled = false;
  bool isLocationEnabled = false;
  bool animated = true;
  bool isBirthdayWished = false;
  List<String> attendanceMethods = [];
  double? currentLocationAccuracyMeters;

  double? workspaceLatitude;
  double? workspaceLongitude;
  double? workspaceRadiusMeters;
  double? lastWorkspaceDistanceMeters;

  Holiday? holiday;
  Award? award;
  Training? training;
  EventApi? event;

  final noteController = TextEditingController();

  Map<String, dynamic> get attendanceList {
    return _attendanceList;
  }

  final List<double> _weeklyReport = [];

  List<double> get weeklyReport {
    return _weeklyReport;
  }

  List<BarChartGroupData> barchartValue = [];

  List<BarChartGroupData> rawBarGroups = [];
  List<BarChartGroupData> showingBarGroups = [];

  void buildgraph() {
    const int daysInWeek = 7;
    for (int i = 0; i < daysInWeek; i++) {
      barchartValue.add(makeGroupData(i, 0));
    }

    rawBarGroups.addAll(barchartValue);
    showingBarGroups.addAll(rawBarGroups);
  }

  Future<void> checkAD() async {
    Preferences preferences = Preferences();
    isAD = await preferences.getEnglishDate();
    notifyListeners();
  }

  Future<void> getFeatures() async {
    Preferences preferences = Preferences();
    features = await preferences.getFeatures();
    notifyListeners();
  }

  Future<Dashboardresponse> getDashboard() async {
    Preferences preferences = Preferences();
    animated = getAnimation();
    var uri = Uri.parse(await preferences.getAppUrl() + Constant.DASHBOARD_URL);

    String token = await preferences.getToken();

    final fcm = await FcmToken.get(retries: 1);

    Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token',
    };

    if (FcmToken.isValid(fcm)) {
      headers['fcm_token'] = fcm!;
      debugPrint('Dashboard FCM refresh token: ${FcmToken.mask(fcm)}');
    } else {
      debugPrint('Dashboard FCM refresh skipped: token missing');
    }

    final response = await http.get(uri, headers: headers);
    log(response.body.toString());
    final responseData = json.decode(response.body);

    if (response.statusCode == 200) {
      _updateWorkspaceLocationFromResponse(responseData);
      final dashboardResponse = Dashboardresponse.fromJson(responseData);

      department = dashboardResponse.data.user.department;
      branch = dashboardResponse.data.user.branch;

      if (dashboardResponse.data.user.dob != "") {
        final dob =
            DateFormat("yyyy-MM-dd").parse(dashboardResponse.data.user.dob);
        final currentDate = DateTime.now();
        final isBirthday =
            dob.month == currentDate.month && currentDate.day == dob.day;

        if (isBirthday) {
          if (!await preferences.getBirthdayWished()) {
            isBirthdayWished = false;
            preferences.saveBirthdayWished(true);
          } else {
            isBirthdayWished = true;
          }
        } else {
          preferences.saveBirthdayWished(false);
          isBirthdayWished = true;
        }
      }

      updateAttendanceStatus(dashboardResponse.data.employeeTodayAttendance);
      updateOverView(dashboardResponse.data.overview);

      makeWeeklyReport(dashboardResponse.data.employeeWeeklyReport);
      controlFeatures(dashboardResponse.data.features);
      await preferences.saveUserDashboard(dashboardResponse.data.user);

      employeeList = dashboardResponse.data.employee;
      preferences.saveShowNfc(dashboardResponse.data.addNfc);
      preferences.saveNote(dashboardResponse.data.attendance_note);
      preferences
          .saveEmployeeLocation(dashboardResponse.data.employee_location);
      isNoteEnabled = await preferences.getNote();
      isLocationEnabled = await preferences.getEnableLocation();

      final holidayResponse = dashboardResponse.data.holiday;
      final recentAwardResponse = dashboardResponse.data.recentAward;
      event = dashboardResponse.data.recentEvent;
      training = dashboardResponse.data.recentTraining;

      if (holidayResponse != null) {
        bool isAd = await preferences.getEnglishDate();
        DateTime tempDate =
            DateFormat("yyyy-MM-dd").parse(holidayResponse.eventDate);

        NepaliDateTime nepaliDate = tempDate.toNepaliDateTime();
        holiday = Holiday(
            id: holidayResponse.id,
            day: isAd
                ? DateFormat('dd').format(tempDate)
                : NepaliDateFormat('dd').format(nepaliDate),
            month: isAd
                ? DateFormat('MMM').format(tempDate)
                : NepaliDateFormat('MMMM').format(nepaliDate),
            title: holidayResponse.event,
            description: holidayResponse.description,
            dateTime: tempDate,
            isPublicHoliday: holidayResponse.isPublicHoliday);
      } else {
        holiday = null;
      }

      if (recentAwardResponse != null) {
        award = Award(
            award_description: recentAwardResponse.award_description,
            award_name: recentAwardResponse.award_name,
            awarded_by: recentAwardResponse.awarded_by,
            awarded_date: recentAwardResponse.awarded_date,
            employee_name: recentAwardResponse.employee_name,
            gift_description: recentAwardResponse.gift_description,
            gift_item: recentAwardResponse.gift_item,
            id: recentAwardResponse.id,
            image: recentAwardResponse.image,
            awardImage: recentAwardResponse.awardImage,
            reward_code: recentAwardResponse.reward_code);
      } else {
        award = null;
      }

      attendanceMethods = dashboardResponse.data.attedanceMethod;

      DateTime startTime = DateFormat("hh:mm a")
          .parse(dashboardResponse.data.officeTime.startTime);
      DateTime endTime = DateFormat("hh:mm a")
          .parse(dashboardResponse.data.officeTime.endTime);

      AwesomeNotifications().cancelAllSchedules();
      for (var shift in dashboardResponse.data.shift_dates) {
        scheduleNewNotification(
            shift,
            "Please check in on time ⏱️⌛️",
            startTime.hour,
            startTime.minute,
            "Almost done with your shift 😄⌛️ Remember to checkout ⏱️",
            endTime.hour,
            endTime.minute);
      }

      checkAD();
      return dashboardResponse;
    } else {
      if (response.statusCode == 401) {
        preferences.clearPrefs();
        Get.offAll(LoginScreen());
      }

      var errorMessage = responseData['message'];
      print(errorMessage.toString());
      throw errorMessage;
    }
  }

  bool _isOutsideWorkspaceMessage(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('outside') &&
        (normalized.contains('workspace') ||
            normalized.contains('work space') ||
            normalized.contains('work-space'));
  }

  Future<AttendanceLocationDetails?> getAttendanceLocationDetailsIfNeeded(
      String errorMessage) async {
    if (!_isOutsideWorkspaceMessage(errorMessage)) {
      return null;
    }

    try {
      double currentLat = locationStatus['latitude'] ?? 0.0;
      double currentLon = locationStatus['longitude'] ?? 0.0;
      if (currentLat == 0.0 || currentLon == 0.0) {
        final preferences = Preferences();
        final position = await LocationStatus().determinePosition(
          await preferences.getWorkSpace(),
          forceHighAccuracy: true,
        );
        currentLat = position.latitude;
        currentLon = position.longitude;
        locationStatus.update('latitude', (value) => currentLat);
        locationStatus.update('longitude', (value) => currentLon);
        currentLocationAccuracyMeters = position.accuracy;
        _lastLocationRefreshAt = DateTime.now();
      }

      final currentAddress = await _getAddressLabel(currentLat, currentLon);
      final hasBranchLocation =
          workspaceLatitude != null && workspaceLongitude != null;
      final branchAddress = hasBranchLocation
          ? await _getAddressLabel(workspaceLatitude!, workspaceLongitude!)
          : null;
      final distanceMeters = hasBranchLocation
          ? Geolocator.distanceBetween(
              currentLat, currentLon, workspaceLatitude!, workspaceLongitude!)
          : null;

      return AttendanceLocationDetails(
        branchName: branch.trim().isEmpty ? null : branch.trim(),
        currentLatitude: currentLat,
        currentLongitude: currentLon,
        currentAddress: currentAddress,
        currentAccuracyMeters: currentLocationAccuracyMeters,
        branchLatitude: workspaceLatitude,
        branchLongitude: workspaceLongitude,
        branchAddress: branchAddress,
        distanceMeters: distanceMeters,
        allowedDistanceMeters: _getEffectiveWorkspaceRadiusMeters(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> buildWorkspaceDistanceInfoIfNeeded(String errorMessage) async {
    final details = await getAttendanceLocationDetailsIfNeeded(errorMessage);
    if (details == null) {
      return null;
    }

    final buffer = StringBuffer();
    if (details.branchName != null) {
      buffer.writeln('Branch: ${details.branchName}');
    }
    buffer.writeln(
        'Current device address: ${details.currentAddress ?? 'Unable to determine current address'}');
    buffer.writeln(
        'Current device location: ${details.currentLatitude.toStringAsFixed(6)}, ${details.currentLongitude.toStringAsFixed(6)}');
    if (details.currentAccuracyMeters != null &&
        details.currentAccuracyMeters! > 0) {
      buffer.writeln(
          'Device GPS accuracy: ${_formatDistanceInMeters(details.currentAccuracyMeters!)}');
    }

    if (details.hasBranchLocation) {
      buffer.writeln(
          'Branch address: ${details.branchAddress ?? 'Unable to determine branch address'}');
      buffer.writeln(
          'Branch location: ${details.branchLatitude!.toStringAsFixed(6)}, ${details.branchLongitude!.toStringAsFixed(6)}');
      if (details.distanceMeters != null) {
        buffer.writeln(
            'Distance from branch: ${_formatDistanceInMeters(details.distanceMeters!)}');
      }
      if (details.allowedDistanceMeters != null) {
        buffer.writeln(
            'Allowed distance: ${_formatDistanceInMeters(details.allowedDistanceMeters!)}');
      }
    }
    return buffer.toString().trim();
  }

  String _formatDistanceInMeters(double meters) {
    return '${meters.toStringAsFixed(0)} m';
  }

  Future<String?> _getAddressLabel(double latitude, double longitude) async {
    final cacheKey =
        '${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}';
    final cached = _addressCache[cacheKey];
    if (cached != null) {
      return cached;
    }

    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isEmpty) {
        return null;
      }

      final placemark = placemarks.first;
      final parts = <String?>[
        placemark.name,
        placemark.street,
        placemark.subLocality,
        placemark.locality,
        placemark.administrativeArea,
        placemark.country,
      ]
          .where((part) => part != null && part.trim().isNotEmpty)
          .cast<String>()
          .toList();

      if (parts.isEmpty) {
        return null;
      }

      final formatted = parts.join(', ');
      _addressCache[cacheKey] = formatted;
      return formatted;
    } catch (_) {
      return null;
    }
  }

  void _updateWorkspaceLocationFromResponse(dynamic responseData) {
    final workspace = _extractWorkspaceLocation(responseData);
    if (workspace == null) {
      return;
    }
    workspaceLatitude = workspace.lat;
    workspaceLongitude = workspace.lon;
    workspaceRadiusMeters = workspace.radiusMeters;
  }

  _WorkspaceLocation? _extractWorkspaceLocation(dynamic node) {
    if (node is Map) {
      // Common direct keys.
      final direct = _tryReadLocationFromMap(node);
      if (direct != null) {
        return direct;
      }

      // Common nested keys.
      const nestedKeys = [
        'office_location',
        'branch_location',
        'workspace_location',
        'attendance_location',
        'location',
        'office',
        'branch',
        'workspace',
        'geofence',
        'attendance',
        'data',
      ];
      for (final key in nestedKeys) {
        final value = node[key];
        final nested = _extractWorkspaceLocation(value);
        if (nested != null) {
          return nested;
        }
      }

      // Heuristic: scan maps whose key suggests workspace/branch/office.
      for (final entry in node.entries) {
        final k = entry.key.toString().toLowerCase();
        if (!(k.contains('office') ||
            k.contains('branch') ||
            k.contains('workspace') ||
            k.contains('location') ||
            k.contains('geofence'))) {
          continue;
        }
        final nested = _extractWorkspaceLocation(entry.value);
        if (nested != null) {
          return nested;
        }
      }
    }

    if (node is List) {
      for (final item in node) {
        final nested = _extractWorkspaceLocation(item);
        if (nested != null) {
          return nested;
        }
      }
    }
    return null;
  }

  _WorkspaceLocation? _tryReadLocationFromMap(Map<dynamic, dynamic> map) {
    double? lat;
    double? lon;

    // Try prefixed keys first (most likely to be workspace-related).
    lat ??= _tryParseDouble(map['branch_latitude']);
    lon ??= _tryParseDouble(map['branch_longitude']);
    lat ??= _tryParseDouble(map['office_latitude']);
    lon ??= _tryParseDouble(map['office_longitude']);
    lat ??= _tryParseDouble(map['workspace_latitude']);
    lon ??= _tryParseDouble(map['workspace_longitude']);

    // Try common latitude/longitude keys only if the map looks like a location object.
    final keys = map.keys.map((e) => e.toString().toLowerCase()).toList();
    final looksLikeLocation = keys.any((k) =>
        k.contains('office') ||
        k.contains('branch') ||
        k.contains('workspace') ||
        k.contains('geofence') ||
        k == 'location' ||
        k.endsWith('_location'));

    if (looksLikeLocation) {
      lat ??= _tryParseDouble(map['latitude'] ?? map['lat']);
      lon ??= _tryParseDouble(map['longitude'] ??
          map['lon'] ??
          map['lng'] ??
          map['long']);
    }

    if (lat == null || lon == null) {
      return null;
    }

    final radius = _tryParseDouble(map['radius'] ??
        map['radius_in_meter'] ??
        map['radius_in_meters'] ??
        map['allowed_branch_radius_in_meter'] ??
        map['workspace_radius'] ??
        map['allowed_radius'] ??
        map['max_distance'] ??
        map['max_distance_in_meters'] ??
        map['workspace_area']);

    return _WorkspaceLocation(lat: lat, lon: lon, radiusMeters: radius);
  }

  double? _tryParseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  void makeWeeklyReport(List<dynamic> employeeWeeklyReport) {
    const int daysInWeek = 7;
    _weeklyReport.clear();
    for (var item in employeeWeeklyReport) {
      if (item != null) {
        final productiveMinutes =
            num.tryParse(item['productive_time_in_min'].toString()) ?? 0;
        final hr = productiveMinutes / 60;

        _weeklyReport.add(hr);
      } else {
        _weeklyReport.add(0);
      }
    }

    while (_weeklyReport.length < daysInWeek) {
      _weeklyReport.add(0);
    }

    barchartValue.clear();
    rawBarGroups.clear();
    showingBarGroups.clear();
    for (int i = 0; i < daysInWeek; i++) {
      barchartValue.add(makeGroupData(i, _weeklyReport[i].toDouble()));
    }

    rawBarGroups.addAll(barchartValue);
    showingBarGroups.addAll(rawBarGroups);

    notifyListeners();
  }

  void updateAttendanceStatus(EmployeeTodayAttendance employeeTodayAttendance) {
    _attendanceList.update('production-time',
        (value) => calculateProdHour(employeeTodayAttendance.productionTime));
    _attendanceList.update(
        'check-out', (value) => employeeTodayAttendance.checkOutAt);
    _attendanceList.update('production_hour',
        (value) => calculateHourText(employeeTodayAttendance.productionTime));
    _attendanceList.update(
        'check-in', (value) => employeeTodayAttendance.checkInAt);

    notifyListeners();
  }

  void updateOverView(Overview overview) {
    _overviewList.update('present', (value) => overview.presentDays.toString());
    _overviewList.update(
        'holiday', (value) => overview.totalHolidays.toString());
    _overviewList.update(
        'leave', (value) => overview.totalLeaveTaken.toString());
    _overviewList.update(
        'request', (value) => overview.totalPendingLeaves.toString());
    _overviewList.update('total_project',
        (value) => overview.total_assigned_projects.toString());
    _overviewList.update(
        'total_task', (value) => overview.total_pending_tasks.toString());
    _overviewList.update(
        'total_awards', (value) => overview.total_awards.toString());
    _overviewList.update(
        'active_training', (value) => overview.active_training.toString());
    _overviewList.update(
        'active_event', (value) => overview.active_event.toString());

    notifyListeners();
  }

  double calculateProdHour(int value) {
    double hour = value / 60;
    double hr = hour / Constant.TOTAL_WORKING_HOUR;

    return hr > 1 ? 1 : hr;
  }

  String calculateHourText(int value) {
    double second = value * 60.toDouble();
    double min = second / 60;
    int minGone = (min % 60).toInt();
    int hour = min ~/ 60;

    print("$hour hr $minGone min");
    return "$hour hr $minGone min";
  }

  void controlFeatures(List<Feature> features) {
    Preferences preferences = Preferences();
    Map<String, String> featureList = <String, String>{};

    for (var feature in features) {
      featureList[feature.key] = feature.status;
    }

    preferences.setFeatures(featureList);
  }

  Future<bool> getCheckInStatus() async {
    try {
      final now = DateTime.now();
      if (_lastLocationRefreshAt != null &&
          now.difference(_lastLocationRefreshAt!) < _locationCacheTtl &&
          (locationStatus['latitude'] ?? 0) != 0.0 &&
          (locationStatus['longitude'] ?? 0) != 0.0) {
        await _validateWithinWorkspaceIfNeeded(
          latitude: locationStatus['latitude'] ?? 0,
          longitude: locationStatus['longitude'] ?? 0,
        );
        return true;
      }

      Preferences preferences = Preferences();
      final position = await LocationStatus().determinePosition(
        await preferences.getWorkSpace(),
        forceHighAccuracy: true,
      );

      locationStatus.update('latitude', (value) => position.latitude);
      locationStatus.update('longitude', (value) => position.longitude);
      currentLocationAccuracyMeters = position.accuracy;
      _lastLocationRefreshAt = now;

      if (locationStatus['latitude'] != 0.0 &&
          locationStatus['longitude'] != 0.0) {
        await _validateWithinWorkspaceIfNeeded(
          latitude: position.latitude,
          longitude: position.longitude,
        );
        return true;
      } else {
        Future.error(
            'Location is not detected. Please check if location is enabled and try again.');
        return false;
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> _shouldEnforceWorkspaceLocation() async {
    if (isLocationEnabled) {
      return true;
    }
    try {
      return await Preferences().getEnableLocation();
    } catch (_) {
      return false;
    }
  }

  Future<void> _validateWithinWorkspaceIfNeeded({
    required double latitude,
    required double longitude,
  }) async {
    final shouldEnforce = await _shouldEnforceWorkspaceLocation();
    if (!shouldEnforce) {
      lastWorkspaceDistanceMeters = null;
      return;
    }

    if (workspaceLatitude == null || workspaceLongitude == null) {
      lastWorkspaceDistanceMeters = null;
      return;
    }

    final allowedRadius = _getEffectiveWorkspaceRadiusMeters();
    if (allowedRadius == null) {
      lastWorkspaceDistanceMeters = null;
      return;
    }

    final distanceMeters = Geolocator.distanceBetween(
      latitude,
      longitude,
      workspaceLatitude!,
      workspaceLongitude!,
    );
    lastWorkspaceDistanceMeters = distanceMeters;

    if (distanceMeters > allowedRadius) {
      throw 'You are outside the workspace location.';
    }
  }

  Future<double?> getWorkspaceDistanceMeters({
    bool forceHighAccuracy = false,
  }) async {
    if (workspaceLatitude == null || workspaceLongitude == null) {
      return null;
    }

    final now = DateTime.now();
    final isCacheValid = _lastLocationRefreshAt != null &&
        now.difference(_lastLocationRefreshAt!) <= _locationCacheTtl &&
        (locationStatus['latitude'] ?? 0) != 0 &&
        (locationStatus['longitude'] ?? 0) != 0;

    double currentLat;
    double currentLon;
    if (isCacheValid) {
      currentLat = locationStatus['latitude'] ?? 0.0;
      currentLon = locationStatus['longitude'] ?? 0.0;
    } else {
      final preferences = Preferences();
      final position = await LocationStatus().determinePosition(
        await preferences.getWorkSpace(),
        forceHighAccuracy: forceHighAccuracy,
      );
      currentLat = position.latitude;
      currentLon = position.longitude;
      locationStatus.update('latitude', (value) => currentLat);
      locationStatus.update('longitude', (value) => currentLon);
      currentLocationAccuracyMeters = position.accuracy;
      _lastLocationRefreshAt = now;
    }

    final distanceMeters = Geolocator.distanceBetween(
      currentLat,
      currentLon,
      workspaceLatitude!,
      workspaceLongitude!,
    );
    lastWorkspaceDistanceMeters = distanceMeters;
    return distanceMeters;
  }

  double? _getEffectiveWorkspaceRadiusMeters() {
    if (workspaceLatitude == null || workspaceLongitude == null) {
      return null;
    }
    if (workspaceRadiusMeters != null && workspaceRadiusMeters! > 0) {
      return workspaceRadiusMeters!;
    }
    return _defaultWorkspaceRadiusMeters;
  }

  Future<String> onSendLocation() async {
    try {
      await getCheckInStatus();
      Preferences preferences = Preferences();
      var uri =
          Uri.parse(await preferences.getAppUrl() + Constant.SEND_LOCATION);

      String token = await preferences.getToken();

      Map<String, String> headers = {
        'Accept': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token'
      };

      final response = await http.post(uri, headers: headers, body: {
        'latitude': locationStatus['latitude'].toString(),
        'longitude': locationStatus['longitude'].toString(),
      });

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return responseData["message"];
      } else {
        if (response.statusCode == 401) {
          preferences.clearPrefs();
          Get.offAll(LoginScreen());
        }
        var errorMessage = responseData['message'];
        throw errorMessage;
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<AttendanceStatusResponse> checkInAttendance() async {
    Preferences preferences = Preferences();
    var uri = Uri.parse(await preferences.getAppUrl() + Constant.CHECK_IN_URL);

    String token = await preferences.getToken();

    Map<String, String> headers = {
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token'
    };

    await getCheckInStatus();

    final response = await http.post(uri, headers: headers, body: {
      'router_bssid': await WifiInfo().info.getWifiBSSID() ?? "",
      'check_in_latitude': locationStatus['latitude'].toString(),
      'check_in_longitude': locationStatus['longitude'].toString(),
    });

    final responseData = json.decode(response.body);

    if (response.statusCode == 200) {
      final attendanceResponse =
          AttendanceStatusResponse.fromJson(responseData);
      debugPrint(attendanceResponse.toString());

      updateAttendanceStatus(EmployeeTodayAttendance(
          checkInAt: attendanceResponse.data.checkInAt,
          checkOutAt: attendanceResponse.data.checkOutAt,
          productionTime: attendanceResponse.data.productiveTimeInMin));

      return attendanceResponse;
    } else {
      if (response.statusCode == 401) {
        preferences.clearPrefs();
        Get.offAll(LoginScreen());
      }
      var errorMessage = responseData['message'];
      throw errorMessage;
    }
  }

  Future<void> scheduleNewNotification(
      String date,
      String startMessage,
      int startHr,
      int startMin,
      String endMessage,
      int endHr,
      int endMin) async {
    final convertedDate = new DateFormat('yyyy-MM-dd').parse(date);

    await AwesomeNotifications().createNotification(
        content: NotificationContent(
            id: Random.Random().nextInt(1000000),
            // -1 is replaced by a random number
            channelKey: 'digital_hr_channel',
            title: "Hello There",
            body: startMessage,
            //'asset://assets/images/balloons-in-sky.jpg',
            notificationLayout: NotificationLayout.Default,
            payload: {'notificationId': '1234567890'}),
        actionButtons: [
          NotificationActionButton(
              key: 'REDIRECT', label: 'Open', actionType: ActionType.Default),
          NotificationActionButton(
              key: 'DISMISS',
              label: 'Dismiss',
              actionType: ActionType.DismissAction,
              isDangerousOption: true)
        ],
        schedule: NotificationCalendar.fromDate(
            date: DateTime(convertedDate.year, convertedDate.month,
                convertedDate.day, startHr, startMin - 15)));

    await AwesomeNotifications().createNotification(
        content: NotificationContent(
            id: Random.Random().nextInt(1000000),
            // -1 is replaced by a random number
            channelKey: 'digital_hr_channel',
            title: "Hello There",
            body: endMessage,
            //'asset://assets/images/balloons-in-sky.jpg',
            notificationLayout: NotificationLayout.Default,
            payload: {'notificationId': '1234567890'}),
        actionButtons: [
          NotificationActionButton(
              key: 'REDIRECT', label: 'Open', actionType: ActionType.Default),
          NotificationActionButton(
              key: 'DISMISS',
              label: 'Dismiss',
              actionType: ActionType.DismissAction,
              isDangerousOption: true)
        ],
        schedule: NotificationCalendar.fromDate(
            date: DateTime(convertedDate.year, convertedDate.month,
                convertedDate.day, endHr, endMin - 15)));
  }

  Future<AttendanceStatusResponse> checkOutAttendance() async {
    Preferences preferences = Preferences();
    var uri = Uri.parse(await preferences.getAppUrl() + Constant.CHECK_OUT_URL);

    String token = await preferences.getToken();

    Map<String, String> headers = {
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token'
    };

    await getCheckInStatus();

    final response = await http.post(uri, headers: headers, body: {
      'router_bssid': await WifiInfo().wifiBSSID() ?? "",
      'check_out_latitude': locationStatus['latitude'].toString(),
      'check_out_longitude': locationStatus['longitude'].toString(),
    });
    debugPrint(response.body.toString());

    final responseData = json.decode(response.body);

    if (response.statusCode == 200) {
      final attendanceResponse =
          AttendanceStatusResponse.fromJson(responseData);

      updateAttendanceStatus(EmployeeTodayAttendance(
          checkInAt: attendanceResponse.data.checkInAt,
          checkOutAt: attendanceResponse.data.checkOutAt,
          productionTime: attendanceResponse.data.productiveTimeInMin));

      return attendanceResponse;
    } else {
      if (response.statusCode == 401) {
        preferences.clearPrefs();
        Get.offAll(LoginScreen());
      }
      var errorMessage = responseData['message'];
      throw errorMessage;
    }
  }

  Future<AttendanceStatusResponse> verifyAttendanceApi(String type, String note,
      {String attendanceStatus = "", String identifier = ""}) async {
    Preferences preferences = Preferences();
    var uri =
        Uri.parse(await preferences.getAppUrl() + Constant.ATTENDANCE_URL);
    print(identifier);

    String token = await preferences.getToken();

    Map<String, String> headers = {
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token'
    };

    final shouldEnforce = await _shouldEnforceWorkspaceLocation();
    if (type == "wifi" || shouldEnforce) {
      await getCheckInStatus();
    }

    final shouldSendCoordinates = type == "wifi" || shouldEnforce;
    final latitude =
        shouldSendCoordinates ? locationStatus['latitude'].toString() : "";
    final longitude =
        shouldSendCoordinates ? locationStatus['longitude'].toString() : "";

    final http.Client client = LoggingMiddleware(http.Client());

    final response = await client.post(uri, headers: headers, body: {
      'attendance_type': type,
      'latitude': latitude,
      'longitude': longitude,
      'router_bssid': type == "wifi" ? await WifiInfo().wifiBSSID() ?? "" : "",
      'identifier': type != "wifi" ? identifier : "",
      'attendance_status_type': type == "wifi" ? attendanceStatus : "",
      'note': note,
    });

    log(response.body.toString());

    final responseData = json.decode(response.body);

    if (response.statusCode == 200) {
      final attendanceResponse =
          AttendanceStatusResponse.fromJson(responseData);

      updateAttendanceStatus(EmployeeTodayAttendance(
          checkInAt: attendanceResponse.data.checkInAt,
          checkOutAt: attendanceResponse.data.checkOutAt,
          productionTime: attendanceResponse.data.productiveTimeInMin));
      noteController.clear();
      return attendanceResponse;
    } else {
      _updateWorkspaceLocationFromResponse(responseData);
      if (response.statusCode == 401) {
        preferences.clearPrefs();
        Get.offAll(LoginScreen());
      }
      var errorMessage = responseData['message'];
      throw errorMessage;
    }
  }

  final Color leftBarColor = HexColor("#FFFFFF");

  final double width = 15;

  BarChartGroupData makeGroupData(int x, double y1) {
    return BarChartGroupData(barsSpace: 4, x: x, barRods: [
      BarChartRodData(
        toY: y1,
        color: leftBarColor,
        width: width,
      ),
    ]);
  }
}

class _WorkspaceLocation {
  final double lat;
  final double lon;
  final double? radiusMeters;

  const _WorkspaceLocation({
    required this.lat,
    required this.lon,
    this.radiusMeters,
  });
}

class AttendanceLocationDetails {
  final String? branchName;
  final double currentLatitude;
  final double currentLongitude;
  final String? currentAddress;
  final double? currentAccuracyMeters;
  final double? branchLatitude;
  final double? branchLongitude;
  final String? branchAddress;
  final double? distanceMeters;
  final double? allowedDistanceMeters;

  const AttendanceLocationDetails({
    required this.branchName,
    required this.currentLatitude,
    required this.currentLongitude,
    required this.currentAddress,
    required this.currentAccuracyMeters,
    required this.branchLatitude,
    required this.branchLongitude,
    required this.branchAddress,
    required this.distanceMeters,
    required this.allowedDistanceMeters,
  });

  bool get hasBranchLocation =>
      branchLatitude != null && branchLongitude != null;
}
