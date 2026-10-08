import 'package:flutter/material.dart';

import '../config/repair_price_config.dart';
import '../models/repair_device.dart';

class RepairDeviceFilter extends StatelessWidget {
  final List<RepairDeviceType> deviceTypes;
  final List<RepairDeviceSeries> series;
  final String selectedDeviceType;
  final String selectedSeries;
  final ValueChanged<String> onDeviceTypeSelected;
  final ValueChanged<String> onSeriesSelected;

  const RepairDeviceFilter({
    Key? key,
    required this.deviceTypes,
    required this.series,
    required this.selectedDeviceType,
    required this.selectedSeries,
    required this.onDeviceTypeSelected,
    required this.onSeriesSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _chips(
          label: 'Type',
          items: {
            '': 'All',
            for (final item in deviceTypes) item.slug: item.name
          },
          selected: selectedDeviceType,
          onSelected: onDeviceTypeSelected,
        ),
        const SizedBox(height: 8),
        _chips(
          label: 'Series',
          items: {'': 'All', for (final item in series) item.slug: item.name},
          selected: selectedSeries,
          onSelected: onSeriesSelected,
        ),
      ],
    );
  }

  Widget _chips({
    required String label,
    required Map<String, String> items,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    return SizedBox(
      height: 42,
      child: Row(
        children: [
          SizedBox(
            width: 54,
            child: Text(
              label,
              style: const TextStyle(
                color: RepairPriceConfig.secondaryText,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final slug = items.keys.elementAt(index);
                final isSelected = selected == slug;
                return ChoiceChip(
                  label: Text(items[slug] ?? ''),
                  selected: isSelected,
                  onSelected: (_) => onSelected(slug),
                  selectedColor: RepairPriceConfig.primaryBlue,
                  labelStyle: TextStyle(
                    color:
                        isSelected ? Colors.white : RepairPriceConfig.mainText,
                    fontWeight: FontWeight.w700,
                  ),
                  backgroundColor: RepairPriceConfig.card,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: RepairPriceConfig.border),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
