import 'dart:io';
import 'package:cnattendance/widget/sell_out/commission_rules_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cnattendance/screen/sell_out_report_screen.dart';
import 'package:cnattendance/screen/profile/NotificationScreen.dart';
import 'package:cnattendance/services/sell_out_api_service.dart';
import '../models/pos_report.dart';
import '../providers/pos_reporting_provider.dart';
import '../services/pos_reporting_repository.dart';
import '../widgets/pos_components.dart';
import '../widgets/pos_filters_bar.dart';
import '../widgets/pos_sales_chart.dart';
import '../widgets/pos_transactions.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

class PosWorkspaceScreen extends StatelessWidget {
  static const routeName = posDashboardRoute;
  const PosWorkspaceScreen(
      {super.key,
      this.initialModule = 'dashboard',
      this.repository,
      this.moduleBuilder});
  final String initialModule;
  final PosReportingRepository? repository;
  final Widget Function(String module)? moduleBuilder;
  @override
  Widget build(BuildContext context) => Theme(
      data: posWorkspaceTheme(Theme.of(context)),
      child: ChangeNotifierProvider(
        create: (_) => PosReportingProvider(
            repository: repository, initialModule: initialModule)
          ..refresh(),
        child: _PosWorkspaceBody(moduleBuilder: moduleBuilder),
      ));
}

class _PosWorkspaceBody extends StatefulWidget {
  const _PosWorkspaceBody({this.moduleBuilder});
  final Widget Function(String module)? moduleBuilder;
  @override
  State<_PosWorkspaceBody> createState() => _PosWorkspaceBodyState();
}

