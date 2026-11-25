import 'package:cnattendance/features/community/social_feed_screen.dart';
import 'dart:ui';
import 'dart:async';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/features/appearance/app_appearance_api.dart';
import 'package:cnattendance/features/appearance/theme_modes_api.dart';
import 'package:cnattendance/provider/dashboardprovider.dart';
import 'package:cnattendance/provider/prefprovider.dart';
import 'package:cnattendance/screen/dashboard/homescreen.dart';
import 'package:cnattendance/screen/dashboard/leavescreen.dart';
import 'package:cnattendance/screen/dashboard/attendancescreen.dart';
import 'package:cnattendance/screen/dashboard/morescreen.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:cnattendance/theme/app_theme_mode.dart';
import 'package:cnattendance/theme/theme_layout.dart';
import 'package:cnattendance/theme/theme_provider.dart';
import 'package:cnattendance/widget/dashboard_drawer.dart';
import 'package:cnattendance/widget/dashboard_drawer_scope.dart';
import 'package:cnattendance/widget/radialDecoration.dart';
import 'package:cnattendance/widget/homescreen/overviewdashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:cnattendance/theme/royal_colors.dart';
import 'package:cnattendance/theme/royal_blue_day_theme.dart';
import 'package:cnattendance/widget/enterprise/khmer_luxury_frame.dart';
import 'package:persistent_bottom_nav_bar_v2/persistent_bottom_nav_bar_v2.dart';
import 'package:provider/provider.dart';
import 'package:cnattendance/features/repair_price/pages/repair_device_page.dart';
import 'package:cnattendance/features/repair_price/providers/repair_price_provider.dart';
import 'package:cnattendance/features/company_documents/company_documents_screen.dart';
import 'package:cnattendance/screen/assetscreen/admin_asset_list_screen.dart';
import 'package:cnattendance/screen/profile/teamsheetscreen.dart';
import 'package:cnattendance/screen/profile/noticescreen.dart';
import 'package:cnattendance/screen/profile/meetingscreen.dart';
import 'package:cnattendance/screen/profile/supportscreen.dart';
import 'package:cnattendance/screen/advancesalary/advancesalaryscreen.dart';
import 'package:cnattendance/screen/complainscreen/complainscreen.dart';
import 'package:cnattendance/screen/warningscreen/warningscreen.dart';
import 'package:cnattendance/screen/profile/holidayscreen.dart';
import 'package:cnattendance/screen/profile/leavecalendarscreen.dart';
import 'package:cnattendance/screen/profile/front_side_preview_page.dart';
import 'package:cnattendance/screen/dashboard/projectscreen.dart';
import 'package:cnattendance/screen/awards/awardsscreen.dart';
import 'package:cnattendance/screen/training/trainingscreen.dart';
import 'package:cnattendance/screen/profile/payslipscreen.dart';
import 'package:cnattendance/screen/tadascreen/tadascreen.dart';
import 'package:cnattendance/utils/asset_permissions.dart';
import 'package:cnattendance/features/daily_records/quick_create.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

class DashboardScreen extends StatefulWidget {
  static const String routeName = '/dashboard';

  @override
  State<StatefulWidget> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  final PersistentTabController _controller =
      PersistentTabController(initialIndex: 0);
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedRailIndex = 0;
  bool? _railExpanded;
  bool _socialFeedImmersive = false;
  bool _repairNavigationVisible = true;
  final Map<String, GlobalKey<NavigatorState>> _tabNavigatorKeys = {};
  final Map<String, _TabRouteObserver> _tabRouteObservers = {};

