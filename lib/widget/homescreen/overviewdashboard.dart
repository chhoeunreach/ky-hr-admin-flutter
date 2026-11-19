import 'package:cnattendance/features/community/social_feed_screen.dart';
import 'package:cnattendance/features/home_highlights/home_highlight_api.dart';
import 'package:cnattendance/features/home_highlights/home_highlights_screen.dart';
import 'package:cnattendance/features/repair_price/pages/repair_device_page.dart';
import 'package:cnattendance/screen/dashboard/chatlistscreen.dart';
import 'package:cnattendance/theme/theme_layout.dart';
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
    // Screenshot style: 4 columns on phones, 5 on wide layouts.
    final crossAxisCount = width >= 720
        ? 5
        : width > 340
            ? 4
            : 2;

    final tilesByItem = <LayoutItem, Widget>{
      if (LayoutItem.present.allowed(features))
        LayoutItem.present: CardOverView(
          type: translate('home_screen.present'),
          value: _overview['present'] ?? '—',
          icon: "assets/icons/present_icon.png",
          chipColor: const Color(0xFF2563EB),
          callback: () {
            pushScreen(context, screen: AttendanceScreen(), withNavBar: false);
          },
        ),
      if (LayoutItem.holiday.allowed(features))
        LayoutItem.holiday: CardOverView(
          type: translate('home_screen.holidays'),
          value: _overview['holiday'] ?? '—',
          icon: Icons.celebration,
          chipColor: const Color(0xFFF59E0B),
          callback: () {
            pushScreen(context,
                screen: HolidayScreen(),
                withNavBar: false,
                pageTransitionAnimation: PageTransitionAnimation.fade);
          },
        ),
      if (LayoutItem.leaveRequest.allowed(features))
        LayoutItem.leaveRequest: CardOverView(
          type: translate('home_screen.leave'),
          value: _overview['leave'] ?? '—',
          icon: Icons.sick,
          chipColor: const Color(0xFF7C3AED),
          callback: () {
            pushScreen(context, screen: LeaveScreen(), withNavBar: false);
          },
        ),
      if (LayoutItem.events.allowed(features))
        LayoutItem.events: CardOverView(
          type: translate('home_screen.event'),
          value: _overview['active_event'] ?? '—',
          icon: Icons.calendar_month,
          chipColor: const Color(0xFFEC4899),
          callback: () {
            pushScreen(context,
                screen: EventListScreen(),
                withNavBar: false,
                pageTransitionAnimation: PageTransitionAnimation.fade);
          },
        ),
      if (LayoutItem.projects.allowed(features))
        LayoutItem.projects: CardOverView(
          type: translate('home_screen.projects'),
          value: _overview['total_project'] ?? '—',
          icon: Icons.work_history_outlined,
          chipColor: const Color(0xFF0EA5E9),
          callback: () {
            pushScreen(context, screen: ProjectScreen(), withNavBar: false);
          },
        ),
      if (LayoutItem.tasks.allowed(features))
        LayoutItem.tasks: CardOverView(
          type: translate('home_screen.task'),
          value: _overview['total_task'] ?? '—',
          icon: Icons.outlined_flag_sharp,
          chipColor: const Color(0xFF3B82F6),
          callback: () {
            pushScreen(context, screen: ProjectScreen(), withNavBar: false);
          },
        ),
      if (LayoutItem.awards.allowed(features))
        LayoutItem.awards: CardOverView(
          type: translate('home_screen.awards'),
          value: _overview['total_awards'] ?? '—',
          icon: Icons.workspace_premium_outlined,
          chipColor: const Color(0xFFF59E0B),
          callback: () {
            pushScreen(context, screen: AwardsScreen(), withNavBar: false);
          },
        ),
      if (LayoutItem.training.allowed(features))
        LayoutItem.training: CardOverView(
          type: translate('home_screen.training'),
          value: _overview['active_training'] ?? '—',
          icon: Icons.model_training_rounded,
          chipColor: const Color(0xFF10B981),
          callback: () {
            pushScreen(context,
                screen: TrainingScreen(),
                withNavBar: true,
                pageTransitionAnimation: PageTransitionAnimation.fade);
          },
        ),
      if (LayoutItem.socialPost.allowed(features))
        LayoutItem.socialPost: CardOverView(
          type: 'Social Post',
          value: '1',
          subtitle: 'Daily log',
          icon: Icons.campaign_outlined,
          chipColor: const Color(0xFF6366F1),
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
      if (enterprise.layout.shows(LayoutItem.repairShortcut))
        LayoutItem.repairShortcut: _shortcut(
          context,
          translate('dashboard_screen.repair_list'),
          Icons.build_outlined,
          () => const RepairDevicePage(),
        ),
      if (LayoutItem.chatShortcut.allowed(features) &&
          enterprise.layout.shows(LayoutItem.chatShortcut))
        LayoutItem.chatShortcut: _shortcut(
          context,
          translate('dashboard_screen.chat'),
          Icons.chat_bubble_outline,
          () => const ChatListScreen(),
        ),
      if (LayoutItem.socialShortcut.allowed(features) &&
          enterprise.layout.shows(LayoutItem.socialShortcut))
        LayoutItem.socialShortcut: _shortcut(
          context,
          translate('community.social_feed'),
          Icons.dynamic_feed_outlined,
          () => const SocialFeedScreen(),
        ),
      if (enterprise.layout.shows(LayoutItem.highlightsShortcut))
        LayoutItem.highlightsShortcut: _shortcut(
          context,
          'Highlights',
          Icons.auto_awesome_outlined,
          () => HomeHighlightsScreen(api: HomeHighlightApi()),
        ),
    };
    final tiles = [
      for (final item in enterprise.layout.visible(LayoutArea.shortcuts))
        if (tilesByItem[item] case final Widget tile)
          KeyedSubtree(key: ValueKey(item), child: tile),
    ];

    if (tiles.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: EnterpriseGlass(
        radius: 22,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        glowColor: enterprise.primary,
        glowOpacity: 0.16,
        glowingBorder: true,
        child: GridView(
          shrinkWrap: true,
          primary: false,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 4,
            mainAxisSpacing: 6,
            mainAxisExtent: 78,
          ),
          children: tiles,
        ),
      ),
    );
  }

  Widget _shortcut(BuildContext context, String label, IconData icon,
      Widget Function() screen) {
    return CardOverView(
      type: label,
      value: '',
      icon: icon,
      callback: () => pushScreen(context, screen: screen(), withNavBar: false),
    );
  }
}
