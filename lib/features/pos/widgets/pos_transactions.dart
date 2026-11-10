import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/pos_report.dart';
import '../providers/pos_reporting_provider.dart';
import 'pos_components.dart';

class PosTransactions extends StatelessWidget {
  const PosTransactions(
      {super.key,
      required this.model,
      required this.onOpen,
      required this.onEdit,
      required this.onExport,
      this.exporting = false,
      this.onPage,
      this.onPageSize});
  final PosReportingProvider model;
  final ValueChanged<PosTransaction> onOpen, onEdit;
  final VoidCallback onExport;
  final bool exporting;
  final ValueChanged<int>? onPage, onPageSize;
  String _date(PosTransaction row) {
    final date = DateTime.tryParse(row.report.createdAt)?.toLocal();
    return date == null
        ? row.report.createdAt
        : DateFormat('MMM d, h:mm a').format(date);
  }

  Widget _action(PosTransaction row) => PopupMenuButton<String>(
      tooltip: posTr('actions'),
      icon: const Icon(Icons.more_horiz, color: posMuted, size: 20),
      onSelected: (action) => action == 'edit' ? onEdit(row) : onOpen(row),
      itemBuilder: (_) => [
            PopupMenuItem(value: 'view', child: Text(posTr('view_details'))),
            if (row.canEdit)
              PopupMenuItem(
                  value: 'edit', child: Text(posTr('edit_transaction')))
          ]);

