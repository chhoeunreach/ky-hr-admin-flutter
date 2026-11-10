import 'dart:math' as math;
import 'package:cnattendance/models/report_commission_calculation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cnattendance/models/sell_out_report.dart';

const salesBlue = Color(0xff0063dc);
const salesInk = Color(0xff10182e);
const salesMuted = Color(0xff496080);
const salesBorder = Color(0xffdce6f5);

/// Presentation for the sales overview; records and actions come from the screen.
class SalesDashboard extends StatefulWidget {
  const SalesDashboard({
    super.key,
    required this.reports,
    this.calculation,
    this.reportsTitle,
    this.amountLabel,
    this.serviceIcon = Icons.shopping_bag_outlined,
    required this.translate,
    required this.onOpen,
    required this.onEdit,
    required this.canEdit,
    required this.onExport,
    required this.onFilter,
    required this.emptyState,
    required this.reportsKey,
  });

  final List<SellOutReport> reports;
  final ReportCommissionCalculation? calculation;
  final String? reportsTitle;
  final String? amountLabel;
  final IconData serviceIcon;
  final String Function(String) translate;
  final ValueChanged<SellOutReport> onOpen;
  final ValueChanged<SellOutReport> onEdit;
  final bool Function(SellOutReport) canEdit;
  final VoidCallback onExport;
  final VoidCallback onFilter;
  final Widget emptyState;
  final GlobalKey reportsKey;

  @override
  State<SalesDashboard> createState() => _SalesDashboardState();
}

class _SalesDashboardState extends State<SalesDashboard> {
  int _page = 0;
  int _pageSize = 25;
  int get _effectivePageSize =>
      _pageSize == 0 ? math.max(1, widget.reports.length) : _pageSize;
  ReportCommissionCalculation get calculation =>
      widget.calculation ?? ReportCommissionCalculation(widget.reports);
  String tr(String key) => widget.translate(key);
  String money(num value) =>
      NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(value);

