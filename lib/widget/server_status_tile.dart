import 'package:cnattendance/provider/dashboardprovider.dart';
import 'package:cnattendance/provider/morescreenprovider.dart';
import 'package:cnattendance/services/server_status_service.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:cnattendance/widget/customqrscanner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:provider/provider.dart';

class ServerStatusTile extends StatefulWidget {
  const ServerStatusTile({super.key});

  @override
  State<ServerStatusTile> createState() => _ServerStatusTileState();
}

class _ServerStatusTileState extends State<ServerStatusTile> {
  final ServerStatusService _service = ServerStatusService();
  ServerCheckResult? _lastResult;
  bool _checking = false;

  Future<void> _checkCurrentServer() async {
    setState(() => _checking = true);
    final result = await _service.checkCurrentServer();
    if (!mounted) return;
    setState(() {
      _lastResult = result;
      _checking = false;
    });
  }

  Future<void> _scanAndSwitch() async {
    final scannedValue = await showCustomQrScanner(context);
    if (scannedValue == null || scannedValue.trim().isEmpty) {
      return;
    }

    EasyLoading.show(
      status: translate('server_status.checking_server'),
      maskType: EasyLoadingMaskType.black,
    );

    final result = await _service.switchServer(scannedValue);
    if (!mounted) return;

    EasyLoading.dismiss(animation: true);
    setState(() => _lastResult = result);

    if (result.isConnected) {
      try {
        await context.read<DashboardProvider>().getDashboard();
        await context.read<MoreScreenProvider>().getFeatures();
      } catch (e) {
        debugPrint('Server changed, but dashboard refresh failed: $e');
      }
      if (!mounted) return;
      showToast(translate('server_status.server_changed_successfully'));
    } else {
      showToast(result.message);
    }
  }

  Future<void> _showStatusDialog() async {
    final currentUrl = await _service.currentServerUrl();
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final enterprise = EnterpriseTheme.of(dialogContext);
        final result = _lastResult;
        final isConnected = result?.isConnected == true;
        final statusColor = result == null
            ? enterprise.mutedText
            : isConnected
                ? Colors.greenAccent
                : Colors.orangeAccent;

        return AlertDialog(
          backgroundColor: enterprise.surface,
          title: Row(
            children: [
              Icon(Icons.dns_rounded, color: statusColor, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  translate('server_status.title'),
                  style: TextStyle(color: enterprise.text, fontSize: 16),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                translate('server_status.current_server'),
                style: TextStyle(
                  color: enterprise.mutedText,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              SelectableText(
                result?.url ?? currentUrl,
                style: TextStyle(color: enterprise.text, fontSize: 13),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(
                    result == null
                        ? Icons.help_outline_rounded
                        : isConnected
                            ? Icons.check_circle_rounded
                            : Icons.error_outline_rounded,
                    color: statusColor,
                    size: 18,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      _checking
                          ? translate('server_status.checking')
                          : result?.message ??
                              translate('server_status.tap_check'),
                      style: TextStyle(color: enterprise.text, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(translate('server_status.close')),
            ),
            TextButton.icon(
              onPressed: _checking
                  ? null
                  : () async {
                      await _checkCurrentServer();
                      if (mounted) {
                        Navigator.of(dialogContext).pop();
                        _showStatusDialog();
                      }
                    },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(translate('server_status.check')),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _scanAndSwitch();
              },
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
              label: Text(translate('server_status.scan')),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final enterprise = EnterpriseTheme.of(context);
    final result = _lastResult;
    final isConnected = result?.isConnected == true;
    final iconColor = result == null
        ? Colors.white
        : isConnected
            ? Colors.greenAccent
            : Colors.orangeAccent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _showStatusDialog,
        child: EnterpriseGlass(
          radius: 14,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          glowOpacity: 0.07,
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [enterprise.primary, enterprise.accent],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.24),
                  ),
                ),
                child: Icon(Icons.dns_rounded, color: iconColor, size: 18),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      translate('server_status.title'),
                      style: TextStyle(
                        color: enterprise.text,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (result != null)
                      Text(
                        result.isConnected
                            ? translate('server_status.connected')
                            : result.message,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: enterprise.mutedText,
                          fontSize: 11.5,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: enterprise.mutedText, size: 19),
            ],
          ),
        ),
      ),
    );
  }
}
