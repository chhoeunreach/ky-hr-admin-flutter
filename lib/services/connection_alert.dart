import 'dart:async';

import 'package:cnattendance/services/server_status_service.dart';
import 'package:cnattendance/utils/navigationservice.dart';
import 'package:cnattendance/widget/buttonborder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:hexcolor/hexcolor.dart';

/// Shows a blocking alert when the app cannot reach its primary server or the
/// backup server. The alert keeps re-checking the connection and only closes
/// once a server responds, so the user is prompted to connect until the
/// connection error clears.
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
    final context =
        state?.overlay?.context ?? state?.context;
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
  }) : super(key: key);

  static const routeName = '/connection-alert';

  final String primaryUrl;
  final String? fallbackUrl;

  /// Connection check used by the retry button and the automatic re-check.
  /// Defaults to the real server status check; tests can inject a fake.
  final Future<ServerCheckResult> Function()? checkServer;

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
    // as the primary or the backup server becomes reachable again.
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
    final result =
        await (widget.checkServer ?? ServerStatusService().checkCurrentServer)();
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.all(24),
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 60, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(
                translate('connection_error.title'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                translate('connection_error.message'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 12),
              Text(
                '${translate('connection_error.primary_server')}: ${widget.primaryUrl}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.black45),
              ),
              if (widget.fallbackUrl != null)
                Text(
                  '${translate('connection_error.backup_server')}: ${widget.fallbackUrl}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.black45),
                ),
              const SizedBox(height: 8),
              Text(
                _lastMessage ??
                    translate('connection_error.reconnecting'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.redAccent),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: _checking
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 15),
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                        ),
                      )
                    : ElevatedButton(
                        style: TextButton.styleFrom(
                          backgroundColor: HexColor("#036eb7"),
                          shape: ButtonBorder(),
                        ),
                        onPressed: _check,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          child: Text(
                            translate('connection_error.retry'),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
