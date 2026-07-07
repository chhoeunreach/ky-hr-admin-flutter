import 'package:cnattendance/provider/dashboardprovider.dart';
import 'package:cnattendance/provider/morescreenprovider.dart';
import 'package:cnattendance/provider/prefprovider.dart';
import 'package:cnattendance/screen/advancesalary/advancesalaryscreen.dart';
import 'package:cnattendance/screen/advancesalary/admin/admin_advancesalary_screen.dart';
import 'package:cnattendance/screen/assetscreen/assetscreen.dart';
import 'package:cnattendance/screen/awards/awardsscreen.dart';
import 'package:cnattendance/screen/complainscreen/complainscreen.dart';
import 'package:cnattendance/screen/dashboard/projectscreen.dart';
import 'package:cnattendance/screen/eventscreen/eventlistscreen.dart';
import 'package:cnattendance/screen/profile/aboutscreen.dart';
import 'package:cnattendance/screen/profile/changepasswordscreen.dart';
import 'package:cnattendance/screen/profile/companyrulesscreen.dart';
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
import 'package:cnattendance/screen/tadascreen/TadaScreen.dart';
import 'package:cnattendance/theme/app_theme_mode.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:cnattendance/theme/theme_provider.dart';
import 'package:cnattendance/screen/training/trainingscreen.dart';
import 'package:cnattendance/screen/warningscreen/warningscreen.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:cnattendance/widget/headerprofile.dart';
import 'package:cnattendance/widgets/theme_selector.dart';
import 'package:cnattendance/widget/premium_background.dart';
import 'package:flutter/material.dart';
import 'package:cnattendance/widget/morescreen/services.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:focus_detector/focus_detector.dart';
import 'package:get_storage/get_storage.dart';
import 'package:provider/provider.dart';

class MoreScreen extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => MoreScreenState();
}

