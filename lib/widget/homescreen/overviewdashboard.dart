import 'package:cnattendance/features/community/social_feed_screen.dart';
import 'package:cnattendance/features/home_highlights/home_highlight_api.dart';
import 'package:cnattendance/features/home_highlights/home_highlights_screen.dart';
import 'package:cnattendance/features/repair_price/pages/repair_device_page.dart';
import 'package:cnattendance/features/repair_price/providers/repair_price_provider.dart';
import 'package:cnattendance/screen/dashboard/chatlistscreen.dart';
import 'package:cnattendance/screen/dashboard/morescreen.dart';
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
import 'package:cnattendance/core/theme/app_colors.dart';

class OverviewDashboard extends StatefulWidget {
  final PersistentTabController controller;
  final String? forceMenu;

  OverviewDashboard(this.controller, {this.forceMenu});

  @override
  State<OverviewDashboard> createState() => _OverviewDashboardState();
}

class _OverviewDashboardState extends State<OverviewDashboard> {
  @override
  Widget build(BuildContext context) {
    final _overview = Provider.of<DashboardProvider>(context).overviewList;
    final dashboard = context.watch<DashboardProvider>();
    final features = dashboard.features;
    final canRepair = context.watch<RepairPriceProvider>().canView;
    final canViewHighlights = features['home_highlight.view'] == '1';
    final employeeId =
        int.tryParse(context.watch<PrefProvider>().userId.trim()) ?? 0;
    final width = MediaQuery.sizeOf(context).width;
    final enterprise = EnterpriseTheme.of(context);

    bool shortcutVisible(LayoutItem item, String menu) {
      if (widget.forceMenu == menu) return true;
      if (!dashboard.mobileLayoutConfigured) {
        return enterprise.layout.shows(item);
      }
      return dashboard.isMobileMenuAt(menu, 'home_quick') ||
          dashboard.isMobileMenuAt(menu, 'top');
    }
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
          chipColor: AppColors.customFF2563EB,
          callback: () {
            pushScreen(context, screen: AttendanceScreen(), withNavBar: false);
          },
        ),
      if (LayoutItem.holiday.allowed(features))
        LayoutItem.holiday: CardOverView(
          type: translate('home_screen.holidays'),
          value: _overview['holiday'] ?? '—',
          icon: Icons.celebration,
          chipColor: AppColors.customFFF59E0B,
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
          chipColor: AppColors.customFF7C3AED,
          callback: () {
            pushScreen(context, screen: LeaveScreen(), withNavBar: false);
          },
        ),
      if (LayoutItem.events.allowed(features))
        LayoutItem.events: CardOverView(
          type: translate('home_screen.event'),
          value: _overview['active_event'] ?? '—',
          icon: Icons.calendar_month,
          chipColor: AppColors.customFFEC4899,
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
          chipColor: AppColors.customFF0EA5E9,
          callback: () {
            pushScreen(context, screen: ProjectScreen(), withNavBar: false);
          },
        ),
      if (LayoutItem.tasks.allowed(features))
        LayoutItem.tasks: CardOverView(
          type: translate('home_screen.task'),
          value: _overview['total_task'] ?? '—',
          icon: Icons.outlined_flag_sharp,
          chipColor: AppColors.customFF3B82F6,
          callback: () {
            pushScreen(context, screen: ProjectScreen(), withNavBar: false);
          },
        ),
      if (LayoutItem.awards.allowed(features))
        LayoutItem.awards: CardOverView(
          type: translate('home_screen.awards'),
          value: _overview['total_awards'] ?? '—',
          icon: Icons.workspace_premium_outlined,
          chipColor: AppColors.customFFF59E0B,
          callback: () {
            pushScreen(context, screen: AwardsScreen(), withNavBar: false);
          },
        ),
      if (LayoutItem.training.allowed(features))
        LayoutItem.training: CardOverView(
          type: translate('home_screen.training'),
          value: _overview['active_training'] ?? '—',
          icon: Icons.model_training_rounded,
          chipColor: AppColors.successToken,
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
          chipColor: AppColors.customFF6366F1,
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
      if (canRepair &&
          (widget.forceMenu == 'repair' ||
              enterprise.layout.shows(LayoutItem.repairShortcut)))
        LayoutItem.repairShortcut: _shortcut(
          context,
          translate('dashboard_screen.repair_list'),
          Icons.build_outlined,
          () => const RepairDevicePage(),
        ),
      if (LayoutItem.chatShortcut.allowed(features) &&
          shortcutVisible(LayoutItem.chatShortcut, 'chat'))
        LayoutItem.chatShortcut: _shortcut(
          context,
          translate('dashboard_screen.chat'),
          Icons.chat_bubble_outline,
          () => const ChatListScreen(),
        ),
      if (LayoutItem.socialShortcut.allowed(features) &&
          shortcutVisible(LayoutItem.socialShortcut, 'social-feed'))
        LayoutItem.socialShortcut: _shortcut(
          context,
          translate('community.social_feed'),
          Icons.dynamic_feed_outlined,
          () => const SocialFeedScreen(),
        ),
      if (canViewHighlights &&
          shortcutVisible(LayoutItem.highlightsShortcut, 'home-highlights'))
        LayoutItem.highlightsShortcut: _shortcut(
          context,
          'Highlights',
          Icons.auto_awesome_outlined,
          () => HomeHighlightsScreen(api: HomeHighlightApi()),
        ),
    };
    String? menuFor(LayoutItem item) => switch (item) {
          LayoutItem.present => 'attendance',
          LayoutItem.holiday => 'holiday',
          LayoutItem.leaveRequest => 'leave-request',
          LayoutItem.events => 'event',
          LayoutItem.projects || LayoutItem.tasks => 'project-management',
          LayoutItem.awards => 'award',
          LayoutItem.training => 'training',
          LayoutItem.socialPost => 'social-rewards',
          LayoutItem.chatShortcut => 'chat',
          LayoutItem.socialShortcut => 'social-feed',
          LayoutItem.highlightsShortcut => 'home-highlights',
          _ => null,
        };

