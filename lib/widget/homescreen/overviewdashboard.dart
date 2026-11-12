import 'package:cnattendance/screen/dashboard/attendancescreen.dart';
import 'package:cnattendance/screen/dashboard/leavescreen.dart';
import 'package:cnattendance/provider/dashboardprovider.dart';
import 'package:cnattendance/provider/prefprovider.dart';
import 'package:cnattendance/screen/awards/awardsscreen.dart';
import 'package:cnattendance/screen/dashboard/projectscreen.dart';
import 'package:cnattendance/screen/eventscreen/eventlistscreen.dart';
import 'package:cnattendance/screen/profile/holidayscreen.dart';
import 'package:cnattendance/screen/social_rewards/social_submission_screen.dart';
import 'package:cnattendance/screen/training/trainingscreen.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:flutter/material.dart';
import 'package:cnattendance/widget/homescreen/cardoverview.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:persistent_bottom_nav_bar_v2/persistent_bottom_nav_bar_v2.dart';
import 'package:provider/provider.dart';

class OverviewDashboard extends StatefulWidget {
  final PersistentTabController controller;

  OverviewDashboard(this.controller);

  @override
  State<OverviewDashboard> createState() => _OverviewDashboardState();
}

class _OverviewDashboardState extends State<OverviewDashboard> {
  @override
  Widget build(BuildContext context) {
    final _overview = Provider.of<DashboardProvider>(context).overviewList;
    final features = context.watch<DashboardProvider>().features;
    final employeeId =
        int.tryParse(context.watch<PrefProvider>().userId.trim()) ?? 0;
    final width = MediaQuery.sizeOf(context).width;
    final enterprise = EnterpriseTheme.of(context);
    final crossAxisCount = width >= 720
        ? 3
        : width > 340
            ? 2
            : 1;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  translate('home_screen.overview'),
                  style: TextStyle(
                    color: enterprise.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                width: 34,
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  gradient: LinearGradient(
                    colors: [enterprise.accent, enterprise.primary],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GridView(
            shrinkWrap: true,
            primary: false,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              mainAxisExtent: 78,
            ),
            children: [
              if (features["attendance"] == "1")
                CardOverView(
                  type: translate('home_screen.present'),
                  value: _overview['present']!,
                  icon: "assets/icons/present_icon.png",
                  callback: () {
                    pushScreen(context,
                        screen: AttendanceScreen(), withNavBar: false);
                  },
                ),
              if (features["holiday"] == "1")
                CardOverView(
                  type: translate('home_screen.holidays'),
                  value: _overview['holiday']!,
                  icon: Icons.celebration,
                  callback: () {
                    pushScreen(context,
                        screen: HolidayScreen(),
                        withNavBar: false,
                        pageTransitionAnimation: PageTransitionAnimation.fade);
                  },
                ),
              if (features["leave-request"] == "1")
                CardOverView(
                  type: translate('home_screen.leave'),
                  value: _overview['leave']!,
                  icon: Icons.sick,
                  callback: () {
                    pushScreen(context,
                        screen: LeaveScreen(), withNavBar: false);
                  },
                ),
              if (features["event"] == "1")
                CardOverView(
                  type: translate('home_screen.event'),
                  value: _overview['active_event']!,
                  icon: Icons.calendar_month,
                  callback: () {
                    pushScreen(context,
                        screen: EventListScreen(),
                        withNavBar: false,
                        pageTransitionAnimation: PageTransitionAnimation.fade);
                  },
                ),
              if (features["project-management"] == "1")
                CardOverView(
                  type: translate('home_screen.projects'),
                  value: _overview['total_project']!,
                  icon: Icons.work_history_outlined,
                  callback: () {
                    pushScreen(context,
                        screen: ProjectScreen(),
                        withNavBar: false,
                        pageTransitionAnimation: PageTransitionAnimation.fade);
                  },
                ),
              if (features["project-management"] == "1")
                CardOverView(
                  type: translate('home_screen.task'),
                  value: _overview['total_task']!,
                  icon: Icons.outlined_flag_sharp,
                  callback: () {
                    pushScreen(context,
                        screen: ProjectScreen(),
                        withNavBar: false,
                        pageTransitionAnimation: PageTransitionAnimation.fade);
                  },
                ),
              if (features["award"] == "1")
                CardOverView(
                  type: translate('home_screen.awards'),
                  value: _overview['total_awards']!,
                  icon: Icons.workspace_premium_outlined,
                  callback: () {
                    pushScreen(context,
                        screen: AwardsScreen(),
                        withNavBar: false,
                        pageTransitionAnimation: PageTransitionAnimation.fade);
                  },
                ),
              if (features["training"] == "1")
                CardOverView(
                  type: translate('home_screen.training'),
                  value: _overview['active_training']!,
                  icon: Icons.model_training_rounded,
                  callback: () {
                    pushScreen(context,
                        screen: TrainingScreen(),
                        withNavBar: true,
                        pageTransitionAnimation: PageTransitionAnimation.fade);
                  },
                ),
              if (features["social-rewards"] == "1")
                CardOverView(
                  type: 'Social Post',
                  value: '1',
                  subtitle: 'Daily log',
                  icon: Icons.campaign_outlined,
                  callback: () {
                    pushScreen(
                      context,
                      screen: SocialSubmissionScreen(
                        employeeId: employeeId,
                      ),
                      withNavBar: false,
                      pageTransitionAnimation: PageTransitionAnimation.fade,
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