  @override
  Widget build(BuildContext context) {
    final report = model.report!;
    final start = (report.page - 1) * report.perPage;
    return PosPanel(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(
            child: Text(
                posTr(
                    model.destination == 'dashboard'
                        ? 'recent_transactions'
                        : 'module_transactions',
                    {'module': posModuleName(model.destination)}),
                maxLines: 2,
                style: const TextStyle(
                    fontSize: 14, color: posInk, fontWeight: FontWeight.w800))),
        const SizedBox(width: 6),
        SizedBox(
            width: 78,
            child: DropdownButton<int>(
                key: const ValueKey('pos-page-size'),
                dropdownColor: Colors.white,
                borderRadius: BorderRadius.circular(12),
                elevation: 6,
                isExpanded: true,
                value: model.filters.perPage,
                underline: const SizedBox.shrink(),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontSize: 11, color: posMuted),
                items: [20, 25, 100, 250, 500]
                    .map((size) =>
                        DropdownMenuItem(value: size, child: Text('$size')))
                    .toList(),
                selectedItemBuilder: (_) => [20, 25, 100, 250, 500]
                    .map((size) => Align(
                        alignment: Alignment.centerLeft,
                        child: Text(posTr('show_rows', {'count': '$size'}),
                            maxLines: 1, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (size) {
                  if (size == null) return;
                  if (onPageSize != null) {
                    onPageSize!(size);
                  } else {
                    model
                        .update(model.filters.copyWith(perPage: size, page: 1));
                  }
                })),
        SizedBox(
            width: 34,
            child: IconButton(
                tooltip: posTr('export'),
                onPressed: exporting || report.total == 0 ? null : onExport,
                padding: EdgeInsets.zero,
                icon: exporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.download_outlined,
                        color: posBlue, size: 22))),
      ]),
      const Divider(color: posBorder),
      if (report.transactions.isEmpty)
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(children: [
              const Icon(Icons.receipt_long_outlined,
                  color: posMuted, size: 30),
              const SizedBox(height: 8),
              Text(posTr('empty'),
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: posInk)),
              const SizedBox(height: 4),
              Text(posTr('empty_hint'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: posMuted))
            ]))
      else
        LayoutBuilder(builder: (context, constraints) {
          if (constraints.maxWidth < 650) {
            return Column(
                children: List.generate(report.transactions.length, (index) {
              final row = report.transactions[index];
              return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: ValueKey('pos-transaction-${row.report.id}'),
                    onTap: () => onOpen(row),
                    child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: const BoxDecoration(
                            border:
                                Border(bottom: BorderSide(color: posBorder))),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                  width: 28,
                                  height: 28,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                      color: posModuleColor(row.type)
                                          .withValues(alpha: .08),
                                      borderRadius: BorderRadius.circular(7)),
                                  child: Text('${start + index + 1}',
                                      style: const TextStyle(
                                          fontSize: 10, color: posMuted))),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(
                                        row.report.invoiceNo.isEmpty
                                            ? posTr('reference_pending')
                                            : row.report.invoiceNo,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: posBlue,
                                            fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 4),
                                    Text(
                                        row.report.customerName.isEmpty
                                            ? posTr('walk_in')
                                            : row.report.customerName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 12, color: posInk)),
                                    const SizedBox(height: 4),
                                    Text(
                                        '${posModuleName(row.type)} · ${posTr('qty_value', {
                                              'count': '${row.quantity}'
                                            })}',
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: posModuleColor(row.type))),
                                    const SizedBox(height: 4),
                                    Text(_date(row),
                                        style: const TextStyle(
                                            fontSize: 10, color: posMuted)),
                                  ])),
                              const SizedBox(width: 6),
                              Flexible(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                    Text(
                                        posMoney(row.report.totalAmount,
                                            report.currency),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            color: posInk,
                                            fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 5),
                                    if (report.commissionPolicy.visible)
                                      PosStatusBadge(status: row.status),
                                    const SizedBox(height: 4),
                                    if (report.commissionPolicy.visible)
                                      Text(
                                          posTr('commission_value', {
                                            'amount': posMoney(
                                                row.commission, report.currency)
                                          }),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 9, color: posMuted)),
                                  ])),
                              SizedBox(
                                  width: 28, height: 30, child: _action(row)),
                            ])),
                  ));
            }));
          }
          return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 18,
                horizontalMargin: 4,
                dataRowMinHeight: 52,
                dataRowMaxHeight: 64,
                columns: [
                  'number',
                  'transaction_type',
                  'reference',
                  'customer',
                  'quantity',
                  'amount',
                  if (report.commissionPolicy.visible) 'commission_status',
                  'date',
                  'actions'
                ]
                    .map((key) => DataColumn(
                        label: Text(posTr(key),
                            style: const TextStyle(
                                fontSize: 11,
                                color: posMuted,
                                fontWeight: FontWeight.w700))))
                    .toList(),
                rows: List.generate(report.transactions.length, (i) {
                  final row = report.transactions[i];
                  return DataRow(cells: [
                    DataCell(Text('${start + i + 1}')),
                    DataCell(Text(posModuleName(row.type))),
                    DataCell(
                        Text(row.report.invoiceNo,
                            style: const TextStyle(color: posBlue)),
                        onTap: () => onOpen(row)),
                    DataCell(SizedBox(
                        width: 120,
                        child: Text(
                            row.report.customerName.isEmpty
                                ? posTr('walk_in')
                                : row.report.customerName,
                            overflow: TextOverflow.ellipsis))),
                    DataCell(Text('${row.quantity}')),
                    DataCell(Text(
                        posMoney(row.report.totalAmount, report.currency))),
                    if (report.commissionPolicy.visible)
                      DataCell(PosStatusBadge(status: row.status)),
                    DataCell(
                        Text(_date(row), style: const TextStyle(fontSize: 11))),
                    DataCell(_action(row)),
                  ]);
                }),
              ));
        }),
      const SizedBox(height: 8),
      Text(
          posTr('showing', {
            'from': report.total == 0 ? '0' : '${start + 1}',
            'to': '${start + report.transactions.length}',
            'total': '${report.total}'
          }),
          style: const TextStyle(fontSize: 11, color: posMuted)),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        IconButton(
            key: const ValueKey('pos-previous-page'),
            tooltip: posTr('previous_page'),
            onPressed: report.page > 1 && !model.loading
                ? () {
                    if (onPage != null) {
                      onPage!(report.page - 1);
                    } else {
                      model.page(report.page - 1);
                    }
                  }
                : null,
            icon: const Icon(Icons.chevron_left)),
        Text(
            posTr('page_of',
                {'page': '${report.page}', 'total': '${report.lastPage}'}),
            style: const TextStyle(fontSize: 12, color: posMuted)),
        IconButton(
            key: const ValueKey('pos-next-page'),
            tooltip: posTr('next_page'),
            onPressed: report.page < report.lastPage && !model.loading
                ? () {
                    if (onPage != null) {
                      onPage!(report.page + 1);
                    } else {
                      model.page(report.page + 1);
                    }
                  }
                : null,
            icon: const Icon(Icons.chevron_right)),
      ]),
    ]));
  }
}
