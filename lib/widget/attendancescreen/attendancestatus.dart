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
    final active =
        status['check_in_at'] != "-" && status['check_out_at'] == "-";
    final progressColor = active ? enterprise.accent : enterprise.secondary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      child: EnterpriseGlass(
        radius: 24,
        padding: const EdgeInsets.all(18),
        glowColor: progressColor,
        glowOpacity: 0.10,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '${translate('attendance_screen.check_in')} | ${translate('attendance_screen.check_out')}',
              style: TextStyle(
                fontSize: 15,
                color: enterprise.text,
                fontWeight: FontWeight.w800,
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 20.0),
              child: LinearPercentIndicator(
                animation: true,
                animationDuration: 1000,
                lineHeight: 30.0,
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
              padding: EdgeInsets.only(left: 10, right: 10, top: 10),
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
