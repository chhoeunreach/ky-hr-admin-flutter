import 'package:cnattendance/provider/holidaycontroller.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:cnattendance/widget/holiday/holidaycardview.dart';
import 'package:cnattendance/widget/holiday/toggleholiday.dart';
import 'package:cnattendance/widget/premium_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';

class HolidayScreen extends StatelessWidget {
  static const routeName = '/holidays';

  @override
  Widget build(BuildContext context) {
    final model = Get.put(HolidayController());
    final enterprise = EnterpriseTheme.of(context);
    return PremiumBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          title: Text(
            translate('holiday_screen.holidays'),
            style: TextStyle(
              color: enterprise.text,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          iconTheme: IconThemeData(color: enterprise.text),
        ),
        body: RefreshIndicator(
          onRefresh: () {
            return model.getHolidays();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Container(
              child: Column(
                children: [ToggleHoliday(), HolidayCardView()],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
