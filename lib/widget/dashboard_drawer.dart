import 'dart:io';

import 'package:cnattendance/data/source/network/model/dashboard/User.dart';
import 'package:cnattendance/features/community/social_feed_screen.dart';
import 'package:cnattendance/features/company_documents/company_documents_screen.dart';
import 'package:cnattendance/features/pos/pages/pos_workspace_screen.dart';
import 'package:cnattendance/features/repair_price/pages/repair_device_page.dart';
import 'package:cnattendance/provider/dashboardprovider.dart';
import 'package:cnattendance/provider/prefprovider.dart';
import 'package:cnattendance/screen/assetscreen/admin_asset_list_screen.dart';
import 'package:cnattendance/screen/links/link_list_screen.dart';
import 'package:cnattendance/screen/loanmanagement/loancalculatescreen.dart';
import 'package:cnattendance/screen/profile/front_side_preview_page.dart';
import 'package:cnattendance/screen/profile/teamsheetscreen.dart';
import 'package:cnattendance/screen/sell_out_report_screen.dart';
import 'package:cnattendance/screen/social_rewards/social_submission_screen.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';
import 'package:cnattendance/core/ky_security/ky_http.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cnattendance/core/theme/app_colors.dart';
import 'package:cnattendance/utils/asset_permissions.dart';

Color sidebarForeground(EnterpriseTheme enterprise) {
  final colors = enterprise.colors.gradientColors;
  final luminance = colors.fold<double>(
        0,
        (total, color) => total + color.computeLuminance(),
      ) /
      colors.length;
  return luminance > 0.46 ? AppColors.customFF172033 : AppColors.white;
}

Color sidebarTone(Color color) => Color.lerp(color, AppColors.black, 0.42)!;

