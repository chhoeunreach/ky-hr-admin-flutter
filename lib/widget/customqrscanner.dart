import 'package:cnattendance/widget/buttonborder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

Future<String?> showCustomQrScanner(BuildContext context) async {
  return showDialog<String>(
    context: context,
    builder: (context) => const _CustomQrScannerDialog(),
  );
}

class _CustomQrScannerDialog extends StatefulWidget {
  const _CustomQrScannerDialog();

  @override
  State<_CustomQrScannerDialog> createState() => _CustomQrScannerDialogState();
}

class _CustomQrScannerDialogState extends State<_CustomQrScannerDialog> {
  late final MobileScannerController _controller;
  bool _didScan = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      facing: CameraFacing.back,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_didScan || capture.barcodes.isEmpty) {
      return;
    }

    final value = capture.barcodes.first.rawValue;
    if (value == null || value.trim().isEmpty) {
      return;
    }

    _didScan = true;
    await _controller.stop();
    if (!mounted) return;
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      backgroundColor: colorScheme.surface,
      title: Row(
        children: [
          Expanded(
            child: Text(
              translate('attendance_messages.scan_qr_code'),
              style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
            ),
          ),
          IconButton(
            tooltip: translate('attendance_messages.switch_camera'),
            onPressed: () => _controller.switchCamera(),
            icon: Icon(
              Icons.cameraswitch_rounded,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 220,
        height: 220,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, null); // Return text
          },
          style: ElevatedButton.styleFrom(
            shape: ButtonBorder(),
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
          ),
          child: Container(
            width: double.infinity,
            child: Center(
              child: Text(translate('attendance_messages.cancel')),
            ),
          ),
        ),
      ],
    );
  }
}
