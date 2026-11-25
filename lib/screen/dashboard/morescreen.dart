import 'package:cnattendance/features/community/social_feed_screen.dart';
import 'package:cnattendance/features/company_documents/company_documents_screen.dart';
import 'package:cnattendance/features/delivery/delivery_dashboard_screen.dart';
import 'package:cnattendance/features/repair_price/pages/repair_device_page.dart';
import 'package:cnattendance/provider/dashboardprovider.dart';
import 'package:cnattendance/provider/morescreenprovider.dart';
import 'package:cnattendance/provider/prefprovider.dart';
import 'package:cnattendance/screen/advancesalary/advancesalaryscreen.dart';
import 'package:cnattendance/screen/advancesalary/admin/admin_advancesalary_screen.dart';
import 'package:cnattendance/screen/assetscreen/admin_asset_list_screen.dart';
import 'package:cnattendance/screen/assetscreen/assetscreen.dart';
import 'package:cnattendance/screen/awards/awardsscreen.dart';
import 'package:cnattendance/screen/complainscreen/complainscreen.dart';
import 'package:cnattendance/screen/dashboard/admin/banner_admin_screen.dart';
import 'package:cnattendance/screen/dashboard/projectscreen.dart';
import 'package:cnattendance/screen/eventscreen/eventlistscreen.dart';
import 'package:cnattendance/screen/meeting_attendance/meeting_attendance_screen.dart';
import 'package:cnattendance/screen/profile/aboutscreen.dart';
import 'package:cnattendance/screen/profile/changepasswordscreen.dart';
import 'package:cnattendance/screen/profile/companyrulesscreen.dart';
import 'package:cnattendance/screen/links/link_list_screen.dart';
import 'package:cnattendance/screen/profile/front_side_preview_page.dart';
import 'package:cnattendance/screen/profile/holidayscreen.dart';
import 'package:cnattendance/screen/profile/leavecalendarscreen.dart';
import 'package:cnattendance/screen/profile/meetingscreen.dart';
import 'package:cnattendance/screen/profile/noticescreen.dart';
import 'package:cnattendance/screen/profile/payslipscreen.dart';
import 'package:cnattendance/screen/profile/profilescreen.dart';
import 'package:cnattendance/screen/profile/ssfhistoryscreen.dart';
import 'package:cnattendance/screen/profile/supportscreen.dart';
import 'package:cnattendance/screen/profile/group_list_screen.dart';
import 'package:cnattendance/screen/profile/teamsheetscreen.dart';
import 'package:cnattendance/screen/social_rewards/admin_social_rewards_screen.dart';
import 'package:cnattendance/screen/social_rewards/social_submission_screen.dart';
import 'package:cnattendance/screen/tadascreen/tadascreen.dart';
import 'package:cnattendance/theme/app_theme_mode.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:cnattendance/theme/theme_provider.dart';
import 'package:cnattendance/screen/training/trainingscreen.dart';
import 'package:cnattendance/screen/warningscreen/warningscreen.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:cnattendance/utils/asset_permissions.dart';
import 'package:cnattendance/widget/headerprofile.dart';
import 'package:cnattendance/widgets/theme_selector.dart';
import 'package:cnattendance/widget/premium_background.dart';
import 'package:cnattendance/widget/server_status_tile.dart';
import 'package:flutter/material.dart';
import 'package:cnattendance/widget/morescreen/services.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:focus_detector/focus_detector.dart';
import 'package:provider/provider.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

class MoreScreen extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => MoreScreenState();
}

