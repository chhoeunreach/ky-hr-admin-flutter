import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/repair_device.dart';

class RepairDeviceCard extends StatelessWidget {
  final RepairDevice device;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const RepairDeviceCard({
    super.key,
    required this.device,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final enterprise = EnterpriseTheme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: enterprise.isDark ? 0.08 : 0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: enterprise.glassStroke, width: 1),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(alpha: enterprise.isDark ? 0.20 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Tappable main card area (Icon + Details)
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.horizontal(
                  left: const Radius.circular(14),
                  right: (onEdit == null && onDelete == null)
                      ? const Radius.circular(14)
                      : Radius.zero,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      // Device Icon / Image
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: enterprise.glassStroke, width: 0.8),
                        ),
                        child: device.image.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: CachedNetworkImage(
                                  imageUrl: device.image,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) =>
                                      _defaultIcon(device, enterprise),
                                ),
                              )
                            : _defaultIcon(device, enterprise),
                      ),
                      const SizedBox(width: 12),

                      // Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              device.name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: enterprise.text,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                if (device.brand != null) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: enterprise.primary
                                          .withValues(alpha: 0.22),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                          color: enterprise.accent
                                              .withValues(alpha: 0.4)),
                                    ),
                                    child: Text(
                                      device.brand!.name,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: enterprise.accent,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                if (device.modelNumber.isNotEmpty)
                                  Text(
                                    device.modelNumber,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: enterprise.mutedText,
                                    ),
                                  ),
                              ],
                            ),
                            if (device.series != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                device.series!.name,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: enterprise.mutedText,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),

                      if (onEdit == null && onDelete == null)
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 13,
                          color: enterprise.mutedText.withValues(alpha: 0.6),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Actions Menu ("More" 3-dots button) - completely separate from card tap
          if (onEdit != null || onDelete != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert_rounded,
                  size: 20,
                  color: enterprise.mutedText,
                ),
                tooltip: 'More',
                color: enterprise.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (val) {
                  if (val == 'edit') onEdit?.call();
                  if (val == 'delete') onDelete?.call();
                },
                itemBuilder: (_) => [
                  if (onEdit != null)
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_rounded,
                              size: 16, color: enterprise.text),
                          const SizedBox(width: 8),
                          Text(
                            'កែសម្រួល / Edit',
                            style: TextStyle(
                                fontSize: 12.5, color: enterprise.text),
                          ),
                        ],
                      ),
                    ),
                  if (onDelete != null)
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded,
                              size: 16, color: Colors.redAccent),
                          SizedBox(width: 8),
                          Text(
                            'លុប / Delete',
                            style: TextStyle(
                                fontSize: 12.5, color: Colors.redAccent),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _defaultIcon(RepairDevice device, EnterpriseTheme enterprise) {
    final typeName = device.deviceType?.slug.toLowerCase() ?? '';
    IconData icon;
    if (typeName.contains('tablet') || typeName.contains('ipad')) {
      icon = Icons.tablet_mac_rounded;
    } else if (typeName.contains('laptop') || typeName.contains('macbook')) {
      icon = Icons.laptop_mac_rounded;
    } else if (typeName.contains('desktop')) {
      icon = Icons.desktop_windows_rounded;
    } else {
      icon = Icons.smartphone_rounded;
    }

    return Icon(
      icon,
      size: 24,
      color: enterprise.accent,
    );
  }
}
