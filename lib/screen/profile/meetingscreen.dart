import 'package:cnattendance/provider/meetingcontroller.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:cnattendance/widget/meeting/meetinglistview.dart';
import 'package:cnattendance/widget/radialDecoration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';

class MeetingScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final model = Get.put(MeetingController());
    final enterprise = EnterpriseTheme.of(context);

    return Container(
      decoration: RadialDecoration(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          iconTheme: IconThemeData(color: enterprise.text),
          title: Text(
            translate('meeting_list_screen.meeting_detail'),
            style: TextStyle(
              color: enterprise.text,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: RefreshIndicator(
            onRefresh: () {
              model.page = 1;
              return model.getMeetingList();
            },
            child: MeetingListView()),
      ),
    );
  }
}