  bool _loadedUser = false;
  bool _repairPermissionsStarted = false;
  bool _initialLandingHandled = false;
  RepairPriceProvider? _repairProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _loadedUser) {
        return;
      }
      _loadedUser = true;
      context.read<PrefProvider>().getUser();
      unawaited(_refreshAppAppearance());
      unawaited(_refreshThemeModes());
      unawaited(context.read<DashboardProvider>().refreshMobileFeatures());
    });
    _restoreRailState();
  }

  /// Pulls the admin-managed background + floating-effect switches so the
  /// whole app reflects the latest configuration.
  Future<void> _refreshAppAppearance() async {
    try {
      final config = await AppAppearanceApi().fetch();
      if (!mounted) return;
      await context.read<ThemeProvider>().applyServerAppearance(config);
    } catch (_) {
      // Keep the last cached appearance while the server is unreachable.
    }
  }

  /// Pulls active and role-filtered theme modes and admin default colors.
  Future<void> _refreshThemeModes() async {
    try {
      final modes = await ThemeModesApi().fetch();
      if (!mounted) return;
      await context.read<ThemeProvider>().applyRemoteThemeModes(modes);
    } catch (_) {
      // Keep the last cached theme modes while the server is unreachable.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (mounted && state == AppLifecycleState.resumed) {
      unawaited(context.read<DashboardProvider>().refreshMobileFeatures());
      unawaited(_refreshAppAppearance());
      unawaited(_refreshThemeModes());
      unawaited(_repairProvider?.loadWebPermissions());
    }
  }

  void _ensureRepairPermissions(BuildContext context) {
    if (_repairPermissionsStarted) return;
    _repairPermissionsStarted = true;
    _repairProvider = context.read<RepairPriceProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_repairProvider?.loadWebPermissions());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _restoreRailState() async {
    final expanded = await Preferences().getRailExpanded();
    if (!mounted || expanded == null) return;
    setState(() {
      _railExpanded = expanded;
    });
  }

  ItemConfig getItemConfig(Icon icon, String title) {
    return ItemConfig(
      icon: icon,
      activeColorSecondary: AppColors.white,
      activeForegroundColor: AppColors.white,
      inactiveBackgroundColor: AppColors.white30,
      inactiveForegroundColor: AppColors.white30,
      title: title,
    );
  }

  @override
  Widget build(BuildContext context) {
    final enterprise = EnterpriseTheme.of(context);
    const drawer = DashboardDrawer();
    return Scaffold(
      key: _scaffoldKey,
      drawer: enterprise.layout.menuOnRight ? null : drawer,
      endDrawer: enterprise.layout.menuOnRight ? drawer : null,
      body: ChangeNotifierProvider(
        create: (_) => RepairPriceProvider(),
        child: DashboardDrawerScope(
          openDrawer: () {
            _openDashboardDrawer(enterprise.layout.menuOnRight);
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              _ensureRepairPermissions(context);
              if (constraints.maxWidth >= 720) {
                return _buildRailLayout(context, constraints.maxWidth);
              }
              return _buildMobileTabs(context);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildRailLayout(BuildContext context, double width) {
    final enterprise = EnterpriseTheme.of(context);
    final sidebarFg = sidebarForeground(enterprise);
    final extended = _railExpanded ?? (width >= 1100);
    final features = context.watch<DashboardProvider>().features;
    final hasSocialFeed = features['social-feed'] != '0';
    final hasRepair = features['repair'] != '0';

    final railItems = [
      LayoutItem.home,
      if (hasSocialFeed) LayoutItem.social,
      if (hasRepair) LayoutItem.repair,
      if (features['attendance'] != '0') LayoutItem.attendance,
      LayoutItem.more,
    ];
    final repairIndex = railItems.indexOf(LayoutItem.repair);
    final visibleRail = enterprise.layout.visibleTabIndices(railItems);
    final selectedRail = visibleRail.indexOf(_selectedRailIndex);
    final showDrawerButton = enterprise.layout.showMenuButton &&
        !(_selectedRailIndex == 0 &&
            enterprise.layout.shows(LayoutItem.profile));
    final destinations = <NavigationRailDestination>[
      NavigationRailDestination(
        icon: const Icon(Icons.dashboard_outlined),
        selectedIcon: const Icon(Icons.dashboard),
        label: Text(translate('dashboard_screen.home')),
      ),
      if (hasSocialFeed)
        NavigationRailDestination(
          icon: const Icon(Icons.dynamic_feed_outlined),
          selectedIcon: const Icon(Icons.dynamic_feed),
          label: Text(translate('community.social_feed')),
        ),
      if (hasRepair)
        NavigationRailDestination(
          icon: const Icon(Icons.build_circle_outlined),
          selectedIcon: const Icon(Icons.build_circle),
          label: Text(translate('dashboard_screen.repair_list')),
        ),
      if (features["attendance"] != "0")
        NavigationRailDestination(
          icon: const Icon(Icons.analytics_outlined),
          selectedIcon: const Icon(Icons.analytics),
          label: Text(translate('dashboard_screen.attendance')),
        ),
      NavigationRailDestination(
        icon: const Icon(Icons.settings_outlined),
        selectedIcon: const Icon(Icons.settings),
        label: Text(translate('dashboard_screen.more')),
      ),
    ];
    final pages = <Widget>[
      HomeScreen(_controller),
      if (hasSocialFeed)
        SocialFeedScreen(
            showBackButton: false,
            onImmersiveChanged: _handleSocialFeedImmersive),
      if (hasRepair)
        _selectedRailIndex == repairIndex
            ? const RepairDevicePage(showBackButton: false)
            : const SizedBox.shrink(),
      if (features["attendance"] != "0") AttendanceScreen(),
      MoreScreen(),
    ];
    final socialFeedIndex = hasSocialFeed ? 1 : -1;
    final showRailControls =
        _selectedRailIndex.clamp(0, destinations.length - 1) != socialFeedIndex;

    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: enterprise.pageGradient,
            border: Border(
              right: BorderSide(
                color: sidebarFg.withValues(alpha: 0.14),
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(7, 0),
              ),
            ],
          ),
          child: NavigationRail(
            selectedIndex: selectedRail < 0 ? null : selectedRail,
            extended: extended,
            minWidth: 76,
            minExtendedWidth: 204,
            groupAlignment: -0.78,
            labelType: extended
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.selected,
            backgroundColor: Colors.transparent,
            indicatorColor: enterprise.accent.withValues(alpha: 0.24),
            indicatorShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            selectedIconTheme: IconThemeData(color: sidebarFg, size: 22),
            selectedLabelTextStyle: TextStyle(
              color: sidebarFg,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
            unselectedIconTheme: IconThemeData(
              color: sidebarFg.withValues(alpha: 0.68),
              size: 21,
            ),
            unselectedLabelTextStyle: TextStyle(
              color: sidebarFg.withValues(alpha: 0.68),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
            leading: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 16),
              child: extended
                  ? Row(
                      children: [
                        if (showRailControls && showDrawerButton)
                          IconButton.filledTonal(
                            tooltip: 'Menu',
                            icon: const Icon(Icons.menu),
                            onPressed: () {
                              _openDashboardDrawer(
                                  enterprise.layout.menuOnRight);
                            },
                          ),
                        if (showRailControls && showDrawerButton)
                          const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'HRKY',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: sidebarFg,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (showRailControls) ...[
                          const SizedBox(width: 4),
                          _railToggleButton(extended: true),
                        ],
                      ],
                    )
                  : Column(
                      children: [
                        if (showRailControls) ...[
                          if (showDrawerButton) ...[
                            IconButton.filledTonal(
                              tooltip: 'Menu',
                              icon: const Icon(Icons.menu),
                              onPressed: () {
                                _openDashboardDrawer(
                                    enterprise.layout.menuOnRight);
                              },
                            ),
                            const SizedBox(height: 8),
                          ],
                          _railToggleButton(extended: false),
                        ],
                      ],
                    ),
            ),
            destinations: [
              for (final index in visibleRail) destinations[index]
            ],
            onDestinationSelected: (index) {
              setState(() {
                _selectedRailIndex = visibleRail[index];
              });
            },
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _selectedRailIndex.clamp(
                0, pages.isEmpty ? 0 : pages.length - 1),
            children: pages,
          ),
        ),
      ],
    );
  }

  Widget _railToggleButton({required bool extended}) {
    return IconButton.filledTonal(
      tooltip: extended ? 'Collapse sidebar' : 'Expand sidebar',
      icon: Icon(
        extended ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
      ),
      onPressed: () {
        final next = !extended;
        setState(() {
          _railExpanded = next;
        });
        Preferences().setRailExpanded(next);
      },
    );
  }

  void _openDashboardDrawer(bool onRight) {
    final scaffold = _scaffoldKey.currentState;
    if (onRight) {
      scaffold?.openEndDrawer();
    } else {
      scaffold?.openDrawer();
    }
  }

  Widget _buildMobileTabs(BuildContext context) {
    final enterprise = EnterpriseTheme.of(context);
    final sidebarFg = sidebarForeground(enterprise);
    final dashboard = context.watch<DashboardProvider>();
    final features = dashboard.features;

    final tabIds = <LayoutItem>[];
    final tabKeys = <String>[];
    final tabs = <PersistentTabConfig>[];

    void addTab(LayoutItem id, Widget screen, ItemConfig item,
        {String? tabKey}) {
      tabIds.add(id);
      tabKeys.add(tabKey ?? id.name);
      tabs.add(PersistentTabConfig(
        screen: screen,
        item: item,
        navigatorConfig: _mobileTabNavigatorConfig(tabKey ?? id.name),
      ));
    }

    void addBottomMenu(String menu) {
      if (menu == 'social-feed' && features[menu] != '0') {
        addTab(
          LayoutItem.social,
          SocialFeedScreen(
            showBackButton: false,
            onImmersiveChanged: _handleSocialFeedImmersive,
          ),
          getItemConfig(
            const Icon(Icons.dynamic_feed_outlined),
            translate('community.social_feed'),
          ),
        );
        return;
      }
      if (menu == 'repair' && features[menu] != '0') {
        addTab(
          LayoutItem.repair,
          RepairDevicePage(
            showBackButton: false,
            onNavigationVisibilityChanged: (visible) {
              if (_repairNavigationVisible == visible || !mounted) return;
              setState(() => _repairNavigationVisible = visible);
            },
          ),
          getItemConfig(
            const Icon(Icons.build_circle_outlined),
            translate(enterprise.isRoyalBlueGold
                ? 'royal.repair'
                : 'dashboard_screen.repair_list'),
          ),
        );
        return;
      }
      if (menu == 'leave-request' && features[menu] != '0') {
        addTab(
          LayoutItem.leave,
          LeaveScreen(),
          getItemConfig(
            const Icon(Icons.sick),
            translate('dashboard_screen.leave'),
          ),
        );
        return;
      }
      if (menu == 'attendance' && features[menu] != '0') {
        addTab(
          LayoutItem.attendance,
          AttendanceScreen(),
          getItemConfig(
            const Icon(Icons.co_present_outlined),
            translate('dashboard_screen.attendance'),
          ),
        );
        return;
      }
      if ((menu == 'assets' ||
              menu == 'admin_assets' ||
              menu == 'admin-assets') &&
          AssetPermissions.canOpenAdmin(features)) {
        addTab(
          LayoutItem.more,
          const AdminAssetListScreen(),
          getItemConfig(
            const Icon(Icons.inventory_2_outlined),
            translate('more_screen.admin_assets'),
          ),
          tabKey: 'role-assets',
        );
        return;
      }
      if (menu == 'company-documents' && features[menu] != '0') {
        addTab(
          LayoutItem.more,
          const CompanyDocumentsScreen(),
          getItemConfig(
            const Icon(Icons.folder_shared_outlined),
            translate('more_screen.company_documents'),
          ),
          tabKey: 'role-company-documents',
        );
        return;
      }
      if (menu == 'team-sheet' && features[menu] != '0') {
        addTab(
          LayoutItem.more,
          TeamSheetScreen(),
          getItemConfig(
            const Icon(Icons.group),
            translate('more_screen.team_sheet'),
          ),
          tabKey: 'role-team-sheet',
        );
        return;
      }
      if (dashboard.mobileLayoutConfigured && features[menu] != '0') {
        addTab(
          LayoutItem.more,
          _RoleFunctionTab(menu, _controller),
          getItemConfig(const Icon(Icons.apps_outlined), _roleMenuLabel(menu)),
          tabKey: 'role-$menu',
        );
      }
    }

    addTab(
      LayoutItem.home,
      HomeScreen(_controller),
      getItemConfig(
        const Icon(Icons.home_filled),
        translate('dashboard_screen.home'),
      ),
    );
    if (dashboard.mobileLayoutConfigured) {
      for (final menu in dashboard.mobileMenusAt('bottom')) {
        addBottomMenu(menu);
      }
    } else {
      for (final menu in const [
        'repair',
        'leave-request',
        'attendance',
        'social-feed',
      ]) {
        addBottomMenu(menu);
      }
    }
    addTab(
      LayoutItem.more,
      MoreScreen(),
      getItemConfig(
        const Icon(Icons.more),
        translate('dashboard_screen.more'),
      ),
    );

    if (!_initialLandingHandled &&
        dashboard.mobileLayoutConfigured &&
        dashboard.mobileLayoutInitialTab.isNotEmpty &&
        dashboard.mobileLayoutInitialTab != 'home') {
      final target = dashboard.mobileLayoutInitialTab;
      final targetIndex = tabKeys.indexWhere((k) =>
          k == target ||
          k == 'role-$target' ||
          k.toLowerCase().contains(target.toLowerCase()));
      if (targetIndex >= 0 && targetIndex < tabs.length) {
        _controller.jumpToTab(targetIndex);
      }
      _initialLandingHandled = true;
    }

    if (_controller.index >= tabs.length) {
      _controller.jumpToTab(0);
    }

    final activeTabIndex = _controller.index.clamp(0, tabIds.length - 1);
    final activeNavigator =
        _tabNavigatorKeys[tabKeys[activeTabIndex]]?.currentState;
    final isSocialFeedActive = tabIds[activeTabIndex] == LayoutItem.social;
    final immersive = isSocialFeedActive && _socialFeedImmersive;
    final socialDetailOpen =
        isSocialFeedActive && (activeNavigator?.canPop() ?? false);
    final isRepairActive = tabIds[activeTabIndex] == LayoutItem.repair;
    final repairDetailOpen =
        isRepairActive && (activeNavigator?.canPop() ?? false);
    final hideMenuButton = immersive || (activeNavigator?.canPop() ?? false);
    final homeTabIndex = tabIds.indexOf(LayoutItem.home);
    final homeShowsMenuInProfile = activeTabIndex == homeTabIndex &&
        enterprise.layout.showMenuButton &&
        enterprise.layout.shows(LayoutItem.profile);

    final visibleTabs = dashboard.mobileLayoutConfigured
        ? List<int>.generate(tabIds.length, (index) => index)
        : enterprise.layout.visibleTabIndices(tabIds);
    final menuOnRight = enterprise.layout.menuOnRight;
    final moreSlot = visibleTabs.indexOf(tabIds.lastIndexOf(LayoutItem.more));
    final showCreateRecord = moreSlot >= 0 &&
        !hideMenuButton &&
        MediaQuery.viewInsetsOf(context).bottom == 0;

    return Stack(
      children: [
        PersistentTabView(
          key: ValueKey(
              'tabs_${features["social-feed"]}_${features["repair"]}_${features["leave-request"]}_${features["attendance"]}_${dashboard.mobileLayout.hashCode}_${dashboard.mobileLayoutPositions.hashCode}'),
          controller: _controller,
          onTabChanged: (index) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _repairNavigationVisible = true;
                });
              }
            });
            if (index != tabIds.indexOf(LayoutItem.repair)) return;
            final provider = context.read<RepairPriceProvider>();
            provider.initDevicePage();
          },
          backgroundColor: enterprise.layout.background ?? themedChromeColor(),
          handleAndroidBackButtonPress: true,
          resizeToAvoidBottomInset: true,
          stateManagement: true,
          hideNavigationBar: immersive ||
              socialDetailOpen ||
              repairDetailOpen ||
              (isRepairActive && !_repairNavigationVisible),
          floatingActionButton: showCreateRecord
              ? CreateRecordButton(
                  showDeliveryShortcut: features['delivery'] != '0',
                )
              : null,
          floatingActionButtonLocation: showCreateRecord
              ? AboveMoreLocation(slot: moreSlot, slots: visibleTabs.length)
              : null,
          popAllScreensOnTapOfSelectedTab: true,
          popActionScreens: PopActionScreensType.all,
          tabs: tabs,
          navBarBuilder: (navBarConfig) {
            return DashboardNavigationBar(
                navBarConfig: navBarConfig, visibleTabs: visibleTabs);
          },
        ),
        // Sidebar menu button pinned at the top-left corner of every tab screen.
        if (!hideMenuButton &&
            enterprise.layout.showMenuButton &&
            !homeShowsMenuInProfile)
          Positioned(
            top: 0,
            left: menuOnRight ? null : 12,
            right: menuOnRight ? 12 : null,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: enterprise.isLight
                    ? Material(
                        color: AppColors.white,
                        elevation: 5,
                        shadowColor: enterprise.primary.withValues(alpha: .18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: enterprise.primary.withValues(alpha: .16),
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _openDashboardDrawer(
                              enterprise.layout.menuOnRight),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 11),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.menu_rounded,
                                    size: 21, color: enterprise.primary),
                                const SizedBox(width: 9),
                                // Text(
                                //   'ម៉ឺនុយ',
                                //   style: TextStyle(
                                //     color: enterprise.primary,
                                //     fontSize: 14,
                                //     fontWeight: FontWeight.w700,
                                //   ),
                                // ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : Material(
                        color: enterprise.isRoyalLuxuryDay
                            ? KhmerLuxuryColors.iceBlue.withValues(alpha: .94)
                            : enterprise.colors.backgroundColor
                                .withValues(alpha: 0.84),
                        shape: enterprise.isKhmerHeritage ||
                                enterprise.isRoyalBlueGold
                            ? RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(13),
                                side: BorderSide(
                                  color: enterprise.isRoyalLuxuryDay
                                      ? KhmerLuxuryColors.metallicGold
                                      : enterprise.cardBorder,
                                ),
                              )
                            : const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: IconButton(
                          tooltip: MaterialLocalizations.of(context)
                              .openAppDrawerTooltip,
                          icon: Icon(
                            Icons.menu,
                            color: enterprise.isRoyalLuxuryDay
                                ? KhmerLuxuryColors.deepRoyalBlue
                                : sidebarFg,
                          ),
                          onPressed: () {
                            _openDashboardDrawer(enterprise.layout.menuOnRight);
                          },
                        ),
                      ),
              ),
            ),
          ),
      ],
    );
  }

  NavigatorConfig _mobileTabNavigatorConfig(String id) {
    final navigatorKey =
        _tabNavigatorKeys.putIfAbsent(id, () => GlobalKey<NavigatorState>());
    final observer = _tabRouteObservers.putIfAbsent(
        id, () => _TabRouteObserver(_onMobileTabRouteChanged));
    return NavigatorConfig(
      navigatorKey: navigatorKey,
      navigatorObservers: <NavigatorObserver>[observer],
    );
  }

  void _onMobileTabRouteChanged() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  void _handleSocialFeedImmersive(bool immersive) {
    if (!mounted || _socialFeedImmersive == immersive) return;
    setState(() => _socialFeedImmersive = immersive);
  }
}