  @override
  void didUpdateWidget(covariant SalesDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reports.length != widget.reports.length ||
        !Iterable.generate(widget.reports.length,
                (i) => identical(oldWidget.reports[i], widget.reports[i]))
            .every((same) => same)) {
      _page = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final reports = widget.reports;
    final tiles = <(String, String, IconData, Color)>[
      (
        tr('reports'),
        '${reports.length}',
        Icons.receipt_long_outlined,
        salesBlue
      ),
      (
        tr('qty'),
        '${reports.fold<int>(0, (sum, r) => sum + r.totalQty)}',
        Icons.inventory_2_outlined,
        const Color(0xff07952e)
      ),
      if (calculation.policy.visible)
        (
          tr('qualified'),
          '${reports.where((r) => calculation.isEligible(r)).length}',
          Icons.verified_outlined,
          const Color(0xffe79700)
        ),
      if (calculation.policy.visible)
        (
          tr('failed'),
          '${reports.where((r) => r.isCommissionable && !calculation.isEligible(r)).length}',
          Icons.warning_amber_rounded,
          const Color(0xffdc253b)
        ),
      (
        widget.amountLabel ?? tr('sales_amount'),
        money(reports.fold<double>(0, (sum, r) => sum + r.totalAmount)),
        Icons.paid_outlined,
        const Color(0xff7536de)
      ),
      if (calculation.policy.visible)
        (
          tr('commission'),
          money(reports.fold<double>(
              0, (sum, r) => sum + calculation.commission(r))),
          Icons.percent_rounded,
          const Color(0xff00a6b2)
        ),
    ];
    return Column(
      children: [
        LayoutBuilder(builder: (context, constraints) {
          final columns = constraints.maxWidth < 360 ? 2 : 3;
          final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
          return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tiles.map((tile) {
                final card = Container(
                  width: width,
                  constraints: const BoxConstraints(minHeight: 64),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                  decoration: BoxDecoration(
                    color: tile.$4.withValues(alpha: .055),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: tile.$4.withValues(alpha: .13)),
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                          color: tile.$4.withValues(alpha: .08),
                          shape: BoxShape.circle),
                      child: Icon(tile.$3, color: tile.$4, size: 21),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(tile.$1,
                                maxLines: 1,
                                style: const TextStyle(
                                    color: salesMuted, fontSize: 11)),
                          ),
                          const SizedBox(height: 3),
                          FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(tile.$2,
                                  style: const TextStyle(
                                      color: salesInk,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800))),
                        ])),
                  ]),
                );
                if (tile.$3 != Icons.percent_rounded ||
                    !calculation.policy.canCalculate) return card;
                return Semantics(
                    button: true,
                    child: InkWell(
                      key: const ValueKey('commission-summary'),
                      borderRadius: BorderRadius.circular(12),
                      onTap: _showCommissionBreakdown,
                      child: Tooltip(
                          message: tr('commission_breakdown'), child: card),
                    ));
              }).toList());
        }),
        const SizedBox(height: 12),
        _reports(),
      ],
    );
  }

  String _commissionExplanation(SellOutReport report) {
    if (!calculation.policy.canCalculate) return tr('saved_commission');

    if (!calculation.isEligible(report)) {
      return calculation
          .failureKeys(report)
          .map((key) => tr(key)
              .replaceAll('{threshold}', '${report.sellQtyThreshold}')
              .replaceAll('{qty}', '${calculation.periodSellQty(report)}'))
          .join(' • ');
    }
    final rule = calculation
        .policy.rules[SellOutReport.canonicalServiceType(report.serviceType)];
    final qty = rule?.perItem == true ? report.totalQty : 1;
    final formula =
        '$qty × ${money(rule?.rate ?? 0)} = ${money(calculation.commission(report))}';
    return SellOutReport.canonicalServiceType(report.serviceType) == 'sell' &&
            calculation.mode == ReportCommissionMode.withConditions
        ? '$formula • ${tr('period_qty_qualified').replaceAll('{qty}', '${calculation.periodSellQty(report)}').replaceAll('{threshold}', '${report.sellQtyThreshold}')}'
        : formula;
  }

  void _showCommissionBreakdown() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
          child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .65,
        child: Column(children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
              child: Row(children: [
                Expanded(
                    child: Text(tr('commission_breakdown'),
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: salesInk))),
                IconButton(
                    tooltip: tr('close'),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close)),
              ])),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(children: [
                Expanded(
                    child: Text(tr('total_commission'),
                        style: const TextStyle(color: salesMuted))),
                Text(
                    money(widget.reports.fold<double>(
                        0, (sum, r) => sum + calculation.commission(r))),
                    style: const TextStyle(
                        fontSize: 22,
                        color: salesBlue,
                        fontWeight: FontWeight.w800)),
              ])),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                  tr(calculation.mode == ReportCommissionMode.withConditions
                      ? 'period_breakdown_with_conditions'
                      : 'period_breakdown_without_conditions'),
                  style: const TextStyle(fontSize: 12, color: salesMuted))),
          const Divider(),
          Expanded(
              child: widget.reports.isEmpty
                  ? Center(child: Text(tr('no_reports_found')))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      itemCount: widget.reports.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (_, index) {
                        final report = widget.reports[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                              report.invoiceNo.isEmpty
                                  ? tr('invoice_pending')
                                  : report.invoiceNo,
                              style: const TextStyle(
                                  color: salesInk,
                                  fontWeight: FontWeight.w700)),
                          subtitle: Text(_commissionExplanation(report),
                              style: const TextStyle(
                                  color: salesMuted, fontSize: 12)),
                          trailing: Text(money(calculation.commission(report)),
                              style: const TextStyle(
                                  color: salesBlue,
                                  fontWeight: FontWeight.w800)),
                        );
                      },
                    )),
        ]),
      )),
    );
  }

  Widget _panel({required Widget child, Key? key}) => Container(
        key: key,
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .94),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: salesBorder),
        ),
        child: child,
      );

  Widget _reportHeader(List<SellOutReport> reports) =>
      LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxWidth < 450;
        return Row(children: [
          if (!compact) ...[
            const Icon(Icons.receipt_long_outlined, color: salesBlue, size: 23),
            const SizedBox(width: 9),
          ],
          Expanded(
              child: Text(
                  '${widget.reportsTitle ?? tr('sales_reports')} (${reports.length})',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: salesInk,
                      fontWeight: FontWeight.w800,
                      fontSize: compact ? 14 : 16))),
          const SizedBox(width: 8),
          _pageSizeSelector(compact: compact),
          const SizedBox(width: 4),
          IconButton(
              tooltip: tr('export_reports'),
              onPressed: reports.isEmpty ? null : widget.onExport,
              constraints:
                  BoxConstraints.tightFor(width: compact ? 32 : 44, height: 40),
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.file_download_outlined,
                  color: salesBlue, size: 22)),
          IconButton(
              tooltip: tr('filter_date'),
              onPressed: widget.onFilter,
              constraints:
                  BoxConstraints.tightFor(width: compact ? 32 : 44, height: 40),
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.filter_alt_outlined,
                  color: salesBlue, size: 22)),
        ]);
      });

  void _selectPage(int page) {
    setState(() => _page = page);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = widget.reportsKey.currentContext;
      if (target != null)
        Scrollable.ensureVisible(target,
            duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
    });
  }

  Widget _pageSizeSelector({bool compact = false}) => Tooltip(
        message: tr('rows_per_page'),
        child: Container(
          width: compact ? 84 : 110,
          height: 40,
          padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 10),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: salesBorder)),
          child: DropdownButton<int>(
            key: const ValueKey('sales-page-size'),
            dropdownColor: Colors.white,
            elevation: 6,
            isExpanded: true,
            isDense: true,
            iconSize: 16,
            value: _pageSize,
            underline: const SizedBox.shrink(),
            borderRadius: BorderRadius.circular(12),
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: salesMuted, fontSize: 12),
            items: [25, 100, 250, 500, 0]
                .map((size) => DropdownMenuItem(
                      value: size,
                      child: Text(size == 0 ? tr('all') : '$size'),
                    ))
                .toList(),
            selectedItemBuilder: (_) => [25, 100, 250, 500, 0]
                .map((size) => Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                          tr('show_rows_value').replaceAll(
                              '{count}', size == 0 ? tr('all') : '$size'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: (size) {
              if (size == null) return;
              setState(() => _pageSize = size);
              _selectPage(0);
            },
          ),
        ),
      );

  Widget _pagination(int start, int end, int total, int pages) =>
      Column(children: [
        Row(children: [
          Expanded(
              child: Text(
                  tr('showing_reports')
                      .replaceAll('{start}', '${start + 1}')
                      .replaceAll('{end}', '$end')
                      .replaceAll('{total}', '$total'),
                  style: const TextStyle(color: salesMuted, fontSize: 11))),
        ]),
        LayoutBuilder(builder: (context, constraints) {
          final window = math.min(pages, constraints.maxWidth < 360 ? 3 : 5);
          final first =
              math.max(0, math.min(_page - window ~/ 2, pages - window));
          return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (constraints.maxWidth >= 500)
              IconButton(
                  tooltip: tr('first_page'),
                  onPressed: _page > 0 ? () => _selectPage(0) : null,
                  icon: const Icon(Icons.first_page)),
            IconButton(
                tooltip: tr('previous_page'),
                onPressed: _page > 0 ? () => _selectPage(_page - 1) : null,
                icon: const Icon(Icons.chevron_left)),
            ...List.generate(window, (i) {
              final page = first + i;
              final selected = page == _page;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Semantics(
                    selected: selected,
                    child: TextButton(
                      key: ValueKey('sales-page-${page + 1}'),
                      onPressed: () => _selectPage(page),
                      style: TextButton.styleFrom(
                          minimumSize: const Size(32, 36),
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          backgroundColor:
                              selected ? salesBlue : Colors.transparent,
                          foregroundColor: selected ? Colors.white : salesMuted,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9)),
                          textStyle: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700)),
                      child: Text('${page + 1}'),
                    )),
              );
            }),
            IconButton(
                tooltip: tr('next_page'),
                onPressed:
                    _page + 1 < pages ? () => _selectPage(_page + 1) : null,
                icon: const Icon(Icons.chevron_right)),
            if (constraints.maxWidth >= 500)
              IconButton(
                  tooltip: tr('last_page'),
                  onPressed:
                      _page + 1 < pages ? () => _selectPage(pages - 1) : null,
                  icon: const Icon(Icons.last_page)),
          ]);
        }),
        const SizedBox(height: 4),
        Text(
            tr('page_of')
                .replaceAll('{page}', '${_page + 1}')
                .replaceAll('{total}', '$pages'),
            style: const TextStyle(color: salesMuted, fontSize: 10)),
      ]);

  Widget _reports() {
    final reports = widget.reports;
    final pages = (reports.length / _effectivePageSize).ceil();
    final start = _page * _effectivePageSize;
    final end = math.min(start + _effectivePageSize, reports.length);
    return _panel(
        key: widget.reportsKey,
        child: Column(children: [
          _reportHeader(reports),
          const SizedBox(height: 12),
          if (reports.isEmpty)
            widget.emptyState
          else ...[
            LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                          width: math.max(340, constraints.maxWidth),
                          child: Column(children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 12),
                              decoration: BoxDecoration(
                                  color: const Color(0xffeaf1fb),
                                  borderRadius: BorderRadius.circular(10)),
                              child: Row(children: [
                                _cell(tr('invoice'), 3, header: true),
                                _cell(tr('customer'),
                                    constraints.maxWidth < 600 ? 2 : 3,
                                    header: true),
                                _cell(tr('qty'), 1, header: true),
                                _cell(tr('amount'), 2, header: true),
                                if (calculation.policy.visible)
                                  _cell(tr('status'), 2, header: true),
                                SizedBox(
                                    width:
                                        constraints.maxWidth < 600 ? 28 : 64),
                              ]),
                            ),
                            ...reports.sublist(start, end).map((r) =>
                                _reportRow(r,
                                    compact: constraints.maxWidth < 600)),
                          ])),
                    )),
            const SizedBox(height: 10),
            _pagination(start, end, reports.length, pages),
          ],
        ]));
  }

  Widget _cell(String text, int flex, {bool header = false, Color? color}) =>
      Expanded(
          flex: flex,
          child: Text(text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: color ?? (header ? salesMuted : salesInk),
                  fontSize: 12,
                  fontWeight: header ? FontWeight.w700 : FontWeight.w600)));

  Widget _reportRow(SellOutReport report, {required bool compact}) {
    final eligible = calculation.isEligible(report);
    final statusColor = !report.isCommissionable
        ? salesMuted
        : eligible
            ? const Color(0xff07952e)
            : const Color(0xffd92232);
    final date = DateTime.tryParse(report.createdAt)?.toLocal();
    return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => widget.onOpen(report),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: salesBorder))),
            child: Row(children: [
              Expanded(
                  flex: 3,
                  child: Row(children: [
                    if (!compact)
                      Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                              color: const Color(0xffedf4ff),
                              borderRadius: BorderRadius.circular(9)),
                          child: Icon(widget.serviceIcon,
                              color: salesBlue, size: 18)),
                    if (!compact) const SizedBox(width: 8),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(
                              report.invoiceNo.isEmpty
                                  ? tr('invoice_pending')
                                  : report.invoiceNo,
                              style: const TextStyle(
                                  color: salesBlue,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12),
                              overflow: TextOverflow.ellipsis),
                          if (date != null)
                            Text(DateFormat.jm().format(date),
                                style: const TextStyle(
                                    color: salesMuted, fontSize: 10)),
                        ])),
                  ])),
              _cell(
                  report.customerName.isEmpty
                      ? tr('walk_in_customer')
                      : report.customerName,
                  compact ? 2 : 3),
              _cell('${report.totalQty}', 1),
              Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(money(report.totalAmount),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: salesInk,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      if (calculation.policy.visible)
                        Tooltip(
                          message:
                              '${tr('commission')}: ${_commissionExplanation(report)}',
                          child: Semantics(
                              label: tr('commission'),
                              child: Row(children: [
                                const Icon(Icons.percent_rounded,
                                    size: 10, color: Color(0xff00a6b2)),
                                const SizedBox(width: 2),
                                Flexible(
                                    child: Text(
                                        money(calculation.commission(report)),
                                        key: ValueKey(
                                            'invoice-commission-${report.invoiceNo}'),
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: Color(0xff008c98),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700))),
                              ])),
                        ),
                    ],
                  )),
              if (calculation.policy.visible)
                Expanded(
                    flex: 2,
                    child: Tooltip(
                      message: _commissionExplanation(report),
                      child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: compact ? 4 : 8, vertical: 6),
                          decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: .08),
                              borderRadius: BorderRadius.circular(99)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(
                                eligible
                                    ? Icons.check_circle_outline
                                    : !report.isCommissionable
                                        ? Icons.remove_circle_outline
                                        : Icons.close,
                                color: statusColor,
                                size: compact ? 11 : 13),
                            const SizedBox(width: 3),
                            Flexible(
                                child: Text(
                                    tr(!report.isCommissionable
                                        ? 'other'
                                        : eligible
                                            ? 'qualified'
                                            : 'failed'),
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: statusColor,
                                        fontSize: compact ? 9 : 10,
                                        fontWeight: FontWeight.w700)))
                          ])),
                    )),
              if (compact)
                SizedBox(
                    width: 28,
                    child: PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      tooltip: tr('report_actions'),
                      icon: const Icon(Icons.chevron_right,
                          color: salesMuted, size: 20),
                      onSelected: (action) => action == 'edit'
                          ? widget.onEdit(report)
                          : widget.onOpen(report),
                      itemBuilder: (_) => [
                        PopupMenuItem(
                            value: 'view', child: Text(tr('detail_title'))),
                        if (widget.canEdit(report))
                          PopupMenuItem(
                              value: 'edit', child: Text(tr('edit_report'))),
                      ],
                    ))
              else ...[
                SizedBox(
                    width: 40,
                    child: widget.canEdit(report)
                        ? IconButton(
                            tooltip: tr('edit_report'),
                            onPressed: () => widget.onEdit(report),
                            icon: const Icon(Icons.edit_outlined,
                                size: 17, color: salesMuted))
                        : null),
                const Icon(Icons.chevron_right, color: salesMuted, size: 24),
              ],
            ]),
          ),
        ));
  }
}
