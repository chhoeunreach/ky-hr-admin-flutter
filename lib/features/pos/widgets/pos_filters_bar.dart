import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../providers/pos_reporting_provider.dart';
import 'pos_components.dart';

class PosFiltersBar extends StatefulWidget {
  const PosFiltersBar(
      {super.key,
      required this.model,
      required this.searchController,
      required this.onCustomDate,
      required this.onReset,
      required this.onRules});
  final PosReportingProvider model;
  final TextEditingController searchController;
  final VoidCallback onCustomDate, onReset, onRules;
  @override
  State<PosFiltersBar> createState() => _PosFiltersBarState();
}

class _PosFiltersBarState extends State<PosFiltersBar> {
  bool _expanded = false;
  Widget _select(
          {required String keyName,
          required String label,
          required String value,
          required Map<String, String> options,
          required ValueChanged<String> onChange}) =>
      DropdownButtonFormField<String>(
        key: ValueKey('$keyName-$value'),
        initialValue: options.containsKey(value) ? value : options.keys.first,
        isExpanded: true,
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(12),
        menuMaxHeight: 320,
        icon: const Icon(Icons.keyboard_arrow_down_rounded,
            color: posMuted, size: 20),
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(fontSize: 12, color: posInk),
        decoration: InputDecoration(
            labelText: label,
            filled: true,
            fillColor: Colors.white,
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: posBlue, width: 1.4)),
            labelStyle: const TextStyle(fontSize: 11),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: posBorder)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: posBorder))),
        items: options.entries
            .map((e) => DropdownMenuItem(
                value: e.key,
                child: Text(e.value,
                    maxLines: 1, overflow: TextOverflow.ellipsis)))
            .toList(),
        onChanged: (value) {
          if (value != null) onChange(value);
        },
      );
  @override
  Widget build(BuildContext context) {
    final m = widget.model, f = m.filters;
    final date = f.from == f.to
        ? DateFormat.yMMMd().format(f.from)
        : '${DateFormat.MMMd().format(f.from)} – ${DateFormat.yMMMd().format(f.to)}';
    final today = DateUtils.dateOnly(DateTime.now());
    final quickPeriods = <String, DateTimeRange>{
      'today': DateTimeRange(start: today, end: today),
      'this_month': DateTimeRange(
          start: DateTime(today.year, today.month),
          end: DateTime(today.year, today.month + 1, 0)),
      'last_month': DateTimeRange(
          start: DateTime(today.year, today.month - 1),
          end: DateTime(today.year, today.month, 0)),
      'this_year': DateTimeRange(
          start: DateTime(today.year), end: DateTime(today.year, 12, 31)),
    };
    return PosPanel(
        child: Column(children: [
      Row(children: [
        Expanded(
            child: OutlinedButton.icon(
                key: const ValueKey('pos-date'),
                onPressed: widget.onCustomDate,
                icon: const Icon(Icons.calendar_month_outlined, size: 17),
                label: Text(date,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                    foregroundColor: posBlue,
                    side: const BorderSide(color: posBorder)))),
        PopupMenuButton<String>(
            key: const ValueKey('pos-date-presets'),
            tooltip: posTr('quick_dates'),
            icon: const Icon(Icons.expand_more, size: 20),
            onSelected: m.period,
            itemBuilder: (_) => [
                  'today',
                  'yesterday',
                  'last_7_days',
                  'last_30_days',
                  'this_month',
                  'last_month',
                  'this_year'
                ]
                    .map((key) =>
                        PopupMenuItem(value: key, child: Text(posTr(key))))
                    .toList()),
        IconButton(
            key: const ValueKey('pos-filter-toggle'),
            tooltip: posTr('filters'),
            onPressed: () => setState(() => _expanded = !_expanded),
            icon: Icon(_expanded ? Icons.filter_alt : Icons.filter_alt_outlined,
                color: posBlue, size: 20)),
        if (m.report?.commissionPolicy.canCalculate ?? false)
          PopupMenuButton<String>(
              key: const ValueKey('pos-commission-mode'),
              tooltip: posTr('commission_rules'),
              icon: const Icon(Icons.calculate_outlined,
                  color: posBlue, size: 21),
              onSelected: (mode) {
                if (mode == 'rules')
                  widget.onRules();
                else
                  m.update(f.copyWith(commissionMode: mode, page: 1));
              },
              itemBuilder: (_) => [
                    if (m.report?.commissionPolicy.canChangeMode ?? false)
                      for (final mode in [
                        'with_conditions',
                        'without_conditions'
                      ])
                        CheckedPopupMenuItem(
                            value: mode,
                            checked: f.commissionMode == mode,
                            child: Text(posTr(mode))),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                        value: 'rules', child: Text(posTr('commission_rules'))),
                  ]),
      ]),
      Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
              spacing: 6,
              runSpacing: 2,
              children: quickPeriods.entries
                  .map((entry) => ChoiceChip(
                      key: ValueKey('pos-period-${entry.key}'),
                      label: Text(posTr(entry.key)),
                      selected: f.from == entry.value.start &&
                          f.to == entry.value.end,
                      showCheckmark: false,
                      selectedColor: posBlue,
                      backgroundColor: posBackground,
                      side: BorderSide(
                          color: f.range == entry.value ? posBlue : posBorder),
                      labelStyle: TextStyle(
                          fontSize: 11,
                          color:
                              f.range == entry.value ? Colors.white : posBlue),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      onSelected: (_) => m.period(entry.key)))
                  .toList())),
      const SizedBox(height: 8),
      _select(
          keyName: 'pos-branch',
          label: posTr('branch'),
          value: f.branch,
          options: {
            '': posTr('all_branches'),
            for (final branch in m.report?.branches ?? <String>[])
              branch: branch
          },
          onChange: (v) => m.update(f.copyWith(branch: v, page: 1))),
      const SizedBox(height: 8),
      TextField(
          key: const ValueKey('pos-search'),
          controller: widget.searchController,
          maxLength: 160,
          onChanged: m.search,
          style: const TextStyle(fontSize: 12),
          decoration: InputDecoration(
              hintText: posTr('search_hint'),
              counterText: '',
              hintStyle: const TextStyle(fontSize: 11, color: posMuted),
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              filled: true,
              fillColor: posBackground,
              suffixIcon: f.search.isNotEmpty
                  ? IconButton(
                      tooltip: posTr('clear_search'),
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        widget.searchController.clear();
                        m.search('');
                      })
                  : null,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none))),
      if (_expanded) ...[
        const SizedBox(height: 10),
        if (m.destination == 'dashboard') ...[
          _select(
              keyName: 'pos-type',
              label: posTr('transaction_type'),
              value: f.type,
              options: {
                'all': posTr('all_types'),
                for (final type in m.report?.modules ?? <String>[])
                  type: posModuleName(type)
              },
              onChange: (v) =>
                  m.update(f.copyWith(type: v, status: 'all', page: 1))),
          const SizedBox(height: 10),
        ],
        _select(
            keyName: 'pos-employee',
            label: posTr('employee'),
            value: f.employee,
            options: {
              '': posTr('all_employees'),
              for (final employee in m.report?.employees ?? <String>[])
                employee: employee
            },
            onChange: (v) => m.update(f.copyWith(employee: v, page: 1))),
        const SizedBox(height: 10),
        if (m.report?.commissionPolicy.visible ?? false)
          _select(
              keyName: 'pos-status',
              label: posTr('commission_status'),
              value: f.status,
              options: {
                'all': posTr('all_statuses'),
                if (f.type != 'buy_in') ...{
                  'qualified': posTr('qualified'),
                  'failed': posTr('failed')
                },
                if (f.type == 'all' || f.type == 'buy_in')
                  'not_applicable': posTr('not_applicable')
              },
              onChange: (v) => m.update(f.copyWith(status: v, page: 1))),
        Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
                onPressed: widget.onReset,
                icon: const Icon(Icons.restart_alt, size: 17),
                label: Text(posTr('reset_filters'),
                    style: const TextStyle(fontSize: 12)))),
      ],
    ]));
  }
}
