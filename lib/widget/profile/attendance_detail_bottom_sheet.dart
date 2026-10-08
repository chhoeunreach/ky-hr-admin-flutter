import 'package:cnattendance/widget/radialDecoration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';

import '../../model/employeeattendancereport.dart';

class AttendanceDetailBottomSheet extends StatefulWidget {
  final String date;
  final List<EmployeeAttendanceReport> attendances;

  AttendanceDetailBottomSheet(this.date, this.attendances);

  @override
  State<StatefulWidget> createState() => AttendanceDetailBottomSheetState();
}

class AttendanceDetailBottomSheetState
    extends State<AttendanceDetailBottomSheet> {
  @override
  Widget build(BuildContext context) {
    double workedHr = 0;
    final workingHr = widget.attendances.first.working_hours_min;
    final statusLabel = _attendanceStatusLabel(
      widget.attendances.first.dayStatus,
      widget.attendances.first.statusLabel,
    );
    final dayStatus = widget.attendances.first.dayStatus;

    for (final att in widget.attendances) {
      workedHr = workedHr + att.worked_hours_min;
    }

    final extraTime = workingHr - workedHr;

    return Container(
      decoration: RadialDecoration(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: SafeArea(
          child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${translate('attendance_screen.attendance_summary')}",
                style: TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
              ),
              IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(
                    Icons.close,
                    size: 20,
                    color: Colors.white,
                  )),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  translate('attendance_screen.start_time'),
                  textAlign: TextAlign.start,
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ),
              Expanded(
                child: Text(
                  translate('attendance_screen.end_time'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ),
              Expanded(
                child: Text(
                  translate('attendance_screen.worked_hours'),
                  textAlign: TextAlign.end,
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ),
            ],
          ),
          if (dayStatus != 'present')
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 8, bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                statusLabel,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ListView.builder(
            itemCount: widget.attendances.length,
            shrinkWrap: true,
            primary: false,
            itemBuilder: (context, index) {
              final attendance = widget.attendances[index];
              return Row(
                children: [
                  Expanded(
                    child: Text(
                      attendance.check_in,
                      textAlign: TextAlign.start,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      attendance.check_out,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      attendance.worked_hours,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Divider(
              color: Colors.white38,
              height: 5,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                translate('attendance_screen.worked_hours'),
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              Text(
                convertMinutesToFormattedString(workedHr),
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
          if (extraTime.isNegative)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  translate('attendance_screen.overtime'),
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                Text(
                  "+${convertMinutesToFormattedString(extraTime)}",
                  style: TextStyle(color: Colors.green, fontSize: 16),
                ),
              ],
            ),
          if (!extraTime.isNegative)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  translate('attendance_screen.undertime'),
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
                Text(
                  "-${convertMinutesToFormattedString(extraTime)}",
                  style: TextStyle(color: Colors.red, fontSize: 16),
                ),
              ],
            ),
        ],
      )),
    );
  }
}

String _attendanceStatusLabel(String status, String fallback) {
  final normalizedStatus = status.trim().toLowerCase();
  final normalizedFallback = fallback.trim().toLowerCase();
  switch (normalizedStatus.isNotEmpty ? normalizedStatus : normalizedFallback) {
    case 'present':
      return translate('attendance_status.present');
    case 'absent':
      return translate('attendance_status.absent');
    case 'leave':
      return translate('attendance_status.leave');
    case 'time_leave':
      return translate('attendance_status.time_leave');
    case 'leave_request':
      return translate('attendance_status.leave_request');
    case 'time_leave_request':
      return translate('attendance_status.time_leave_request');
    case 'holiday':
      return translate('attendance_status.holiday');
    case 'weekend':
      return translate('attendance_status.weekend');
    case 'late':
      return translate('attendance_status.late');
    case 'early':
      return translate('attendance_status.early');
  }

  if (normalizedFallback == 'on review' || normalizedFallback == 'pending') {
    return translate('attendance_status.pending');
  }
  if (normalizedFallback == 'approved') {
    return translate('attendance_status.approved');
  }
  if (normalizedFallback == 'rejected') {
    return translate('attendance_status.rejected');
  }
  return fallback;
}

String convertMinutesToFormattedString(double minutes) {
  final hours = (minutes / 60).floor();
  final remainingMinutes = (minutes % 60).round();
  return '${hours}h ${remainingMinutes}m';
}
