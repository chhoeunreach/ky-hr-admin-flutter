import 'package:cnattendance/models/sell_out_report.dart';
import 'package:cnattendance/provider/dashboardprovider.dart';
import 'package:cnattendance/screen/awards/awardsscreen.dart';
import 'package:cnattendance/screen/dashboard/projectscreen.dart';
import 'package:cnattendance/screen/eventscreen/eventlistscreen.dart';
import 'package:cnattendance/screen/profile/holidayscreen.dart';
import 'package:cnattendance/screen/sell_out_report_screen.dart';
import 'package:cnattendance/screen/training/trainingscreen.dart';
import 'package:cnattendance/services/sell_out_api_service.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:flutter/material.dart';
import 'package:cnattendance/widget/homescreen/cardoverview.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:persistent_bottom_nav_bar_v2/persistent_bottom_nav_bar_v2.dart';
import 'package:provider/provider.dart';

class _SellOutTypeTotals {
  final int qty;
  final double? commission;

  const _SellOutTypeTotals({required this.qty, required this.commission});
}

class OverviewDashboard extends StatefulWidget {
  final PersistentTabController controller;

  OverviewDashboard(this.controller);

  @override
  State<OverviewDashboard> createState() => _OverviewDashboardState();
}

class _OverviewDashboardState extends State<OverviewDashboard> {
  late final Future<List<SellOutReport>> _sellOutReportsFuture =
      SellOutApiService().fetchReports();

  Map<String, _SellOutTypeTotals> _aggregateByType(
      List<SellOutReport> reports) {
    final now = DateTime.now();
    final currentMonthReports = reports.where((report) {
      final createdAt = DateTime.tryParse(report.createdAt);
      return createdAt != null &&
          createdAt.year == now.year &&
          createdAt.month == now.month;
    });

    final totals = <String, _SellOutTypeTotals>{};
    for (final report in currentMonthReports) {
      final type = SellOutReport.canonicalServiceType(report.serviceType);
      if (type.isEmpty) continue;
      final existing = totals[type];
      final qty = (existing?.qty ?? 0) + report.totalQty;
      final commission = report.isCommissionable
          ? (existing?.commission ?? 0) + report.commission
          : existing?.commission;
      totals[type] = _SellOutTypeTotals(qty: qty, commission: commission);
    }
    return totals;
  }

  @override
  Widget build(BuildContext context) {
    final _overview = Provider.of<DashboardProvider>(context).overviewList;
    final features = context.watch<DashboardProvider>().features;
    final width = MediaQuery.sizeOf(context).width;
    final enterprise = EnterpriseTheme.of(context);
    final crossAxisCount = width >= 720
        ? 3
        : width > 340
            ? 2
            : 1;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  translate('home_screen.overview'),
                  style: TextStyle(
                    color: enterprise.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                width: 34,
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  gradient: LinearGradient(
                    colors: [enterprise.accent, enterprise.primary],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FutureBuilder<List<SellOutReport>>(
            future: _sellOutReportsFuture,
            builder: (context, snapshot) {
              final totals = snapshot.hasData
                  ? _aggregateByType(snapshot.data!)
                  : const <String, _SellOutTypeTotals>{};
              return GridView(
                shrinkWrap: true,
                primary: false,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: 96,
                ),
                children: [
              CardOverView(
                type: translate('home_screen.present'),
                value: _overview['present']!,
                icon: "assets/icons/present_icon.png",
                callback: () {
                  widget.controller.jumpToTab(3);
                },
              ),
              CardOverView(
                type: translate('home_screen.holidays'),
                value: _overview['holiday']!,
                icon: Icons.celebration,
                callback: () {
                  pushScreen(context,
                      screen: HolidayScreen(),
                      withNavBar: false,
                      pageTransitionAnimation: PageTransitionAnimation.fade);
                },
              ),
              CardOverView(
                type: translate('home_screen.leave'),
                value: _overview['leave']!,
                icon: Icons.sick,
                callback: () {
                  widget.controller.jumpToTab(2);
                },
              ),
              if (features["event"] == "1")
                CardOverView(
                  type: translate('home_screen.event'),
                  value: _overview['active_event']!,
                  icon: Icons.calendar_month,
                  callback: () {
                    pushScreen(context,
                        screen: EventListScreen(),
                        withNavBar: false,
                        pageTransitionAnimation: PageTransitionAnimation.fade);
                  },
                ),
              if (features["project-management"] == "1")
                CardOverView(
                  type: translate('home_screen.projects'),
                  value: _overview['total_project']!,
                  icon: Icons.work_history_outlined,
                  callback: () {
                    pushScreen(context,
                        screen: ProjectScreen(),
                        withNavBar: false,
                        pageTransitionAnimation: PageTransitionAnimation.fade);
                  },
                ),
              if (features["project-management"] == "1")
                CardOverView(
                  type: translate('home_screen.task'),
                  value: _overview['total_task']!,
                  icon: Icons.outlined_flag_sharp,
                  callback: () {
                    pushScreen(context,
                        screen: ProjectScreen(),
                        withNavBar: false,
                        pageTransitionAnimation: PageTransitionAnimation.fade);
                  },
                ),
              if (features["award"] == "1")
                CardOverView(
                  type: translate('home_screen.awards'),
                  value: _overview['total_awards']!,
                  icon: Icons.workspace_premium_outlined,
                  callback: () {
                    pushScreen(context,
                        screen: AwardsScreen(),
                        withNavBar: false,
                        pageTransitionAnimation: PageTransitionAnimation.fade);
                  },
                ),
              if (features["training"] == "1")
                CardOverView(
                  type: translate('home_screen.training'),
                  value: _overview['active_training']!,
                  icon: Icons.model_training_rounded,
                  callback: () {
                    pushScreen(context,
                        screen: TrainingScreen(),
                        withNavBar: true,
                        pageTransitionAnimation: PageTransitionAnimation.fade);
                  },
                ),
                  _serviceCard(context, totals,
                      translate('home_screen.service_sell'),
                      Icons.point_of_sale),
                  _serviceCard(context, totals,
                      translate('home_screen.service_material'),
                      Icons.inventory_2_outlined),
                  _serviceCard(context, totals,
                      translate('home_screen.service_iron'),
                      Icons.local_laundry_service),
                  _serviceCard(context, totals,
                      translate('home_screen.service_repair'),
                      Icons.build_circle_outlined),
                  _serviceCard(context, totals,
                      translate('home_screen.service_buy_in'),
                      Icons.add_shopping_cart),
                  _serviceCard(context, totals,
                      translate('home_screen.service_icloud_cus'),
                      Icons.cloud_outlined),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _serviceCard(BuildContext context, Map<String, _SellOutTypeTotals> totals,
      String serviceType, IconData icon) {
    final typeTotals = totals[SellOutReport.canonicalServiceType(serviceType)];
    final commission = typeTotals?.commission;
    return CardOverView(
      type: serviceType,
      value: (typeTotals?.qty ?? 0).toString(),
      subtitle: commission != null
          ? '\$${commission.toStringAsFixed(2)}'
          : null,
      icon: icon,
      callback: () {
        pushScreen(
          context,
          screen: SellOutReportScreen(serviceType: serviceType),
          withNavBar: false,
          pageTransitionAnimation: PageTransitionAnimation.fade,
        );
      },
    );
  }
}
