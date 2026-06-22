import 'dart:ui';

import 'package:cnattendance/provider/prefprovider.dart';
import 'package:cnattendance/screen/dashboard/chatlistscreen.dart';
import 'package:cnattendance/screen/dashboard/homescreen.dart';
import 'package:cnattendance/screen/dashboard/leavescreen.dart';
import 'package:cnattendance/screen/dashboard/attendancescreen.dart';
import 'package:cnattendance/screen/dashboard/morescreen.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:cnattendance/widget/radialDecoration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:persistent_bottom_nav_bar_v2/persistent_bottom_nav_bar_v2.dart';
import 'package:provider/provider.dart';

class DashboardScreen extends StatefulWidget {
  static const String routeName = '/dashboard';

  @override
  State<StatefulWidget> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  final PersistentTabController _controller =
      PersistentTabController(initialIndex: 0);

  bool _loadedUser = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _loadedUser) {
        return;
      }
      _loadedUser = true;
      context.read<PrefProvider>().getUser();
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
    return Scaffold(
      body: PersistentTabView(
        controller: _controller,
        backgroundColor: themedChromeColor(),
        handleAndroidBackButtonPress: true,
        // Default is true.
        resizeToAvoidBottomInset: true,
        // This needs to be true if you want to move up the screen when keyboard appears. Default is true.
        stateManagement: true,
        popAllScreensOnTapOfSelectedTab: true,
        popActionScreens: PopActionScreensType.all,
        tabs: [
          PersistentTabConfig(
              screen: HomeScreen(_controller),
              item: getItemConfig(
                Icon(Icons.home_filled),
                translate('dashboard_screen.home'),
              )),
          PersistentTabConfig(
              screen: ChatListScreen(),
              item: getItemConfig(
                Icon(Icons.chat_bubble),
                translate('dashboard_screen.chat'),
              )),
          PersistentTabConfig(
              screen: LeaveScreen(),
              item: getItemConfig(
                Icon(Icons.sick),
                translate('dashboard_screen.leave'),
              )),
          PersistentTabConfig(
              screen: AttendanceScreen(),
              item: getItemConfig(
                Icon(Icons.co_present_outlined),
                translate('dashboard_screen.attendance'),
              )),
          PersistentTabConfig(
              screen: MoreScreen(),
              item: getItemConfig(
                Icon(Icons.more),
                translate('dashboard_screen.more'),
              )),
        ],
        navBarBuilder: (navBarConfig) {
          return _EnterpriseFloatingNavBar(navBarConfig: navBarConfig);
        },
      ),
    );
  }
}

class _EnterpriseFloatingNavBar extends StatelessWidget {
  final NavBarConfig navBarConfig;

  const _EnterpriseFloatingNavBar({required this.navBarConfig});

  @override
  Widget build(BuildContext context) {
    final enterprise = EnterpriseTheme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              height: 68,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white
                        .withValues(alpha: enterprise.isDark ? 0.13 : 0.72),
                    enterprise.surface
                        .withValues(alpha: enterprise.isDark ? 0.72 : 0.58),
                  ],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: enterprise.glassStroke),
                boxShadow: [
                  BoxShadow(
                    color: enterprise.accent.withValues(alpha: 0.20),
                    blurRadius: 26,
                    spreadRadius: 1,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Row(
                children: [
                  for (var i = 0; i < navBarConfig.items.length; i++)
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
    final iconTheme = IconThemeData(
      color: selected ? Colors.white : enterprise.text.withValues(alpha: 0.62),
      size: 22,
    );
    return Semantics(
      selected: selected,
      button: true,
      label: item.title,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: selected
                ? LinearGradient(
                    colors: [enterprise.primary, enterprise.accent],
                  )
                : null,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: enterprise.accent.withValues(alpha: 0.34),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconTheme(
                data: iconTheme,
                child: selected ? item.icon : item.inactiveIcon,
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 260),
                style: TextStyle(
                  color: selected
                      ? Colors.white
                      : enterprise.text.withValues(alpha: 0.58),
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                  height: 1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                child: Text(item.title ?? ''),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
