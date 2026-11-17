import 'package:cnattendance/provider/dashboardprovider.dart';
import 'package:cnattendance/screen/profile/holidayscreen.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:cnattendance/widget/holiday/holidaycard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

class UpcomingHoliday extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final holiday = context.watch<DashboardProvider>().holiday;
    final enterprise = EnterpriseTheme.of(context);
    return Visibility(
      visible: holiday != null ? true : false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  translate('home_screen.upcoming_holiday'),
                  style: TextStyle(
                    color: enterprise.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Spacer(),
                GestureDetector(
                  onTap: () {
                    Get.to(HolidayScreen());
                  },
                  child: Text(
                    translate('home_screen.view_all'),
                    style: TextStyle(
                      color: enterprise.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 6,
            ),
            holiday != null
                ? Holidaycard(
                    id: holiday.id,
                    name: holiday.title,
                    month: holiday.month,
                    day: holiday.day,
                    desc: holiday.description,
                    isPublicHoliday: holiday.isPublicHoliday)
                : SizedBox.shrink()
          ],
        ),
      ),
    );
  }
}
