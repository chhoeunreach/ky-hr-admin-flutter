import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:flutter/material.dart';
import '../models/repair_device.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

class RepairSeriesFilter extends StatelessWidget {
  final List<RepairDeviceSeries> series;
  final int? selectedSeriesId;
  final ValueChanged<int?> onSeriesSelected;

  const RepairSeriesFilter({
    super.key,
    required this.series,
    required this.selectedSeriesId,
    required this.onSeriesSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty) return const SizedBox.shrink();
    final enterprise = EnterpriseTheme.of(context);

    return SizedBox(
      height: 28,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: series.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final isAll = index == 0;
          final isSelected = isAll
              ? selectedSeriesId == null
              : selectedSeriesId == series[index - 1].id;
          final title = isAll ? 'All Series' : series[index - 1].name;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (isAll) {
                  onSeriesSelected(null);
                } else {
                  onSeriesSelected(series[index - 1].id);
                }
              },
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? enterprise.primary.withValues(alpha: 0.25)
                      : AppColors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color:
                        isSelected ? enterprise.accent : enterprise.glassStroke,
                    width: 0.9,
                  ),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected && !isAll) ...[
                      Icon(
                        Icons.check_circle_rounded,
                        size: 11,
                        color: enterprise.accent,
                      ),
                      const SizedBox(width: 3),
                    ],
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? enterprise.accent
                            : enterprise.mutedText,
                      ),
                    ),
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
