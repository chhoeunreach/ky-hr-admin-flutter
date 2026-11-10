import 'dart:io';
import 'package:cnattendance/features/pos/pages/pos_workspace_screen.dart';
import 'dart:ui';

import 'package:cnattendance/data/source/network/model/dashboard/User.dart';
import 'package:cnattendance/provider/dashboardprovider.dart';
import 'package:cnattendance/provider/prefprovider.dart';
import 'package:cnattendance/screen/dashboard/chatlistscreen.dart';
import 'package:cnattendance/screen/dashboard/homescreen.dart';
import 'package:cnattendance/screen/dashboard/leavescreen.dart';
import 'package:cnattendance/screen/dashboard/attendancescreen.dart';
import 'package:cnattendance/screen/dashboard/morescreen.dart';
import 'package:cnattendance/screen/links/link_list_screen.dart';
import 'package:cnattendance/screen/loanmanagement/loancalculatescreen.dart';
import 'package:cnattendance/screen/profile/front_side_preview_page.dart';
import 'package:cnattendance/screen/sell_out_report_screen.dart';
import 'package:cnattendance/screen/social_rewards/social_submission_screen.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:cnattendance/widget/radialDecoration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:persistent_bottom_nav_bar_v2/persistent_bottom_nav_bar_v2.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cnattendance/features/repair_price/pages/repair_device_page.dart';
import 'package:cnattendance/features/repair_price/providers/repair_price_provider.dart';

class DashboardScreen extends StatefulWidget {
  static const String routeName = '/dashboard';

