import 'package:cnattendance/widget/attendancescreen/attendance_status_label.dart';
import 'package:cnattendance/model/employeeattendancereport.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:cnattendance/widget/profile/attendance_detail_bottom_sheet.dart';
import 'package:flutter/material.dart';

class AttendanceCardView extends StatelessWidget {
  final int index;
  final String grouped;
  final List<EmployeeAttendanceReport> attendances;

  AttendanceCardView(
    this.index,
    this.grouped,
    this.attendances,
  );

  @override
  Widget build(BuildContext context) {
    if (attendances.isEmpty) {
      return const SizedBox.shrink();
    }
    final enterprise = EnterpriseTheme.of(context);
    final rowColor = enterprise.isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.white.withValues(alpha: 0.94);
    final primaryText = enterprise.isDark ? Colors.white : enterprise.text;
    final secondaryText = enterprise.isDark
        ? Colors.white70
        : enterprise.text.withValues(alpha: 0.66);
    final statusItem = EmployeeAttendanceReport.statusForDay(attendances);
    final statusColor = _statusColor(statusItem.dayStatus, statusItem);
    final statusLabel =
        attendanceStatusLabel(statusItem.dayStatus, statusItem.statusLabel);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: rowColor,
        borderRadius: BorderRadius.circular(12),
        elevation: enterprise.isDark ? 0 : 1.5,
        shadowColor: enterprise.primary.withValues(alpha: 0.10),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            showModalBottomSheet(
                context: context,
                useRootNavigator: true,
                isScrollControlled: true,
                constraints: BoxConstraints(maxHeight: 300),
                builder: (context) {
                  return AttendanceDetailBottomSheet(grouped, attendances);
                });
          },
          child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 3),
              child: Row(
                crossAxisAlignment: attendances.length == 1
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    flex: 1,
                    child: Container(
                      child: Text(grouped,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: primaryText,
                            fontWeight: FontWeight.w800,
                          ),
                          textAlign: TextAlign.center),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Container(
                      child: Text(attendances.first.week_day,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: secondaryText,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center),
                    ),
                  ),
                  Expanded(
                    flex: 6,
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      primary: false,
                      shrinkWrap: true,
                      itemCount: attendances.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Row(
                            children: [
                              Expanded(
                                  flex: 3,
                                  child: Container(
                                    child: Text(attendances[index].check_in,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: primaryText,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        textAlign: TextAlign.center),
                                  )),
                              Expanded(
                                  flex: 3,
                                  child: Container(
                                    child: Text(attendances[index].check_out,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: primaryText,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        textAlign: TextAlign.center),
                                  )),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          statusLabel,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                      flex: 1,
                      child: Icon(
                        Icons.remove_red_eye,
                        color: enterprise.primary,
                        size: 17,
                      )),
                ],
              )),
        ),
      ),
    );
  }
}

Color _statusColor(String status, EmployeeAttendanceReport attendance) {
  switch (status) {
    case 'absent':
      return const Color(0xffdc2626);
    case 'leave':
    case 'time_leave':
      return const Color(0xff2563eb);
    case 'leave_request':
    case 'time_leave_request':
      return const Color(0xfff59e0b);
    default:
      return attendance.isPositiveStatus
          ? const Color(0xff16a34a)
          : const Color(0xfff59e0b);
  }
}
