import 'package:cnattendance/model/month.dart';
import 'package:cnattendance/utils/navigationservice.dart';
import 'package:cnattendance/widget/customalertdialog.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:overlay_support/overlay_support.dart';

class Constant {
  static const production = "https://cnattendancev2.cyclonenepal.com/";
  static const keonUrl = "https://digitalhr.bosathemes.com/";
  static const staging = "https://attendance.cyclonenepal.com/";
  static const localhost = "http://192.168.1.66:8000/";
  static const codecanyon = "https://digitalhr.cyclonenepal.com/";

  static const appUrl = production;

  /**
   * Change value based on your need.
   */
  static const MAIN_URL = production;

  static const API_URL = "api";
  static const PRIVACY_POLICY_URL = MAIN_URL + "privacy";

  static const LOGIN_URL = "$API_URL/login";
  static const LOGOUT_URL = "$API_URL/logout";
  static const DASHBOARD_URL = "$API_URL/dashboard";

  static const CHECK_IN_URL = "$API_URL/employees/check-in";
  static const CHECK_OUT_URL = "$API_URL/employees/check-out";
  static const ATTENDANCE_URL = "$API_URL/employees/attendance";
  static const SEND_LOCATION = "$API_URL/users/location";

  static const ADD_NFC_URL = "$API_URL/nfc/store";

  static const SEND_PUSH_NOTIFICATION = "$API_URL/employee/push";
  static const CHAT_CONTACTS = "$API_URL/employee/chat/contacts";
  static const CHAT_MEDIA_UPLOAD = "$API_URL/employee/chat/media-upload";
  static const ADMIN_CHAT_MESSAGES = "$API_URL/employee/chat/admin/messages";

  static const ATTENDANCE_REPORT_URL = "$API_URL/employees/attendance-detail";
  static const LEAVE_TYPE_URL = "$API_URL/leave-types";
  static const LEAVE_TYPE_DETAIL_URL =
      "$API_URL/leave-requests/employee-leave-requests";
  static const ISSUE_LEAVE = "$API_URL/leave-requests/store";
  static const ISSUE_TIME_LEAVE = "$API_URL/time-leave-requests/store";
  static const CANCEL_LEAVE = "$API_URL/leave-requests/cancel";
  static const CANCEL_TIME_LEAVE = "$API_URL/time-leave-requests/cancel";
  static const PROFILE_URL = "$API_URL/users/profile";
  static const EMPLOYEE_PROFILE_URL = "$API_URL/users/profile-detail";
  static const CONTENT_URL = "$API_URL/static-page-content";
  static const TEAM_SHEET_URL = "$API_URL/users/company/team-sheet";
  static const LEAVE_CALENDAR_API =
      "$API_URL/leave-requests/employee-leave-calendar";
  static const LEAVE_CALENDAR_BY_DAY_API =
      "$API_URL/leave-requests/employee-leave-list";
  static const OFFICE_CALENDAR_API = "$API_URL/employee/office-calendar";
  static const HOLIDAYS_API = "$API_URL/holidays";
  static const CHANGE_PASSWORD_API = "$API_URL/users/change-password";
  static const RULES_API = "$API_URL/company-rules";
  static const EDIT_PROFILE_URL = "$API_URL/users/update-profile";
  static const NOTIFICATION_URL = "$API_URL/notifications";
  static const NOTICE_URL = "$API_URL/notices";
  static const MEETING_URL = "$API_URL/team-meetings";

  static const PROJECT_DASHBOARD_URL = "$API_URL/project-management-dashboard";
  static const PROJECT_LIST_URL = "$API_URL/assigned-projects-list";
  static const PROJECT_DETAIL_URL = "$API_URL/assigned-projects-detail";
  static const TASK_LIST_URL = "$API_URL/assigned-task-list";
  static const TASK_DETAIL_URL = "$API_URL/assigned-task-detail";
  static const UPDATE_CHECKLIST_TOGGLE_URL =
      "$API_URL/assigned-task-checklist/toggle-status";
  static const UPDATE_TASK_TOGGLE_URL =
      "$API_URL/assigned-task-detail/change-status";
  static const EMPLOYEE_DETAIL_URL = "$API_URL/users/profile-detail";
  static const GET_COMMENT_URL = "$API_URL/assigned-task-comments";
  static const SAVE_COMMENT_URL = "$API_URL/assigned-task/comments/store";
  static const DELETE_COMMENT_URL = "$API_URL/assigned-task/comment/delete";
  static const DELETE_REPLY_URL = "$API_URL/assigned-task/reply/delete";

  static const TADA_LIST_URL = "$API_URL/employee/tada-lists";
  static const TADA_DETAIL_URL = "$API_URL/employee/tada-details";
  static const TADA_STORE_URL = "$API_URL/employee/tada/store";
  static const TADA_UPDATE_URL = "$API_URL/employee/tada/update";
  static const TADA_DELETE_ATTACHMENT_URL =
      "$API_URL/employee/tada/delete-attachment";

  static const ADVANCE_SALARY_LIST_URL =
      "$API_URL/employee/advance-salaries-lists";
  static const ADVANCE_SALARY_CREATE_URL =
      "$API_URL/employee/advance-salaries/store";
  static const ADVANCE_SALARY_UPDATE_URL =
      "$API_URL/employee/advance-salaries-detail/update";
  static const ADVANCE_SALARY_DETAIL_URL =
      "$API_URL/employee/advance-salaries-detail";
  static const ADVANCE_SALARY_APPROVE_URL =
      "$API_URL/employee/advance-salaries-detail/approve";
  static const ADVANCE_SALARY_REJECT_URL =
      "$API_URL/employee/advance-salaries-detail/reject";