    final shortcutItems = dashboard.mobileLayoutConfigured || widget.forceMenu != null
        ? LayoutItem.values.where((item) => item.area == LayoutArea.shortcuts)
        : enterprise.layout.visible(LayoutArea.shortcuts);
    List<Widget> tilesForZone(String zone) {
      final tiles = <Widget>[
        for (final item in shortcutItems)
          if (tilesByItem[item] case final Widget tile)
            if (widget.forceMenu != null
                ? menuFor(item) == widget.forceMenu
                : menuFor(item) == null
                    ? zone == 'home_quick'
                    : dashboard.mobileLayoutConfigured
                        ? dashboard.isMobileMenuAt(menuFor(item)!, zone)
                        : zone == 'home_quick')
              KeyedSubtree(key: ValueKey('${item.name}_$zone'), child: tile),
      ];
      if (widget.forceMenu != null || !dashboard.mobileLayoutConfigured) {
        return tiles;
      }
      final represented = tilesByItem.keys
          .map(menuFor)
          .whereType<String>()
          .toSet();
      for (final entry in dashboard.mobileLayout.entries) {
        if (entry.value.contains(zone) &&
            dashboard.features[entry.key] == '1' &&
            !represented.contains(entry.key)) {
          final label = entry.key
              .split('-')
              .map((word) => word.isEmpty
                  ? word
                  : '${word[0].toUpperCase()}${word.substring(1)}')
              .join(' ');
          tiles.add(KeyedSubtree(
            key: ValueKey('${entry.key}_$zone'),
            child: CardOverView(
              type: label,
              value: '',
              icon: Icons.apps_outlined,
              callback: () => pushScreen(
                context,
                screen: MoreScreen(),
                withNavBar: false,
              ),
            ),
          ));
        }
      }
      return tiles;
    }
    final tiles = tilesForZone('home_quick');
    final topTiles = tilesForZone('top');

    if (tiles.isEmpty && topTiles.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (topTiles.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            child: SizedBox(
              height: 78,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: topTiles.map((tile) => SizedBox(width: 88, child: tile)).toList(),
              ),
            ),
          ),
        if (tiles.isNotEmpty) Padding(
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
        ),
      ],
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
