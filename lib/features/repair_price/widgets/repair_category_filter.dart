import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import '../models/repair_category.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

class RepairCategoryFilter extends StatelessWidget {
  final List<RepairCategory> categories;
  final int? selectedCategoryId;
  final ValueChanged<int?> onCategorySelected;
  final VoidCallback? onAddCategory;
  final ValueChanged<RepairCategory>? onEditCategory;

  const RepairCategoryFilter({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategorySelected,
    this.onAddCategory,
    this.onEditCategory,
  });

  @override
  Widget build(BuildContext context) {
    final enterprise = EnterpriseTheme.of(context);
    final totalItems = categories.length + 1 + (onAddCategory != null ? 1 : 0);

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: totalItems,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          // Check if this is the "+ Add Category" button at the end
          if (onAddCategory != null && index == totalItems - 1) {
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onAddCategory,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: enterprise.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: enterprise.accent.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded,
                          size: 15, color: enterprise.accent),
                      const SizedBox(width: 4),
                      Text(
                        translate('repair_screen.category'),
                        style: TextStyle(
                          fontSize: 12,
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
              ? selectedCategoryId == null
              : selectedCategoryId == categories[index - 1].id;
          final category = isAll ? null : categories[index - 1];

          final title = isAll
              ? translate('repair_screen.all_categories')
              : category!.nameKh.isNotEmpty
                  ? '${category.nameKh} (${category.name})'
                  : category.name;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (isAll) {
                  onCategorySelected(null);
                } else {
                  onCategorySelected(category?.id);
                }
              },
              onLongPress: !isAll && onEditCategory != null && category != null
                  ? () => onEditCategory!(category)
                  : null,
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? enterprise.primary
                      : AppColors.white
                          .withValues(alpha: enterprise.isDark ? 0.08 : 0.40),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color:
                        isSelected ? enterprise.accent : enterprise.glassStroke,
                    width: 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: enterprise.accent.withValues(alpha: 0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
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
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color:
                            isSelected ? AppColors.white : enterprise.mutedText,
                      ),
                    ),
                    if (!isAll &&
                        isSelected &&
                        onEditCategory != null &&
                        category != null) ...[
                      const SizedBox(width: 5),
                      GestureDetector(
                        onTap: () => onEditCategory!(category),
                        child: Icon(
                          Icons.edit_rounded,
                          size: 13,
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
