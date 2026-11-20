import 'dart:async';
import 'dart:io';
import 'package:cnattendance/features/pos/pages/pos_workspace_screen.dart';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/model/auth.dart';
import 'package:cnattendance/provider/attendancereportprovider.dart';
import 'package:cnattendance/provider/chatbadgecontroller.dart';
import 'package:cnattendance/provider/dashboardprovider.dart';
import 'package:cnattendance/provider/leaveprovider.dart';
import 'package:cnattendance/provider/morescreenprovider.dart';
import 'package:cnattendance/provider/payslipdetailprovider.dart';
import 'package:cnattendance/provider/payslipprovider.dart';
import 'package:cnattendance/provider/prefprovider.dart';
import 'package:cnattendance/provider/profileprovider.dart';
import 'package:cnattendance/provider/ssfprovider.dart';
import 'package:cnattendance/services/background_sync_manager.dart';
import 'package:cnattendance/services/connection_alert.dart';
import 'package:cnattendance/services/database_helper.dart';
import 'package:cnattendance/services/push_notification_service.dart';
import 'package:cnattendance/services/server_url_resolver.dart';
import 'package:cnattendance/screen/auth/login_screen.dart';
import 'package:cnattendance/screen/dashboard/dashboard_screen.dart';
import 'package:cnattendance/screen/profile/editprofilescreen.dart';
import 'package:cnattendance/screen/profile/front_side_preview_page.dart';
import 'package:cnattendance/screen/profile/id_card_screen.dart';
import 'package:cnattendance/screen/profile/payslipdetailscreen.dart';
import 'package:cnattendance/screen/profile/profilescreen.dart';
import 'package:cnattendance/screen/profile/meetingdetailscreen.dart';
import 'package:cnattendance/screen/sell_out_report_screen.dart';
import 'package:cnattendance/screen/splashscreen.dart';
import 'package:cnattendance/security/app_integrity.dart';
import 'package:cnattendance/security/integrity_blocked_screen.dart';
import 'package:cnattendance/theme/app_theme_data.dart';
import 'package:cnattendance/theme/app_theme_mode.dart';
import 'package:cnattendance/theme/theme_provider.dart';
import 'package:cnattendance/provider/notificationcontroller.dart';
import 'package:cnattendance/utils/app_badge_sync.dart';
import 'package:cnattendance/utils/chat_unread_store.dart';
import 'package:cnattendance/utils/incoming_chat_listener.dart';
import 'package:cnattendance/utils/navigationservice.dart';
import 'package:cnattendance/widget/enterprise/app_motion.dart';
import 'package:cnattendance/widget/enterprise/rose_pink_effects.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_mentions/flutter_mentions.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'package:in_app_notification/in_app_notification.dart';
import 'package:flutter_translate/flutter_translate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorWidget.builder = (details) {
    debugPrint('Widget build failed: ${details.exception}');
    return const Material(
      color: Color(0xfff5f8fd),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  color: Color(0xffc53030), size: 46),
              SizedBox(height: 12),
              Text('Unable to display this screen',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Color(0xff253858),
                      fontSize: 17,
                      fontWeight: FontWeight.w700)),
              SizedBox(height: 6),
              Text('Please go back and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xff5f6f82))),
            ],
          ),
        ),
      ),
    );
  };
  // Clone / re-sign / repackage gate — must run before Firebase, push,
  // Firestore, Workmanager, or any other service starts. On failure every
  // service stays off and only the blocked screen is shown.
  if (await AppIntegrity.isTampered()) {
    debugPrint('App integrity failed: ${AppIntegrity.lastReason}');
    await AppIntegrity.wipeSession();
    runApp(const IntegrityBlockedScreen());
    return;
  }

  // When neither the primary nor the backup server is reachable, block the UI
  // with a connection alert that keeps retrying until a server responds.
  ServerUrlResolver.onAllServersUnreachable = (primary, fallback) =>
      ConnectionAlert.show(primaryUrl: primary, fallbackUrl: fallback);
  try {
    final delegate = await LocalizationDelegate.create(
        fallbackLocale: 'km',
        supportedLocales: [
          'km',
          'en_US',
          'ar',
          'es',
          'ne',
          'fa',
          'in',
          'pt',
          'ru',
          'de',
          'tr',
          'fr'
        ]);

    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    await GetStorage.init();
    ChatUnreadStore.markStorageReady();
    final initialStorage = GetStorage();
    if (initialStorage.read("language") == null) {
      await initialStorage.write("language", "km");
    }
    // Reuse a recently verified server for a few seconds so the home screen,
    // notifications and first navigation do not each pay an extra health-check
    // round-trip. The next call after the window re-verifies, preserving
    // failover behaviour.
    ServerUrlResolver.shared.healthyCacheTtl = const Duration(seconds: 15);
    ChatBadgeController.ensureRegistered();

    if (Platform.isAndroid) {
      // Cosmetic; never block the first frame on it.
      unawaited(FlutterDisplayMode.setHighRefreshRate());
    }

    await PushNotificationService.initialize();

    runApp(LocalizedApp(delegate, MyApp()));
    Future.microtask(() => IncomingChatListener.instance.start());
    unawaited(PushNotificationService.finishStartupSetup());
    configLoading();
    // Offline-first queue recovery and the background worker are not needed to
    // paint the first frame. Run them after the UI is attached so cold start is
    // not blocked by SQLite/platform-channel work.
    unawaited(_warmUpBackgroundServices());
  } catch (error, stackTrace) {
    debugPrint('App startup failed: $error');
    debugPrintStack(stackTrace: stackTrace);
    runApp(_StartupErrorApp(error: error.toString()));
  }
}

