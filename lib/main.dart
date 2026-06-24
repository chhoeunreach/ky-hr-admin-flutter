import 'dart:async';
import 'dart:io';

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
import 'package:cnattendance/services/database_helper.dart';
import 'package:cnattendance/services/push_notification_service.dart';
import 'package:cnattendance/screen/auth/login_screen.dart';
import 'package:cnattendance/screen/dashboard/dashboard_screen.dart';
import 'package:cnattendance/screen/profile/editprofilescreen.dart';
import 'package:cnattendance/screen/profile/payslipdetailscreen.dart';
import 'package:cnattendance/screen/profile/profilescreen.dart';
import 'package:cnattendance/screen/profile/meetingdetailscreen.dart';
import 'package:cnattendance/screen/sell_out_report_screen.dart';
import 'package:cnattendance/screen/splashscreen.dart';
import 'package:cnattendance/theme/app_theme_data.dart';
import 'package:cnattendance/theme/app_theme_mode.dart';
import 'package:cnattendance/theme/theme_provider.dart';
import 'package:cnattendance/provider/notificationcontroller.dart';
import 'package:cnattendance/utils/app_badge_sync.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:cnattendance/utils/incoming_chat_listener.dart';
import 'package:cnattendance/utils/navigationservice.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

@pragma('vm:entry-point')
Future<void> _messageHandler(RemoteMessage message) async {
  await PushNotificationService.handleBackgroundMessage(message);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    var delegate = await LocalizationDelegate.create(
        fallbackLocale: 'en_US',
        supportedLocales: [
          'en_US',
          'ar',
          'es',
          'ne',
          'fa',
          'in',
          'km',
          'pt',
          'ru',
          'de',
          'tr',
          'fr'
        ]);

    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    await GetStorage.init();
    ChatBadgeController.ensureRegistered();

    if (Platform.isAndroid) {
      await FlutterDisplayMode.setHighRefreshRate();
    }

    await PushNotificationService.initialize();

    // Offline-first image upload queue: clear out any rows left stuck in
    // `uploading` from a previous process kill, then start the background
    // sync worker so queued images keep retrying even if the app is closed.
    await DatabaseHelper.instance.resetStuckUploadingToPending();
    await BackgroundSyncManager.instance.initialize();
    unawaited(BackgroundSyncManager.instance.schedulePeriodicUpload());

    runApp(LocalizedApp(delegate, MyApp()));
    Future.microtask(() => IncomingChatListener.instance.start());
    unawaited(PushNotificationService.finishStartupSetup());
    configLoading();
  } catch (error, stackTrace) {
    debugPrint('App startup failed: $error');
    debugPrintStack(stackTrace: stackTrace);
    runApp(_StartupErrorApp(error: error.toString()));
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
    var localizationDelegate = LocalizedApp.of(context).delegate;
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
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                // Dismiss the keyboard when tapping outside the TextField
                FocusScope.of(context).requestFocus();
              },
              child: LocalizationProvider(
                state: LocalizationProvider.of(context).state,
                child: Consumer<ThemeProvider>(
                  builder: (context, themeProvider, _) {
                    return AnimatedTheme(
                      data: themeProvider.themeData,
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
                        locale: Locale(storage.read("language") ?? "en"),
                        theme: themeProvider.themeData,
                        darkTheme: themeProvider.darkTheme,
                        themeMode: themeProvider.mode == AppThemeMode.dark
                            ? ThemeMode.dark
                            : ThemeMode.light,
                        initialRoute: '/',
                        routes: {
                          '/': (_) => SplashScreen(),
                          LoginScreen.routeName: (_) => LoginScreen(),
                          DashboardScreen.routeName: (_) => DashboardScreen(),
                          ProfileScreen.routeName: (_) => ProfileScreen(),
                          EditProfileScreen.routeName: (_) =>
                              EditProfileScreen(),
                          MeetingDetailScreen.routeName: (_) =>
                              MeetingDetailScreen(),
                          PaySlipDetailScreen.routeName: (_) =>
                              PaySlipDetailScreen(),
                          SellOutReportScreen.routeName: (_) =>
                              SellOutReportScreen(),
                        },
                        builder: EasyLoading.init(),
                      ),
                    );
                  },
                ),
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
