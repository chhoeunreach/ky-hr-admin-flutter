import 'package:cnattendance/provider/leavecalendarcontroller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';
import 'package:toggle_switch/toggle_switch.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

class CalendarToggle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final LeaveCalendarController model = Get.find();
    return Obx(
      () => Center(
        child: ToggleSwitch(
          activeBgColor: [AppColors.white12],
          activeFgColor: AppColors.white,
          inactiveFgColor: AppColors.white,
          inactiveBgColor: Colors.transparent,
          minWidth: 100,
          minHeight: 45,
          initialLabelIndex: model.toggleValue.value,
          totalSwitches: 3,
          onToggle: (index) {
            model.changeToggle(index ?? 0);
          },
          labels: [
            translate('common.leave'),
            translate('common.holiday'),
            translate('common.birthday')
          ],
        ),
      ),
    );
  }
}
