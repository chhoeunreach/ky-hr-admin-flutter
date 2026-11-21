import 'package:cnattendance/features/community/social_feed_screen.dart';
import 'dart:ui';
import 'dart:async';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/provider/dashboardprovider.dart';
import 'package:cnattendance/provider/prefprovider.dart';
import 'package:cnattendance/screen/dashboard/homescreen.dart';
import 'package:cnattendance/screen/dashboard/leavescreen.dart';
import 'package:cnattendance/screen/dashboard/attendancescreen.dart';
import 'package:cnattendance/screen/dashboard/morescreen.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:cnattendance/theme/theme_layout.dart';
import 'package:cnattendance/widget/dashboard_drawer.dart';
import 'package:cnattendance/widget/dashboard_drawer_scope.dart';
import 'package:cnattendance/widget/radialDecoration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:cnattendance/theme/royal_colors.dart';
import 'package:persistent_bottom_nav_bar_v2/persistent_bottom_nav_bar_v2.dart';
import 'package:provider/provider.dart';
import 'package:cnattendance/features/repair_price/pages/repair_device_page.dart';
import 'package:cnattendance/features/repair_price/providers/repair_price_provider.dart';
import 'package:cnattendance/features/daily_records/quick_create.dart';

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
    });
    _restoreRailState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (mounted && state == AppLifecycleState.resumed) {
      unawaited(context.read<DashboardProvider>().refreshMobileFeatures());
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
      activeColorSecondary: Colors.white,
      activeForegroundColor: Colors.white,
      inactiveBackgroundColor: Colors.white30,
      inactiveForegroundColor: Colors.white30,
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
    final canRepair = context.watch<RepairPriceProvider>().canView;
    final hasSocialFeed = features['social-feed'] == '1';

    final railItems = [
      LayoutItem.home,
      if (hasSocialFeed) LayoutItem.social,
      if (canRepair) LayoutItem.repair,
      if (LayoutItem.attendance.allowed(features)) LayoutItem.attendance,
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
      if (canRepair)
        NavigationRailDestination(
          icon: const Icon(Icons.build_circle_outlined),
          selectedIcon: const Icon(Icons.build_circle),
          label: Text(translate('dashboard_screen.repair_list')),
        ),
      if (features["attendance"] == "1")
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
      if (canRepair)
        _selectedRailIndex == repairIndex
            ? const RepairDevicePage(showBackButton: false)
            : const SizedBox.shrink(),
      if (features["attendance"] == "1") AttendanceScreen(),
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
                color: Colors.black.withValues(alpha: 0.12),
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
    final features = context.watch<DashboardProvider>().features;
    final canRepair = context.watch<RepairPriceProvider>().canView;

    final tabIds = <LayoutItem>[];
    final tabs = <PersistentTabConfig>[];

    void addTab(LayoutItem id, Widget screen, ItemConfig item) {
      tabIds.add(id);
      tabs.add(PersistentTabConfig(
        screen: screen,
        item: item,
        navigatorConfig: _mobileTabNavigatorConfig(id.name),
      ));
    }

    addTab(
      LayoutItem.home,
      HomeScreen(_controller),
      getItemConfig(
        const Icon(Icons.home_filled),
        translate('dashboard_screen.home'),
      ),
    );
    if (features["social-feed"] == "1")
      addTab(
        LayoutItem.social,
        SocialFeedScreen(
            showBackButton: false,
            onImmersiveChanged: _handleSocialFeedImmersive),
        getItemConfig(
          const Icon(Icons.dynamic_feed_outlined),
          translate('community.social_feed'),
        ),
      );
    if (canRepair)
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
    if (features["leave-request"] == "1")
      addTab(
        LayoutItem.leave,
        LeaveScreen(),
        getItemConfig(
          const Icon(Icons.sick),
          translate('dashboard_screen.leave'),
        ),
      );
    if (features["attendance"] == "1")
      addTab(
        LayoutItem.attendance,
        AttendanceScreen(),
        getItemConfig(
          const Icon(Icons.co_present_outlined),
          translate('dashboard_screen.attendance'),
        ),
      );
    addTab(
      LayoutItem.more,
      MoreScreen(),
      getItemConfig(
        const Icon(Icons.more),
        translate('dashboard_screen.more'),
      ),
    );

    if (_controller.index >= tabs.length) {
      _controller.jumpToTab(0);
    }

    final activeTabIndex = _controller.index.clamp(0, tabIds.length - 1);
    final activeNavigator =
        _tabNavigatorKeys[tabIds[activeTabIndex].name]?.currentState;
    final isSocialFeedActive = tabIds[activeTabIndex] == LayoutItem.social;
    final immersive = isSocialFeedActive && _socialFeedImmersive;
    final socialDetailOpen =
        isSocialFeedActive && (activeNavigator?.canPop() ?? false);
    final isRepairActive = tabIds[activeTabIndex] == LayoutItem.repair;
    final repairDetailOpen =
        isRepairActive && (activeNavigator?.canPop() ?? false);
    final hideMenuButton = immersive || (activeNavigator?.canPop() ?? false);

    final visibleTabs = enterprise.layout.visibleTabIndices(tabIds);
    final menuOnRight = enterprise.layout.menuOnRight;
    final moreSlot = visibleTabs.indexOf(tabIds.indexOf(LayoutItem.more));
    final showCreateRecord = moreSlot >= 0 &&
        !hideMenuButton &&
        MediaQuery.viewInsetsOf(context).bottom == 0;

    return Stack(
      children: [
        PersistentTabView(
          key: ValueKey(
              'tabs_${features["social-feed"]}_${features["leave-request"]}_${features["attendance"]}_$canRepair'),
          controller: _controller,
          onTabChanged: (index) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() {});
            });
            if (index != tabIds.indexOf(LayoutItem.repair)) return;
            final provider = context.read<RepairPriceProvider>();
            if (provider.deviceLoadingState != RepairLoadingState.initial) {
              provider.initDevicePage();
            }
          },
          backgroundColor: enterprise.layout.background ?? themedChromeColor(),
          handleAndroidBackButtonPress: true,
          resizeToAvoidBottomInset: true,
          stateManagement: true,
          hideNavigationBar: immersive ||
              socialDetailOpen ||
              repairDetailOpen ||
              (isRepairActive && !_repairNavigationVisible),
          floatingActionButton:
              showCreateRecord ? const CreateRecordButton() : null,
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
        if (!hideMenuButton && enterprise.layout.showMenuButton)
          Positioned(
            top: 0,
            left: menuOnRight ? null : 12,
            right: menuOnRight ? 12 : null,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Material(
                  color:
                      enterprise.colors.backgroundColor.withValues(alpha: 0.84),
                  shape:
                      enterprise.isKhmerHeritage || enterprise.isRoyalBlueGold
                          ? RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13),
                              side: BorderSide(color: enterprise.cardBorder),
                            )
                          : const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: IconButton(
                    tooltip:
                        MaterialLocalizations.of(context).openAppDrawerTooltip,
                    icon: Icon(Icons.menu, color: sidebarFg),
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

class DashboardNavigationBar extends StatelessWidget {
  final NavBarConfig navBarConfig;

  const DashboardNavigationBar(
      {super.key, required this.navBarConfig, required this.visibleTabs});

  final List<int> visibleTabs;

  @override
  Widget build(BuildContext context) {
    final enterprise = EnterpriseTheme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            enabled: !enterprise.isRoyalBlueGold,
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              height: 66,
              decoration: BoxDecoration(
                gradient: enterprise.isRoyalBlueGold
                    ? const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [RoyalColors.deepBlue, RoyalColors.navy],
                      )
                    : enterprise.pageGradient,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: enterprise.accent.withValues(
                    alpha:
                        enterprise.isKhmerHeritage || enterprise.isRoyalBlueGold
                            ? .68
                            : .34,
                  ),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: enterprise.primary.withValues(alpha: 0.18),
                    blurRadius: 24,
                    spreadRadius: 0.5,
                    offset: const Offset(0, 0),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
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
            ),
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
    final inactiveColor =
        sidebarForeground(enterprise).withValues(alpha: royal ? .97 : .72);
    final customAccent = enterprise.layout.accent;
    final activeColor = customAccent == null
        ? (royal
            ? RoyalColors.navy
            : heritage
                ? enterprise.colors.backgroundColor
                : Colors.white)
        : ThemeData.estimateBrightnessForColor(customAccent) == Brightness.dark
            ? Colors.white
            : const Color(0xff211720);
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
                        activeColor == Colors.white
                            ? Colors.black
                            : Colors.white,
                        .16)!,
                  ]
                : royal
                    ? RoyalColors.goldGradient.colors
                    : heritage
                        ? [enterprise.text, enterprise.accent]
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
        ? Border.all(color: enterprise.accent.withValues(alpha: 0.44))
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
                                  color: Colors.black45,
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