String _roleMenuLabel(String menu) => menu
    .split('-')
    .map((word) =>
        word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}')
    .join(' ');

class _RoleFunctionTab extends StatelessWidget {
  const _RoleFunctionTab(this.menu, this.controller);

  final String menu;
  final PersistentTabController controller;

  @override
  Widget build(BuildContext context) {
    if (menu == 'assets' || menu == 'admin_assets' || menu == 'admin-assets') {
      return const AdminAssetListScreen();
    }
    if (menu == 'company-documents') {
      return const CompanyDocumentsScreen();
    }
    if (menu == 'team-sheet') {
      return TeamSheetScreen();
    }
    if (menu == 'repair') {
      return const RepairDevicePage();
    }
    if (menu == 'notice') {
      return NoticeScreen();
    }
    if (menu == 'meeting') {
      return MeetingScreen();
    }
    if (menu == 'advance-salary') {
      return AdvanceSalaryScreen();
    }
    if (menu == 'support') {
      return SupportScreen();
    }
    if (menu == 'complaint') {
      return ComplainScreen();
    }
    if (menu == 'warning') {
      return WarningScreen();
    }
    if (menu == 'holiday') {
      return HolidayScreen();
    }
    if (menu == 'leave-calendar') {
      return LeaveCalendarScreen();
    }
    if (menu == 'id-card') {
      return const FrontSidePreviewPage();
    }
    if (menu == 'project-management') {
      return ProjectScreen();
    }
    if (menu == 'award') {
      return AwardsScreen();
    }
    if (menu == 'training') {
      return TrainingScreen();
    }
    if (menu == 'tada') {
      return TadaScreen();
    }
    if (menu == 'payroll-management') {
      return PaySlipScreen();
    }
    const quickServiceMenus = {
      'leave-request',
      'event',
      'social-rewards',
      'chat',
      'home-highlights',
    };
    if (!quickServiceMenus.contains(menu)) return MoreScreen();
    return Scaffold(
      appBar: AppBar(title: Text(_roleMenuLabel(menu))),
      body: SingleChildScrollView(
        child: OverviewDashboard(controller, forceMenu: menu),
      ),
    );
  }
}

