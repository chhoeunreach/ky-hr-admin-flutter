import 'package:cnattendance/provider/leavecalendarcontroller.dart';
import 'package:cnattendance/widget/leavecalendar/BirthdayListview.dart';
import 'package:cnattendance/widget/leavecalendar/HolidayListview.dart';
import 'package:cnattendance/widget/leavecalendar/LeaveCalendarView.dart';
import 'package:cnattendance/widget/leavecalendar/LeaveListview.dart';
import 'package:cnattendance/widget/profile/calendartoggle.dart';
import 'package:cnattendance/widget/radialDecoration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

class LeaveCalendarScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final model = Get.put(LeaveCalendarController());
    return Container(
      decoration: RadialDecoration(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(translate('leave_calendar_screen.leave_calendar'),
              style: TextStyle(color: AppColors.white)),
          iconTheme: IconThemeData(color: AppColors.white),
          elevation: 0,
          actions: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Tooltip(
                  textStyle: TextStyle(color: AppColors.black),
                  decoration: BoxDecoration(color: AppColors.white),
                  message: "⏱️ -> Time Leave ",
                  child: Icon(Icons.info)),
            )
          ],
          backgroundColor: Colors.transparent,
        ),
        body: SingleChildScrollView(
          child: Obx(
            () => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LeaveCalendarView(),
                Container(
                    padding: EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                    child: CalendarToggle()),
                model.toggleValue.value == 0
                    ? LeaveListView()
                    : SizedBox.shrink(),
                model.toggleValue.value == 1
                    ? HolidayListView()
                    : SizedBox.shrink(),
                model.toggleValue.value == 2
                    ? BirthdayListView()
                    : SizedBox.shrink(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