  static const ADMIN_ADVANCE_SALARY_LIST_URL =
      "$API_URL/admin/advance-salaries-lists";
  static const ADMIN_ADVANCE_SALARY_CREATE_URL =
      "$API_URL/admin/advance-salaries/store";

  static const SUPPORT_URL = "$API_URL/support/query-store";
  static const DEPARTMENT_LIST_URL = "$API_URL/support/department-lists";
  static const SUPPORT_LIST_URL = "$API_URL/support/get-user-query-lists";

  static const PAYSLIP_LIST_URL = "$API_URL/employee/payslip";
  static const PAYSLIP_DETAIL_URL = "$API_URL/employee/payslip/";
  static const SSF_HISTORY_URL = "$API_URL/payroll/ssf-history";

  static const APPLY_RESIGNATION_URL = "$API_URL/resignation/store";
  static const RESIGNATION_URL = "$API_URL/resignation/";

  static const TRAINING_LIST_URL = "$API_URL/training/";
  static const EVENT_LIST_URL = "$API_URL/events/";
  static const EVENT_DETAIL_URL = "$API_URL/event/";

  static const AWARDS_URL = "$API_URL/awards/";

  static const ASSETS_URL = "$API_URL/assets/";
  static const ASSETS_RETURN_URL = "$API_URL/asset-return/";

  static const WARNING_LIST_URL = "$API_URL/warning";
  static const WARNING_RESPONSE_URL = "$API_URL/warning/store/";

  static const COMPLAINT_LIST_URL = "$API_URL/complaint";
  static const COMPLAINT_RESPONSE_URL = "$API_URL/complaint/response/store/";
  static const COMPLAINT_APPLY_URL = "$API_URL/complaint/store";

  static const EMPLOYEE_DEPARTMENT_URL = "$API_URL/department-employees/";

  static const TOTAL_WORKING_HOUR = 8;
}

extension StringExtension on String {
  bool isUnique() {
    return true;
  }
}

void showToast(String message, {VoidCallback? onTap}) {
  if (message.trim().isEmpty) {
    return;
  }

  final toastTitle = _toastTitle(message);
  final toastBody = _toastBody(message);

  showOverlayNotification(
    (context) => SafeArea(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(1, 23, 84, 0.12),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              leading: Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Color(0xffeaf1ff),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  color: Color(0xff011754),
                  size: 20,
                ),
              ),
              title: Text(
                toastTitle,
                style: const TextStyle(
                  color: Color(0xff011754),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                toastBody,
                style: const TextStyle(
                  color: Color(0xff52607a),
                  fontSize: 12.5,
                  height: 1.3,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
    duration: const Duration(seconds: 4),
  );
}

void showAlertMessage(String message) {
  final context =
      NavigationService.navigatorKey.currentState?.overlay?.context ??
          NavigationService.navigatorKey.currentState?.context;

  if (context == null || message.trim().isEmpty) {
    return;
  }

  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: CustomAlertDialog(message),
    ),
  );
}

String _toastTitle(String message) {
  final parts = message.split('\n');
  final title = parts.first.trim();
  return title.isEmpty ? 'Digital HRMS' : title;
}

String _toastBody(String message) {
  final parts = message.split('\n');
  if (parts.length <= 1) {
    return message.trim();
  }

  final body = parts.skip(1).join('\n').trim();
  return body.isEmpty ? parts.first.trim() : body;
}

String unknownError(e) {
  try {
    if (e is String) {
      throw e.toString();
    } else {
      var errorMessage = e['message'];
      throw errorMessage;
    }
  } catch (e) {
    throw e.toString();
  }
}

String findKey(Map<String, dynamic> map) {
  for (var entry in map.entries) {
    if (entry.value is Map && entry.value['identifier'] != null) {
      List<int> identifierValue = List<int>.from(entry.value['identifier']);
      if (identifierValue.toString() != "[]") {
        debugPrint(identifierValue.toString());
        return identifierValue.toString();
      }
    }
  }
  return "[]";
}

final List<Month> engMonth = [
  Month(0, 'January'),
  Month(1, 'Febuary'),
  Month(2, 'March'),
  Month(3, 'April'),
  Month(4, 'May'),
  Month(5, 'June'),
  Month(6, 'July'),
  Month(7, 'August'),
  Month(8, 'September'),
  Month(9, 'October'),
  Month(10, 'November'),
  Month(11, 'December'),
];

final List<Month> nepaliMonth = [
  Month(0, 'Baisakh'),
  Month(1, 'Jestha'),
  Month(2, 'Asadh'),
  Month(3, 'Shwaran'),
  Month(4, 'Bhadra'),
  Month(5, 'Asoj'),
  Month(6, 'Kartik'),
  Month(7, 'Mangsir'),
  Month(8, 'Poush'),
  Month(9, 'Magh'),
  Month(10, 'Falgun'),
  Month(11, 'Chaitra'),
];

int calc() {
  return 10 - 5;
}

void value() {
  calc();
}

bool getAppTheme() {
  final box = GetStorage();
  return box.read('theme') ?? true;
}

bool getAnimation() {
  final box = GetStorage();
  return box.read('animation') ?? true;
}

String appTheme = "#011754";
String appAlternateTheme = "#041033";

String radialBoxTheme = appAlternateTheme;

//light theme constant
String ltextColor = "#000000";

//dark theme constant
String dtextColor = "#ffffff";