class DashboardNavigationBar extends StatelessWidget {
  final NavBarConfig navBarConfig;

  const DashboardNavigationBar(
      {super.key, required this.navBarConfig, required this.visibleTabs});

  final List<int> visibleTabs;

  @override
  Widget build(BuildContext context) {
    final enterprise = EnterpriseTheme.of(context);
    final isDayMode = enterprise.mode == AppThemeMode.light;
    final isCleanDay =
        isDayMode && (context.watch<ThemeProvider?>()?.dayModeClean ?? true);
    final navSurface = Container(
      height: 66,
      decoration: BoxDecoration(
        color: isCleanDay ? AppColors.white : null,
        gradient: isCleanDay
            ? null
            : isDayMode
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.white.withValues(alpha: 0.92),
                      const Color(0xfff1f5f9).withValues(alpha: 0.88),
                    ],
                  )
                : enterprise.isRoyalLuxuryDay
                    ? KhmerLuxuryColors.frosted
                    : enterprise.isRoyalDay
                        ? RoyalDayColors.frosted
                        : enterprise.isRoyalBlueGold
                            ? const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  RoyalColors.deepBlue,
                                  RoyalColors.navy
                                ],
                              )
                            : enterprise.pageGradient,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isCleanDay
              ? AppColors.customFFE2E8F0
              : enterprise.accent.withValues(
                  alpha:
                      enterprise.isKhmerHeritage || enterprise.isRoyalBlueGold
                          ? .68
                          : .34,
                ),
          width: 1,
        ),
        boxShadow: isCleanDay
            ? const [
                BoxShadow(
                  color: Color(0x0a0f172a),
                  blurRadius: 20,
                  offset: Offset(0, 4),
                ),
                BoxShadow(
                  color: Color(0x050f172a),
                  blurRadius: 6,
                  offset: Offset(0, 1),
                ),
              ]
            : [
                BoxShadow(
                  color: enterprise.primary.withValues(alpha: 0.18),
                  blurRadius: 24,
                  spreadRadius: 0.5,
                ),
                BoxShadow(
                  color: AppColors.black
                      .withValues(alpha: enterprise.isRoyalDay ? .05 : .35),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Row(
        children: [
          for (final i in visibleTabs)
            Expanded(
              child: _EnterpriseNavItem(
                item: navBarConfig.items[i],
                selected: navBarConfig.selectedIndex == i,
                onTap: () => navBarConfig.onItemSelected(i),
              ),
            ),
        ],
      ),
    );
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            enabled: !isCleanDay && !enterprise.isRoyalBlueGold,
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: enterprise.isRoyalLuxuryDay
                ? KhmerLuxuryFrame(
                    style: KhmerFrameStyle.goldBlue,
                    radius: 28,
                    cornerSize: 16,
                    child: navSurface,
                  )
                : navSurface,
          ),
        ),
      ),
    );
  }
}

