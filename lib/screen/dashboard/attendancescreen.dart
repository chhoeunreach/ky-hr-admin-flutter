import 'package:cnattendance/provider/attendancereportprovider.dart';
import 'package:cnattendance/widget/headerprofile.dart';
import 'package:cnattendance/widget/premium_background.dart';
import 'package:flutter/material.dart';
import 'package:cnattendance/widget/attendancescreen/attendancestatus.dart';
import 'package:cnattendance/widget/attendancescreen/attendancetoggle.dart';
import 'package:cnattendance/widget/attendancescreen/reportlistview.dart';
import 'package:focus_detector/focus_detector.dart';
import 'package:provider/provider.dart';

class AttendanceScreen extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => AttendanceScreenState();
}

class AttendanceScreenState extends State<AttendanceScreen> {
  var initial = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && initial) {
        initial = false;
        loadAttendanceReport(initialize: true);
      }
    });
  }

  Future<String> loadAttendanceReport({bool initialize = false}) async {
    try {
      final provider = context.read<AttendanceReportProvider>();
      if (initialize) {
        await provider.getDate();
      } else {
        await provider.getAttendanceReport();
      }
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
    }
    return 'loaded';
  }

  @override
  Widget build(BuildContext context) {
    return PremiumBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: FocusDetector(
          onVisibilityGained: () {
            if (initial) initial = false;
            loadAttendanceReport(initialize: true);
          },
          child: SafeArea(
              child: RefreshIndicator(
            onRefresh: () {
              return loadAttendanceReport();
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                    child: Column(children: [
                  const HeaderProfile(),
                  AttendanceStatus(),
                  AttendanceToggle(),
                ])),
                const ReportListView(asSliver: true),
              ],
            ),
          )),
        ),
      ),
    );
  }
}
