import 'package:cnattendance/features/community/flash_view_presenter.dart';
import 'dart:async';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/data/source/network/model/login/User.dart';
import 'package:cnattendance/provider/dashboardprovider.dart';
import 'package:cnattendance/provider/prefprovider.dart';
import 'package:cnattendance/screen/auth/login_screen.dart';
import 'package:cnattendance/services/push_notification_service.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:cnattendance/utils/locationstatus.dart';
import 'package:cnattendance/widget/customalertdialog.dart';
import 'package:cnattendance/widget/homescreen/checkattendance.dart';
import 'package:cnattendance/widget/homescreen/overviewdashboard.dart';
import 'package:cnattendance/features/appearance/app_appearance_api.dart';
import 'package:cnattendance/features/banner_slideshow/banner_slideshow_api.dart';
import 'package:cnattendance/widget/premium_background.dart';
import 'package:cnattendance/theme/app_theme_mode.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:cnattendance/theme/theme_layout.dart';
import 'package:cnattendance/theme/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:focus_detector/focus_detector.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:persistent_bottom_nav_bar_v2/persistent_bottom_nav_bar_v2.dart';
import 'package:provider/provider.dart';
import 'package:cnattendance/data/source/network/model/dashboard/Dashboard.dart';
import 'package:cnattendance/utils/app_device_info.dart';
import 'package:cnattendance/widget/app_update_dialog.dart';
import 'package:cnattendance/widget/headerprofile.dart';
import 'package:cnattendance/widget/homescreen/myteam.dart';
import 'package:cnattendance/widget/homescreen/weeklyreportchart.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:flutter/foundation.dart';

class HomeScreen extends StatefulWidget {
  final PersistentTabController controller;

  HomeScreen(this.controller);

  @override
  State<StatefulWidget> createState() => HomeScreenState(controller);
}

class HomeScreenState extends State<HomeScreen> {
  QuickActions quickActions = const QuickActions();
  bool isEnabled = true;
  bool isLoading = false;
  bool _dashboardLoadedOnce = false;
  bool _dashboardRefreshInFlight = false;
  bool _dashboardLoadFailed = false;
  DateTime? _lastDashboardRefreshAt;

  PersistentTabController controller;