class _EnterpriseNavItem extends StatelessWidget {
  final ItemConfig item;
  final bool selected;
  final VoidCallback onTap;

  const _EnterpriseNavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enterprise = EnterpriseTheme.of(context);
    final heritage = enterprise.isKhmerHeritage;
    final royal = enterprise.isRoyalBlueGold;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 260);
    final inactiveColor = enterprise.isRoyalDay
        ? (enterprise.isRoyalLuxuryDay
            ? KhmerLuxuryColors.darkText
            : enterprise.text)
        : enterprise.mode == AppThemeMode.light
            ? AppColors.customFF64748B
            : sidebarForeground(enterprise)
                .withValues(alpha: royal ? .97 : .72);
    final customAccent = enterprise.layout.accent;
    final activeColor = customAccent == null
        ? (enterprise.isRoyalDay
            ? enterprise.isRoyalLuxuryDay
                ? KhmerLuxuryColors.darkText
                : AppColors.white
            : royal
                ? RoyalColors.navy
                : heritage
                    ? enterprise.colors.backgroundColor
                    : AppColors.white)
        : ThemeData.estimateBrightnessForColor(customAccent) == Brightness.dark
            ? AppColors.white
            : AppColors.customFF211720;
    final textColor = selected ? activeColor : inactiveColor;
    final iconTheme = IconThemeData(
      color: textColor,
      size: 20,
    );

    final Gradient? tabGradient = selected
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: customAccent != null
                ? [
                    customAccent,
                    Color.lerp(
                        customAccent,
                        activeColor == AppColors.white
                            ? AppColors.black
                            : AppColors.white,
                        .16)!,
                  ]
                : enterprise.isRoyalDay
                    ? enterprise.isRoyalLuxuryDay
                        ? const [
                            KhmerLuxuryColors.brightGold,
                            KhmerLuxuryColors.metallicGold,
                            KhmerLuxuryColors.darkGold,
                          ]
                        : RoyalDayColors.controls.colors
                    : royal
                        ? RoyalColors.goldGradient.colors
                        : heritage
                            ? [enterprise.text, enterprise.accent]
                            : enterprise.mode == AppThemeMode.light
                                ? [
                                    enterprise.primary,
                                    enterprise.secondary,
                                  ]
                                : [
                                    sidebarTone(enterprise.primary),
                                    sidebarTone(enterprise.secondary),
                                  ],
          )
        : null;

    final List<BoxShadow>? tabShadow = selected
        ? [
            BoxShadow(
              color: enterprise.primary.withValues(alpha: 0.36),
              blurRadius: 16,
              offset: const Offset(0, 3),
            ),
          ]
        : null;

    final BoxBorder? tabBorder = selected
        ? Border.all(
            color: enterprise.accent
                .withValues(alpha: enterprise.isRoyalDay ? .9 : .44))
        : null;

    return Semantics(
      selected: selected,
      button: true,
      label: item.title,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: duration,
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: tabGradient,
            border: tabBorder,
            boxShadow: tabShadow,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconTheme(
                data: iconTheme,
                child: selected ? item.icon : item.inactiveIcon,
              ),
              const SizedBox(height: 2),
              Flexible(
                child: AnimatedDefaultTextStyle(
                  duration: duration,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 9.5,
                    letterSpacing: -0.1,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                    height: 1.1,
                    shadows:
                        selected && !heritage && !royal && customAccent == null
                            ? const [
                                Shadow(
                                  color: AppColors.black45,
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                              ]
                            : null,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  child: Text(item.title ?? ''),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabRouteObserver extends NavigatorObserver {
  _TabRouteObserver(this.onRouteChanged);

  final VoidCallback onRouteChanged;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      onRouteChanged();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      onRouteChanged();

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      onRouteChanged();

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      onRouteChanged();
}
