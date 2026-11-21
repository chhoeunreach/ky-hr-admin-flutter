import 'package:cached_network_image/cached_network_image.dart';
import 'package:cnattendance/provider/chatbadgecontroller.dart';
import 'package:cnattendance/provider/notificationcontroller.dart';
import 'package:cnattendance/provider/prefprovider.dart';
import 'package:cnattendance/screen/dashboard/chatlistscreen.dart';
import 'package:cnattendance/screen/profile/NotificationScreen.dart';
import 'package:cnattendance/screen/profile/profilescreen.dart';
import 'package:cnattendance/services/server_status_service.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:cnattendance/theme/royal_colors.dart';
import 'package:cnattendance/widget/homescreen/royal_dashboard_widgets.dart';
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
    this.showMenuButton = true,
    this.royalOnline = false,
  });

  final bool showMenuButton;
  final bool royalOnline;

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
            status: translate('server_status.checking_server'),
            maskType: EasyLoadingMaskType.black);
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
    final theme = EnterpriseTheme.of(context);
    final royal = theme.isRoyalBlueGold;
    final initials = provider.fullname
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => word.characters.first)
        .join();
    final royalAvatar = SizedBox.square(
      dimension: 36,
      child: ColoredBox(
        color: RoyalColors.deepBlue,
        child: Center(
          child: initials.isEmpty
              ? const Icon(Icons.person, color: RoyalColors.lightGold)
              : Text(initials.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      ),
    );
    final labelSurface =
        theme.layout.background ?? theme.colors.backgroundColor;
    final labelColor = ThemeData.estimateBrightnessForColor(labelSurface) ==
            Brightness.dark
        ? Colors.white
        : const Color(0xFF211720);
    final features = context.watch<DashboardProvider>().features;
    final isEnabledLocation =
        context.watch<DashboardProvider>().isLocationEnabled;
    // On mobile the sidebar menu is a button pinned at the screen's top-left
    // corner (see DashboardScreen), so the header keeps only the avatar row.
    final isMobileLayout = MediaQuery.sizeOf(context).width < 720;
    final showInlineMenu = widget.showMenuButton && !isMobileLayout;
    final pinnedMenuClearance =
        isMobileLayout && theme.layout.showMenuButton;

    final profile = <Widget>[
      // 1. Menu Squircle Button (desktop rail only; mobile uses the pinned one)
      if (showInlineMenu) ...[
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(21),
            onTap: _openDashboardDrawer,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0C2247).withValues(alpha: 0.78),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.menu_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
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
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: royal
                      ? [RoyalColors.lightGold, theme.accent]
                      : theme.isKhmerHeritage
                          ? [theme.text, theme.accent]
                          : const [Color(0xFF0066FF), Color(0xFF5EB1FF)],
                ),
              ),
              child: ClipOval(
                child: royal && provider.avatar.trim().isEmpty
                    ? royalAvatar
                    : CachedNetworkImage(
                        imageUrl: provider.avatar,
                        memCacheWidth: royal ? 176 : null,
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                        placeholder: (context, url) {
                          if (royal) return royalAvatar;
                          return Image.asset(
                            'assets/images/dummy_avatar.png',
                            width: 36,
                            height: 36,
                            fit: BoxFit.cover,
                          );
                        },
                        errorWidget: (context, url, error) {
                          if (royal) return royalAvatar;
                          return Image.asset(
                            'assets/images/dummy_avatar.png',
                            width: 36,
                            height: 36,
                            fit: BoxFit.cover,
                          );
                        },
                      ),
              ),
            ),
            if (!royal || widget.royalOnline)
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
      const SizedBox(width: 8),

      // 3. User Info Column: Hello There 👋, Name, Staff Code Pill
      Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    translate(royal
                        ? 'royal.${royalGreeting(royalLocalTime(DateTime.now()))}'
                        : 'home_screen.hello_there'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: labelColor.withValues(alpha: 0.90),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 3),
                const Text('👋', style: TextStyle(fontSize: 11)),
              ],
            ),
            Text(
              provider.fullname.isNotEmpty
                  ? provider.fullname
                  : royal
                      ? translate('royal.employee')
                      : "សៅរឿន រាជ",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: labelColor,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            if (!royal ||
                provider.userName.isNotEmpty ||
                provider.userId.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: royal ||
                          theme.isKhmerHeritage ||
                          theme.layout.background != null
                      ? theme.accent.withValues(alpha: .18)
                      : Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  royal
                      ? (provider.userName.isNotEmpty
                          ? provider.userName
                          : provider.userId)
                      : "${provider.userName.isNotEmpty ? provider.userName : 'KY0021'} · Staff",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: labelColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    ];
    final actions = <Widget>[
      if (features['chat'] == '1')
        Tooltip(
          message: translate('dashboard_screen.chat'),
          child: Obx(() {
            final chatUnread =
                ChatBadgeController.ensureRegistered().unreadCount.value;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                _HeaderIconButton(
                  icon: Icons.chat_bubble_rounded,
                  color: Colors.white,
                  onPressed: () => pushScreen(
                    context,
                    screen: const ChatListScreen(),
                    withNavBar: false,
                    pageTransitionAnimation: PageTransitionAnimation.fade,
                  ),
                ),
                if (chatUnread > 0)
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
                            color:
                                const Color(0xFFEF4444).withValues(alpha: 0.45),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Text(
                        chatUnread > 99 ? '99+' : chatUnread.toString(),
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
            );
          }),
        ),
      if (isEnabledLocation)
        Tooltip(
          message: royal ? translate('royal.send_location') : 'Send Location',
          child: _HeaderIconButton(
            icon: Icons.location_on_rounded,
            color: Colors.white,
            onPressed: sendLocation,
          ),
        ),
      Tooltip(
        message: translate('server_status.title'),
        child: _HeaderIconButton(
          icon: Icons.grid_view_rounded,
          color: Colors.white,
          onPressed: testServerConnection,
        ),
      ),
      if (features["notifications"] == "1")
        Tooltip(
          message: royal ? translate('royal.notifications') : 'Notifications',
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
                        pageTransitionAnimation: PageTransitionAnimation.fade);
                  },
                ),
                if (notificationController.badgeCount > 0)
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
                            color:
                                const Color(0xFFEF4444).withValues(alpha: 0.45),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Text(
                        notificationController.badgeCount > 99
                            ? '99+'
                            : notificationController.badgeCount.toString(),
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
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(
        (royal ? 0 : 10) + (pinnedMenuClearance ? 48 : 0),
        6,
        royal ? 0 : 10,
        2,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final minimumProfileWidth = showInlineMenu ? 164.0 : 116.0;
          if (constraints.maxWidth >=
              minimumProfileWidth +
                  actions.length * (royal ? 42 : _HeaderIconButton.slotWidth)) {
            return Row(children: [...profile, ...actions]);
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(children: profile),
              const SizedBox(height: 4),
              Wrap(
                  alignment: WrapAlignment.end,
                  runSpacing: 4,
                  children: actions),
            ],
          );
        },
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  static const _size = 34.0;
  static const _spacing = 4.0;
  static const slotWidth = _size + _spacing;

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
    final theme = EnterpriseTheme.of(context);
    return Container(
      width: theme.isRoyalBlueGold ? 42 : _size,
      height: theme.isRoyalBlueGold ? 42 : _size,
      margin: EdgeInsets.only(left: theme.isRoyalBlueGold ? 0 : _spacing),
      decoration: BoxDecoration(
        shape: theme.isKhmerHeritage ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: theme.isKhmerHeritage ? BorderRadius.circular(12) : null,
        gradient: theme.isKhmerHeritage ? theme.cardGradient : null,
        color: theme.isKhmerHeritage
            ? null
            : const Color(0xFF0C2247).withValues(alpha: 0.72),
        border: Border.all(
          color: theme.isKhmerHeritage
              ? theme.cardBorder
              : Colors.white.withValues(alpha: 0.20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon,
            color: theme.isRoyalBlueGold
                ? RoyalColors.lightGold
                : theme.isKhmerHeritage
                    ? theme.text
                    : color,
            size: 18),
        onPressed: onPressed,
      ),
    );
  }
}