class _PosWorkspaceBodyState extends State<_PosWorkspaceBody> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  final _transactionsKey = GlobalKey();
  bool _exporting = false;
  final _api = SellOutApiService();

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _navigate(PosReportingProvider model, String module) {
    if (module == 'more') {
      _more(model);
      return;
    }
    if (module != 'dashboard') {
      if (module != 'icloud_cus' &&
          !(model.report?.modules.contains(module) ?? false)) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) =>
              widget.moduleBuilder?.call(module) ??
              SellOutReportScreen(serviceType: posServiceType(module))));
      return;
    }
    _search.clear();
    model.navigate(module);
    if (_scroll.hasClients)
      _scroll.animateTo(0,
          duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
  }

  Future<void> _loadReportPage(
      PosReportingProvider model, Future<void> Function() request) async {
    FocusScope.of(context).unfocus();
    final render = _transactionsKey.currentContext?.findRenderObject();
    final offset = render == null
        ? null
        : RenderAbstractViewport.maybeOf(render)
            ?.getOffsetToReveal(render, 0)
            .offset;
    final pending = request();
    final revision = model.requestRevision;
    await pending;
    if (!mounted ||
        revision != model.requestRevision ||
        model.loading ||
        model.errorKey != null ||
        offset == null) return;
    // Loading replaces the long table with a skeleton. Restore the table's
    // position once the server page arrives rather than leaving the user at top.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
          offset.clamp(0.0, _scroll.position.maxScrollExtent).toDouble(),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut);
    });
  }

  Future<void> _customDate(PosReportingProvider model) async {
    final range = await showDateRangePicker(
        context: context,
        initialDateRange: model.filters.range,
        firstDate: DateTime(2020),
        lastDate: DateTime(DateTime.now().year + 2, 12, 31),
        builder: (context, child) => Theme(
            data: Theme.of(context).copyWith(
                colorScheme:
                    Theme.of(context).colorScheme.copyWith(primary: posBlue)),
            child: child!));
    if (range != null && mounted)
      model.update(model.filters
          .copyWith(from: range.start, to: range.end, page: 1, bucket: ''));
  }

  Future<void> _create(PosReportingProvider model, String type) async {
    if (!(model.report?.canCreate ?? false) ||
        !(model.report?.modules.contains(type) ?? false)) return;
    final created = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => SellOutReportCreateScreen(
            serviceType: posServiceType(type),
            commissionPolicy: model.report?.commissionPolicy)));
    if (created == true && mounted) await model.refresh();
  }

  void _open(PosTransaction row) =>
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => SellOutReportDetailScreen(report: row.report)));
  Future<void> _edit(PosReportingProvider model, PosTransaction row) async {
    if (!row.canEdit) return;
    try {
      final full = await _api.fetchReport(row.report.id!);
      if (!mounted) return;
      if (!full.isCreatedToday()) {
        _message(translate('sell_out_report.edit_today_only'));
        await model.refresh();
        return;
      }
      final updated = await Navigator.of(context).push<bool>(MaterialPageRoute(
          builder: (_) => SellOutReportCreateScreen(
              serviceType: full.serviceType, existingReport: full)));
      if (updated == true && mounted) await model.refresh();
    } catch (error) {
      if (mounted) _message(posTr(PosReportingProvider.failureKey(error)));
    }
  }

  void _message(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));
  Future<void> _export(PosReportingProvider model) async {
    setState(() => _exporting = true);
    try {
      final bytes = await model.repository.export(model.filters);
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/kneayerng-${DateTime.now().microsecondsSinceEpoch}.csv');
      await file.writeAsBytes(bytes);
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      await Share.shareXFiles([XFile(file.path)],
          sharePositionOrigin:
              box == null ? null : box.localToGlobal(Offset.zero) & box.size);
    } catch (_) {
      if (mounted) _message(posTr('export_error'));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _rules() {
    final report = context.read<PosReportingProvider>().report;
    if (report != null)
      showServerCommissionRules(context, report.commissionPolicy);
  }

  void _more(PosReportingProvider model) => showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (context) => SafeArea(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (final type in ['repair', 'buy_in']
                .where((t) => model.report?.modules.contains(t) ?? false))
              ListTile(
                  leading:
                      Icon(posModuleIcon(type), color: posModuleColor(type)),
                  title: Text(posModuleName(type)),
                  onTap: () {
                    Navigator.pop(context);
                    _navigate(model, type);
                  }),
            ListTile(
                leading: const Icon(Icons.cloud_outlined),
                title: Text(posModuleName('icloud_cus')),
                onTap: () {
                  Navigator.pop(context);
                  _navigate(model, 'icloud_cus');
                }),
            if (model.report?.commissionPolicy.visible ?? false)
              ListTile(
                  leading: const Icon(Icons.rule_outlined),
                  title: Text(posTr('commission_rules')),
                  onTap: () {
                    Navigator.pop(context);
                    _rules();
                  }),
            ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: Text(posTr('hr_home')),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(this.context).popUntil((route) =>
                      route.isFirst || route.settings.name == '/dashboard');
                }),
          ])));

  Widget _kpis(PosReportingProvider model) {
    final r = model.report!;
    final allTypes = model.filters.type == 'all';
    final entries = <(String, String, IconData, Color)>[
      (
        posTr(allTypes ? 'sales_reports' : 'reports'),
        '${r.metric(allTypes ? 'reports' : 'total_transactions').toInt()}',
        Icons.receipt_long_outlined,
        posBlue
      ),
      (
        posTr(allTypes ? 'quantity_sold' : 'quantity'),
        '${r.metric(allTypes ? 'quantity' : 'module_quantity').toInt()}',
        Icons.inventory_2_outlined,
        AppColors.customFF16885F
      ),
      if (r.commissionPolicy.visible)
        (
          posTr('qualified'),
          '${r.metric(allTypes ? 'qualified' : 'module_qualified').toInt()}',
          Icons.verified_outlined,
          AppColors.customFFD38115
        ),
      if (r.commissionPolicy.visible)
        (
          posTr('failed'),
          '${r.metric(allTypes ? 'failed' : 'module_failed').toInt()}',
          Icons.warning_amber_rounded,
          AppColors.customFFCF4353
        ),
      (
        posTr(model.filters.type == 'buy_in'
            ? 'purchase_amount'
            : allTypes
                ? 'recorded_revenue'
                : 'amount'),
        posMoney(
            r.metric(allTypes ? 'sales_amount' : 'module_amount'), r.currency),
        Icons.payments_outlined,
        AppColors.customFF7952CC
      ),
      if (r.commissionPolicy.visible)
        (
          posTr('report_commission'),
          posMoney(r.metric('commission'), r.currency),
          Icons.percent_rounded,
          AppColors.customFF0596A1
        ),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 900 ? 3 : 2;
      return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: entries
              .map((e) => SizedBox(
                  width: (constraints.maxWidth - (columns - 1) * 8) / columns,
                  child: PosKpiCard(
                      title: e.$1, value: e.$2, icon: e.$3, color: e.$4)))
              .toList());
    });
  }

  Widget _quickAccess(PosReportingProvider model) => PosPanel(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(posTr('quick_access'),
            style: const TextStyle(
                fontSize: 13, color: posInk, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        LayoutBuilder(
            builder: (context, constraints) => Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [...posModules, 'icloud_cus']
                    .where((type) =>
                        type == 'icloud_cus' ||
                        model.report!.modules.contains(type))
                    .map((type) => SizedBox(
                        width: (constraints.maxWidth - 12) / 3,
                        child: InkWell(
                          key: ValueKey('pos-quick-$type'),
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => _navigate(model, type),
                          child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 3),
                              child: Column(children: [
                                Icon(posModuleIcon(type),
                                    size: 22, color: posModuleColor(type)),
                                const SizedBox(height: 5),
                                Text(posModuleName(type),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 11, color: posInk)),
                              ])),
                        )))
                    .toList())),
      ]));

  Widget _categories(PosReportingProvider model) => PosPanel(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        key: const PageStorageKey('pos-business-overview'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        collapsedShape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(posTr('business_overview'),
            style: const TextStyle(
                fontSize: 14, color: posInk, fontWeight: FontWeight.w800)),
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                  color: posBackground, borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                Expanded(
                    flex: 4,
                    child: Text(posTr('breakdown_service'),
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: posMuted))),
                Expanded(
                    flex: 3,
                    child: Text(posTr('amount'),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: posMuted))),
                if (model.report!.commissionPolicy.visible)
                  Expanded(
                      flex: 3,
                      child: Text(posTr('commission_column'),
                          key:
                              const ValueKey('pos-breakdown-commission-header'),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: posMuted))),
              ])),
          ...model.report!.categories
              .where((c) => model.report!.modules.contains(c.type))
              .map((category) => InkWell(
                    key: ValueKey('pos-category-${category.type}'),
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _navigate(model, category.type),
                    child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 12),
                        decoration: const BoxDecoration(
                            border:
                                Border(bottom: BorderSide(color: posBorder))),
                        child: Row(children: [
                          Expanded(
                              flex: 4,
                              child: Row(children: [
                                Icon(posModuleIcon(category.type),
                                    color: posModuleColor(category.type),
                                    size: 18),
                                const SizedBox(width: 6),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(posModuleName(category.type),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 3),
                                      Text(
                                          posTr(
                                              category.isPurchase
                                                  ? 'purchase_count'
                                                  : 'transaction_count',
                                              {
                                                'count':
                                                    '${category.transactions}'
                                              }),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 9, color: posMuted)),
                                    ])),
                              ])),
                          Expanded(
                              flex: 3,
                              child: Align(
                                  alignment: Alignment.centerRight,
                                  child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                          posMoney(category.amount,
                                              model.report!.currency),
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700))))),
                          if (model.report!.commissionPolicy.visible)
                            Expanded(
                                flex: 3,
                                child: Align(
                                    alignment: Alignment.centerRight,
                                    child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                            category.commission == null
                                                ? '—'
                                                : posMoney(category.commission!,
                                                    model.report!.currency),
                                            key: ValueKey(
                                                'pos-category-commission-${category.type}'),
                                            style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors
                                                    .customFF16885F))))),
                        ])),
                  )),
          const Divider(),
          ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(posTr('gross_profit'),
                  style: const TextStyle(fontSize: 13)),
              subtitle: Text(posTr('profit_unavailable'),
                  style: const TextStyle(fontSize: 11, color: posMuted)),
              trailing: Text(posTr('unavailable'),
                  style: const TextStyle(fontSize: 11, color: posMuted))),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(posTr('total_transactions'),
                style: const TextStyle(fontSize: 12, color: posMuted)),
            Text('${model.report!.metric('total_transactions').toInt()}',
                style: const TextStyle(fontWeight: FontWeight.w800))
          ]),
        ],
      ));

  @override
  Widget build(BuildContext context) {
    final model = context.watch<PosReportingProvider>();
    final modules = model.report?.modules ?? <String>[];
    return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: posBackground,
          appBar: AppBar(
            backgroundColor: posBlue,
            foregroundColor: AppColors.white,
            elevation: 0,
            title:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(posModuleName(model.destination),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800)),
              Text(model.report?.businessName ?? 'KNEAYERNG',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.customFFD8E9FF)),
            ]),
            actions: [
              if (model.report?.canCreate ?? false)
                PopupMenuButton<String>(
                    key: const ValueKey('pos-create'),
                    tooltip: posTr('new_transaction'),
                    icon: const Icon(Icons.add_circle_outline),
                    onSelected: (type) => _create(model, type),
                    itemBuilder: (_) => modules
                        .map((type) => PopupMenuItem(
                            value: type,
                            child: Text(posTr('new_module',
                                {'module': posModuleName(type)}))))
                        .toList()),
              IconButton(
                  tooltip: posTr('notifications'),
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => NotificationScreen())),
                  icon: const Icon(Icons.notifications_none, size: 22)),
              IconButton(
                  tooltip: posTr('refresh'),
                  onPressed: model.loading ? null : model.refresh,
                  icon: const Icon(Icons.refresh, size: 21)),
            ],
          ),
          body: RefreshIndicator(
              onRefresh: model.refresh,
              color: posBlue,
              child: ListView(
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(12),
                  children: [
                    PosFiltersBar(
                        model: model,
                        searchController: _search,
                        onCustomDate: () => _customDate(model),
                        onReset: () {
                          _search.clear();
                          model.reset();
                        },
                        onRules: _rules),
                    const SizedBox(height: 10),
                    if (model.loading)
                      const PosLoadingSkeleton()
                    else if (model.errorKey != null)
                      PosPanel(
                          child: Column(children: [
                        const Icon(Icons.error_outline,
                            color: AppColors.customFFCF4353, size: 30),
                        const SizedBox(height: 10),
                        Text(posTr(model.errorKey!),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: posMuted)),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                            onPressed: model.refresh,
                            icon: const Icon(Icons.refresh, size: 17),
                            label: Text(posTr('retry')))
                      ]))
                    else if (model.report != null) ...[
                      _kpis(model),
                      const SizedBox(height: 10),
                      if (model.destination == 'dashboard') ...[
                        _quickAccess(model),
                        const SizedBox(height: 10),
                        PosSalesChart(report: model.report!, model: model),
                        const SizedBox(height: 10),
                        _categories(model),
                        const SizedBox(height: 10),
                      ],
                      if (model.destination == 'repair')
                        Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(posTr('repair_scope'),
                                style: const TextStyle(
                                    fontSize: 11, color: posMuted))),
                      PosTransactions(
                          key: _transactionsKey,
                          model: model,
                          onPage: (page) =>
                              _loadReportPage(model, () => model.page(page)),
                          onPageSize: (size) => _loadReportPage(
                              model,
                              () => model.update(model.filters
                                  .copyWith(perPage: size, page: 1))),
                          onOpen: _open,
                          onEdit: (row) => _edit(model, row),
                          onExport: () => _export(model),
                          exporting: _exporting),
                      const SizedBox(height: 10),
                      Text(posTr('data_scope'),
                          textAlign: TextAlign.center,
                          style:
                              const TextStyle(fontSize: 10, color: posMuted)),
                    ],
                  ])),
          bottomNavigationBar: PosNavigation(
              destination: model.destination,
              modules: modules,
              onSelect: (module) => _navigate(model, module)),
        ));
  }
}
