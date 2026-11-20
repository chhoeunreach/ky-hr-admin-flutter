import 'dart:async';
import 'dart:io';

import 'package:cnattendance/services/device_clock_monitor.dart';
import 'package:cnattendance/services/device_clock_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_translate/flutter_translate.dart';

const MethodChannel _deviceClockSettingsChannel =
    MethodChannel('cnattendance/device_clock');

/// Checks the device date/time against the HR server before an attendance
/// action (e.g. tapping the scan button) is allowed to proceed.
///
/// The check itself runs in the background via [DeviceClockMonitor] — this
/// never blocks the tap waiting on the network. The action is only held back
/// when the cached result already says the clock is wrong (confirmed with a
/// quick server re-check when the cached result is stale).
///
/// Returns `true` when the action may continue:
/// - the clock matches the server, or
/// - the server could not be reached (verification unavailable — attendance
///   must still work offline), or
/// - no background result is available yet (the submit-time check in
///   `verifyAttendanceApi` still validates against the server).
///
/// Returns `false` when the clock does not match the server and the user
/// cancels instead of correcting it.
Future<bool> ensureDeviceClockAllowsAction(BuildContext context) async {
  final monitor = DeviceClockMonitor.instance;
  // Keep the cached check warm in the background; never block on it here.
  unawaited(monitor.refresh());

  final cached = monitor.latest;
  if (cached == null) return true;

  DeviceClockCheck? confirmed;
  if (cached.status == DeviceClockStatus.incorrect && !monitor.isFresh()) {
    // Stale mismatch — confirm with a quick server re-check first.
    confirmed = await monitor.refresh(force: true);
  }
  final initial = confirmed ?? cached;
  if (initial.status != DeviceClockStatus.incorrect) return true;

  DeviceClockCheck current = initial;
  while (context.mounted) {
    final result = current;
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
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(translate('device_clock.cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(translate('device_clock.check_again')),
            ),
            if (Platform.isAndroid)
              FilledButton.tonalIcon(
                onPressed: () async {
                  try {
                    await _deviceClockSettingsChannel
                        .invokeMethod<bool>('openDateTimeSettings');
                  } on PlatformException {
                    // Keep the dialog open; Check again remains available.
                  }
                },
                icon: const Icon(Icons.settings_rounded),
                label: Text(translate('device_clock.open_settings')),
              ),
          ],
        ),
      ),
    );
    if (retry != true) return false;

    current = await _runClockCheck(monitor) ?? current;
    if (current.status != DeviceClockStatus.incorrect) return true;
  }
  return false;
}

/// Quick server re-check with visible feedback (only used when the user
/// explicitly taps "Check again" — the normal path stays in the background).
Future<DeviceClockCheck?> _runClockCheck(DeviceClockMonitor monitor) async {
  EasyLoading.show(
    status: translate('device_clock.checking'),
    maskType: EasyLoadingMaskType.black,
  );
  try {
    return await monitor.checkNow();
  } finally {
    EasyLoading.dismiss(animation: true);
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
