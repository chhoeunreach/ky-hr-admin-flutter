import 'package:cnattendance/provider/prefprovider.dart';
import 'package:cnattendance/screen/dashboard/chatlistscreen.dart';
import 'package:cnattendance/screen/dashboard/homescreen.dart';
import 'package:cnattendance/screen/dashboard/leavescreen.dart';
import 'package:cnattendance/screen/dashboard/attendancescreen.dart';
import 'package:cnattendance/screen/dashboard/morescreen.dart';
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
        navBarBuilder: (NavBarConfig) {
          return Style9BottomNavBar(
            navBarConfig: NavBarConfig,
            navBarDecoration: NavBarDecoration(color: themedChromeColor()),
          );
        },
      ),
    );
  }
}