  @override
  State<StatefulWidget> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  final PersistentTabController _controller =
      PersistentTabController(initialIndex: 0);
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedRailIndex = 0;

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
    final enterprise = EnterpriseTheme.of(context);
    final employeeId =
        int.tryParse(context.watch<PrefProvider>().userId.trim()) ?? 0;
    final dashboardProvider = context.watch<DashboardProvider>();
    final branchName = dashboardProvider.branch.trim();
    final paymentQrCodes = dashboardProvider.paymentQrCodes;
    final drawerWidth = (MediaQuery.sizeOf(context).width * 0.76).clamp(
      236.0,
      280.0,
    );
    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        width: drawerWidth,
        backgroundColor: enterprise.surface,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _paymentQrHeader(
                context,
                enterprise,
                branchName.isEmpty ? 'Branch' : branchName,
                paymentQrCodes,
              ),
              _drawerSectionLabel(enterprise, 'Services'),
              _drawerMenuItem(enterprise,
                  icon: Icons.dashboard_outlined,
                  label: translate('pos.dashboard'), onTap: () {
                Navigator.of(context).pop();
                Get.to(() => const PosWorkspaceScreen());
              }),
              _sellOutDrawerItem(
                context,
                enterprise,
                translate('home_screen.service_sell'),
                Icons.point_of_sale,
              ),
              _sellOutDrawerItem(
                context,
                enterprise,
                translate('home_screen.service_material'),
                Icons.inventory_2_outlined,
              ),
              _sellOutDrawerItem(
                context,
                enterprise,
                translate('home_screen.service_iron'),
                Icons.local_laundry_service,
              ),
              _sellOutDrawerItem(
                context,
                enterprise,
                translate('home_screen.service_repair'),
                Icons.build_circle_outlined,
              ),
              _sellOutDrawerItem(
                context,
                enterprise,
                translate('home_screen.service_buy_in'),
                Icons.add_shopping_cart,
              ),
              _sellOutDrawerItem(
                context,
                enterprise,
                translate('home_screen.service_icloud_cus'),
                Icons.cloud_outlined,
              ),
              _drawerDivider(enterprise),
              _drawerSectionLabel(enterprise, 'Tools'),
              _drawerMenuItem(
                enterprise,
                icon: Icons.calculate_outlined,
                label: 'Loan Calculate',
                onTap: () {
                  Navigator.of(context).pop();
                  Get.to(() => LoanCalculateScreen());
                },
              ),
              _drawerMenuItem(
                enterprise,
                icon: Icons.campaign_outlined,
                label: translate('dashboard_screen.social_rewards'),
                onTap: () {
                  Navigator.of(context).pop();
                  Get.to(
                    () => SocialSubmissionScreen(employeeId: employeeId),
                  );
                },
              ),
              _drawerMenuItem(
                enterprise,
                icon: Icons.badge_rounded,
                label: 'View My Card',
                onTap: () {
                  Navigator.of(context).pop();
                  Get.to(() => const FrontSidePreviewPage());
                },
              ),
              _drawerMenuItem(
                enterprise,
                icon: Icons.link,
                label: translate('more_screen.links'),
                onTap: () {
                  Navigator.of(context).pop();
                  Get.to(() => const LinkListScreen());
                },
              ),
            ],
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 720) {
            return _buildRailLayout(context, constraints.maxWidth);
          }
          return _buildMobileTabs(context);
        },
      ),
    );
  }

  Widget _buildRailLayout(BuildContext context, double width) {
    final colorScheme = Theme.of(context).colorScheme;
    final extended = width >= 1100;
    final repairProvider = Provider.of<RepairPriceProvider>(context);
    final bool showRepairTab = repairProvider.canView;

    final destinations = <NavigationRailDestination>[
      NavigationRailDestination(
        icon: const Icon(Icons.dashboard_outlined),
        selectedIcon: const Icon(Icons.dashboard),
        label: Text(translate('dashboard_screen.home')),
      ),
      if (showRepairTab)
        NavigationRailDestination(
          icon: const Icon(Icons.build_circle_outlined),
          selectedIcon: const Icon(Icons.build_circle),
          label: Text(translate('dashboard_screen.repair_list')),
        ),
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
      if (showRepairTab) const RepairDevicePage(),
      AttendanceScreen(),
      MoreScreen(),
    ];

    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(
              right: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.72),
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(8, 0),
              ),
            ],
          ),
          child: NavigationRail(
            selectedIndex: _selectedRailIndex,
            extended: extended,
            minWidth: 76,
            minExtendedWidth: 204,
            groupAlignment: -0.78,
            labelType: extended
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.selected,
            backgroundColor: Colors.transparent,
            indicatorColor: colorScheme.primaryContainer,
            indicatorShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            selectedIconTheme:
                IconThemeData(color: colorScheme.onPrimaryContainer, size: 22),
            selectedLabelTextStyle: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
            unselectedIconTheme: IconThemeData(
              color: colorScheme.onSurface.withValues(alpha: 0.62),
              size: 21,
            ),
            unselectedLabelTextStyle: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.62),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
            leading: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 22),
              child: extended
                  ? Row(
                      children: [
                        IconButton.filledTonal(
                          tooltip: 'Menu',
                          icon: const Icon(Icons.menu),
                          onPressed: () {
                            _scaffoldKey.currentState?.openDrawer();
                          },
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'HRKY',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    )
                  : IconButton.filledTonal(
                      tooltip: 'Menu',
                      icon: const Icon(Icons.menu),
                      onPressed: () {
                        _scaffoldKey.currentState?.openDrawer();
                      },
                    ),
            ),
            destinations: destinations,
            onDestinationSelected: (index) {
              setState(() {
                _selectedRailIndex = index;
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

  Widget _buildMobileTabs(BuildContext context) {
    final enterprise = EnterpriseTheme.of(context);
    final repairProvider = Provider.of<RepairPriceProvider>(context);
    final bool showRepairTab = repairProvider.canView;

    final tabs = [
      PersistentTabConfig(
          screen: HomeScreen(_controller),
          item: getItemConfig(
            const Icon(Icons.home_filled),
            translate('dashboard_screen.home'),
          )),
      if (showRepairTab)
        PersistentTabConfig(
            screen: const RepairDevicePage(),
            item: getItemConfig(
              const Icon(Icons.build_circle_outlined),
              translate('dashboard_screen.repair_list'),
            )),
      PersistentTabConfig(
          screen: ChatListScreen(),
          item: getItemConfig(
            const Icon(Icons.chat_bubble),
            translate('dashboard_screen.chat'),
          )),
      PersistentTabConfig(
          screen: LeaveScreen(),
          item: getItemConfig(
            const Icon(Icons.sick),
            translate('dashboard_screen.leave'),
          )),
      PersistentTabConfig(
          screen: AttendanceScreen(),
          item: getItemConfig(
            const Icon(Icons.co_present_outlined),
            translate('dashboard_screen.attendance'),
          )),
      PersistentTabConfig(
          screen: MoreScreen(),
          item: getItemConfig(
            const Icon(Icons.more),
            translate('dashboard_screen.more'),
          )),
    ];

    if (_controller.index >= tabs.length) {
      _controller.jumpToTab(0);
    }

    return Stack(
      children: [
        PersistentTabView(
          key: ValueKey('persistent_tab_bar_${showRepairTab ? 6 : 5}'),
          controller: _controller,
          backgroundColor: themedChromeColor(),
          handleAndroidBackButtonPress: true,
          resizeToAvoidBottomInset: true,
          stateManagement: true,
          popAllScreensOnTapOfSelectedTab: true,
          popActionScreens: PopActionScreensType.all,
          tabs: tabs,
          navBarBuilder: (navBarConfig) {
            return _EnterpriseFloatingNavBar(navBarConfig: navBarConfig);
          },
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(left: 12, top: 6),
            child: Material(
              color: enterprise.surface.withValues(alpha: 0.68),
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: IconButton(
                tooltip: 'Menu',
                icon: Icon(Icons.menu, color: enterprise.text),
                onPressed: () {
                  _scaffoldKey.currentState?.openDrawer();
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sellOutDrawerItem(
    BuildContext context,
    EnterpriseTheme enterprise,
    String serviceType,
    IconData icon,
  ) {
    return _drawerMenuItem(
      enterprise,
      icon: icon,
      label: serviceType,
      onTap: () {
        Navigator.of(context).pop();
        Get.to(() => SellOutReportScreen(serviceType: serviceType));
      },
    );
  }

  Widget _drawerMenuItem(
    EnterpriseTheme enterprise, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: enterprise.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: enterprise.primary.withValues(alpha: 0.92),
                    size: 17,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: enterprise.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: enterprise.mutedText.withValues(alpha: 0.62),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _drawerSectionLabel(EnterpriseTheme enterprise, String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 5),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: enterprise.mutedText.withValues(alpha: 0.72),
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
    );
  }

  Widget _drawerDivider(EnterpriseTheme enterprise) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Divider(
        height: 1,
        color: enterprise.glassStroke,
      ),
    );
  }

  Widget _paymentQrHeader(
    BuildContext context,
    EnterpriseTheme enterprise,
    String branchName,
    List<PaymentQrCode> paymentQrCodes,
  ) {
    final firstQr =
        paymentQrCodes.isNotEmpty ? paymentQrCodes.first.qrCodeUrl : '';
    final firstQrUri = _absoluteUri(firstQr);
    return InkWell(
      onTap: () => _showPaymentQr(
        context,
        enterprise,
        branchName,
        paymentQrCodes,
      ),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(10, 10, 10, 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              enterprise.primary.withValues(alpha: 0.95),
              enterprise.accent.withValues(alpha: 0.86),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: enterprise.accent.withValues(alpha: 0.24),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            if (firstQrUri != null)
              Container(
                width: 48,
                height: 48,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Image.network(
                    firstQrUri.toString(),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.qr_code_2_rounded,
                      color: Colors.black87,
                      size: 34,
                    ),
                  ),
                ),
              )
            else
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.qr_code_2_rounded,
                  color: Colors.black87,
                  size: 38,
                ),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Payment QR',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    branchName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    paymentQrCodes.isEmpty
                        ? 'No QR uploaded'
                        : '${paymentQrCodes.length} code(s) View',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentQr(
    BuildContext context,
    EnterpriseTheme enterprise,
    String branchName,
    List<PaymentQrCode> paymentQrCodes,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360, maxHeight: 560),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Payment QR',
                    style: TextStyle(
                      color: enterprise.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    branchName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: enterprise.mutedText,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: paymentQrCodes.isEmpty
                        ? _emptyPaymentQrState(enterprise)
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: paymentQrCodes.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              return _paymentQrCard(
                                context,
                                enterprise,
                                paymentQrCodes[index],
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _emptyPaymentQrState(EnterpriseTheme enterprise) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      decoration: BoxDecoration(
        color: enterprise.glassFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: enterprise.glassStroke),
      ),
      child: Column(
        children: [
          Icon(
            Icons.qr_code_2_rounded,
            color: enterprise.mutedText,
            size: 72,
          ),
          const SizedBox(height: 10),
          Text(
            'No payment QR uploaded',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: enterprise.text,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentQrCard(
    BuildContext context,
    EnterpriseTheme enterprise,
    PaymentQrCode paymentQrCode,
  ) {
    final paymentLink = paymentQrCode.link.trim();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: enterprise.glassFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: enterprise.glassStroke),
      ),
      child: Column(
        children: [
          Text(
            paymentQrCode.paymentName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: enterprise.text,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 230,
              height: 230,
              color: Colors.white,
              padding: const EdgeInsets.all(8),
              child: _paymentQrImage(paymentQrCode.qrCodeUrl, size: 72),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.open_in_full_rounded, size: 18),
                  label: const Text('View full'),
                  onPressed: () {
                    _showFullPaymentQr(context, enterprise, paymentQrCode);
                  },
                ),
              ),
              if (paymentLink.isNotEmpty) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.link_rounded, size: 18),
                  label: const Text('Link'),
                  onPressed: () => _openPaymentLink(context, paymentLink),
                ),
              ],
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Download'),
                  onPressed: () {
                    _downloadPaymentQr(context, paymentQrCode);
                  },
                ),
              ),
            ],
          ),
          if (paymentLink.isNotEmpty) ...[
            const SizedBox(height: 8),
            Material(
              color: enterprise.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _openPaymentLink(context, paymentLink),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.link_rounded,
                        size: 16,
                        color: enterprise.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          paymentLink,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: enterprise.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.open_in_new_rounded,
                        size: 16,
                        color: enterprise.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showFullPaymentQr(
    BuildContext context,
    EnterpriseTheme enterprise,
    PaymentQrCode paymentQrCode,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Close',
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(dialogContext).pop(),
                      ),
                      Expanded(
                        child: Text(
                          paymentQrCode.paymentName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Download',
                        icon: const Icon(
                          Icons.download_rounded,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          _downloadPaymentQr(context, paymentQrCode);
                        },
                      ),
                      if (paymentQrCode.link.trim().isNotEmpty)
                        IconButton(
                          tooltip: 'Open link',
                          icon: const Icon(
                            Icons.open_in_new_rounded,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            _openPaymentLink(context, paymentQrCode.link);
                          },
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 5,
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(14),
                        child:
                            _paymentQrImage(paymentQrCode.qrCodeUrl, size: 92),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _downloadPaymentQr(
    BuildContext context,
    PaymentQrCode paymentQrCode,
  ) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preparing QR download...')),
      );
      final uri = _absoluteUri(paymentQrCode.qrCodeUrl);
      if (uri == null) {
        throw Exception('Invalid QR image URL');
      }
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw Exception('Failed to download QR image');
      }
      final dir = await getTemporaryDirectory();
      final ext = _imageExtension(paymentQrCode.qrCodeUrl);
      final name = _safeFileName(paymentQrCode.paymentName);
      final filePath =
          '${dir.path}/payment_qr_${name}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);
      await Share.shareXFiles(
        [XFile(filePath)],
        text: paymentQrCode.paymentName,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $error')),
      );
    }
  }

  Future<void> _openPaymentLink(BuildContext context, String link) async {
    final uri = _paymentLinkUri(link);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid payment link')),
      );
      return;
    }

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open payment link')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open payment link: $error')),
      );
    }
  }

  Uri? _paymentLinkUri(String link) {
    final trimmed = link.trim();
    if (trimmed.isEmpty) return null;

    final withScheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(trimmed)
        ? trimmed
        : 'https://$trimmed';
    return _absoluteUri(withScheme);
  }

  Uri? _absoluteUri(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return null;
    }
    return uri;
  }

  Widget _paymentQrImage(String url, {required double size}) {
    final uri = _absoluteUri(url);
    if (uri == null) {
      return Icon(
        Icons.broken_image_outlined,
        color: Colors.black54,
        size: size,
      );
    }

    return Image.network(
      uri.toString(),
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(
        Icons.broken_image_outlined,
        color: Colors.black54,
        size: size,
      ),
    );
  }

  String _imageExtension(String url) {
    final cleanUrl = url.split('?').first.toLowerCase();
    final ext = cleanUrl.contains('.') ? cleanUrl.split('.').last : 'png';
    return ['jpg', 'jpeg', 'png', 'webp'].contains(ext) ? ext : 'png';
  }

  String _safeFileName(String value) {
    final cleaned = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return cleaned.isEmpty ? 'branch' : cleaned;
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
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white
                        .withValues(alpha: enterprise.isDark ? 0.13 : 0.72),
                    enterprise.surface
                        .withValues(alpha: enterprise.isDark ? 0.72 : 0.58),
                  ],
                ),
                borderRadius: BorderRadius.circular(26),
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
      size: 20,
      shadows: selected
          ? const [
              Shadow(
                color: Colors.black38,
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ]
          : null,
    );

    final Gradient? tabGradient = selected
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              enterprise.secondary,
              enterprise.primary,
              enterprise.accent,
            ],
            stops: const [0.0, 0.45, 1.0],
          )
        : null;

    final List<BoxShadow>? tabShadow = selected
        ? [
            BoxShadow(
              color: enterprise.accent.withValues(alpha: 0.55),
              blurRadius: 18,
              spreadRadius: 1.5,
              offset: const Offset(0, 3),
            ),
            BoxShadow(
              color: enterprise.primary.withValues(alpha: 0.45),
              blurRadius: 12,
              offset: const Offset(0, 1),
            ),
          ]
        : null;

    final BoxBorder? tabBorder = selected
        ? Border.all(
            color: enterprise.accent.withValues(alpha: 0.85),
            width: 1.2,
          )
        : null;

    final Color textColor =
        selected ? Colors.white : enterprise.text.withValues(alpha: 0.58);

    return Semantics(
      selected: selected,
      button: true,
      label: item.title,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
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
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 260),
                style: TextStyle(
                  color: textColor,
                  fontSize: 9.5,
                  letterSpacing: -0.1,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                  height: 1.1,
                  shadows: selected
                      ? const [
                          Shadow(
                            color: Colors.black45,
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ]
                      : null,
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
