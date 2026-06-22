import 'package:cnattendance/widget/buttonborder.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

Future<String?> showCustomQrScanner(BuildContext context) async {
  return showDialog<String>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      final colorScheme = theme.colorScheme;

      return AlertDialog(
        backgroundColor: colorScheme.surface,
        title: Text(
          'Scan QR Code',
          style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
        ),
        content: SizedBox(
          width: 200,
          height: 200,
          child: MobileScanner(
            onDetect: (barcodes) {
              Navigator.pop(context, barcodes.barcodes.first.rawValue ?? null);
            },
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
              child: Center(child: Text('Cancel')),
            ),
          ),
        ],
      );
    },
  );
}
