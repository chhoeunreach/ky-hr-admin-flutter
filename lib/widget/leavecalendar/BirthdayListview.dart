import 'package:cnattendance/provider/leavecalendarcontroller.dart';
import 'package:cnattendance/widget/leavecalendar/birthdaycard.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class BirthdayListView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final LeaveCalendarController model = Get.find();
    return Obx(() => Container(
        padding: EdgeInsets.symmetric(horizontal: 20),
        width: double.infinity,
        child: ListView.builder(
            primary: false,
            shrinkWrap: true,
            itemCount: model.employeeBirthdayList.length,
            physics: NeverScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              final birthday = model.employeeBirthdayList[index];
              return GestureDetector(
                  onTap: () {},
                  child: BirthdayCard(
                      id: birthday.id,
                      name: birthday.name,
                      image: birthday.avatar, post: birthday.role)
              );
            }),
      ),
    );
  }
}