  HomeScreenState(this.controller);

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback(
      (timeStamp) async {
        unawaited(PushNotificationService.openInitialNotification());

        quickActions.initialize((type) async {
          if (type == "actionCheckIn") {
            await onCheckInShortCut();
          } else if (type == "actionCheckOut") {
            await onCheckOutShortCut();
          }
        });
        quickActions.setShortcutItems(<ShortcutItem>[
          ShortcutItem(
              type: 'actionCheckIn',
              localizedTitle: 'Check In',
              icon: 'check_in'),
          ShortcutItem(
              type: 'actionCheckOut',
              localizedTitle: 'Check Out',
              icon: 'check_out'),
        ]);

        unawaited(
          Provider.of<DashboardProvider>(context, listen: false).getFeatures(),
        );
        unawaited(loadDashboard(force: true));
      },
    );
    super.initState();
  }

  void locationStatus() async {
    try {
      final preferences = Preferences();
      final position = await LocationStatus()
          .determinePosition(await preferences.getWorkSpace());

      if (!mounted) {
        return;
      }
      final location =
          Provider.of<DashboardProvider>(context, listen: false).locationStatus;

      location.update('latitude', (value) => position.latitude);
      location.update('longitude', (value) => position.longitude);
    } catch (e) {
      if (kDebugMode) debugPrint(e.toString());
      showToast(e.toString());
    }
  }

  Future<void> onCheckInShortCut() async {
    final pref = Preferences();
    if ((await pref.getToken()).isNotEmpty) {
      if ((await pref.getUserAuth())) {
        return;
      }
      final provider = Provider.of<DashboardProvider>(context, listen: false);
      try {
        isLoading = true;
        setState(() {
          EasyLoading.show(
              status: translate('loader.requesting'),
              maskType: EasyLoadingMaskType.black);
        });
        final status = await provider.getCheckInStatus();
        if (status) {
          final response = await provider.checkInAttendance();
          isEnabled = true;
          if (!mounted) {
            return;
          }
          if (response.statusCode == 401) {
            Get.offAll(LoginScreen());
            return;
          }
          setState(() {
            EasyLoading.dismiss(animation: true);
            isLoading = false;
            showDialog(
              context: context,
              builder: (context) {
                return Dialog(
                  child: CustomAlertDialog(response.message),
                );
              },
            );
          });
        }
      } catch (e) {
        if (kDebugMode) debugPrint(e.toString());
        final message = e.toString();
        final extra =
            await provider.buildWorkspaceDistanceInfoIfNeeded(message);
        setState(() {
          EasyLoading.dismiss(animation: true);
          isLoading = false;
          showDialog(
            context: context,
            builder: (context) {
              return Dialog(
                child: CustomAlertDialog(
                    extra == null ? message : '$message\n\n$extra'),
              );
            },
          );
        });
      }
    } else {
      showToast(translate('alerts.please_login_first'));
    }
  }

  Future<void> onCheckOutShortCut() async {
    final pref = Preferences();
    if ((await pref.getToken()).isNotEmpty) {
      if ((await pref.getUserAuth())) {
        return;
      }
      final provider = Provider.of<DashboardProvider>(context, listen: false);
      try {
        isLoading = true;
        setState(() {
          EasyLoading.show(
              status: translate('loader.loading'),
              maskType: EasyLoadingMaskType.black);
        });
        final status = await provider.getCheckInStatus();
        if (status) {
          final response = await provider.checkOutAttendance();
          isEnabled = true;
          if (!mounted) {
            return;
          }
          if (response.statusCode == 401) {
            Get.offAll(LoginScreen());
            return;
          }
          setState(() {
            EasyLoading.dismiss(animation: true);
            isLoading = false;
            showDialog(
              context: context,
              builder: (context) {
                return Dialog(
                  child: CustomAlertDialog(response.message),
                );
              },
            );
          });
        }
      } catch (e) {
        if (kDebugMode) debugPrint(e.toString());
        final message = e.toString();
        final extra =
            await provider.buildWorkspaceDistanceInfoIfNeeded(message);
        setState(() {
          EasyLoading.dismiss(animation: true);
          isLoading = false;
          showDialog(
            context: context,
            builder: (context) {
              return Dialog(
                child: CustomAlertDialog(
                    extra == null ? message : '$message\n\n$extra'),
              );
            },
          );
        });
      }
    } else {
      showToast(translate('alerts.please_login_first'));
    }
  }

  Future<String> loadDashboard({bool force = false}) async {
    if (_dashboardRefreshInFlight) return 'loaded';
    final now = DateTime.now();
    if (!force &&
        _lastDashboardRefreshAt != null &&
        now.difference(_lastDashboardRefreshAt!) <
            const Duration(seconds: 20)) {
      return 'loaded';
    }

    _dashboardRefreshInFlight = true;
    try {
      final dashboardResponse =
          await Provider.of<DashboardProvider>(context, listen: false)
              .getDashboard();
      if (!mounted) return 'loaded';
      _lastDashboardRefreshAt = DateTime.now();
      if (!_dashboardLoadedOnce || _dashboardLoadFailed) {
        setState(() {
          _dashboardLoadedOnce = true;
          _dashboardLoadFailed = false;
        });
      }

      if (force && mounted) {
        unawaited(() async {
          try {
            final appearance = await AppAppearanceApi().fetch();
            if (mounted) {
              await context.read<ThemeProvider>().applyServerAppearance(appearance);
            }
          } catch (_) {}
        }());
        unawaited(() async {
          try {
            final banner = await BannerSlideshowApi().fetch();
            await Preferences().saveHomeSlideshow(banner);
          } catch (_) {}
        }());
      }

      final user = dashboardResponse.data.user;

      Provider.of<PrefProvider>(context, listen: false).saveBasicUser(User(
          id: user.id,
          name: user.name,
          email: user.email,
          username: user.username,
          avatar: user.avatar,
          workspace_type: user.workspace_type));

      Provider.of<PrefProvider>(context, listen: false)
          .saveEngDateEnabled(dashboardResponse.data.dateInAd);

      if (!Provider.of<DashboardProvider>(context, listen: false)
          .isBirthdayWished) {
        await showBirthdayWish();
      }

      if (dashboardResponse.data.appVersionInfo != null) {
        await _checkAppVersion(dashboardResponse.data.appVersionInfo);
      }
      if (mounted &&
          !(dashboardResponse.data.appVersionInfo?.isForceUpdate ?? false)) {
        await FlashViewPresenter.showPending(context);
      }
      return 'loaded';
    } catch (_) {
      if (mounted && !_dashboardLoadFailed) {
        setState(() => _dashboardLoadFailed = true);
      }
      return 'loaded';
    } finally {
      _dashboardRefreshInFlight = false;
    }
  }

  Future<void> _checkAppVersion(AppVersionInfo? versionInfo) async {
    if (versionInfo == null || !versionInfo.versionCheckEnabled || !mounted)
      return;

    final details = await AppDeviceInfo.getDetails();
    final currentVersion = details.appVersion;
    final latestVersion = versionInfo.latestVersion;

    final shouldShow = versionInfo.showAlert ||
        AppDeviceInfo.isVersionOlder(currentVersion, latestVersion) ||
        AppDeviceInfo.isVersionOlder(currentVersion, versionInfo.minVersion);

    if (shouldShow) {
      if (!mounted) return;
      await showAppUpdateDialog(
        automatic: true,
        context: context,
        currentVersion: currentVersion,
        latestVersion:
            latestVersion.isNotEmpty ? latestVersion : currentVersion,
        downloadUrl: versionInfo.downloadUrl,
        releaseNotes: versionInfo.releaseNotes,
        alertTitle: versionInfo.alertTitle,
        isForceUpdate: versionInfo.isForceUpdate ||
            AppDeviceInfo.isVersionOlder(
                currentVersion, versionInfo.minVersion),
      );
    }
  }

  Future<void> showBirthdayWish() async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: GestureDetector(
            onTap: () {
              Navigator.pop(context);
            },
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Lottie.asset('assets/raw/hbd.json'),
                  Lottie.asset('assets/raw/hbd_text.json'),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final showAttendance = context.select<DashboardProvider, bool>(
        (provider) => provider.features['attendance'] == '1' &&
            provider.isMobileMenuAt('attendance', 'home_quick'));
    final enterprise = EnterpriseTheme.of(context);
    final profileVisible = enterprise.layout.shows(LayoutItem.profile);
    final showMenuInset = enterprise.layout.showMenuButton &&
        !profileVisible &&
        MediaQuery.sizeOf(context).width < 720;
    final royal = enterprise.isRoyalBlueGold;
    final sections = <LayoutItem, Widget>{
      LayoutItem.profile: RepaintBoundary(
        child: HeaderProfile(
            showMenuButton: enterprise.layout.showMenuButton,
            royalOnline: context.select<DashboardProvider, bool>(
                (value) => value.employeeOnline)),
      ),
      LayoutItem.quickServices: OverviewDashboard(controller),
      if (showAttendance) ...{
        LayoutItem.weeklyReport: WeeklyReportChart(),
        LayoutItem.team: MyTeam(),
      },
    };
    return Stack(
      children: [
        Positioned.fill(
          child: PremiumBackground(
            imageBackground: enterprise.mode == AppThemeMode.light
                ? 'assets/images/home_bg_bright.svg'
                : null,
            child: const SizedBox.expand(),
          ),
        ),
        HomeSurfaceStyle(
          clean: enterprise.mode == AppThemeMode.light,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: FocusDetector(
              onFocusGained: () {
                if (_dashboardLoadedOnce) {
                  unawaited(loadDashboard());
                }
              },
              child: RefreshIndicator(
                triggerMode: RefreshIndicatorTriggerMode.onEdge,
                color: enterprise.accent,
                backgroundColor: enterprise.cardBackground,
                edgeOffset: 50,
                onRefresh: () {
                  return loadDashboard(force: true);
                },
                child: SafeArea(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.only(
                      top: showMenuInset ? 54 : 0,
                      bottom: enterprise.isRoyalDay ? 44 : 0,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: showAttendance || royal
                            ? RepaintBoundary(
                                child: CheckAttendance(
                                  controller: controller,
                                  otherSections: sections,
                                  dashboardLoading: !_dashboardLoadedOnce &&
                                      !_dashboardLoadFailed,
                                  dashboardError: _dashboardLoadFailed,
                                  onRetryDashboard: () =>
                                      loadDashboard(force: true),
                                ),
                              )
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (final item in enterprise.layout
                                      .visible(LayoutArea.home))
                                    if (sections[item]
                                        case final Widget section)
                                      KeyedSubtree(
                                        key: ValueKey(item),
                                        child: section,
                                      ),
                                  const SizedBox(height: 6),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
