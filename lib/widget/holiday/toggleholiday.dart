import 'package:cnattendance/provider/holidaycontroller.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';
import 'package:toggle_switch/toggle_switch.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

class ToggleHoliday extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final HolidayController model = Get.find();
    final enterprise = EnterpriseTheme.of(context);
    return Obx(
      () => Center(
        child: Container(
          decoration: BoxDecoration(
            color: enterprise.isDark
                ? AppColors.ink900.withValues(alpha: 0.6)
                : AppColors.customFFF1F5F9.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: enterprise.cardBorder),
          ),
          padding: const EdgeInsets.all(3),
          child: ToggleSwitch(
            activeBgColor: [enterprise.accent],
            activeFgColor: AppColors.white,
            inactiveFgColor: enterprise.text,
            inactiveBgColor: Colors.transparent,
            minWidth: 100,
            minHeight: 40,
            cornerRadius: 20,
            initialLabelIndex: model.toggleValue.value,
            totalSwitches: 2,
            onToggle: (index) {
              model.toggleValue.value = index!;
              model.holidayListFilter();
            },
            labels: [
              translate('holiday_screen.upcoming'),
              translate('holiday_screen.past')
            ],
          ),
        ),
      ),
    );
  }
}
