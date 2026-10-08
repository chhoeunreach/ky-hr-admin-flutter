import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import '../models/repair_service.dart';
import '../utils/repair_price_helper.dart';
import 'repair_status_badge.dart';

class RepairServiceCard extends StatelessWidget {
  final RepairService service;
  final bool canViewCost;
  final bool canManagePrices;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onEditPrice;

  const RepairServiceCard({
    super.key,
    required this.service,
    required this.canViewCost,
    this.canManagePrices = false,
    this.isSelected = false,
    required this.onTap,
    this.onEditPrice,
  });

  @override
  Widget build(BuildContext context) {
    final enterprise = EnterpriseTheme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: enterprise.isDark ? 0.08 : 0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? enterprise.primary : enterprise.glassStroke,
          width: isSelected ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? enterprise.primary.withValues(alpha: 0.2)
                : Colors.black
                    .withValues(alpha: enterprise.isDark ? 0.20 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Title and Price
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (service.nameKh.isNotEmpty) ...[
                            Text(
                              service.nameKh,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: enterprise.text,
                              ),
                            ),
                            const SizedBox(height: 2),
                          ],
                          Text(
                            service.name,
                            style: TextStyle(
                              fontSize: service.nameKh.isNotEmpty ? 12.5 : 14,
                              fontWeight: service.nameKh.isNotEmpty
                                  ? FontWeight.w500
                                  : FontWeight.w600,
                              color: service.nameKh.isNotEmpty
                                  ? enterprise.mutedText
                                  : enterprise.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          RepairPriceHelper.currency(service.sellingPrice),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: enterprise.accent,
                          ),
                        ),
                        if (canManagePrices && onEditPrice != null) ...[
                          const SizedBox(height: 3),
                          InkWell(
                            onTap: onEditPrice,
                            borderRadius: BorderRadius.circular(5),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color:
                                    enterprise.primary.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                    color: enterprise.accent
                                        .withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.edit_note_rounded,
                                      size: 13, color: enterprise.accent),
                                  const SizedBox(width: 3),
                                  Text(
                                    translate('repair_screen.edit_price'),
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: enterprise.accent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Middle row: Part type & Availability
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (service.partType.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                              color: enterprise.glassStroke, width: 0.8),
                        ),
                        child: Text(
                          service.partType,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: enterprise.text,
                          ),
                        ),
                      ),
                    RepairStatusBadge(status: service.availabilityStatus),
                  ],
                ),

                const SizedBox(height: 8),

                // Warranty & Repair Time
                Row(
                  children: [
                    Icon(Icons.verified_outlined,
                        size: 13, color: enterprise.mutedText),
                    const SizedBox(width: 4),
                    Text(
                      '${translate('repair_screen.warranty')}: ${service.warrantyLabel}',
                      style: TextStyle(
                          fontSize: 11.5, color: enterprise.mutedText),
                    ),
                    const SizedBox(width: 14),
                    Icon(Icons.timer_outlined,
                        size: 13, color: enterprise.mutedText),
                    const SizedBox(width: 4),
                    Text(
                      '${translate('repair_screen.repair_time')}: ${service.timeLabel}',
                      style: TextStyle(
                          fontSize: 11.5, color: enterprise.mutedText),
                    ),
                  ],
                ),

                // Protected Cost & Profit Section (visible only if canViewCost is true)
                if (canViewCost && service.partCost != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: enterprise.glassStroke, width: 0.8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _costItem(enterprise, 'Part Cost',
                            RepairPriceHelper.currency(service.partCost)),
                        Container(
                            width: 1,
                            height: 18,
                            color: enterprise.glassStroke),
                        _costItem(enterprise, 'Service Fee',
                            RepairPriceHelper.currency(service.serviceFee)),
                        Container(
                            width: 1,
                            height: 18,
                            color: enterprise.glassStroke),
                        _costItem(
                          enterprise,
                          'Profit',
                          RepairPriceHelper.currency(service.profit),
                          valueColor: enterprise.accent,
                          isBold: true,
                        ),
                      ],
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

  Widget _costItem(EnterpriseTheme enterprise, String label, String value,
      {Color? valueColor, bool isBold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: enterprise.mutedText,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
            color: valueColor ?? enterprise.text,
          ),
        ),
      ],
    );
  }
}
