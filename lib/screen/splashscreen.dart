import 'dart:io';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/services/device_clock_service.dart';
import 'package:cnattendance/screen/auth/login_screen.dart';
import 'package:cnattendance/screen/dashboard/dashboard_screen.dart';
import 'package:cnattendance/widget/radialDecoration.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_translate/flutter_translate.dart';

class SplashScreen extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => SplashState();
}

class SplashState extends State<SplashScreen> with WidgetsBindingObserver {
  static const _clockSettingsChannel =
      MethodChannel('cnattendance/device_clock');
  final DeviceClockService _clockService = DeviceClockService();
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
    _clockService.dispose();
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
    while (mounted) {
      if (mounted) setState(() => _checkingClock = true);
      final result = await _clockService.check();
      if (!mounted) return;
      if (result.status == DeviceClockStatus.correct) {
        await _continueToApp();
        return;
      }

      setState(() => _checkingClock = false);
      final retry = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => PopScope(
          canPop: false,
          child: AlertDialog(
            icon: Icon(
              result.status == DeviceClockStatus.incorrect
                  ? Icons.schedule_rounded
                  : Icons.cloud_off_rounded,
            ),
            title: Text(translate(result.status == DeviceClockStatus.incorrect
                ? 'device_clock.mismatch_title'
                : 'device_clock.unavailable_title')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(translate(result.status == DeviceClockStatus.incorrect
                    ? 'device_clock.mismatch_message'
                    : 'device_clock.unavailable_message')),
                if (result.status == DeviceClockStatus.incorrect &&
                    result.deviceTime != null &&
                    result.serverTime != null) ...[
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
              if (Platform.isAndroid &&
                  result.status == DeviceClockStatus.incorrect)
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
    final routeName = await preferences.getToken() == ''
        ? LoginScreen.routeName
        : DashboardScreen.routeName;
    if (mounted) Navigator.pushReplacementNamed(context, routeName);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: RadialDecoration(),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset("assets/icons/logo_bnw.png", width: 120, height: 120),
            if (_checkingClock) ...[
              const SizedBox(height: 18),
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 10),
              Text(translate('device_clock.checking'),
                  style: const TextStyle(color: Colors.white)),
            ],
          ],
        ),
      ),
    );
  }
}
