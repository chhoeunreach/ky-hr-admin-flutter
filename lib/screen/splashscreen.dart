import 'dart:io';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/services/device_clock_monitor.dart';
import 'package:cnattendance/services/device_clock_service.dart';
import 'package:cnattendance/screen/auth/login_screen.dart';
import 'package:cnattendance/screen/dashboard/dashboard_screen.dart';
import 'package:cnattendance/core/ky_security/ky_security_manager.dart';
import 'package:cnattendance/core/ky_security/ky_optional_update_prompt.dart';
import 'package:cnattendance/core/ky_security/security_gate_screen.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:cnattendance/widget/radialDecoration.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

class SplashScreen extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => SplashState();
}

class SplashState extends State<SplashScreen> with WidgetsBindingObserver {
  static const _clockSettingsChannel =
      MethodChannel('cnattendance/device_clock');
  bool _checkingClock = true;
  bool _waitingForDateSettings = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _checkClockAndContinue());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _waitingForDateSettings) {
      _waitingForDateSettings = false;
      if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop(true);
      }
    }
  }

  Future<void> _checkClockAndContinue() async {
    // Quick server check (short timeout); afterwards the monitor keeps
    // re-checking in the background and only a mismatch ever blocks the user.
    final monitor = DeviceClockMonitor.instance..start();
    if (mounted) setState(() => _checkingClock = true);
    final current = await monitor.refresh(force: true);
    if (!mounted) return;

    if (current == null || current.status != DeviceClockStatus.incorrect) {
      // Correct or unverifiable (offline) — never hold the app hostage.
      await _continueToApp();
      return;
    }

    setState(() => _checkingClock = false);
    DeviceClockCheck mismatch = current;
    while (mounted) {
      final result = mismatch;
      final retry = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => PopScope(
          canPop: false,
          child: AlertDialog(
            icon: const Icon(Icons.schedule_rounded),
            title: Text(translate('device_clock.mismatch_title')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(translate('device_clock.mismatch_message')),
                if (result.deviceTime != null && result.serverTime != null) ...[
                  const SizedBox(height: 14),
                  Text(
                      '${translate('device_clock.device_time')}: ${result.deviceTime!.toLocal()}'),
                  Text(
                      '${translate('device_clock.server_time_utc')}: ${result.serverTime!.toUtc()}'),
                  if (result.offset != null)
                    Text(_clockDifferenceText(result.offset!)),
                  if (Platform.isIOS) ...[
                    const SizedBox(height: 12),
                    Text(translate('device_clock.ios_help')),
                  ],
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(translate('device_clock.check_again')),
              ),
              if (Platform.isAndroid)
                FilledButton.tonalIcon(
                  onPressed: () async {
                    try {
                      final opened =
                          await _clockSettingsChannel.invokeMethod<bool>(
                                'openDateTimeSettings',
                              ) ??
                              false;
                      if (opened) _waitingForDateSettings = true;
                    } on PlatformException {
                      // Keep the check dialog open; the retry action remains available.
                    }
                  },
                  icon: const Icon(Icons.settings_rounded),
                  label: Text(translate('device_clock.open_settings')),
                ),
            ],
          ),
        ),
      );
      if (retry != true) return;

      setState(() => _checkingClock = true);
      final recheck = await monitor.refresh(force: true);
      if (!mounted) return;
      setState(() => _checkingClock = false);
      if (recheck == null || recheck.status != DeviceClockStatus.incorrect) {
        await _continueToApp();
        return;
      }
      mismatch = recheck;
    }
  }

  String _clockDifferenceText(Duration offset) {
    final absoluteSeconds = offset.inSeconds.abs();
    final minutes = absoluteSeconds ~/ 60;
    final seconds = absoluteSeconds % 60;
    final direction = offset.isNegative
        ? 'device_clock.device_ahead'
        : 'device_clock.device_behind';
    return '${translate(direction)} ${translate('device_clock.minutes_seconds', args: {
          'minutes': minutes,
          'seconds': seconds,
        })}';
  }

  Future<void> _continueToApp() async {
    final preferences = Preferences();
    if (await preferences.getHardReset()) {
      await preferences.clearPrefs();
      await preferences.saveHardReset(false);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, LoginScreen.routeName);
      return;
    }
    final token = await preferences.getToken();
    if (token.isEmpty) {
      if (mounted)
        Navigator.pushReplacementNamed(context, LoginScreen.routeName);
      return;
    }

    Map<String, dynamic>? securityState;
    if (Platform.isAndroid) {
      Map<String, dynamic> state;
      try {
        state = await KySecurityManager.shared.initialize();
      } catch (_) {
        state = {'state': 'offlineRestricted'};
      }
      securityState = state;
      if (!mounted) return;
      if (KySecurityManager.shared.securityApplies &&
          state['state'] != 'authorized' &&
          state['state'] != 'offlineAuthorized' &&
          state['state'] != 'disabled') {
        Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
          builder: (_) => SecurityGateScreen(initialState: state),
        ));
        return;
      }
    }

    final optionalUpdate = securityState?['optional_update'];
    if (optionalUpdate is Map && mounted) {
      await KyOptionalUpdatePrompt.show(
        context,
        Map<String, dynamic>.from(optionalUpdate),
      );
    }
    if (mounted)
      Navigator.pushReplacementNamed(context, DashboardScreen.routeName);
  }

  @override
  Widget build(BuildContext context) {
    final enterprise = EnterpriseTheme.of(context);
    final onLight = !enterprise.isDark;
    return Container(
      decoration: RadialDecoration(),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              "assets/icons/logo_bnw.png",
              width: 120,
              height: 120,
              color: onLight ? enterprise.text : null,
            ),
            if (_checkingClock) ...[
              const SizedBox(height: 18),
              CircularProgressIndicator(
                  color: onLight ? enterprise.primary : AppColors.white),
              const SizedBox(height: 10),
              Text(translate('device_clock.checking'),
                  style: TextStyle(
                      color: onLight ? enterprise.text : AppColors.white)),
            ],
          ],
        ),
      ),
    );
  }
}
