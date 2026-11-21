import 'package:flutter/material.dart';
import '../config/repair_price_config.dart';
import '../models/repair_device.dart';
import '../models/repair_service.dart';
import 'repair_edit_price_sheet.dart';
import 'repair_price_card.dart';
import 'repair_status_badge.dart';

class RepairDetailBottomSheet extends StatelessWidget {
  final RepairDevice device;
  final RepairService service;
  final bool canViewCost;
  final bool canManagePrices;
  final Future<void> Function(RepairService service)? onPriceUpdated;

  const RepairDetailBottomSheet({
    super.key,
    required this.device,
    required this.service,
    required this.canViewCost,
    this.canManagePrices = false,
    this.onPriceUpdated,
  });

  static Future<void> show(
    BuildContext context, {
    required RepairDevice device,
    required RepairService service,
    required bool canViewCost,
    bool canManagePrices = false,
    Future<void> Function(RepairService service)? onPriceUpdated,
  }) {
    return showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RepairDetailBottomSheet(
        device: device,
        service: service,
        canViewCost: canViewCost,
        canManagePrices: canManagePrices,
        onPriceUpdated: onPriceUpdated,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: RepairPriceConfig.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: RepairPriceConfig.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: RepairPriceConfig.primaryBlue,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        service.nameKh.isNotEmpty
                            ? service.nameKh
                            : service.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: RepairPriceConfig.mainText,
                        ),
                      ),
                      if (service.nameKh.isNotEmpty)
                        Text(
                          service.name,
                          style: const TextStyle(
                            fontSize: 13,
                            color: RepairPriceConfig.secondaryText,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: RepairPriceConfig.secondaryText),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(color: RepairPriceConfig.border, height: 1),

          // Scrollable Body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status, Part Type & Edit Button
                  Row(
                    children: [
                      RepairStatusBadge(status: service.availabilityStatus),
                      const SizedBox(width: 8),
                      if (service.partType.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: RepairPriceConfig.background,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: RepairPriceConfig.border, width: 0.8),
                          ),
                          child: Text(
                            service.partType,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: RepairPriceConfig.mainText,
                            ),
                          ),
                        ),
                      const Spacer(),
                      if (canManagePrices && onPriceUpdated != null)
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            side: const BorderSide(
                                color: RepairPriceConfig.primaryBlue),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.edit_note_rounded,
                              size: 16, color: RepairPriceConfig.primaryBlue),
                          label: const Text(
                            'Edit Price',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: RepairPriceConfig.primaryBlue),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            RepairEditPriceSheet.show(
                              context,
                              service: service,
                              onSave: onPriceUpdated!,
                            );
                          },
                        ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Description
                  if (service.description.isNotEmpty) ...[
                    const Text(
                      'Description / ការពិពណ៌នា',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: RepairPriceConfig.mainText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      service.description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: RepairPriceConfig.secondaryText,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Part Name
                  if (service.partName.isNotEmpty) ...[
                    _infoRow(
                      Icons.build_circle_outlined,
                      'Part Name / ឈ្មោះគ្រឿងបន្លាស់',
                      service.partName,
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Warranty & Repair Time
                  Row(
                    children: [
                      Expanded(
                        child: _infoBox(
                          Icons.verified_outlined,
                          'Warranty / ធានា',
                          service.warrantyLabel,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _infoBox(
                          Icons.timer_outlined,
                          'Repair Time / រយៈពេល',
                          service.timeLabel,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Price Breakdown Card
                  RepairPriceCard(
                    service: service,
                    canViewCost: canViewCost,
                  ),

                  if (service.note.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            RepairPriceConfig.warning.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: RepairPriceConfig.warning
                                .withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline,
                              size: 16, color: RepairPriceConfig.warning),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              service.note,
                              style: const TextStyle(
                                fontSize: 12,
                                color: RepairPriceConfig.mainText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: RepairPriceConfig.primaryBlue),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                    fontSize: 11, color: RepairPriceConfig.secondaryText),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: RepairPriceConfig.mainText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoBox(IconData icon, String title, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: RepairPriceConfig.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: RepairPriceConfig.border, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: RepairPriceConfig.secondaryText),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    color: RepairPriceConfig.secondaryText,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: RepairPriceConfig.mainText,
            ),
          ),
        ],
      ),
    );
  }
}