class DashboardDrawer extends StatelessWidget {
  const DashboardDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final enterprise = EnterpriseTheme.of(context);
    final employeeId =
        int.tryParse(context.watch<PrefProvider>().userId.trim()) ?? 0;
    final dashboardProvider = context.watch<DashboardProvider>();
    final branchName = dashboardProvider.branch.trim();
    final paymentQrCodes = dashboardProvider.paymentQrCodes;
    final screen = MediaQuery.sizeOf(context);
    final safeTop = MediaQuery.paddingOf(context).top;
    final isMobile = screen.width < 720;
    final drawerWidth = (screen.width * 0.80).clamp(264.0, 320.0).toDouble();
    return Drawer(
      width: drawerWidth,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      child: Padding(
        // Keep the mobile top navigation visible above the drawer surface.
        padding: EdgeInsets.only(top: isMobile ? safeTop + 56 : 0),
        child: Container(
          decoration: BoxDecoration(
            color: enterprise.isLight ? AppColors.white : null,
            gradient: enterprise.isLight ? null : enterprise.pageGradient,
            borderRadius: isMobile
                ? const BorderRadius.horizontal(right: Radius.circular(24))
                : BorderRadius.zero,
            border: enterprise.isLight
                ? Border.all(color: enterprise.primary.withValues(alpha: .10))
                : null,
            boxShadow: [
              BoxShadow(
                color: enterprise.primary.withValues(alpha: .14),
                blurRadius: 24,
                offset: const Offset(8, 4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 12),
              children: [
                if (enterprise.isLight) _profileHeader(context, enterprise),
                _paymentQrHeader(
                  context,
                  enterprise,
                  branchName.isEmpty ? 'Branch' : branchName,
                  paymentQrCodes,
                ),
                ...[
                  _drawerSectionLabel(enterprise, 'Services'),
                  _drawerMenuItem(context, enterprise,
                      icon: Icons.dashboard_outlined,
                      label: translate('pos.dashboard'),
                      permissionKey: 'sell-staff-report', onTap: () {
                    Navigator.of(context).pop();
                    Get.to(() => const PosWorkspaceScreen());
                  }),
                  _sellOutDrawerItem(
                      context,
                      enterprise,
                      translate('home_screen.service_sell'),
                      Icons.point_of_sale),
                  _sellOutDrawerItem(
                    context,
                    enterprise,
                    translate('home_screen.service_sell_sim'),
                    Icons.sim_card,
                    serviceTypeValue: 'SellSim',
                  ),
                  _sellOutDrawerItem(
                      context,
                      enterprise,
                      translate('home_screen.service_material'),
                      Icons.inventory_2_outlined),
                  _sellOutDrawerItem(
                      context,
                      enterprise,
                      translate('home_screen.service_iron'),
                      Icons.local_laundry_service),
                  _sellOutDrawerItem(
                      context,
                      enterprise,
                      translate('home_screen.service_repair'),
                      Icons.build_circle_outlined),
                  _sellOutDrawerItem(
                      context,
                      enterprise,
                      translate('home_screen.service_buy_in'),
                      Icons.add_shopping_cart),
                  _sellOutDrawerItem(
                    context,
                    enterprise,
                    translate('home_screen.service_icloud_cus'),
                    Icons.cloud_outlined,
                    serviceTypeValue: 'iCloud Cus',
                  ),
                  _drawerDivider(enterprise),
                  _drawerSectionLabel(enterprise, 'Tools'),
                  _drawerMenuItem(context, enterprise,
                      icon: Icons.dynamic_feed_outlined,
                      label: translate('community.social_feed'),
                      permissionKey: 'social-feed', onTap: () {
                    Navigator.of(context).pop();
                    Get.to(() => const SocialFeedScreen());
                  }),
                  _drawerMenuItem(
                    context,
                    enterprise,
                    icon: Icons.calculate_outlined,
                    label: translate('loan_calculate_screen.loan_calculator'),
                    permissionKey: 'loan',
                    onTap: () {
                      Navigator.of(context).pop();
                      Get.to(() => LoanCalculateScreen());
                    },
                  ),
                  _drawerMenuItem(
                    context,
                    enterprise,
                    icon: Icons.campaign_outlined,
                    label: translate('dashboard_screen.social_rewards'),
                    permissionKey: 'social-rewards',
                    onTap: () {
                      Navigator.of(context).pop();
                      Get.to(
                          () => SocialSubmissionScreen(employeeId: employeeId));
                    },
                  ),
                  _drawerMenuItem(
                    context,
                    enterprise,
                    icon: Icons.badge_rounded,
                    label: translate('dashboard_screen.view_my_card'),
                    permissionKey: 'id-card',
                    onTap: () {
                      Navigator.of(context).pop();
                      Get.to(() => const FrontSidePreviewPage());
                    },
                  ),
                  _drawerMenuItem(
                    context,
                    enterprise,
                    icon: Icons.link,
                    label: translate('more_screen.links'),
                    permissionKey: 'links',
                    onTap: () {
                      Navigator.of(context).pop();
                      Get.to(() => const LinkListScreen());
                    },
                  ),
                  _drawerMenuItem(
                    context,
                    enterprise,
                    icon: Icons.inventory_2_outlined,
                    label: translate('more_screen.admin_assets'),
                    permissionKey: 'assets-admin',
                    extraHideCheck: () => !AssetPermissions.canOpenAdmin(
                      context.watch<DashboardProvider>().features,
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      Get.to(() => const AdminAssetListScreen());
                    },
                  ),
                  _drawerMenuItem(
                    context,
                    enterprise,
                    icon: Icons.build_circle_outlined,
                    label: translate('dashboard_screen.repair_list'),
                    permissionKey: 'repair',
                    onTap: () {
                      Navigator.of(context).pop();
                      Get.to(() => const RepairDevicePage());
                    },
                  ),
                  _drawerMenuItem(
                    context,
                    enterprise,
                    icon: Icons.groups_outlined,
                    label: translate('more_screen.team_sheet'),
                    permissionKey: 'team-sheet',
                    onTap: () {
                      Navigator.of(context).pop();
                      Get.to(() => TeamSheetScreen());
                    },
                  ),
                  _drawerMenuItem(
                    context,
                    enterprise,
                    icon: Icons.folder_shared_outlined,
                    label: translate('more_screen.company_documents'),
                    permissionKey: 'company-documents',
                    onTap: () {
                      Navigator.of(context).pop();
                      Get.to(() => const CompanyDocumentsScreen());
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sellOutDrawerItem(
    BuildContext context,
    EnterpriseTheme enterprise,
    String serviceType,
    IconData icon, {
    String? serviceTypeValue,
  }) {
    return _drawerMenuItem(
      context,
      enterprise,
      icon: icon,
      label: serviceType,
      permissionKey: "sell-staff-report",
      onTap: () {
        Navigator.of(context).pop();
        Get.to(() =>
            SellOutReportScreen(serviceType: serviceTypeValue ?? serviceType));
      },
    );
  }

  Widget _drawerMenuItem(
    BuildContext context,
    EnterpriseTheme enterprise, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    String? permissionKey,
    bool Function()? extraHideCheck,
  }) {
    if (permissionKey != null) {
      final dashboard = context.watch<DashboardProvider>();
      if (dashboard.features[permissionKey] == '0') {
        return const SizedBox.shrink();
      }
      final layoutKey =
          permissionKey == 'assets-admin' ? 'assets' : permissionKey;
      if (!dashboard.isMobileMenuAt(layoutKey, 'sidebar')) {
        return const SizedBox.shrink();
      }
    }
    if (extraHideCheck != null && extraHideCheck()) {
      return const SizedBox.shrink();
    }
    final foreground = enterprise.isLight
        ? AppColors.customFF172033
        : sidebarForeground(enterprise);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: enterprise.isLight
            ? const Color(0xFFF3F7FF)
            : enterprise.colors.cardColor.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onTap,
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: enterprise.isLight
                    ? const Color(0xFFE1EAF8)
                    : foreground.withValues(alpha: 0.10),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: enterprise.accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    icon,
                    color: enterprise.accent,
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
                      color: foreground,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: foreground.withValues(alpha: 0.56),
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
          color: (enterprise.isLight
                  ? AppColors.customFF172033
                  : sidebarForeground(enterprise))
              .withValues(alpha: 0.72),
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.7,
        ),
      ),
    );
  }

  Widget _drawerDivider(EnterpriseTheme enterprise) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Divider(
        height: 1,
        color: enterprise.isLight
            ? const Color(0xFFE5EDF8)
            : sidebarForeground(enterprise).withValues(alpha: 0.16),
      ),
    );
  }

  Widget _profileHeader(
    BuildContext context,
    EnterpriseTheme enterprise,
  ) {
    final user = context.watch<PrefProvider>();
    final displayName = user.fullname.trim().isNotEmpty
        ? user.fullname.trim()
        : user.userName.trim();
    final avatarUrl = user.avatar.trim();
    final initial = displayName.isNotEmpty ? displayName.characters.first : '';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFEAF4FF),
            enterprise.primary.withValues(alpha: .10),
          ],
        ),
        border: Border.all(color: enterprise.primary.withValues(alpha: .12)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: enterprise.primary.withValues(alpha: .12),
            backgroundImage:
                avatarUrl.startsWith('http') ? NetworkImage(avatarUrl) : null,
            child: avatarUrl.startsWith('http')
                ? null
                : Text(
                    initial.toUpperCase(),
                    style: TextStyle(
                      color: enterprise.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName.isNotEmpty ? displayName : 'Welcome',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF17243B),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  user.userId.trim().isNotEmpty
                      ? 'ID ${user.userId.trim()}'
                      : 'Staff account',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.verified_rounded, color: enterprise.primary, size: 18),
        ],
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
              sidebarTone(enterprise.primary),
              sidebarTone(enterprise.accent),
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
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Image.network(
                    firstQrUri.toString(),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.qr_code_2_rounded,
                      color: AppColors.black87,
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
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.qr_code_2_rounded,
                  color: AppColors.black87,
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
                      color: AppColors.white,
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
                      color: AppColors.white.withValues(alpha: 0.82),
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
                      color: AppColors.white.withValues(alpha: 0.92),
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
              color: AppColors.white,
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
          backgroundColor: AppColors.black,
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Close',
                        icon: const Icon(Icons.close, color: AppColors.white),
                        onPressed: () => Navigator.of(dialogContext).pop(),
                      ),
                      Expanded(
                        child: Text(
                          paymentQrCode.paymentName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Download',
                        icon: const Icon(
                          Icons.download_rounded,
                          color: AppColors.white,
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
                            color: AppColors.white,
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
                        color: AppColors.white,
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
      final response = await KyHttp.get(uri);
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
      if (!context.mounted) return;
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
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open payment link')),
        );
      }
    } catch (error) {
      if (!context.mounted) return;
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
        color: AppColors.black54,
        size: size,
      );
    }

    return Image.network(
      uri.toString(),
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(
        Icons.broken_image_outlined,
        color: AppColors.black54,
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
