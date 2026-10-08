import 'package:cnattendance/provider/attendancereportprovider.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:provider/provider.dart';

class AttendanceStatus extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final status = Provider.of<AttendanceReportProvider>(context).todayReport;
    final enterprise = EnterpriseTheme.of(context);
    final dayStatus = status['day_status']?.toString() ?? 'present';
    final statusLabel = status['status_label']?.toString() ?? '';
    final active =
        status['check_in_at'] != "-" && status['check_out_at'] == "-";
    final progressColor = _statusColor(dayStatus, active, enterprise);
    final title = statusLabel.isNotEmpty
        ? _attendanceStatusLabel(dayStatus, statusLabel)
        : '${translate('attendance_screen.check_in')} | ${translate('attendance_screen.check_out')}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: EnterpriseGlass(
        radius: 16,
        padding: const EdgeInsets.all(12),
        glowColor: progressColor,
        glowOpacity: 0.10,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: progressColor,
                fontWeight: FontWeight.w800,
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 10.0),
              child: LinearPercentIndicator(
                animation: true,
                animationDuration: 1000,
                lineHeight: 18.0,
                padding: EdgeInsets.all(0),
                percent: status['production_percent']!,
                center: Text(
                  status['production_hour']!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                barRadius: const Radius.circular(20),
                backgroundColor: enterprise.text.withValues(alpha: 0.12),
                linearGradient: LinearGradient(
                  colors: [progressColor, enterprise.accent],
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.only(left: 6, right: 6, top: 7),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      status['check_in_at']!,
                      style: TextStyle(
                        color: enterprise.mutedText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      status['check_out_at']!,
                      style: TextStyle(
                        color: enterprise.mutedText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ]),
            ),
          ],
        ),
      ),
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

Color _statusColor(String status, bool active, EnterpriseTheme enterprise) {
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
      return active ? enterprise.accent : enterprise.secondary;
  }
}
