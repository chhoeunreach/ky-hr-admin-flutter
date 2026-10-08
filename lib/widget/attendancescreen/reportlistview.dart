import 'package:cnattendance/model/employeeattendancereport.dart';
import 'package:cnattendance/provider/attendancereportprovider.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:provider/provider.dart';
import 'package:cnattendance/widget/attendancescreen/attendancecardview.dart';

class ReportListView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final attendanceList =
        Provider.of<AttendanceReportProvider>(context).attendanceReport;
    final currentMonth =
        Provider.of<AttendanceReportProvider>(context).currentMonthReport;

    final attendanceGrouped =
        EmployeeAttendanceReport.groupAttendanceByDate(attendanceList);
    final groupedEntries = attendanceGrouped.keys.toList();

    if (attendanceList.length > 0) {
      return SingleChildScrollView(
        child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              children: [
                attendanceSummary(currentMonth),
                SizedBox(
                  height: 7,
                ),
                attendanceReportTitle(),
                ListView.builder(
                    shrinkWrap: true,
                    primary: false,
                    itemCount: groupedEntries.length,
                    itemBuilder: (ctx, i) {
                      return AttendanceCardView(i, groupedEntries[i],
                          attendanceGrouped[groupedEntries[i]] ?? []);
                    }),
              ],
            )),
      );
    } else {
      return Visibility(
        visible: Provider.of<AttendanceReportProvider>(context).isLoading
            ? true
            : false,
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }
  }

  Widget attendanceSummary(Map<String, dynamic> currentMonth) {
    return Builder(builder: (context) {
      final enterprise = EnterpriseTheme.of(context);
      final cardColor = enterprise.isDark
          ? Colors.white.withValues(alpha: 0.12)
          : Colors.white.withValues(alpha: 0.94);
      final labelColor = enterprise.isDark
          ? Colors.white
          : enterprise.text.withValues(alpha: 0.78);

      Widget summaryCard({
        required IconData icon,
        required String label,
        required String value,
      }) {
        return Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: enterprise.primary.withValues(alpha: 0.16),
              ),
              boxShadow: [
                BoxShadow(
                  color: enterprise.primary.withValues(
                    alpha: enterprise.isDark ? 0.12 : 0.10,
                  ),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: enterprise.primary.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: enterprise.primary, size: 20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: labelColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          color: enterprise.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return Row(
        children: [
          summaryCard(
            icon: Icons.event_available_rounded,
            label: translate('attendance_screen.present_days'),
            value: currentMonth["present_days"],
          ),
          const SizedBox(
            width: 8,
          ),
          summaryCard(
            icon: Icons.access_time_rounded,
            label: translate('attendance_screen.worked_hours'),
            value: currentMonth["worked_hour"],
          ),
        ],
      );
    });
  }

  Widget attendanceReportTitle() {
    return Builder(builder: (context) {
      final enterprise = EnterpriseTheme.of(context);
      return Container(
        margin: const EdgeInsets.only(top: 3, bottom: 2),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [enterprise.primary, enterprise.accent],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: enterprise.primary.withValues(alpha: 0.24),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: Container(
                child: Text(translate('attendance_screen.date'),
                    style: TextStyle(fontSize: 12, color: Colors.white),
                    textAlign: TextAlign.start),
              ),
            ),
            Expanded(
              flex: 1,
              child: Container(
                child: Text(translate('attendance_screen.day'),
                    style: TextStyle(fontSize: 12, color: Colors.white),
                    textAlign: TextAlign.center),
              ),
            ),
            Expanded(
              flex: 3,
              child: Container(
                child: Text(translate('attendance_screen.start_time'),
                    style: TextStyle(fontSize: 12, color: Colors.white),
                    textAlign: TextAlign.center),
              ),
            ),
            Expanded(
              flex: 3,
              child: Container(
                child: Text(translate('attendance_screen.end_time'),
                    style: TextStyle(fontSize: 12, color: Colors.white),
                    textAlign: TextAlign.center),
              ),
            ),
            Expanded(
              flex: 2,
              child: Container(
                child: Text(translate('attendance_screen.status'),
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: TextStyle(fontSize: 12, color: Colors.white),
                    textAlign: TextAlign.center),
              ),
            ),
            Expanded(
              flex: 1,
              child: Container(
                child: Text(translate('attendance_screen.action'),
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: TextStyle(fontSize: 12, color: Colors.white),
                    textAlign: TextAlign.right),
              ),
            ),
          ],
        ),
      );
    });
  }
}
