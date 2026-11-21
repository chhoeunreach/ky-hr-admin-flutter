import 'package:cnattendance/features/repair_price/pages/repair_device_page.dart';
import 'package:cnattendance/features/repair_price/providers/repair_price_provider.dart';
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
    final canTimeLeave =
        features['mobile.function.Leave.saveTimeLeaveRequest'] == '1';
    final canRepair = context.watch<RepairPriceProvider>().canView;
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

    final actions = <(String, IconData, List<Color>, VoidCallback)>[
      if (features['attendance'] == '1')
        (
          'dashboard_screen.attendance',
          Icons.event_available_rounded,
          const [Color(0xFF2563EB), Color(0xFF60A5FA)],
          () => open(AttendanceScreen())
        ),
      if (features['leave-request'] == '1')
        (
          'dashboard_screen.leave',
          Icons.calendar_month_rounded,
          const [Color(0xFF9333EA), Color(0xFFC084FC)],
          () => open(LeaveScreen())
        ),
      if (canRequest && canTimeLeave)
        (
          'royal.time_off',
          Icons.flight_takeoff_rounded,
          const [Color(0xFFEA580C), Color(0xFFFBBF24)],
          () => request(EarlyLeaveSheet(checkedIn))
        ),
      if (canRequest)
        (
          'royal.request',
          Icons.description_rounded,
          const [Color(0xFF059669), Color(0xFF34D399)],
          () => request(IssueLeaveSheet())
        ),
      if (canRepair)
        (
          'royal.repair',
          Icons.handyman_rounded,
          const [Color(0xFFE11D48), Color(0xFFFB7185)],
          () => open(const RepairDevicePage())
        ),
      if (features['project-management'] == '1')
        (
          'home_screen.task',
          Icons.assignment_turned_in_rounded,
          const [Color(0xFF0284C7), Color(0xFF38BDF8)],
          () => open(ProjectScreen())
        ),
      if (features['chat'] == '1')
        (
          'dashboard_screen.chat',
          Icons.chat_bubble_rounded,
          const [Color(0xFF6366F1), Color(0xFFA78BFA)],
          () => open(const ChatListScreen())
        ),
      (
        'dashboard_screen.more',
        Icons.grid_view_rounded,
        const [Color(0xFF3B82F6), Color(0xFF818CF8)],
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
            for (final (key, icon, gradient, action) in actions)
              SizedBox(
                width: width,
                child: RoyalPanel(
                  radius: 13,
                  padding: EdgeInsets.zero,
                  child: InkWell(
                    onTap: action,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 74),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 3, vertical: 7),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          spacing: 5,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: gradient,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: gradient.first.withValues(alpha: 0.42),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2.5),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Icon(icon, color: Colors.white, size: 20),
                              ),
                            ),
                            Text(translate(key),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800)),
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