/// Post-first-frame warm-up: recovers upload queues left behind by a previous
/// process kill and starts the background sync worker. Failures are logged so
/// they can never take down the already-running UI.
Future<void> _warmUpBackgroundServices() async {
  try {
    await DatabaseHelper.instance.resetStuckUploadingToPending();
    await DatabaseHelper.instance.resetStuckAttendanceUploadingToPending();
  } catch (error, stackTrace) {
    debugPrint('Upload queue recovery failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
  try {
    await BackgroundSyncManager.instance.initialize();
    await BackgroundSyncManager.instance.cancelAll();
  } catch (error, stackTrace) {
    debugPrint('Background sync warm-up failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

void configLoading() {
  EasyLoading.instance
    ..indicatorType = EasyLoadingIndicatorType.cubeGrid
    ..loadingStyle = EasyLoadingStyle.dark
    ..indicatorSize = 50.0
    ..radius = 0.0
    ..progressColor = Colors.blue
    ..backgroundColor = Colors.white
    ..indicatorColor = Colors.blue
    ..textColor = Colors.black
    ..maskType = EasyLoadingMaskType.none
    ..userInteractions = false
    ..dismissOnTap = false;
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    ChatBadgeController.ensureRegistered();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ChatBadgeController.ensureRegistered().refreshUnreadCount();
      if (Get.isRegistered<NotificationController>()) {
        final controller = Get.find<NotificationController>();
        controller.syncLocalNotificationState();
      } else {
        AppBadgeSync.sync();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizationDelegate = LocalizedApp.of(context).delegate;
    final storage = GetStorage();

    return OverlaySupport.global(
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (ctx) => Auth(),
          ),
          ChangeNotifierProvider(
            create: (ctx) => Preferences(),
          ),
          ChangeNotifierProvider(
            create: (ctx) => LeaveProvider(),
          ),
          ChangeNotifierProvider(
            create: (ctx) => PrefProvider(),
          ),
          ChangeNotifierProvider(
            create: (ctx) => ProfileProvider(),
          ),
          ChangeNotifierProvider(
            create: (ctx) => AttendanceReportProvider(),
          ),
          ChangeNotifierProvider(
            create: (ctx) => DashboardProvider(),
          ),
          ChangeNotifierProvider(
            create: (ctx) => MoreScreenProvider(),
          ),
          ChangeNotifierProvider(
            create: (ctx) => PaySlipProvider(),
          ),
          ChangeNotifierProvider(
            create: (ctx) => PaySlipDetailProvider(),
          ),
          ChangeNotifierProvider(
            create: (ctx) => SSFProvider(),
          ),
          ChangeNotifierProvider(
            create: (ctx) => ThemeProvider()..load(),
          ),
        ],
        child: Portal(
          child: InAppNotification(
            child: LocalizationProvider(
              state: LocalizationProvider.of(context).state,
              child: Selector<ThemeProvider, (AppThemeMode, Color?, Color?)>(
                selector: (_, settings) => (
                  settings.mode,
                  settings.layout.background,
                  settings.layout.accent,
                ),
                builder: (context, settings, child) {
                  final theme = context.read<ThemeProvider>().themeData;
                  return AnimatedTheme(
                    data: theme,
                    duration: AppThemeData.animationDuration,
                    child: GetMaterialApp(
                      navigatorKey: NavigationService.navigatorKey,
                      debugShowCheckedModeBanner: false,
                      localizationsDelegates: [
                        GlobalMaterialLocalizations.delegate,
                        GlobalWidgetsLocalizations.delegate,
                        GlobalCupertinoLocalizations.delegate,
                        localizationDelegate
                      ],
                      supportedLocales: localizationDelegate.supportedLocales,
                      locale: Locale(storage.read("language") ?? "km"),
                      theme: theme,
                      darkTheme: theme,
                      themeMode: theme.brightness == Brightness.dark
                          ? ThemeMode.dark
                          : ThemeMode.light,
                      initialRoute: '/',
                      routes: {
                        '/': (_) => SplashScreen(),
                        LoginScreen.routeName: (_) => LoginScreen(),
                        DashboardScreen.routeName: (_) => DashboardScreen(),
                        ProfileScreen.routeName: (_) => ProfileScreen(),
                        IdCardScreen.routeName: (_) => const IdCardScreen(),
                        FrontSidePreviewPage.routeName: (_) =>
                            const FrontSidePreviewPage(),
                        EditProfileScreen.routeName: (_) => EditProfileScreen(),
                        MeetingDetailScreen.routeName: (_) =>
                            MeetingDetailScreen(),
                        PaySlipDetailScreen.routeName: (_) =>
                            PaySlipDetailScreen(),
                        PosWorkspaceScreen.routeName: (_) =>
                            const PosWorkspaceScreen(),
                        SellOutReportScreen.routeName: (_) =>
                            const SellOutReportScreen(),
                      },
                      builder: EasyLoading.init(
                        builder: (context, child) => AppMotion(
                          child: RosePinkEffectsOverlay(
                            child: child ?? const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 56,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 16),
                const Text(
                  'App failed to start',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  error,
                  style: const TextStyle(color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
