import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/pos_report.dart';
import '../providers/pos_reporting_provider.dart';
import 'pos_components.dart';

class PosSalesChart extends StatefulWidget {
  const PosSalesChart({super.key, required this.report, required this.model});
  final PosReport report;
  final PosReportingProvider model;
  @override
  State<PosSalesChart> createState() => _PosSalesChartState();
}

class _PosSalesChartState extends State<PosSalesChart> {
  bool _quantity = false;
  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final purchases = widget.model.filters.type == 'buy_in';
    final points = report.points;
    final values = points
        .map((p) => _quantity
            ? p.quantity
            : purchases
                ? p.purchases
                : p.amount)
        .toList();
    final peak = values.fold<double>(0, math.max);
    final maxY = peak == 0 ? 4.0 : math.max(4.0, (peak / 4).ceilToDouble() * 4);
    final color = purchases ? posModuleColor('buy_in') : posBlue;
    return PosPanel(
        child: Column(children: [
      Row(children: [
        Expanded(
            child: Text(
                posTr(purchases ? 'purchase_overview' : 'sales_overview'),
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: posInk))),
        SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                  value: false,
                  label: Text(posTr('amount'),
                      style: const TextStyle(fontSize: 10))),
              ButtonSegment(
                  value: true,
                  label: Text(posTr('quantity'),
                      style: const TextStyle(fontSize: 10)))
            ],
            showSelectedIcon: false,
            selected: {_quantity},
            onSelectionChanged: (v) => setState(() => _quantity = v.first),
            style: const ButtonStyle(visualDensity: VisualDensity.compact)),
      ]),
      Row(children: [
        for (final preset in <String, String>{
          'last_7_days': '7D',
          'last_30_days': '30D',
          'three_months': '3M',
          'this_year': '1Y'
        }.entries)
          Expanded(
              child: TextButton(
                  onPressed: () => widget.model.period(preset.key),
                  child: Text(preset.value,
                      style: const TextStyle(fontSize: 11)))),
        PopupMenuButton<String>(
            tooltip: posTr('chart_interval'),
            icon: const Icon(Icons.tune, size: 18),
            onSelected: (value) => widget.model
                .update(widget.model.filters.copyWith(bucket: value, page: 1)),
            itemBuilder: (_) => ['day', 'week', 'month']
                .map(
                    (key) => PopupMenuItem(value: key, child: Text(posTr(key))))
                .toList()),
      ]),
      if (points.isEmpty || (values.every((v) => v == 0)))
        SizedBox(
            height: 110,
            child: Center(
                child: Text(posTr('no_chart_data'),
                    style: const TextStyle(color: posMuted, fontSize: 12))))
      else
        Padding(
            padding: const EdgeInsets.fromLTRB(2, 10, 8, 0),
            child: SizedBox(
                height: 135,
                child: LineChart(LineChartData(
                  minY: 0,
                  maxY: maxY,
                  minX: 0,
                  maxX: math.max(1, points.length - 1).toDouble(),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                      drawVerticalLine: false,
                      horizontalInterval: maxY / 4,
                      getDrawingHorizontalLine: (_) =>
                          const FlLine(color: posBorder, strokeWidth: 1)),
                  titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 35,
                              interval: maxY / 4,
                              getTitlesWidget: (v, _) => Text(
                                  NumberFormat.compact().format(v),
                                  style: const TextStyle(
                                      fontSize: 9, color: posMuted)))),
                      bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 26,
                              interval: math
                                  .max(1, (points.length / 5).ceil())
                                  .toDouble(),
                              getTitlesWidget: (v, _) {
                                final i = v.round();
                                if (i < 0 ||
                                    i >= points.length ||
                                    v != i.toDouble())
                                  return const SizedBox.shrink();
                                return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                        DateFormat(report.bucket == 'month'
                                                ? 'MMM'
                                                : 'MMM d')
                                            .format(points[i].date),
                                        style: const TextStyle(
                                            fontSize: 9, color: posMuted)));
                              }))),
                  lineBarsData: [
                    LineChartBarData(
                        spots: List.generate(points.length,
                            (i) => FlSpot(i.toDouble(), values[i])),
                        color: color,
                        barWidth: 2.5,
                        dotData: FlDotData(show: points.length < 15),
                        belowBarData: BarAreaData(
                            show: true, color: color.withValues(alpha: .07)))
                  ],
                  lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (_) => posInk,
                          getTooltipItems: (spots) => spots
                              .map((s) => LineTooltipItem(
                                  '${DateFormat.MMMd().format(points[s.x.toInt()].date)}\n${_quantity ? s.y.toInt() : posMoney(s.y, report.currency)}',
                                  const TextStyle(
                                      color: Colors.white, fontSize: 11)))
                              .toList())),
                )))),
    ]));
  }
}
