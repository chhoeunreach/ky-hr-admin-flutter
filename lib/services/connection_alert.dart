import 'dart:async';

import 'package:cnattendance/core/theme/app_colors.dart';
import 'package:cnattendance/provider/dashboardprovider.dart';
import 'package:cnattendance/provider/morescreenprovider.dart';
import 'package:cnattendance/services/server_configuration.dart';
import 'package:cnattendance/services/server_status_service.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:cnattendance/utils/navigationservice.dart';
import 'package:cnattendance/widget/customqrscanner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:provider/provider.dart';

/// Shows a blocking alert when the app cannot reach its configured server.
/// The alert provides options to retry connecting to the configured server,
/// switch to the backup server (with explicit confirmation), or scan a new
/// server QR code. It also retries periodically in the background.
class ConnectionAlert {
  ConnectionAlert._();

  static bool _showing = false;

  @visibleForTesting
  static void resetForTesting() => _showing = false;

  /// Shows the alert once. Repeated triggers while it is already on screen are
  /// ignored so concurrent requests never stack multiple dialogs.
  static void show({
    required String primaryUrl,
    String? fallbackUrl,
  }) {
    if (_showing) return;
    final state = NavigationService.navigatorKey.currentState;
    final context = state?.overlay?.context ?? state?.context;
    if (context == null) return;
    _showing = true;
    unawaited(showDialog(
      context: context,
      barrierDismissible: false,
      routeSettings: const RouteSettings(name: ConnectionAlertDialog.routeName),
      builder: (_) => ConnectionAlertDialog(
        primaryUrl: primaryUrl,
        fallbackUrl: fallbackUrl,
      ),
    ).whenComplete(() => _showing = false));
  }
}

class ConnectionAlertDialog extends StatefulWidget {
  const ConnectionAlertDialog({
    Key? key,
    required this.primaryUrl,
    this.fallbackUrl,
    this.checkServer,
    this.switchServer,
    this.scanQr,
  }) : super(key: key);

  static const routeName = '/connection-alert';

  final String primaryUrl;
  final String? fallbackUrl;

  /// Connection check used by the retry button and the automatic re-check.
  /// Defaults to the real server status check; tests can inject a fake.
  final Future<ServerCheckResult> Function()? checkServer;

  /// Server switch function used when switching to backup or scanning QR.
  /// Defaults to ServerStatusService().switchServer; tests can inject a fake.
  final Future<ServerCheckResult> Function(String)? switchServer;

  /// QR scanner invoked when the user taps "Scan new QR code".
  /// Defaults to showCustomQrScanner(context); tests can inject a fake.
  final Future<String?> Function(BuildContext)? scanQr;

  @override
  State<ConnectionAlertDialog> createState() => _ConnectionAlertDialogState();
}

class _ConnectionAlertDialogState extends State<ConnectionAlertDialog> {
  Timer? _timer;
  bool _checking = false;
  String? _lastMessage;

  @override
  void initState() {
    super.initState();
    // Keep retrying in the background so the alert dismisses itself as soon
    // as the configured server becomes reachable again.
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    if (_checking || !mounted) return;
    setState(() => _checking = true);
    final result = await (widget.checkServer ??
        ServerStatusService().checkCurrentServer)();
    if (!mounted) return;
    if (result.isConnected) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _checking = false;
      _lastMessage = result.message;
    });
  }

  Future<void> _confirmAndSwitchToBackup() async {
    final fallback = widget.fallbackUrl;
    if (fallback == null || fallback.isEmpty || _checking || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.swap_horiz, color: AppColors.customFF036EB7),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                translate('connection_error.confirm_switch_title'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              translate('connection_error.confirm_switch_message'),
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                fallback,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(translate('server_status.cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.customFF036EB7,
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(
              translate('server_status.confirm'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _checking = true);
    final switcher = widget.switchServer ?? ServerStatusService().switchServer;
    final result = await switcher(fallback);
    if (!mounted) return;

    setState(() => _checking = false);

    if (result.isConnected) {
      _refreshAppData();
      showToast(translate('server_status.server_changed_successfully'));
      Navigator.of(context).pop();
    } else {
      setState(() => _lastMessage = result.message);
      showToast(result.message);
    }
  }

  Future<void> _scanAndSwitchServer() async {
    if (_checking || !mounted) return;
    final scanner = widget.scanQr ?? ((ctx) => showCustomQrScanner(ctx));
    final scannedValue = await scanner(context);
    if (scannedValue == null || scannedValue.trim().isEmpty || !mounted) return;

    late final ServerConfiguration configuration;
    try {
      configuration = ServerConfiguration.parse(scannedValue);
    } catch (_) {
      showToast(translate('alerts.invalid_qr'));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.qr_code_scanner, color: AppColors.customFF036EB7),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                translate('connection_error.confirm_switch_title'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              translate('connection_error.confirm_switch_message'),
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                configuration.primaryUrl,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(translate('server_status.cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.customFF036EB7,
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(
              translate('server_status.confirm'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _checking = true);
    final switcher = widget.switchServer ?? ServerStatusService().switchServer;
    final result = await switcher(scannedValue);
    if (!mounted) return;

    setState(() => _checking = false);

    if (result.isConnected) {
      _refreshAppData();
      showToast(translate('server_status.server_changed_successfully'));
      Navigator.of(context).pop();
    } else {
      setState(() => _lastMessage = result.message);
      showToast(result.message);
    }
  }

  void _refreshAppData() {
    try {
      context.read<DashboardProvider>().getDashboard();
    } catch (_) {}
    try {
      context.read<MoreScreenProvider>().getFeatures();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final hasFallback = widget.fallbackUrl != null &&
        widget.fallbackUrl!.trim().isNotEmpty &&
        widget.fallbackUrl != widget.primaryUrl;

    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.all(24),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 56, color: AppColors.redAccent),
                const SizedBox(height: 14),
                Text(
                  translate('connection_error.title'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  translate('connection_error.message'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: AppColors.black54),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.dns_outlined, size: 16, color: AppColors.black54),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${translate('connection_error.primary_server')}: ${widget.primaryUrl}',
                              style: const TextStyle(fontSize: 11, color: AppColors.black87),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (hasFallback) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.backup_outlined, size: 16, color: AppColors.black54),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${translate('connection_error.backup_server')}: ${widget.fallbackUrl}',
                                style: const TextStyle(fontSize: 11, color: AppColors.black87),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _lastMessage ?? translate('connection_error.reconnecting'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: AppColors.redAccent),
                ),
                const SizedBox(height: 16),
                if (_checking)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    ),
                  )
                else ...[
                  // Retry button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.customFF036EB7,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      onPressed: _check,
                      child: Text(
                        translate('connection_error.retry'),
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  // Switch to backup button
                  if (hasFallback) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade700,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        onPressed: _confirmAndSwitchToBackup,
                        icon: const Icon(Icons.swap_horiz, color: Colors.white, size: 18),
                        label: Text(
                          translate('connection_error.switch_backup'),
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                  // Scan new QR code button
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.customFF036EB7),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      onPressed: _scanAndSwitchServer,
                      icon: const Icon(Icons.qr_code_scanner, color: AppColors.customFF036EB7, size: 18),
                      label: Text(
                        translate('connection_error.scan_new_qr'),
                        style: const TextStyle(
                          color: AppColors.customFF036EB7,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
