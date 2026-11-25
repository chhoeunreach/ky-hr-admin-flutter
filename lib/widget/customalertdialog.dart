import 'package:cnattendance/widget/buttonborder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

class CustomAlertDialog extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final bool isWarning;
  final double? distanceMeters;
  final double? allowedRadiusMeters;

  CustomAlertDialog(
    this.title, {
    this.actionLabel,
    this.isWarning = false,
    this.distanceMeters,
    this.allowedRadiusMeters,
  });

  @override
  Widget build(BuildContext context) {
    String closeText = 'បិទ';
    try {
      closeText = translate('common.close');
    } catch (_) {
      closeText = 'បិទ';
    }
    final message = title.toString().toLowerCase().contains("null")
        ? "សូមបើកបិទរ៉ោតទ័រឡើងវិញ ហើយព្យាយាមម្តងទៀត។"
        : title;
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          isWarning
              ? Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.location_off_rounded,
                      color: Colors.red, size: 56),
                )
              : Image.asset(
                  "assets/icons/dialog_icon.png",
                  width: 80,
                  height: 80,
                ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: isWarning ? FontWeight.w600 : FontWeight.normal,
              color: isWarning ? Colors.red.shade900 : AppColors.black,
              height: 1.4,
            ),
          ),
          if (distanceMeters != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text('ចម្ងាយជាក់ស្ដែង',
                          style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text('${distanceMeters!.toStringAsFixed(0)} ម៉ែត្រ',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.red)),
                    ],
                  ),
                  const SizedBox(height: 20, child: VerticalDivider()),
                  Column(
                    children: [
                      const Text('កម្រិតកំណត់',
                          style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text(
                          '${(allowedRadiusMeters ?? 100).toStringAsFixed(0)} ម៉ែត្រ',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green)),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (actionLabel != null) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                  style: TextButton.styleFrom(
                      backgroundColor: isWarning
                          ? Colors.red.shade700
                          : AppColors.customFF036EB7,
                      shape: ButtonBorder()),
                  onPressed: () {
                    Navigator.pop(context, true);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(actionLabel!,
                        style: const TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.bold)),
                  )),
            ),
            const SizedBox(height: 10),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
                style: TextButton.styleFrom(
                    backgroundColor: isWarning
                        ? Colors.grey.shade200
                        : AppColors.customFF036EB7,
                    shape: ButtonBorder()),
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(closeText,
                      style: TextStyle(
                          color:
                              isWarning ? Colors.black87 : AppColors.white)),
                )),
          )
        ],
      ),
    );
  }
}
