import 'package:cnattendance/features/repair_price/pages/repair_device_page.dart';
import 'package:cnattendance/provider/dashboardprovider.dart';
import 'package:cnattendance/screen/dashboard/attendancescreen.dart';
import 'package:cnattendance/screen/dashboard/chatlistscreen.dart';
import 'package:cnattendance/screen/dashboard/leavescreen.dart';
import 'package:cnattendance/screen/dashboard/morescreen.dart';
import 'package:cnattendance/screen/dashboard/projectscreen.dart';
import 'package:cnattendance/widget/leavescreen/earlyleavesheet.dart';
import 'package:cnattendance/widget/leavescreen/issueleavesheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:persistent_bottom_nav_bar_v2/persistent_bottom_nav_bar_v2.dart';
import 'package:provider/provider.dart';

import 'royal_dashboard_widgets.dart';

class RoyalQuickActions extends StatelessWidget {
  const RoyalQuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    final features = provider.features;
    final canRequest =
        features['mobile.function.Leave.saveLeaveRequestDetail'] == '1';
    final attendance = provider.attendanceList;
    final checkedIn = royalHasTime('${attendance['check-in'] ?? ''}') &&
        !royalHasTime('${attendance['check-out'] ?? ''}');
    void open(Widget page) =>
        pushScreen(context, screen: page, withNavBar: false);
    void request(Widget page) => showModalBottomSheet<void>(
          context: context,
          useRootNavigator: true,
          isScrollControlled: true,
          builder: (context) =>
              Padding(padding: MediaQuery.viewInsetsOf(context), child: page),
        );

    final actions = <(String, IconData, Color, VoidCallback)>[
      if (features['attendance'] == '1')
        (
          'dashboard_screen.attendance',
          Icons.event_available,
          const Color(0xff47b4ff),
          () => open(AttendanceScreen())
        ),
      if (features['leave-request'] == '1')
        (
          'dashboard_screen.leave',
          Icons.calendar_month,
          const Color(0xffcaabff),
          () => open(LeaveScreen())
        ),
      if (canRequest)
        (
          'royal.time_off',
          Icons.flight_takeoff,
          const Color(0xffffc857),
          () => request(EarlyLeaveSheet(checkedIn))
        ),
      if (canRequest)
        (
          'royal.request',
          Icons.description_outlined,
          const Color(0xff72e4a7),
          () => request(IssueLeaveSheet())
        ),
      (
        'royal.repair',
        Icons.handyman,
        const Color(0xffff9dae),
        () => open(const RepairDevicePage())
      ),
      if (features['project-management'] == '1')
        (
          'home_screen.task',
          Icons.assignment_turned_in_outlined,
          const Color(0xff47d6ff),
          () => open(ProjectScreen())
        ),
      if (features['chat'] == '1')
        (
          'dashboard_screen.chat',
          Icons.chat_bubble_outline,
          const Color(0xffd2a5ff),
          () => open(const ChatListScreen())
        ),
      (
        'dashboard_screen.more',
        Icons.grid_view_rounded,
        const Color(0xffffd972),
        () => open(MoreScreen())
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = MediaQuery.textScalerOf(context).scale(12) > 19 ? 2 : 4;
        final width = (constraints.maxWidth - (columns - 1) * 6) / columns;
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final (key, icon, color, action) in actions)
              SizedBox(
                width: width,
                child: RoyalPanel(
                  radius: 13,
                  padding: EdgeInsets.zero,
                  child: InkWell(
                    onTap: action,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 68),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 3, vertical: 6),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          spacing: 4,
                          children: [
                            DecoratedBox(
                              decoration: BoxDecoration(
                                  color: color.withValues(alpha: .17),
                                  borderRadius: BorderRadius.circular(8)),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(icon, color: color, size: 20),
                              ),
                            ),
                            Text(translate(key),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 10, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
