import 'dart:convert';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/data/source/network/model/checkliststatustoggle/CheckListStatusToggleResponse.dart';
import 'package:cnattendance/data/source/network/model/taskdetail/taskdetail.dart';
import 'package:cnattendance/model/checklist.dart';
import 'package:cnattendance/model/member.dart';
import 'package:cnattendance/model/task.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';
import 'package:cnattendance/core/ky_security/ky_http.dart';
import 'package:intl/intl.dart';
import 'package:nepali_date_picker/nepali_date_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../model/attachment.dart';
import 'package:flutter/foundation.dart';

class TaskDetailController extends GetxController {
  var taskDetail =
      (Task.all(0, "", "", "", "", "", "", "Completed", 0, 0, true, [], [], []))
          .obs;

  var memberImages = [].obs;
  var leaderImages = [].obs;

  Future<TaskDetailResponse> getTaskOverview() async {
    final Preferences preferences = Preferences();
    final uri = Uri.parse(await preferences.getAppUrl() +
        Constant.TASK_DETAIL_URL +
        "/" +
        Get.arguments["id"].toString());

    final String token = await preferences.getToken();
    final bool isAd = await preferences.getEnglishDate();

    final Map<String, String> headers = {
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token'
    };

    try {
      EasyLoading.show(
          status: translate('loader.loading'),
          maskType: EasyLoadingMaskType.black);
      final response = await KyHttp.get(
        uri,
        headers: headers,
      );
      EasyLoading.dismiss(animation: true);
      debugPrint(response.body.toString());

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        final taskResponse = TaskDetailResponse.fromJson(responseData);

        final List<Member> members = [];
        memberImages.clear();
        for (var member in taskResponse.data.assigned_member) {
          members.add(
              Member(member.id, member.name, member.avatar, post: member.post));
          memberImages.add(member.avatar);
        }

        final List<Checklist> checkLists = [];
        for (var checkList in taskResponse.data.checklists) {
          checkLists.add(Checklist(checkList.id, checkList.task_id,
              checkList.name, checkList.is_completed));
        }

        final List<Attachment> attachments = [];
        for (var attachment in taskResponse.data.attachments) {
          if (attachment.type == "image") {
            attachments.add(Attachment(0, attachment.attachment_url, "image"));
          } else {
            attachments.add(Attachment(0, attachment.attachment_url, "file"));
          }
        }

        final DateTime startDate =
            DateFormat("MMM dd yyyy").parse(taskResponse.data.start_date);

        final NepaliDateTime nepaliStartDate = startDate.toNepaliDateTime();

        final String nepaliStartTempDate =
            NepaliDateFormat("MMM dd yyyy").format(nepaliStartDate);

        final task = Task.all(
            taskResponse.data.task_id,
            taskResponse.data.task_name,
            taskResponse.data.project_name,
            taskResponse.data.description,
            isAd ? taskResponse.data.start_date : nepaliStartTempDate,
            taskResponse.data.deadline,
            taskResponse.data.priority,
            taskResponse.data.status,
            taskResponse.data.task_progress_percent,
            taskResponse.data.task_comments.length,
            taskResponse.data.has_checklist,
            members,
            checkLists,
            attachments);

        taskDetail.value = task;
        return taskResponse;
      } else {
        final errorMessage = responseData['message'];
        if (kDebugMode) debugPrint(errorMessage);
        throw errorMessage;
      }
    } catch (e) {
      if (kDebugMode) debugPrint(e.toString());
      throw e;
    }
  }

  Future<bool> checkListToggle(String checkListId) async {
    final Preferences preferences = Preferences();
    final uri = Uri.parse(await preferences.getAppUrl() +
        Constant.UPDATE_CHECKLIST_TOGGLE_URL +
        "/" +
        checkListId);

    final String token = await preferences.getToken();

    final Map<String, String> headers = {
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token'
    };

    debugPrint(uri.toString());
    try {
      EasyLoading.show(
          status: translate('loader.loading'),
          maskType: EasyLoadingMaskType.black);
      final response = await KyHttp.get(
        uri,
        headers: headers,
      );
      EasyLoading.dismiss(animation: true);
      debugPrint(response.body.toString());

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        CheckListStatusToggleResponse.fromJson(responseData);

        return true;
      } else {
        final errorMessage = responseData['message'];
        if (kDebugMode) debugPrint(errorMessage);
        return false;
      }
    } catch (e) {
      if (kDebugMode) debugPrint(e.toString());
      return false;
    }
  }

  Future<bool> checkListTaskToggle(String taskId) async {
    final Preferences preferences = Preferences();
    final uri = Uri.parse(await preferences.getAppUrl() +
        Constant.UPDATE_TASK_TOGGLE_URL +
        "/" +
        taskId);

    final String token = await preferences.getToken();

    final Map<String, String> headers = {
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token'
    };

    debugPrint(uri.toString());
    try {
      EasyLoading.show(
          status: translate('loader.loading'),
          maskType: EasyLoadingMaskType.black);
      final response = await KyHttp.get(
        uri,
        headers: headers,
      );
      EasyLoading.dismiss(animation: true);
      debugPrint(response.body.toString());

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        Get.back();
        showToast("Task completed");
        return true;
      } else {
        final errorMessage = responseData['message'];
        if (kDebugMode) debugPrint(errorMessage);
        return false;
      }
    } catch (e) {
      if (kDebugMode) debugPrint(e.toString());
      return false;
    }
  }

  Future<void> launchUrls(String _url) async {
    if (!await launchUrl(Uri.parse(_url),
        mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $_url');
    }
  }

  @override
  void onInit() {
    getTaskOverview();
    super.onInit();
  }
}
