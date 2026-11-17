import 'package:cached_network_image/cached_network_image.dart';
import 'package:cnattendance/provider/notificationcontroller.dart';
import 'package:cnattendance/provider/prefprovider.dart';
import 'package:cnattendance/screen/profile/NotificationScreen.dart';
import 'package:cnattendance/screen/profile/profilescreen.dart';
import 'package:cnattendance/services/server_status_service.dart';
import 'package:cnattendance/widget/dashboard_drawer_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';
import 'package:persistent_bottom_nav_bar_v2/persistent_bottom_nav_bar_v2.dart';
import 'package:provider/provider.dart';

import '../provider/dashboardprovider.dart';
import 'customalertdialog.dart';

class HeaderProfile extends StatefulWidget {
  const HeaderProfile({
    super.key,
    this.showServerTest = false,
    this.showMenuButton = true,
  });

  final bool showServerTest;
  final bool showMenuButton;

  @override
  State<StatefulWidget> createState() => HeaderState();
}

class HeaderState extends State<HeaderProfile> {
  late final NotificationController notificationController;
  bool _notificationsRequested = false;

  @override
  void initState() {
    super.initState();
    notificationController = Get.isRegistered<NotificationController>()
        ? Get.find<NotificationController>()
        : Get.put(NotificationController(), permanent: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final allowed =
        context.watch<DashboardProvider>().features['notifications'] == '1';
    if (allowed && !_notificationsRequested) {
      _notificationsRequested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) notificationController.ensureLoaded();
      });
    }
  }

  Future<void> sendLocation() async {
    try {
      setState(() {
        EasyLoading.show(
            status: translate('loader.requesting'),
            maskType: EasyLoadingMaskType.black);
      });
      final response = await context.read<DashboardProvider>().onSendLocation();
      setState(() {
        EasyLoading.dismiss(animation: true);
        showDialog(
          context: context,
          builder: (context) {
            return Dialog(
              child: CustomAlertDialog(response),
            );
          },
        );
      });
    } catch (e) {
      setState(() {
        EasyLoading.dismiss(animation: true);
        showDialog(
          context: context,
          builder: (context) {
            return Dialog(
              child: CustomAlertDialog(e.toString()),
            );
          },
        );
      });
    }
  }

  void _openDashboardDrawer() {
    final scope = DashboardDrawerScope.maybeOf(context);
    if (scope != null) {
      scope.openDrawer();
      return;
    }
    Scaffold.maybeOf(context)?.openDrawer();
  }

  Future<void> testServerConnection() async {
    try {
      setState(() {
        EasyLoading.show(
            status: 'Checking server', maskType: EasyLoadingMaskType.black);
      });

      final result = await ServerStatusService().checkCurrentServer();
      if (!mounted) {
        return;
      }

      setState(() {
        EasyLoading.dismiss(animation: true);
      });

      showDialog(
        context: context,
        builder: (context) {
          return Dialog(
            child: CustomAlertDialog(
              '${result.isConnected ? 'Connected' : 'Not connected'}\n\n'
              '${result.message}\n\n'
              'Server: ${result.url}',
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        EasyLoading.dismiss(animation: true);
      });
      showDialog(
        context: context,
        builder: (context) {
          return Dialog(
            child: CustomAlertDialog(e.toString()),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PrefProvider>(context);
    final features = context.watch<DashboardProvider>().features;
    final isEnabledLocation =
        context.watch<DashboardProvider>().isLocationEnabled;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: Row(
        children: [
          // 1. Menu Squircle Button
          if (widget.showMenuButton) ...[
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(13),
                onTap: _openDashboardDrawer,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.menu_rounded,
                    color: Color(0xFF0F172A),
                    size: 22,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],

          // 2. Avatar with Green Online Dot
          InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: features["profile"] != "1"
                ? null
                : () {
                    pushScreen(context,
                        screen: ProfileScreen(),
                        withNavBar: false,
                        pageTransitionAnimation: PageTransitionAnimation.fade);
                  },
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF38BDF8),
                        Color(0xFF2563EB),
                      ],
                    ),
                  ),
                  child: ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: provider.avatar,
                      width: 42,
                      height: 42,
                      fit: BoxFit.cover,
                      placeholder: (context, url) {
                        return Image.asset(
                          'assets/images/dummy_avatar.png',
                          width: 42,
                          height: 42,
                          fit: BoxFit.cover,
                        );
                      },
                      errorWidget: (context, url, error) {
                        return Image.asset(
                          'assets/images/dummy_avatar.png',
                          width: 42,
                          height: 42,
                          fit: BoxFit.cover,
                        );
                      },
                    ),
                  ),
                ),
                Positioned(
                  bottom: 1,
                  right: 1,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // 3. User Info Column: Hello There 👋, Name, Staff Code Pill
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      translate('home_screen.hello_there'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.90),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Text('👋', style: TextStyle(fontSize: 11)),
                  ],
                ),
                Text(
                  provider.fullname.isNotEmpty
                      ? provider.fullname
                      : "សៅរឿន រាជ",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "${provider.userName.isNotEmpty ? provider.userName : 'KY0021'} · Staff",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 4. Right Action Buttons: Location, Grid, Notifications
          if (isEnabledLocation)
            Tooltip(
              message: "Send Location",
              child: _HeaderIconButton(
                icon: Icons.location_on_rounded,
                color: Colors.white,
                onPressed: sendLocation,
              ),
            ),
          Tooltip(
            message: "Shortcuts",
            child: _HeaderIconButton(
              icon: Icons.grid_view_rounded,
              color: Colors.white,
              onPressed: () {
                if (widget.showServerTest) {
                  testServerConnection();
                } else {
                  _openDashboardDrawer();
                }
              },
            ),
          ),
          if (features["notifications"] == "1")
            Tooltip(
              message: "Notifications",
              child: Obx(
                () => Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _HeaderIconButton(
                      icon: Icons.notifications_rounded,
                      color: Colors.white,
                      onPressed: () {
                        pushScreen(context,
                            screen: NotificationScreen(),
                            withNavBar: false,
                            pageTransitionAnimation:
                                PageTransitionAnimation.fade);
                      },
                    ),
                    Positioned(
                      right: 1,
                      top: 1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4.5, vertical: 1.5),
                        constraints: const BoxConstraints(
                          minWidth: 17,
                          minHeight: 17,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white, width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFEF4444)
                                  .withValues(alpha: 0.45),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Text(
                          notificationController.badgeCount > 0
                              ? (notificationController.badgeCount > 99
                                  ? '99+'
                                  : notificationController.badgeCount
                                      .toString())
                              : '49',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _HeaderIconButton({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      margin: const EdgeInsets.only(left: 6),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: color, size: 20),
        onPressed: onPressed,
      ),
    );
  }
}
