import 'dart:convert';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/data/source/network/model/projectdashboard/ProjectDashboardResponse.dart';
import 'package:cnattendance/model/member.dart';
import 'package:cnattendance/model/project.dart';
import 'package:cnattendance/model/task.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:cnattendance/core/ky_security/ky_http.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:nepali_date_picker/nepali_date_picker.dart';
import 'package:flutter/foundation.dart';

class ProjectDashboardController extends GetxController {
  var overview = {
    "progress": 0,
    "total_project": 0,
    "project_completed": 0,
  }.obs;

  var taskList = [].obs;
  var projectList = [].obs;

  Future<String> getProjectOverview() async {
    final Preferences preferences = Preferences();
    final uri = Uri.parse(await preferences.getAppUrl() +
        Constant.PROJECT_DASHBOARD_URL +
        "?tasks=10&projects=3");

    final String token = await preferences.getToken();
    final bool isAd = await preferences.getEnglishDate();

    final Map<String, String> headers = {
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token'
    };

    final response = await KyHttp.get(
      uri,
      headers: headers,
    );
    debugPrint(response.body.toString());

    final responseData = json.decode(response.body);

    if (response.statusCode == 200) {
      final projectResponse = ProjectDashboardResponse.fromJson(responseData);

      taskList.clear();
      projectList.clear();

      overview['progress'] =
          projectResponse.data.progressProject.progress_in_percent;
      overview['total_project'] =
          projectResponse.data.progressProject.total_project_assigned;
      overview['project_completed'] =
          projectResponse.data.progressProject.total_project_completed;

      overview.refresh();

      for (var task in projectResponse.data.assigned_task) {
        final DateTime startDate =
            DateFormat("MMM dd yyyy", "en").parse(task.start_date);
        final DateTime endDate = DateFormat("MMM dd yyyy", "en").parse(task.end_date);

        final NepaliDateTime nepaliStartDate = startDate.toNepaliDateTime();
        final NepaliDateTime nepaliEndDate = endDate.toNepaliDateTime();

        final String nepaliStartTempDate =
            NepaliDateFormat("MMM dd yyyy").format(nepaliStartDate);
        final String nepaliEndTempDate =
            NepaliDateFormat("MMM dd yyyy").format(nepaliEndDate);

        final List<Member> taskMembers = [];

        for (var member in task.assigned_member) {
          taskMembers.add(Member(member.id, member.name, member.avatar));
        }

        taskList.add(Task(
            task.task_id,
            task.task_name,
            task.project_name,
            isAd ? task.start_date : nepaliStartTempDate,
            isAd ? task.end_date : nepaliEndTempDate,
            task.status,
            members: taskMembers,
            priority: task.priority));
      }

      final List<Member> members = [];
      for (var project in projectResponse.data.projects) {
        for (var member in project.assigned_member) {
          members.add(Member(member.id, member.name, member.avatar));
        }

        final DateTime tempDate =
            DateFormat("MMM dd yyyy", "en").parse(project.start_date);
        final NepaliDateTime nepaliDate = tempDate.toNepaliDateTime();

        final String nepaliTempDate =
            NepaliDateFormat("MMM dd yyyy").format(nepaliDate);

        projectList.add(Project(
            project.id,
            project.project_name,
            project.slug,
            "",
            isAd ? project.start_date : nepaliTempDate,
            project.priority,
            project.status,
            project.project_progress_percent,
            project.assigned_task_count,
            members, [], []));
      }

      return "Loaded";
    } else {
      final errorMessage = responseData['message'];
      if (kDebugMode) debugPrint(errorMessage);
      throw errorMessage;
    }
  }

  @override
  void onReady() {
    getProjectOverview();
    super.onReady();
  }
}
