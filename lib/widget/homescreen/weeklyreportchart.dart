import 'package:cnattendance/provider/dashboardprovider.dart';
import 'package:flutter/material.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:provider/provider.dart';

class WeeklyReportChart extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => WeeklyReportChartState();
}

class WeeklyReportChartState extends State<WeeklyReportChart> {
  int touchedGroupIndex = -1;

  var initial = true;

  @override
  void didChangeDependencies() {
    if (initial) {
      Provider.of<DashboardProvider>(context, listen: false).buildgraph();
      initial = false;
    }
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context);
    final hasWeeklyData = provider.weeklyReport.any((value) => value > 0);
    final enterprise = EnterpriseTheme.of(context);
    final chartColor =
        enterprise.isDark ? enterprise.accent : enterprise.primary;
    final chartHeight = MediaQuery.sizeOf(context).width < 400 ? 208.0 : 226.0;
    final themedGroups = provider.showingBarGroups
        .map((group) => group.copyWith(
              barRods: group.barRods
                  .map((rod) => rod.copyWith(color: chartColor))
                  .toList(),
            ))
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: SizedBox(
        height: chartHeight,
        child: Container(
          decoration: BoxDecoration(
            gradient: enterprise.cardGradient,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: enterprise.accent.withValues(
                alpha: enterprise.isDark ? 0.36 : 0.28,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: enterprise.primary.withValues(alpha: 0.10),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  makeTransactionsIcon(chartColor),
                  const SizedBox(width: 9),
                  Text(
                    translate('home_screen.weekly'),
                    style: TextStyle(
                      color: enterprise.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    translate('home_screen.reports'),
                    style: TextStyle(
                      color: enterprise.mutedText,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Expanded(
                child: hasWeeklyData
                    ? BarChart(
                        BarChartData(
                          maxY: 16,
                          barTouchData: BarTouchData(
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipItem:
                                  (group, groupIndex, rod, rodIndex) {
                                return BarTooltipItem(
                                  'Worked: ${rod.toY.toStringAsFixed(2)} Hr',
                                  const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                );
                              },
                            ),
                            touchCallback: (event, response) {
                              if (response?.spot == null ||
                                  !event.isInterestedForInteractions) {
                                setState(() => touchedGroupIndex = -1);
                                provider.showingBarGroups =
                                    List.of(provider.rawBarGroups);
                                return;
                              }

                              touchedGroupIndex =
                                  response!.spot!.touchedBarGroupIndex;
                              provider.showingBarGroups =
                                  List.of(provider.rawBarGroups);
                              if (touchedGroupIndex != -1) {
                                final bars = provider
                                    .showingBarGroups[touchedGroupIndex]
                                    .barRods;
                                final average = bars.fold<double>(
                                        0, (sum, bar) => sum + bar.toY) /
                                    bars.length;
                                provider.showingBarGroups[touchedGroupIndex] =
                                    provider.showingBarGroups[touchedGroupIndex]
                                        .copyWith(
                                  barRods: bars
                                      .map((bar) => bar.copyWith(toY: average))
                                      .toList(),
                                );
                              }
                              setState(() {});
                            },
                          ),
                          titlesData: FlTitlesData(
                            show: true,
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) =>
                                    bottomTitles(value, meta, enterprise),
                                reservedSize: 25,
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 27,
                                interval: 4,
                                getTitlesWidget: (value, meta) =>
                                    leftTitles(value, meta, enterprise),
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          barGroups: themedGroups,
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: 4,
                            getDrawingHorizontalLine: (_) => FlLine(
                              color:
                                  enterprise.cardBorder.withValues(alpha: 0.40),
                              strokeWidth: 0.7,
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          translate('home_screen.no_weekly_report'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: enterprise.mutedText,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget leftTitles(double value, TitleMeta meta, EnterpriseTheme enterprise) {
    final style = TextStyle(
      color: enterprise.mutedText,
      fontWeight: FontWeight.w600,
      fontSize: 9,
    );
    String text;
    if (value == 2) {
      text = '2Hr';
    } else if (value == 4) {
      text = '4Hr';
    } else if (value == 6) {
      text = '6Hr';
    } else if (value == 8) {
      text = '8Hr';
    } else if (value == 10) {
      text = '10Hr';
    } else if (value == 12) {
      text = '12Hr';
    } else if (value == 14) {
      text = '14Hr';
    } else if (value == 16) {
      text = '16Hr';
    } else {
      return Container();
    }
    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 0,
      child: Text(text, style: style),
    );
  }

  Widget bottomTitles(
      double value, TitleMeta meta, EnterpriseTheme enterprise) {
    final titles = [
      translate('home_screen.sun'),
      translate('home_screen.mon'),
      translate('home_screen.tue'),
      translate('home_screen.wed'),
      translate('home_screen.thu'),
      translate('home_screen.fri'),
      translate('home_screen.sat')
    ];

    final text = Text(
      titles[value.toInt()],
      style: TextStyle(
        color: enterprise.mutedText,
        fontWeight: FontWeight.w600,
        fontSize: 10,
      ),
    );

    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 3,
      child: text,
    );
  }

  Widget makeTransactionsIcon(Color color) {
    const width = 4.5;
    const space = 3.5;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Container(
          width: width,
          height: 10,
          color: color.withValues(alpha: 0.38),
        ),
        const SizedBox(
          width: space,
        ),
        Container(
          width: width,
          height: 15,
          color: color.withValues(alpha: 0.72),
        ),
        const SizedBox(
          width: space,
        ),
        Container(
          width: width,
          height: 25,
          color: color,
        ),
        const SizedBox(
          width: space,
        ),
        Container(
          width: width,
          height: 15,
          color: color.withValues(alpha: 0.72),
        ),
        const SizedBox(
          width: space,
        ),
        Container(
          width: width,
          height: 10,
          color: Colors.white.withValues(alpha: 0.4),
        ),
      ],
    );
  }
}
