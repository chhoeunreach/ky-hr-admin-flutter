import 'package:cached_network_image/cached_network_image.dart';
import 'package:cnattendance/provider/notificationcontroller.dart';
import 'package:cnattendance/provider/prefprovider.dart';
import 'package:cnattendance/screen/profile/NotificationScreen.dart';
import 'package:cnattendance/screen/profile/profilescreen.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';
import 'package:persistent_bottom_nav_bar_v2/persistent_bottom_nav_bar_v2.dart';
import 'package:provider/provider.dart';

import '../provider/dashboardprovider.dart';
import 'customalertdialog.dart';

class HeaderProfile extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => HeaderState();
}

class HeaderState extends State<HeaderProfile> {
  late final NotificationController notificationController;

  @override
  void initState() {
    super.initState();
    notificationController = Get.isRegistered<NotificationController>()
        ? Get.find<NotificationController>()
        : Get.put(NotificationController(), permanent: true);
    notificationController.ensureLoaded();
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

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PrefProvider>(context);
    final enterprise = EnterpriseTheme.of(context);
    final isEnabledLocation =
        context.watch<DashboardProvider>().isLocationEnabled;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      child: EnterpriseGlass(
        padding: const EdgeInsets.fromLTRB(54, 12, 14, 12),
        radius: 26,
        child: Row(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: () {
                pushScreen(context,
                    screen: ProfileScreen(),
                    withNavBar: false,
                    pageTransitionAnimation: PageTransitionAnimation.fade);
              },
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [
                      enterprise.accent,
                      enterprise.primary,
                      enterprise.secondary,
                      enterprise.accent,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: enterprise.glow,
                      blurRadius: 20,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: provider.avatar,
                    width: 46,
                    height: 46,
                    fit: BoxFit.cover,
                    placeholder: (context, url) {
                      return Image.asset(
                        'assets/images/dummy_avatar.png',
                        width: 46,
                        height: 46,
                        fit: BoxFit.cover,
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    translate('home_screen.hello_there'),
                    style: TextStyle(
                      color: enterprise.mutedText,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    provider.fullname,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: enterprise.text,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    provider.userName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: enterprise.mutedText,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (isEnabledLocation)
              Tooltip(
                message: "Send Location",
                child: _HeaderIconButton(
                  icon: Icons.location_on_rounded,
                  color: enterprise.accent,
                  onPressed: sendLocation,
                ),
              ),
            Tooltip(
              message: "Notifications",
              child: Obx(
                () => TweenAnimationBuilder<double>(
                  tween: Tween(
                    begin: 0,
                    end: notificationController.badgeCount > 0 ? 1 : 0,
                  ),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: 1 + (value * 0.08),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _HeaderIconButton(
                            icon: notificationController.badgeCount > 0
                                ? Icons.notifications_active_rounded
                                : Icons.notifications_rounded,
                            color: enterprise.text,
                            onPressed: () {
                              pushScreen(context,
                                  screen: NotificationScreen(),
                                  withNavBar: false,
                                  pageTransitionAnimation:
                                      PageTransitionAnimation.fade);
                            },
                          ),
                          if (notificationController.badgeCount > 0)
                            Positioned(
                              right: 2,
                              top: 2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 2),
                                constraints: const BoxConstraints(
                                  minWidth: 18,
                                  minHeight: 18,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.redAccent
                                          .withValues(alpha: 0.45),
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  notificationController.badgeCount > 99
                                      ? '99+'
                                      : notificationController.badgeCount
                                          .toString(),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
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
    final enterprise = EnterpriseTheme.of(context);
    return Container(
      width: 42,
      height: 42,
      margin: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: enterprise.isDark ? 0.10 : 0.58),
        border: Border.all(color: enterprise.glassStroke),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: color, size: 21),
        onPressed: onPressed,
      ),
    );
  }
}
