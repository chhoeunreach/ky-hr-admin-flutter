import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import '../models/repair_brand.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

class RepairBrandFilter extends StatelessWidget {
  final List<RepairBrand> brands;
  final int? selectedBrandId;
  final ValueChanged<int?> onBrandSelected;
  final VoidCallback? onAddBrand;
  final ValueChanged<RepairBrand>? onEditBrand;

  const RepairBrandFilter({
    super.key,
    required this.brands,
    required this.selectedBrandId,
    required this.onBrandSelected,
    this.onAddBrand,
    this.onEditBrand,
  });

  @override
  Widget build(BuildContext context) {
    final enterprise = EnterpriseTheme.of(context);
    final totalItems = brands.length + 1 + (onAddBrand != null ? 1 : 0);

    return SizedBox(
      height: 30,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: totalItems,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          // Check if this is the "+ Add Brand" button at the end
          if (onAddBrand != null && index == totalItems - 1) {
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onAddBrand,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: enterprise.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: enterprise.accent.withValues(alpha: 0.5),
                      width: 0.9,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded,
                          size: 14, color: enterprise.accent),
                      const SizedBox(width: 4),
                      Text(
                        translate('repair_screen.brand'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: enterprise.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final isAll = index == 0;
          final isSelected = isAll
              ? selectedBrandId == null
              : selectedBrandId == brands[index - 1].id;
          final title = isAll
              ? translate('repair_screen.all_brands')
              : brands[index - 1].name;
          final brand = isAll ? null : brands[index - 1];

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (isAll) {
                  onBrandSelected(null);
                } else {
                  onBrandSelected(brands[index - 1].id);
                }
              },
              onLongPress: !isAll && onEditBrand != null && brand != null
                  ? () => onEditBrand!(brand)
                  : null,
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? enterprise.primary
                      : AppColors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color:
                        isSelected ? enterprise.accent : enterprise.glassStroke,
                    width: 0.9,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: enterprise.accent.withValues(alpha: 0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 1.5),
                          ),
                        ]
                      : [],
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color:
                            isSelected ? AppColors.white : enterprise.mutedText,
                      ),
                    ),
                    if (!isAll &&
                        isSelected &&
                        onEditBrand != null &&
                        brand != null) ...[
                      const SizedBox(width: 5),
                      GestureDetector(
                        onTap: () => onEditBrand!(brand),
                        child: Icon(
                          Icons.edit_rounded,
                          size: 12,
                          color: AppColors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
