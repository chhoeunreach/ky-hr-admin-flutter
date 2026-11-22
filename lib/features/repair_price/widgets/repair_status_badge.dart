import 'package:flutter/material.dart';
import '../config/repair_price_config.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

class RepairStatusBadge extends StatelessWidget {
  final String status;

  const RepairStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color text;
    String label;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'available':
      case 'in_stock':
        bg = RepairPriceConfig.success.withValues(alpha: 0.1);
        text = RepairPriceConfig.success;
        label = 'Available / មានក្នុងស្តុក';
        icon = Icons.check_circle_outline_rounded;
        break;
      case 'limited':
      case 'limited_stock':
        bg = RepairPriceConfig.warning.withValues(alpha: 0.1);
        text = RepairPriceConfig.warning;
        label = 'Limited / ស្តុកមានកំណត់';
        icon = Icons.error_outline_rounded;
        break;
      case 'unavailable':
      case 'out_of_stock':
        bg = RepairPriceConfig.error.withValues(alpha: 0.1);
        text = RepairPriceConfig.error;
        label = 'Out of Stock / អស់ស្តុក';
        icon = Icons.cancel_outlined;
        break;
      default:
        bg = AppColors.grey.withValues(alpha: 0.1);
        text = RepairPriceConfig.secondaryText;
        label = status;
        icon = Icons.info_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: text),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: text,
            ),
          ),
        ],
      ),
    );
  }
}
