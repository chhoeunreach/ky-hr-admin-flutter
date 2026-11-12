import 'package:cnattendance/features/community/flash_view_presenter.dart';
import 'dart:async';
import 'dart:io';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/data/source/network/model/login/User.dart';
import 'package:cnattendance/provider/dashboardprovider.dart';
import 'package:cnattendance/provider/notificationcontroller.dart';
import 'package:cnattendance/provider/prefprovider.dart';
import 'package:cnattendance/screen/auth/login_screen.dart';
import 'package:cnattendance/screen/general/generalscreen.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:cnattendance/utils/locationstatus.dart';
import 'package:cnattendance/utils/notification_history.dart';
import 'package:cnattendance/widget/customalertdialog.dart';
import 'package:cnattendance/widget/homescreen/checkattendance.dart';
import 'package:cnattendance/widget/homescreen/myteam.dart';
import 'package:cnattendance/widget/homescreen/overviewdashboard.dart';
import 'package:cnattendance/widget/homescreen/recentAward.dart';
import 'package:cnattendance/widget/homescreen/recentEvent.dart';
import 'package:cnattendance/widget/homescreen/recentTraining.dart';
import 'package:cnattendance/widget/homescreen/upcomingholiday.dart';
import 'package:cnattendance/widget/homescreen/weeklyreportchart.dart';
import 'package:cnattendance/widget/premium_background.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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
import 'package:quick_actions/quick_actions.dart';

const String _iosTestFlightUpdateUrl =
    'https://testflight.apple.com/join/hPG4ZA38';

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
  bool _updateDialogShown = false;
  DateTime? _lastDashboardRefreshAt;

  PersistentTabController controller;

  HomeScreenState(this.controller);

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback(
      (timeStamp) async {
        checkNotificationState();

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

  String _initialMessageTitle(RemoteMessage message) {
    return message.notification?.title ??
        message.data["notification_title"] ??
        message.data["sender_name"] ??
        message.data["title"] ??
        message.data["subject"] ??
        "Notification";
  }

  String _initialMessageBody(RemoteMessage message) {
    return message.notification?.body ??
        message.data["message"] ??
        message.data["body"] ??
        message.data["description"] ??
        message.data["content"] ??
        "";
  }

  void checkNotificationState() {
    FirebaseMessaging.instance.getInitialMessage().then((message) async {
      print("FirebaseMessaging.getInitialMessage $message");
      if (message == null) {
        return;
      }
      final localKey = await NotificationHistory.saveRemoteMessage(
        message,
        title: _initialMessageTitle(message),
        body: _initialMessageBody(message),
      );
      if (localKey != null && localKey.isNotEmpty) {
        if (Get.isRegistered<NotificationController>()) {
          await Get.find<NotificationController>().markLocalNotificationAsRead(
            localKey,
          );
        } else {
          await NotificationHistory.markAsRead(localKey);
        }
      }

      final title = _initialMessageTitle(message);
      final body = _initialMessageBody(message);
      final isUpdate = message.data['type'] == 'app_update' ||
          message.data.containsKey('target_version') ||
          title.contains('អាប់ដេត') ||
          title.toLowerCase().contains('update') ||
          body.contains('អាប់ដេត') ||
          body.toLowerCase().contains('update');

      if (isUpdate && mounted) {
        final details = await AppDeviceInfo.getDetails();
        final targetVersion = message.data['target_version']?.toString() ?? '';
        final downloadUrl = _platformDownloadUrl(message.data);
        final forceUpdate = message.data['force_update'] == '1' ||
            message.data['force_update'] == true;

        await showAppUpdateDialog(
          context: context,
          currentVersion: details.appVersion,
          latestVersion:
              targetVersion.isNotEmpty ? targetVersion : details.appVersion,
          downloadUrl: downloadUrl,
          releaseNotes: body,
          alertTitle: title,
          isForceUpdate: forceUpdate,
        );
        return;
      }

      Get.to(GeneralScreen(), arguments: {
        "title": title,
        "message": body,
        "date": "",
        "type": message.data['type']?.toString() ?? '',
        "download_url": _platformDownloadUrl(message.data),
      });
    });
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
      print(e);
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
        print(e);
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
        print(e);
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
      _lastDashboardRefreshAt = now;
      _dashboardLoadedOnce = true;

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
      return 'loaded';
    } finally {
      _dashboardRefreshInFlight = false;
    }
  }

  Future<void> _checkAppVersion(AppVersionInfo? versionInfo) async {
    if (versionInfo == null || !mounted) return;
    if (_updateDialogShown && !versionInfo.isForceUpdate) return;

    final details = await AppDeviceInfo.getDetails();
    final currentVersion = details.appVersion;
    final latestVersion = versionInfo.latestVersion;

    final shouldShow = versionInfo.showAlert ||
        (latestVersion.isNotEmpty &&
            AppDeviceInfo.isVersionOlder(currentVersion, latestVersion));

    if (shouldShow) {
      _updateDialogShown = true;
      if (!mounted) return;
      await showAppUpdateDialog(
        context: context,
        currentVersion: currentVersion,
        latestVersion:
            latestVersion.isNotEmpty ? latestVersion : currentVersion,
        downloadUrl: versionInfo.downloadUrl,
        releaseNotes: versionInfo.releaseNotes,
        alertTitle: versionInfo.alertTitle,
        isForceUpdate: versionInfo.isForceUpdate,
      );
    }
  }

  String _platformDownloadUrl(Map<String, dynamic> data) {
    String read(List<String> keys) {
      for (final key in keys) {
        final value = data[key]?.toString().trim() ?? '';
        if (value.isNotEmpty) return value;
      }
      return '';
    }

    final platformUrl = Platform.isIOS
        ? read([
            'ios_url',
            'app_store_url',
            'apple_store_url',
            'ios_download_url',
          ])
        : read([
            'android_url',
            'play_store_url',
            'android_download_url',
          ]);

    if (platformUrl.isNotEmpty) return platformUrl;
    if (Platform.isIOS) return _iosTestFlightUpdateUrl;

    final fallbackUrl = read(['download_url', 'url']);
    return fallbackUrl.isNotEmpty ? fallbackUrl : 'https://hr.kneayerng.com';
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
    return PremiumBackground(
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
            color: Colors.white,
            backgroundColor: Colors.blueGrey,
            edgeOffset: 50,
            onRefresh: () {
              return loadDashboard(force: true);
            },
            child: SafeArea(
                child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const HeaderProfile(showServerTest: true),
                      if (context
                              .watch<DashboardProvider>()
                              .features["attendance"] ==
                          "1")
                        CheckAttendance(),
                      OverviewDashboard(controller),
                      if (context
                              .watch<DashboardProvider>()
                              .features["holiday"] ==
                          "1")
                        UpcomingHoliday(),
                      Selector<DashboardProvider, Map<String, String>>(
                        selector: (_, provider) => provider.features,
                        builder: (_, features, __) => Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (features["award"] == "1") RecentAward(),
                            if (features["event"] == "1") RecentEvent(),
                            if (features["training"] == "1") RecentTraining(),
                          ],
                        ),
                      ),
                      if (context
                              .watch<DashboardProvider>()
                              .features["attendance"] ==
                          "1")
                        WeeklyReportChart(),
                      if (context
                              .watch<DashboardProvider>()
                              .features["team-sheet"] ==
                          "1")
                        MyTeam(),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            )),
          ),
        ),
      ),
    );
  }
}