class MoreScreenState extends State<MoreScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<MoreScreenProvider>().getFeatures();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final attendanceType =
        context.select<PrefProvider, String>((p) => p.attendanceType);
    final features = context.select<DashboardProvider, Map<String, String>>(
        (p) => Map.of(p.features));
    final showNfc = context.select<MoreScreenProvider, bool>((p) => p.showNfc);
    final attendanceMethod = context.select<DashboardProvider, List<String>>(
        (p) => List.of(p.attendanceMethods));
    final selectedThemeMode =
        context.select<ThemeProvider, AppThemeMode>((p) => p.mode);
    final employeeId = int.tryParse(
            context.select<PrefProvider, String>((p) => p.userId).trim()) ??
        0;
    final enterprise = EnterpriseTheme.of(context);
    final dashboard = context.watch<DashboardProvider>();
    final availableAttendanceMethods =
        attendanceMethod.map((method) => method.toLowerCase()).toList();

    bool showInMore(String menu) => dashboard.isMobileMenuAt(menu, 'sidebar');

    void changeAttendanceType(String type) {
      context.read<PrefProvider>().saveAttendanceType(type);
      showToast("Attendance method set to $type");
    }

    String disabledAttendanceMessage(String label) {
      if (attendanceMethod.isEmpty) {
        return translate('attendance_messages.no_attendance_method');
      }

      return "$label ${translate('attendance_messages.method_disabled_suffix')}";
    }

    void showFeatureDebug() {
      final text =
          features.entries.map((e) => "${e.key}: ${e.value}").join("\n");
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Feature Flags"),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: SelectableText(text.isEmpty ? "No features loaded" : text),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Close"),
            ),
          ],
        ),
      );
    }

    Widget attendanceMethodChip({
      required String type,
      required IconData icon,
      required String label,
      required bool enabled,
    }) {
      final isSelected = attendanceType == type;
      final effectiveSelected = enabled && isSelected;
      final foregroundColor = effectiveSelected
          ? AppColors.white
          : (enterprise.isDark ? AppColors.white : enterprise.text);
      final disabledColor =
          (enterprise.isDark ? AppColors.white : enterprise.text)
              .withValues(alpha: 0.40);
      final borderColor = effectiveSelected
          ? (enterprise.isDark
              ? AppColors.white.withValues(alpha: 0.58)
              : enterprise.primary)
          : (enterprise.isDark
              ? enterprise.accent.withValues(alpha: enabled ? 0.46 : 0.24)
              : (enabled ? AppColors.customFFB8DEFF : AppColors.customFFE2E8F0));
      final fillColor = effectiveSelected
          ? null
          : (enterprise.isDark
              ? enterprise.surface.withValues(alpha: enabled ? 0.70 : 0.38)
              : (enabled ? AppColors.white : AppColors.customFFF1F5F9));

      return InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: enabled
            ? () => changeAttendanceType(type)
            : () => showToast(disabledAttendanceMessage(label)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: effectiveSelected ? null : fillColor,
            gradient: effectiveSelected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [enterprise.primary, enterprise.accent],
                  )
                : null,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: (effectiveSelected ? enterprise.accent : AppColors.black)
                    .withValues(alpha: effectiveSelected ? 0.28 : (enterprise.isDark ? 0.12 : 0.05)),
                blurRadius: effectiveSelected ? 18 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  color: enabled ? foregroundColor : disabledColor, size: 16),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: enabled ? foregroundColor : disabledColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget sectionHeader(String title, {VoidCallback? onLongPress}) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
        child: GestureDetector(
          onLongPress: onLongPress,
          child: Text(
            title,
            style: TextStyle(
              color: enterprise.isDark ? enterprise.text : enterprise.primary,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
          ),
        ),
      );
    }

    return FocusDetector(
      onFocusGained: () {
        context.read<MoreScreenProvider>().getFeatures();
      },
      child: PremiumBackground(
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: HomeSurfaceStyle(
              clean: enterprise.mode == AppThemeMode.light,
              child: SingleChildScrollView(
                child: Container(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const HeaderProfile(showMenuButton: false),
                      if (features['social-feed'] == '1')
                        Services(translate('community.social_feed'),
                            Icons.dynamic_feed_outlined, const SocialFeedScreen()),
                      sectionHeader(translate('more_screen.attendance_default_method')),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 7,
                          children: [
                            attendanceMethodChip(
                              type: "Default",
                              icon: Icons.fingerprint,
                              label: translate('more_screen.default'),
                              enabled:
                                  availableAttendanceMethods.contains("default"),
                            ),
                            attendanceMethodChip(
                              type: "NFC",
                              icon: Icons.nfc,
                              label: translate('more_screen.nfc'),
                              enabled: availableAttendanceMethods.contains("nfc"),
                            ),
                            attendanceMethodChip(
                              type: "QR",
                              icon: Icons.qr_code,
                              label: translate('more_screen.qr_code'),
                              enabled: availableAttendanceMethods.contains("qr"),
                            ),
                          ],
                        ),
                      ),
                      sectionHeader(translate('more_screen.account')),
                  if (features["profile"] != "0")
                    Services(translate('more_screen.profile'), Icons.person,
                        ProfileScreen()),
                  if (features["change-password"] != "0")
                    Services(translate('more_screen.change_password'),
                        Icons.password, ChangePasswordScreen()),
                  sectionHeader(translate('more_screen.management')),
                  if (features["team-sheet"] != "0" && showInMore("team-sheet"))
                    Services(translate('more_screen.team_sheet'), Icons.group,
                        TeamSheetScreen()),
                  if (features["company-documents"] != "0" && showInMore("company-documents"))
                    Services(translate('more_screen.company_documents'),
                        Icons.folder_shared_outlined,
                        const CompanyDocumentsScreen()),
                  if (features["delivery"] != "0" && showInMore("delivery"))
                    Services(translate('more_screen.delivery'),
                        Icons.two_wheeler_rounded,
                        const DeliveryDashboardScreen()),
                  if (AssetPermissions.canOpenAdmin(features) && showInMore("assets"))
                    Services(
                        translate('more_screen.admin_assets'),
                        Icons.inventory_2_outlined,
                        const AdminAssetListScreen()),
                  if (features["repair"] != "0" && showInMore("repair"))
                    Services(
                        translate('dashboard_screen.repair_list'),
                        Icons.build_circle_outlined,
                        const RepairDevicePage()),
                  features["banner-admin"] == "0" || !showInMore("banner-admin")
                      ? SizedBox.shrink()
                      : Services(
                          translate('more_screen.banner_manager'),
                          Icons.view_carousel_rounded,
                          const BannerAdminScreen()),
                  features["advance-salary-admin"] == "0" || !showInMore("advance-salary-admin")
                      ? SizedBox.shrink()
                      : Services(
                          translate('more_screen.admin_advance_salary'),
                          Icons.admin_panel_settings,
                          AdminAdvanceSalaryScreen()),
                  features["social-rewards-admin"] == "0" || !showInMore("social-rewards-admin")
                      ? SizedBox.shrink()
                      : Services(translate('more_screen.social_rewards'),
                          Icons.verified, const AdminSocialRewardsScreen()),
                  sectionHeader(translate('more_screen.office_desk')),
                  if (features["groups"] != "0" && showInMore("groups"))
                    Services(translate('more_screen.groups'), Icons.forum,
                        GroupListScreen()),
                  features["project-management"] == "0" || !showInMore("project-management")
                      ? SizedBox.shrink()
                      : Services(translate('more_screen.project_management'),
                          Icons.work, ProjectScreen()),
                  features["event"] == "0" || !showInMore("event")
                      ? SizedBox.shrink()
                      : Services(translate('common.office_events'), Icons.event,
                          EventListScreen()),
                  features["training"] == "0" || !showInMore("training")
                      ? SizedBox.shrink()
                      : Services(translate('home_screen.training'), Icons.group,
                          TrainingScreen()),
                  features["award"] == "0" || !showInMore("award")
                      ? SizedBox.shrink()
                      : Services(translate('more_screen.awards'),
                          Icons.workspace_premium, AwardsScreen()),
                  features["assets"] == "0" || !showInMore("assets")
                      ? SizedBox.shrink()
                      : Services(translate('common.assets'),
                          Icons.production_quantity_limits, AssetScreen()),
                  if (features["holiday"] != "0" && showInMore("holiday"))
                    Services(translate('more_screen.holiday'),
                        Icons.calendar_month, HolidayScreen()),
                  if (features["notice"] != "0" && showInMore("notice"))
                    Services(translate('more_screen.notices'), Icons.message,
                        NoticeScreen()),
                  features["meeting"] == "0" || !showInMore("meeting")
                      ? SizedBox.shrink()
                      : Services(translate('more_screen.meeting'),
                          Icons.meeting_room, MeetingScreen()),
                  if (features["leave-calendar"] != "0" && showInMore("leave-calendar"))
                    Services(translate('more_screen.leave_calendar'),
                        Icons.calendar_month_outlined, LeaveCalendarScreen()),
                  features["warning"] == "0" || !showInMore("warning")
                      ? SizedBox.shrink()
                      : Services(translate('more_screen.warning'),
                          Icons.warning, WarningScreen()),
                  features["complaint"] == "0" || !showInMore("complaint")
                      ? SizedBox.shrink()
                      : Services(
                          translate('more_screen.complain'),
                          Icons.perm_device_information_outlined,
                          ComplainScreen()),
                  sectionHeader(translate('more_screen.finance'), onLongPress: showFeatureDebug),
                  features["tada"] == "0" || !showInMore("tada")
                      ? SizedBox.shrink()
                      : Services(translate('more_screen.tada'), Icons.money,
                          TadaScreen()),
                  features["payroll-management"] == "0" || !showInMore("payroll-management")
                      ? SizedBox.shrink()
                      : Services(translate('more_screen.payslip'),
                          Icons.payments_outlined, PaySlipScreen()),
                  features["payroll-management"] == "0" || !showInMore("payroll-management")
                      ? SizedBox.shrink()
                      : Services(translate('more_screen.ssf_history'),
                          Icons.payments, SsfHistoryScreen()),
                  features["advance-salary"] == "0" || !showInMore("advance-salary")
                      ? SizedBox.shrink()
                      : Services(translate('more_screen.advance_salary'),
                          Icons.monetization_on, AdvanceSalaryScreen()),
                  features["social-rewards"] == "0" || !showInMore("social-rewards")
                      ? SizedBox.shrink()
                      : Services(
                          translate('more_screen.social_rewards'),
                          Icons.campaign,
                          SocialSubmissionScreen(
                            employeeId: employeeId,
                          )),
                  if (features["id-card"] != "0" && showInMore("id-card"))
                    Services(translate('more_screen.my_id_card'),
                        Icons.badge_rounded, const FrontSidePreviewPage()),
                  if (features["meeting-attendance"] != "0" && showInMore("meeting-attendance"))
                    Services(
                      translate('more_screen.meeting_attendance'),
                      Icons.qr_code_scanner,
                      const MeetingAttendanceScreen(),
                    ),
                  sectionHeader(translate('more_screen.additional')),
                  //Services('Issue Ticket', Icons.note, ProfileScreen()),
                  features["support"] == "0" || !showInMore("support")
                      ? SizedBox.shrink()
                      : Services(translate('more_screen.support'),
                          Icons.support_agent, SupportScreen()),
                  if (features["company-rules"] != "0" && showInMore("company-rules"))
                    Services(translate('more_screen.company_rules'),
                        Icons.rule_folder, CompanyRulesScreen()),
                  if (features["links"] != "0" && showInMore("links"))
                    Services(translate('more_screen.links'), Icons.link,
                        const LinkListScreen()),
                  const ServerStatusTile(),
                  Services(translate('more_screen.about_us'), Icons.info,
                      AboutScreen('about-us')),
                  Services(translate('more_screen.terms_and_conditions'),
                      Icons.rule, AboutScreen('terms-and-conditions')),
                  Services(
                    translate('more_screen.privacy_policy'),
                    Icons.policy,
                    ProfileScreen(),
                    control: 1,
                  ),
                  sectionHeader(translate('more_screen.others')),
                  features["dark-mode"] == "0"
                      ? SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 3),
                          child: EnterpriseGlass(
                            radius: 14,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            glowOpacity: 0.07,
                            child: Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(11),
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        enterprise.primary,
                                        enterprise.accent
                                      ],
                                    ),
                                  ),
                                  child: const Icon(Icons.dark_mode_outlined,
                                      color: AppColors.white, size: 18),
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Text(
                                    translate('more_screen.dark_mode'),
                                    style: TextStyle(
                                      color: enterprise.text,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Switch(
                                  activeThumbColor: enterprise.primary,
                                  value: selectedThemeMode == AppThemeMode.dark,
                                  onChanged: (value) {
                                    context.read<ThemeProvider>().setMode(value
                                        ? AppThemeMode.dark
                                        : AppThemeMode.light);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                  const ThemeSelector(),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 3),
                    child: EnterpriseGlass(
                      radius: 14,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      glowOpacity: 0.07,
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(11),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  enterprise.primary,
                                  enterprise.accent
                                ],
                              ),
                            ),
                            child: const Icon(Icons.animation_rounded,
                                color: AppColors.white, size: 18),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              translate('more_screen.animation'),
                              style: TextStyle(
                                color: enterprise.text,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Switch(
                            activeThumbColor: enterprise.primary,
                            value: context.watch<ThemeProvider>().animationsEnabled,
                            onChanged: context.read<ThemeProvider>().setAnimationsEnabled,
                          ),
                        ],
                      ),
                    ),
                  ),
                  (!showNfc || features["nfc-qr"] != "1")
                      ? SizedBox.shrink()
                      : Services(
                          translate('more_screen.add_nfc'),
                          Icons.nfc,
                          SupportScreen(),
                          control: 3,
                        ),
                  Services(
                    translate('common.language'),
                    Icons.language,
                    ProfileScreen(),
                    control: 4,
                  ),
                  features["resignation"] != "1" || !showInMore("resignation")
                      ? SizedBox.shrink()
                      : Services(
                          translate('more_screen.resignation'),
                          Icons.group_remove_outlined,
                          ProfileScreen(),
                          control: 5,
                        ),
                  Services(
                    translate('more_screen.log_out'),
                    Icons.logout,
                    ProfileScreen(),
                    control: 2,
                  ),
                ],
              ),
            ),
          ))),
        ),
      ),
    );
  }
}
