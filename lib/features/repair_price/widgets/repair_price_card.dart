import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import '../models/repair_service.dart';
import '../utils/repair_price_helper.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

class RepairPriceCard extends StatelessWidget {
  final RepairService service;
  final bool canViewCost;

  const RepairPriceCard({
    super.key,
    required this.service,
    required this.canViewCost,
  });

  @override
  Widget build(BuildContext context) {
    final enterprise = EnterpriseTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            AppColors.white.withValues(alpha: enterprise.isDark ? 0.08 : 0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: enterprise.glassStroke, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.black
                .withValues(alpha: enterprise.isDark ? 0.20 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            translate('repair_screen.price_summary'),
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: enterprise.text,
            ),
          ),
          const SizedBox(height: 10),

          // Selling Price Row
          _summaryRow(
            enterprise,
            translate('repair_screen.selling_price'),
            RepairPriceHelper.currency(service.sellingPrice),
            isPrimary: true,
            primaryColor: enterprise.accent,
          ),

          if (canViewCost && service.partCost != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Divider(color: enterprise.glassStroke, height: 1),
            ),
            _summaryRow(
              enterprise,
              translate('repair_screen.part_cost'),
              RepairPriceHelper.currency(service.partCost),
            ),
            const SizedBox(height: 6),
            _summaryRow(
              enterprise,
              translate('repair_screen.service_fee'),
              RepairPriceHelper.currency(service.serviceFee),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Divider(color: enterprise.glassStroke, height: 1),
            ),
            _summaryRow(
              enterprise,
              translate('repair_screen.profit'),
              RepairPriceHelper.currency(service.profit),
              valueColor: enterprise.accent,
              isBold: true,
            ),
            const SizedBox(height: 5),
            Text(
              'Formula: Profit = Selling Price - Part Cost - Service Fee',
              style: TextStyle(
                fontSize: 9.5,
                color: enterprise.mutedText,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryRow(
    EnterpriseTheme enterprise,
    String label,
    String value, {
    bool isPrimary = false,
    Color? valueColor,
    Color? primaryColor,
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isPrimary ? 14 : 13,
            fontWeight: isPrimary ? FontWeight.w600 : FontWeight.w500,
            color: isPrimary ? enterprise.text : enterprise.mutedText,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isPrimary ? 18 : 14,
            fontWeight: isPrimary || isBold ? FontWeight.w800 : FontWeight.w600,
            color: valueColor ??
                (isPrimary
                    ? (primaryColor ?? enterprise.accent)
                    : enterprise.text),
          ),
        ),
      ],
    );
  }
}