class MoreScreenState extends State<MoreScreen> {
  @override
  Widget build(BuildContext context) {
    final attendanceType = context.watch<PrefProvider>().attendanceType;
    final features = context.watch<MoreScreenProvider>().features;
    final showNfc = context.watch<MoreScreenProvider>().showNfc;
    final attendanceMethod =
        context.watch<DashboardProvider>().attendanceMethods;
    final selectedThemeMode = context.watch<ThemeProvider>().mode;
    final employeeId =
        int.tryParse(context.watch<PrefProvider>().userId.trim()) ?? 0;
    final enterprise = EnterpriseTheme.of(context);

    void changeAttendanceType(String type) {
      context.read<PrefProvider>().saveAttendanceType(type);
      showToast("Attendance method set to $type");
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
    }) {
      final isSelected = attendanceType == type;
      final foregroundColor =
          isSelected || enterprise.isDark ? Colors.white : enterprise.text;
      final borderColor = isSelected
          ? Colors.white.withValues(alpha: 0.58)
          : enterprise.accent
              .withValues(alpha: enterprise.isDark ? 0.46 : 0.68);
      final fillColor = enterprise.surface.withValues(
        alpha: enterprise.isDark ? 0.70 : 0.88,
      );

      return InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => changeAttendanceType(type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? null : fillColor,
            gradient: isSelected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [enterprise.primary, enterprise.accent],
                  )
                : null,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: (isSelected ? enterprise.accent : Colors.black)
                    .withValues(alpha: isSelected ? 0.28 : 0.12),
                blurRadius: isSelected ? 18 : 10,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: foregroundColor, size: 18),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: foregroundColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
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
              child: features.isEmpty
                  ? Center(
                      child: Text(
                        "Loading",
                        style: TextStyle(color: Colors.white, fontSize: 15),
                      ),
                    )
                  : SingleChildScrollView(
                      child: Container(
                        width: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            HeaderProfile(),
                            if (attendanceMethod.isNotEmpty)
                              Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 10),
                                  child: Text(
                                    translate(
                                        'more_screen.attendance_default_method'),
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold),
                                  )),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                spacing: 10,
                                children: [
                                  if (attendanceMethod.contains("default"))
                                    attendanceMethodChip(
                                      type: "Default",
                                      icon: Icons.fingerprint,
                                      label: translate('more_screen.default'),
                                    ),
                                  if (attendanceMethod.contains("nfc"))
                                    attendanceMethodChip(
                                      type: "NFC",
                                      icon: Icons.nfc,
                                      label: translate('more_screen.nfc'),
                                    ),
                                  if (attendanceMethod.contains("qr"))
                                    attendanceMethodChip(
                                      type: "QR",
                                      icon: Icons.qr_code,
                                      label: translate('more_screen.qr_code'),
                                    ),
                                ],
                              ),
                            ),
                            Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 10),
                                child: Text(
                                  translate('more_screen.account'),
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold),
                                )),
                            Services(translate('more_screen.profile'),
                                Icons.person, ProfileScreen()),
                            Services(translate('more_screen.change_password'),
                                Icons.password, ChangePasswordScreen()),
                            Padding(
                                padding: EdgeInsets.only(
                                    left: 20, right: 20, top: 20, bottom: 10),
                                child: Text(
                                  translate('more_screen.office_desk'),
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold),
                                )),
                            Services(translate('more_screen.team_sheet'),
                                Icons.group, TeamSheetScreen()),
                            Services(translate('more_screen.groups'),
                                Icons.forum, GroupListScreen()),
                            features["project-management"] != "1"
                                ? SizedBox.shrink()
                                : Services(
                                    translate('more_screen.project_management'),
                                    Icons.work,
                                    ProjectScreen()),
                            features["event"] != "1"
                                ? SizedBox.shrink()
                                : Services(translate('common.office_events'),
                                    Icons.event, EventListScreen()),
                            features["training"] != "1"
                                ? SizedBox.shrink()
                                : Services(translate('home_screen.training'),
                                    Icons.group, TrainingScreen()),
                            features["award"] != "1"
                                ? SizedBox.shrink()
                                : Services(translate('more_screen.awards'),
                                    Icons.workspace_premium, AwardsScreen()),
                            features["assets"] != "1"
                                ? SizedBox.shrink()
                                : Services(
                                    translate('common.assets'),
                                    Icons.production_quantity_limits,
                                    AssetScreen()),
                            /*features["training"] != "1"
                                ? SizedBox.shrink()
                                : Services(translate('more_screen.training'),
                                    Icons.model_training, TrainingScreen()),*/
                            Services(translate('more_screen.holiday'),
                                Icons.calendar_month, HolidayScreen()),
                            Services(translate('more_screen.notices'),
                                Icons.message, NoticeScreen()),
                            features["meeting"] != "1"
                                ? SizedBox.shrink()
                                : Services(translate('more_screen.meeting'),
                                    Icons.meeting_room, MeetingScreen()),
                            Services(
                                translate('more_screen.leave_calendar'),
                                Icons.calendar_month_outlined,
                                LeaveCalendarScreen()),
                            features["warning"] != "1"
                                ? SizedBox.shrink()
                                : Services(translate('more_screen.warning'),
                                    Icons.warning, WarningScreen()),
                            features["complaint"] != "1"
                                ? SizedBox.shrink()
                                : Services(
                                    translate('more_screen.complain'),
                                    Icons.perm_device_information_outlined,
                                    ComplainScreen()),
                            Padding(
                                padding: EdgeInsets.only(
                                    left: 20, right: 20, top: 20, bottom: 10),
                                child: GestureDetector(
                                  onLongPress: showFeatureDebug,
                                  child: Text(
                                    translate('more_screen.finance'),
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold),
                                  ),
                                )),
                            features["tada"] != "1"
                                ? SizedBox.shrink()
                                : Services(translate('more_screen.tada'),
                                    Icons.money, TadaScreen()),
                            features["payroll-management"] != "1"
                                ? SizedBox.shrink()
                                : Services(translate('more_screen.payslip'),
                                    Icons.payments_outlined, PaySlipScreen()),
                            features["payroll-management"] != "1"
                                ? SizedBox.shrink()
                                : Services("SSF History", Icons.payments,
                                    SsfHistoryScreen()),
                            features["advance-salary"] != "1"
                                ? SizedBox.shrink()
                                : Services(
                                    translate('more_screen.advance_salary'),
                                    Icons.monetization_on,
                                    AdvanceSalaryScreen()),
                            features["social-rewards"] != "1"
                                ? SizedBox.shrink()
                                : Services(
                                    "Social Rewards",
                                    Icons.campaign,
                                    SocialSubmissionScreen(
                                      employeeId: employeeId,
                                    )),
                            features["advance-salary-admin"] != "1"
                                ? SizedBox.shrink()
                                : Services(
                                    "Admin Advance Salary",
                                    Icons.admin_panel_settings,
                                    AdminAdvanceSalaryScreen()),
                            features["social-rewards-admin"] != "1"
                                ? SizedBox.shrink()
                                : Services("Social Rewards", Icons.verified,
                                    const AdminSocialRewardsScreen()),
                            /*features["loan"] != "1"
                                ? SizedBox.shrink()
                                : Services(translate('more_screen.loans'),
                                    Icons.handshake_outlined, LoanListScreen()),*/
                            Padding(
                                padding: EdgeInsets.only(
                                    left: 20, right: 20, top: 20, bottom: 10),
                                child: Text(
                                  translate('more_screen.additional'),
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold),
                                )),
                            //Services('Issue Ticket', Icons.note, ProfileScreen()),
                            features["support"] != "1"
                                ? SizedBox.shrink()
                                : Services(translate('more_screen.support'),
                                    Icons.support_agent, SupportScreen()),
                            Services(translate('more_screen.company_rules'),
                                Icons.rule_folder, CompanyRulesScreen()),
                            Services(translate('more_screen.about_us'),
                                Icons.info, AboutScreen('about-us')),
                            Services(
                                translate('more_screen.terms_and_conditions'),
                                Icons.rule,
                                AboutScreen('terms-and-conditions')),
                            Services(
                              translate('more_screen.privacy_policy'),
                              Icons.policy,
                              ProfileScreen(),
                              control: 1,
                            ),
                            Padding(
                                padding: EdgeInsets.only(
                                    left: 20, right: 20, top: 20, bottom: 10),
                                child: Text(
                                  translate('more_screen.others'),
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold),
                                )),
                            features["dark-mode"] != "1"
                                ? SizedBox.shrink()
                                : Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 0),
                                    child: Column(
                                      children: [
                                        ListTile(
                                          trailing: Switch(
                                            activeThumbColor: Colors.blue,
                                            value: selectedThemeMode ==
                                                AppThemeMode.dark,
                                            onChanged: (value) {
                                              context
                                                  .read<ThemeProvider>()
                                                  .setMode(value
                                                      ? AppThemeMode.dark
                                                      : AppThemeMode.light);
                                            },
                                          ),
                                          dense: true,
                                          minLeadingWidth: 5,
                                          leading: Icon(
                                            Icons.landscape,
                                            color: Colors.white,
                                          ),
                                          title: Text(
                                            translate('more_screen.dark_mode'),
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 15),
                                          ),
                                          onTap: () {
                                            context
                                                .read<ThemeProvider>()
                                                .setMode(selectedThemeMode ==
                                                        AppThemeMode.dark
                                                    ? AppThemeMode.light
                                                    : AppThemeMode.dark);
                                          },
                                          selected: true,
                                        ),
                                        const Divider(
                                          height: 1,
                                          color: Colors.white24,
                                          indent: 15,
                                          endIndent: 15,
                                        ),
                                      ],
                                    ),
                                  ),
                            const ThemeSelector(),
                            Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 0),
                              child: Column(
                                children: [
                                  ListTile(
                                    trailing: Switch(
                                      activeThumbColor: Colors.blue,
                                      value: getAnimation(),
                                      onChanged: (value) {
                                        final box = GetStorage();
                                        box.write('animation',
                                            !(box.read("animation") ?? true));
                                      },
                                    ),
                                    dense: true,
                                    minLeadingWidth: 5,
                                    leading: Icon(
                                      Icons.animation,
                                      color: Colors.white,
                                    ),
                                    title: Text(
                                      translate('more_screen.animation'),
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 15),
                                    ),
                                    onTap: () {
                                      final box = GetStorage();
                                      box.write('animation',
                                          !(box.read("animation") ?? true));
                                    },
                                    selected: true,
                                  ),
                                  const Divider(
                                    height: 1,
                                    color: Colors.white24,
                                    indent: 15,
                                    endIndent: 15,
                                  ),
                                ],
                              ),
                            ),
                            !showNfc
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
                            features["resignation"] != "1"
                                ? SizedBox.shrink()
                                : Services(
                                    "Resignation",
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
                    )),
        ),
      ),
    );
  }
}
