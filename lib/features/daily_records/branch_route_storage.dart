import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'branch_route_model.dart';
import 'daily_records_api.dart';

class BranchRouteStorage {
  static const String activeKey = 'active_branch_route';
  static const String historyKey = 'completed_branch_routes';

  static Future<BranchRoute?> getActiveRoute() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(activeKey);
      if (raw == null || raw.trim().isEmpty) return null;
      return BranchRoute.fromJson(raw);
    } catch (e) {
      debugPrint('Error getting active route: $e');
      return null;
    }
  }

  static Future<void> saveActiveRoute(BranchRoute route) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(activeKey, route.toJson());
    } catch (e) {
      debugPrint('Error saving active route: $e');
    }
  }

  static Future<void> clearActiveRoute() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(activeKey);
    } catch (e) {
      debugPrint('Error clearing active route: $e');
    }
  }

  static Future<List<BranchRoute>> getRouteHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(historyKey);
      if (list == null) return [];
      return list.map((e) => BranchRoute.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error getting route history: $e');
      return [];
    }
  }

  static Future<void> saveToHistory(BranchRoute route) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(historyKey) ?? [];
      final encoded = route.toJson();
      // Remove any existing copy with same ID
      list.removeWhere((item) {
        try {
          final decoded = jsonDecode(item);
          return decoded['id'] == route.id;
        } catch (_) {
          return false;
        }
      });
      list.insert(0, encoded);
      if (list.length > 50) {
        list.removeRange(50, list.length);
      }
      await prefs.setStringList(historyKey, list);
    } catch (e) {
      debugPrint('Error saving route to history: $e');
    }
  }

  static Future<bool> syncRouteToServer(
    BranchRoute route,
    DailyRecordsApi api,
  ) async {
    final List<PlatformFile> uploadFiles = [];

    // Helper to safely add existing files
    void addFileIfPresent(String? path, String prefix) {
      if (path != null && path.trim().isNotEmpty) {
        final file = File(path);
        if (file.existsSync()) {
          final name = '${prefix}_${file.uri.pathSegments.last}';
          uploadFiles.add(PlatformFile(
            path: path,
            name: name,
            size: file.lengthSync(),
          ));
        }
      }
    }

    addFileIfPresent(route.startSelfiePath, 'start_selfie');
    addFileIfPresent(route.endSelfiePath, 'end_selfie');

    for (var i = 0; i < route.supportingPhotos.length; i++) {
      addFileIfPresent(route.supportingPhotos[i], 'support_photo_$i');
    }
    for (var i = 0; i < route.supportingFiles.length; i++) {
      addFileIfPresent(route.supportingFiles[i], 'support_file_$i');
    }

    for (var i = 0; i < route.checkpoints.length; i++) {
      final cp = route.checkpoints[i];
      for (var j = 0; j < cp.photoPaths.length; j++) {
        addFileIfPresent(cp.photoPaths[j], 'cp_${i}_photo_$j');
      }
    }

    final depTime = DateFormat('HH:mm').format(route.startTime);
    final arrTime = route.endTime != null
        ? DateFormat('HH:mm').format(route.endTime!)
        : depTime;

    final checkpointMaps = route.checkpoints.map((c) => c.toMap()).toList();

    final payload = <String, dynamic>{
      'kind': 'activity',
      'request_id': route.id,
      'title': 'បេសកកម្មពី ${route.originBranch} ${route.targetBranches.isNotEmpty ? "ទៅ " + route.targetBranches.join(", ") : ""}',
      'activity_date': DateFormat('yyyy-MM-dd').format(route.startTime),
      'start_time': depTime,
      'end_time': arrTime,
      'body': route.finalSummary?.isNotEmpty == true
          ? route.finalSummary!
          : 'បេសកកម្ម៖ ${route.purpose}\nរយៈពេលសរុប៖ ${route.formattedDuration}',
      'fields': {
        'mission_type': 'branch_route',
        'route_id': route.id,
        'purpose': route.purpose,
        'origin_branch': route.originBranch,
        'target_branches': route.targetBranches,
        'departure_time': depTime,
        'arrival_time': arrTime,
        'status': route.status,
        'total_minutes': route.currentDuration.inMinutes,
        'formatted_duration': route.formattedDuration,
        if (route.startLatitude != null) 'start_latitude': route.startLatitude,
        if (route.startLongitude != null)
          'start_longitude': route.startLongitude,
        if (route.endLatitude != null) 'end_latitude': route.endLatitude,
        if (route.endLongitude != null) 'end_longitude': route.endLongitude,
        'checkpoints_count': route.checkpoints.length,
        'checkpoints_data': jsonEncode(checkpointMaps),
      },
      'tags': [
        '#branch-route',
        '#mission',
        route.originBranch.split(' - ').first.trim().toLowerCase(),
        ...route.targetBranches
            .map((b) => b.split(' - ').first.trim().toLowerCase()),
      ],
    };

    try {
      await api.postWork('work-records', payload, files: uploadFiles);
      final syncedRoute = route.copyWith(isSynced: true);
      await saveToHistory(syncedRoute);
      return true;
    } catch (e) {
      debugPrint('Error syncing route to server: $e');
      return false;
    }
  }
}
