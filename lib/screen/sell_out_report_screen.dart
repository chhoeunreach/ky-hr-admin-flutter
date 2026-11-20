import 'dart:io';
import 'package:cnattendance/models/commission_policy.dart';
import 'package:cnattendance/widget/sell_out/commission_rules_sheet.dart';
import 'dart:convert';
import 'package:cnattendance/features/pos/widgets/pos_components.dart';
import 'package:cnattendance/models/report_commission_calculation.dart';
import 'package:intl/intl.dart';
import 'package:cnattendance/widget/sell_out/sales_dashboard.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:cnattendance/core/ky_security/ky_http.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/models/sell_out_report.dart';
import 'package:cnattendance/models/sell_out_report_line.dart';
import 'package:cnattendance/services/ocr_service.dart';
import 'package:cnattendance/services/sell_out_api_service.dart';
import 'package:cnattendance/widget/premium_background.dart';
import 'package:cnattendance/widget/customqrscanner.dart';

const Color _sellOutNavy = Color(0xff011754);
const Color _sellOutBlue = Color(0xff036eb7);
const Color _sellOutSurface = Colors.white;
const Color _sellOutText = Color(0xff172033);
const Color _sellOutMuted = Color(0xff697386);
const Color _sellOutBorder = Color(0xffdde6f2);
const String _iCloudCustomerServiceType = 'iCloud Cus';

String _sellOutTr(String key) => translate('sell_out_report.$key');

String _displayServiceType(String serviceType) {
  final canonical = SellOutReport.canonicalServiceType(serviceType);
  return canonical == 'icloud_cus' || canonical == 'sell_sim'
      ? posServiceLabel(canonical)
      : serviceType;
}

String _sellOutTrWith(String key, Map<String, String> values) {
  var text = _sellOutTr(key);
  values.forEach((name, value) {
    text = text.replaceAll('{$name}', value);
  });
  return text;
}

class SellOutReportScreen extends StatefulWidget {
  static const String routeName = '/sell-out-report';

  final String serviceType;
  final Future<List<SellOutReport>> Function()? reportLoader;

  const SellOutReportScreen(
      {Key? key, this.serviceType = '', this.reportLoader})
      : super(key: key);

  @override
  State<SellOutReportScreen> createState() => _SellOutReportListScreenState();
}

class _SellOutReportListScreenState extends State<SellOutReportScreen> {
  final _apiService = SellOutApiService();
  final _searchController = TextEditingController();
  late Future<List<SellOutReport>> _reportsFuture;
  late DateTimeRange _dateRange;
  String _searchQuery = '';
  CommissionPolicy _commissionPolicy = const CommissionPolicy();
  bool _commissionModeSelected = false;
  ReportCommissionMode _commissionMode = ReportCommissionMode.withConditions;
  final _scrollController = ScrollController();
  final _reportsKey = GlobalKey();

  String get _canonicalService =>
      SellOutReport.canonicalServiceType(widget.serviceType);
  bool get _isSales =>
      widget.serviceType.isEmpty || _canonicalService == 'sell';
  String get _serviceLabel {
    if (_isSales) return translate('home_screen.service_sell');
    if (['material', 'iron', 'repair', 'buy_in', 'icloud_cus', 'sell_sim']
        .contains(_canonicalService)) {
      return translate('home_screen.service_$_canonicalService');
    }
    return widget.serviceType;
  }

  IconData get _serviceIcon {
    switch (_canonicalService) {
      case 'material':
        return Icons.inventory_2_outlined;
      case 'iron':
        return Icons.local_laundry_service_outlined;
      case 'repair':
        return Icons.build_outlined;
      case 'buy_in':
        return Icons.add_shopping_cart_outlined;
      case 'icloud_cus':
        return Icons.cloud_outlined;
      case 'sell_sim':
        return Icons.sim_card_outlined;
      default:
        return Icons.shopping_bag_outlined;
    }
  }

  @override
  void initState() {
    super.initState();
    final today = DateUtils.dateOnly(DateTime.now());
    _dateRange = DateTimeRange(start: today, end: today);
    _reportsFuture = _loadReports();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<List<SellOutReport>> _loadReports() async {
    _commissionPolicy = const CommissionPolicy();
    final reports = await (widget.reportLoader ?? _apiService.fetchReports)();
    _commissionPolicy = widget.reportLoader != null
        ? (reports.isEmpty ? null : reports.first.commissionPolicy) ??
            CommissionPolicy.defaults()
        : _apiService.commissionPolicy;
    if (!_commissionPolicy.canChangeMode || !_commissionModeSelected)
      _commissionMode = _commissionPolicy.defaultMode == 'without_conditions'
          ? ReportCommissionMode.withoutConditions
          : ReportCommissionMode.withConditions;
    return reports;
  }

  Future<void> _refresh() async {
    setState(() {
      _reportsFuture = _loadReports();
    });
    await _reportsFuture;
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SellOutReportCreateScreen(
          serviceType: widget.serviceType,
          commissionPolicy: _commissionPolicy,
        ),
      ),
    );
    if (created == true && mounted) {
      _refresh();
    }
  }

  void _openDetail(SellOutReport report) {
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => SellOutReportDetailScreen(report: report)),
    );
  }

  bool _isEditableToday(SellOutReport report) => report.isCreatedToday();

  Future<void> _openEdit(SellOutReport report) async {
    if (!_isEditableToday(report)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_sellOutTr('edit_today_only'))));
      return;
    }
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SellOutReportCreateScreen(
          serviceType: widget.serviceType,
          existingReport: report,
          commissionPolicy: _commissionPolicy,
        ),
      ),
    );
    if (updated == true && mounted) {
      _refresh();
    }
  }

  Future<void> _pickDateRange() async {
    final selected = await showDateRangePicker(
      context: context,
      initialDateRange: _dateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: HexColor('#036eb7'),
                ),
          ),
          child: child!,
        );
      },
    );

    if (selected != null && mounted) {
      setState(() {
        _dateRange = DateTimeRange(
            start: _dateOnly(selected.start), end: _dateOnly(selected.end));
      });
    }
  }

  void _resetDateRangeToToday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    setState(() {
      _dateRange = DateTimeRange(start: today, end: today);
    });
  }

  DateTimeRange _dateRangeForPreset(String preset) {
    final now = DateTime.now();
    if (preset == 'this_year') {
      return DateTimeRange(
          start: DateTime(now.year), end: DateTime(now.year, 12, 31));
    }
    final month = preset == 'last_month' ? now.month - 1 : now.month;
    return DateTimeRange(
        start: DateTime(now.year, month),
        end: DateTime(now.year, month + 1, 0));
  }

  void _selectDatePreset(String preset) {
    setState(() => _dateRange = _dateRangeForPreset(preset));
  }

  Widget _buildDateShortcuts({bool compact = false}) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: const Color(0xffe8eff9),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: salesBorder),
        ),
        child: Row(
            children: ['this_month', 'last_month', 'this_year'].map((preset) {
          final range = _dateRangeForPreset(preset);
          final selected =
              _dateRange.start == range.start && _dateRange.end == range.end;
          return Expanded(
              child: Semantics(
                  selected: selected,
                  button: true,
                  child: InkWell(
                    key: ValueKey('date-preset-$preset'),
                    borderRadius: BorderRadius.circular(9),
                    onTap: () => _selectDatePreset(preset),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      height: 36,
                      padding:
                          EdgeInsets.symmetric(horizontal: compact ? 4 : 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                    color: salesInk.withValues(alpha: .07),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1))
                              ]
                            : [],
                      ),
                      child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(_sellOutTr(preset),
                              style: TextStyle(
                                  fontSize: compact ? 11 : 12,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: selected ? salesBlue : salesMuted))),
                    ),
                  )));
        }).toList()),
      );

  Widget _buildCommissionMenu() => !_commissionPolicy.canCalculate
      ? const SizedBox.shrink()
      : Tooltip(
          message:
              '${_sellOutTr('commission_calculation_mode')}: ${_sellOutTr(_commissionMode == ReportCommissionMode.withConditions ? 'with_conditions' : 'without_conditions')}',
          child: Container(
            height: 40,
            width: 46,
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: salesBorder)),
            child: PopupMenuButton<String>(
              key: const ValueKey('commission-mode'),
              tooltip: _sellOutTr('commission_calculation_mode'),
              position: PopupMenuPosition.under,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              padding: EdgeInsets.zero,
              icon: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.calculate_outlined,
                    size: 21,
                    color:
                        _commissionMode == ReportCommissionMode.withConditions
                            ? salesBlue
                            : const Color(0xff008c98)),
                const Icon(Icons.expand_more, size: 12, color: salesMuted),
              ]),
              onSelected: (value) {
                if (value == 'rules') {
                  showServerCommissionRules(context, _commissionPolicy);
                } else {
                  _commissionModeSelected = true;
                  setState(() => _commissionMode = value == 'with_conditions'
                      ? ReportCommissionMode.withConditions
                      : ReportCommissionMode.withoutConditions);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem<String>(
                    enabled: false,
                    child: Text(_sellOutTr('commission_calculation_mode'),
                        style: const TextStyle(
                            color: salesMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700))),
                if (_commissionPolicy.canChangeMode)
                  CheckedPopupMenuItem<String>(
                      value: 'with_conditions',
                      checked: _commissionMode ==
                          ReportCommissionMode.withConditions,
                      child: Text(_sellOutTr('with_conditions'))),
                if (_commissionPolicy.canChangeMode)
                  CheckedPopupMenuItem<String>(
                      value: 'without_conditions',
                      checked: _commissionMode ==
                          ReportCommissionMode.withoutConditions,
                      child: Text(_sellOutTr('without_conditions'))),
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                    value: 'rules',
                    child: Row(children: [
                      const Icon(Icons.rule_outlined,
                          size: 19, color: salesBlue),
                      const SizedBox(width: 10),
                      Text(_sellOutTr('commission_rules')),
                    ])),
              ],
            ),
          ),
        );

  void _navigateModule(String module) {
    if (module == _canonicalService || (module == 'sell' && _isSales)) {
      if (_scrollController.hasClients)
        _scrollController.animateTo(0,
            duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
      return;
    }
    if (module == 'dashboard') {
      Navigator.of(context).pushReplacementNamed(posDashboardRoute);
      return;
    }
    if (module == 'more') {
      showModalBottomSheet<void>(
        context: context,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
        builder: (context) => SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final type in ['repair', 'buy_in', 'icloud_cus'])
            ListTile(
              leading: Icon(
                  type == 'icloud_cus'
                      ? Icons.cloud_outlined
                      : posModuleIcon(type),
                  color: salesBlue),
              title: Text(posServiceLabel(type)),
              onTap: () {
                Navigator.pop(context);
                _navigateModule(type);
              },
            ),
          if (_commissionPolicy.visible)
            ListTile(
                leading: const Icon(Icons.rule_outlined, color: salesBlue),
                title: Text(_sellOutTr('commission_rules')),
                onTap: () {
                  Navigator.pop(context);
                  showServerCommissionRules(this.context, _commissionPolicy);
                }),
        ])),
      );
      return;
    }
    Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => SellOutReportScreen(
            serviceType: posServiceType(module),
            reportLoader: widget.reportLoader)));
  }

  Future<void> _exportReports(List<SellOutReport> reports,
      ReportCommissionCalculation calculation) async {
    String cell(Object value) {
      var text = value.toString();
      if (RegExp(r'^[=+@\-\t\r]').hasMatch(text)) text = "'$text";
      return '"${text.replaceAll('"', '""')}"';
    }

    final rows = <List<Object>>[
      [
        'Invoice',
        'Customer',
        'Phone',
        'Qty',
        'Amount',
        if (_commissionPolicy.visible) 'Commission',
        if (_commissionPolicy.visible) 'Status',
        'Created at',
        'Period from',
        'Period to',
        if (_commissionPolicy.canCalculate) 'Commission mode'
      ],
      ...reports.map((r) => <Object>[
            r.invoiceNo,
            r.customerName,
            r.customerPhone,
            r.totalQty,
            r.totalAmount.toStringAsFixed(2),
            if (_commissionPolicy.visible)
              calculation.commission(r).toStringAsFixed(2),
            if (_commissionPolicy.visible)
              !r.isCommissionable
                  ? 'Other'
                  : calculation.isEligible(r)
                      ? 'Qualified'
                      : 'Failed',
            r.createdAt,
            _formatDateOnly(_dateRange.start),
            _formatDateOnly(_dateRange.end),
            if (_commissionPolicy.canCalculate)
              _commissionMode == ReportCommissionMode.withConditions
                  ? 'With conditions'
                  : 'Without conditions',
          ]),
    ];
    try {
      final directory = await getTemporaryDirectory();
      final file = File(
          '${directory.path}/sales-report-${DateTime.now().microsecondsSinceEpoch}.csv');
      await file.writeAsBytes(utf8.encode(
          '\uFEFF${rows.map((r) => r.map(cell).join(',')).join('\r\n')}'));
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      await Share.shareXFiles([XFile(file.path)],
          sharePositionOrigin:
              box == null ? null : box.localToGlobal(Offset.zero) & box.size);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_sellOutTr('export_failed'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSales = _isSales;
    return Theme(
        data: posWorkspaceTheme(Theme.of(context)),
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Scaffold(
            backgroundColor: posBackground,
            body: Container(
              decoration: const BoxDecoration(color: posBlue),
              child: SafeArea(
                  bottom: false,
                  child: Column(children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 10, 14, 16),
                      child: Row(children: [
                        IconButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            tooltip: MaterialLocalizations.of(context)
                                .backButtonTooltip,
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.white)),
                        Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: .1),
                                borderRadius: BorderRadius.circular(18)),
                            child: Icon(
                                isSales
                                    ? Icons.shopping_cart_outlined
                                    : _serviceIcon,
                                color: Colors.white,
                                size: 27)),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(
                                  isSales ? _sellOutTr('sales') : _serviceLabel,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: isSales ? 24 : 20,
                                      fontWeight: FontWeight.w800)),
                              Text(
                                  isSales
                                      ? _sellOutTr('sales_subtitle')
                                      : _sellOutTrWith('service_subtitle',
                                          {'service': _serviceLabel}),
                                  style: const TextStyle(
                                      color: Color(0xffdaeaff), fontSize: 11)),
                            ])),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 132),
                          child: TextButton.icon(
                              onPressed: _openCreate,
                              style: TextButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: salesBlue,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14))),
                              icon: const Icon(Icons.add, size: 21),
                              label: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                      isSales
                                          ? _sellOutTr('new_sale')
                                          : _sellOutTrWith('new_service',
                                              {'service': _serviceLabel}),
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800)))),
                        ),
                      ]),
                    ),
                    Expanded(
                        child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: const BoxDecoration(
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(26)),
                          color: posBackground),
                      child: FutureBuilder<List<SellOutReport>>(
                        future: _reportsFuture,
                        builder: (context, snapshot) {
                          final reports = snapshot.data ?? <SellOutReport>[];
                          final matching = _filterReportsByDate(reports);
                          final calculation = ReportCommissionCalculation(
                              matching,
                              mode: _commissionMode,
                              policy: _commissionPolicy);
                          final filtered = matching;
                          return RefreshIndicator(
                            color: salesBlue,
                            onRefresh: _refresh,
                            child: SingleChildScrollView(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding:
                                  const EdgeInsets.fromLTRB(12, 14, 12, 24),
                              child: Column(children: [
                                _buildSearchField(),
                                const SizedBox(height: 14),
                                _buildFilters(),
                                const SizedBox(height: 14),
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting)
                                  const Padding(
                                      padding: EdgeInsets.all(60),
                                      child: CircularProgressIndicator())
                                else if (snapshot.hasError)
                                  _buildErrorState(snapshot.error.toString())
                                else
                                  SalesDashboard(
                                    reports: filtered,
                                    showProductNames: _isSales ||
                                        ['material', 'iron', 'repair', 'buy_in']
                                            .contains(_canonicalService),
                                    calculation: calculation,
                                    reportsTitle: isSales
                                        ? null
                                        : _sellOutTrWith('service_reports',
                                            {'service': _serviceLabel}),
                                    amountLabel: isSales
                                        ? null
                                        : _sellOutTr('total_amount'),
                                    serviceIcon: _serviceIcon,
                                    translate: _sellOutTr,
                                    onOpen: _openDetail,
                                    onEdit: _openEdit,
                                    canEdit: _isEditableToday,
                                    onExport: () =>
                                        _exportReports(filtered, calculation),
                                    onFilter: _pickDateRange,
                                    emptyState: _buildEmptyCard(),
                                    reportsKey: _reportsKey,
                                  ),
                              ]),
                            ),
                          );
                        },
                      ),
                    )),
                  ])),
            ),
            bottomNavigationBar: PosNavigation(
              destination: _isSales ? 'sell' : _canonicalService,
              modules: const ['sell', 'material', 'iron', 'repair', 'buy_in'],
              onSelect: _navigateModule,
            ),
          ),
        ));
  }

  Widget _buildFilters() => LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxWidth < 650;
        final iconOnlyDate = constraints.maxWidth < 350;
        final today = DateUtils.dateOnly(DateTime.now());
        final isToday = _dateRange.start == today && _dateRange.end == today;
        final fullLabel = _formatDateRange(_dateRange);
        final sameMonth = _dateRange.start.year == _dateRange.end.year &&
            _dateRange.start.month == _dateRange.end.month;
        final shortLabel = _dateRange.start == _dateRange.end
            ? DateFormat.MMMd().format(_dateRange.start)
            : sameMonth
                ? '${DateFormat.MMMd().format(_dateRange.start)}–${_dateRange.end.day}'
                : '${DateFormat.MMMd().format(_dateRange.start)}–${DateFormat.MMMd().format(_dateRange.end)}';
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                SizedBox(
                  width: iconOnlyDate
                      ? 44
                      : compact
                          ? (constraints.maxWidth * .33)
                              .clamp(100.0, 160.0)
                              .toDouble()
                          : 260,
                  height: 44,
                  child: Tooltip(
                      message: fullLabel,
                      child: OutlinedButton(
                        key: const ValueKey('sales-date-range'),
                        onPressed: _pickDateRange,
                        onLongPress: _resetDateRangeToToday,
                        style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: salesBorder),
                            padding: EdgeInsets.symmetric(
                                horizontal: compact ? 7 : 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12))),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.calendar_month_outlined,
                                  color: salesBlue, size: compact ? 17 : 20),
                              if (!iconOnlyDate) ...[
                                const SizedBox(width: 5),
                                Expanded(
                                    child: Text(
                                        isToday
                                            ? _sellOutTr('today')
                                            : compact
                                                ? shortLabel
                                                : fullLabel,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            color: salesInk,
                                            fontSize: compact ? 11 : 12,
                                            fontWeight: FontWeight.w700))),
                                const SizedBox(width: 2),
                                Icon(Icons.expand_more,
                                    color: salesBlue, size: compact ? 13 : 18),
                              ],
                            ]),
                      )),
                ),
                const SizedBox(width: 8),
                Expanded(child: _buildDateShortcuts(compact: compact)),
                const SizedBox(width: 8),
                _buildCommissionMenu(),
              ]),
            ]);
      });

  List<SellOutReport> _filterReportsByDate(List<SellOutReport> reports) {
    final query = _searchQuery.trim().toLowerCase();
    return reports.where((report) {
      if (widget.serviceType.isNotEmpty &&
          SellOutReport.canonicalServiceType(report.serviceType) !=
              SellOutReport.canonicalServiceType(widget.serviceType)) {
        return false;
      }
      final created = DateTime.tryParse(report.createdAt);
      if (created == null) return false;
      final createdDate = _dateOnly(created.toLocal());
      if (createdDate.isBefore(_dateRange.start) ||
          createdDate.isAfter(_dateRange.end)) {
        return false;
      }
      if (query.isNotEmpty) {
        final haystack = [
          report.invoiceNo,
          report.originalInvoiceNo,
          report.customerName,
          report.customerPhone,
          report.sellerName,
          report.branchName,
          report.note,
          ...report.lines.expand((line) =>
              [line.productName, line.sku, line.imei, line.serialNumber]),
        ].join(' ').toLowerCase();
        if (!haystack.contains(query)) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Widget _buildSearchField() {
    return Padding(
      padding: EdgeInsets.zero,
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        style: const TextStyle(color: _sellOutText, fontSize: 14),
        decoration: InputDecoration(
          hintText: _sellOutTr('search_hint'),
          hintStyle: const TextStyle(color: _sellOutMuted, fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: _sellOutMuted),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear, color: _sellOutMuted),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                ),
          filled: true,
          fillColor: _sellOutSurface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _sellOutBorder),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _sellOutBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _sellOutBlue, width: 1.5),
          ),
        ),
      ),
    );
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  String _formatDateRange(DateTimeRange range) {
    final start = _formatDateOnly(range.start);
    final end = _formatDateOnly(range.end);
    return start == end
        ? start
        : _sellOutTrWith('date_range_to', {'start': start, 'end': end});
  }

  String _formatDateOnly(DateTime value) {
    return DateFormat.yMMMd().format(value);
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 56),
            const SizedBox(height: 12),
            Text(
              _isSales
                  ? _sellOutTr('unable_to_load')
                  : _sellOutTrWith(
                      'unable_to_load_service', {'service': _serviceLabel}),
              style: TextStyle(
                color: HexColor('#011754'),
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
              label: Text(_sellOutTr('retry')),
              style: ElevatedButton.styleFrom(
                backgroundColor: HexColor('#036eb7'),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCard() {
    return Card(
      color: _sellOutSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: _sellOutBorder),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
        child: Column(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: _sellOutBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                color: _sellOutBlue,
                size: 34,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isSales
                  ? _sellOutTr('no_reports_found')
                  : _sellOutTrWith(
                      'no_service_reports', {'service': _serviceLabel}),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _sellOutText,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _sellOutTr('no_reports_hint'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _sellOutMuted,
                fontSize: 13,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: _openCreate,
              icon: const Icon(Icons.add, size: 18),
              label: Text(_sellOutTr('add_new')),
              style: OutlinedButton.styleFrom(
                foregroundColor: _sellOutBlue,
                side: const BorderSide(color: _sellOutBlue),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SellOutReportCreateScreen extends StatefulWidget {
  final String serviceType;
  final SellOutReport? existingReport;
  final Future<String?> Function(BuildContext)? serialNumberScanner;
  final CommissionPolicy? commissionPolicy;

  const SellOutReportCreateScreen({
    Key? key,
    this.serviceType = '',
    this.existingReport,
    this.serialNumberScanner,
    this.commissionPolicy,
  }) : super(key: key);

  @override
  State<SellOutReportCreateScreen> createState() =>
      _SellOutReportCreateScreenState();
}

class SellOutReportDetailScreen extends StatefulWidget {
  final SellOutReport report;

  const SellOutReportDetailScreen({Key? key, required this.report})
      : super(key: key);

  @override
  State<SellOutReportDetailScreen> createState() =>
      _SellOutReportDetailScreenState();
}

class _SellOutReportDetailScreenState extends State<SellOutReportDetailScreen> {
  final _apiService = SellOutApiService();
  late Future<SellOutReport> _reportFuture;

  @override
  void initState() {
    super.initState();
    _reportFuture = widget.report.id == null
        ? Future.value(widget.report)
        : _apiService.fetchReport(widget.report.id!);
  }

  @override
  Widget build(BuildContext context) {
    return PremiumBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(_sellOutTr('detail_title')),
          backgroundColor: HexColor('#011754'),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: FutureBuilder<SellOutReport>(
          future: _reportFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              );
            }

            final report = snapshot.data ?? widget.report;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _detailCard(
                  _sellOutTr('header'),
                  [
                    _detailRow(_sellOutTr('invoice'), report.invoiceNo),
                    _detailRow(_sellOutTr('original_invoice'),
                        report.originalInvoiceNo),
                    _detailRow(_sellOutTr('seller'), report.sellerName),
                    _detailRow(_sellOutTr('branch'), report.branchName),
                    _detailRow(_sellOutTr('customer'), report.customerName),
                    _detailRow(
                        _sellOutTr('customer_phone'), report.customerPhone),
                    _detailRow(_sellOutTr('service_type'),
                        _displayServiceType(report.serviceType)),
                    _detailRow(_sellOutTr('payment'), report.paymentMethod),
                    _detailRow(_sellOutTr('total'),
                        '\$${report.totalAmount.toStringAsFixed(2)}'),
                    if (report.commissionPolicy?.visible ?? false)
                      _detailRow(_sellOutTr('commission'),
                          '\$${report.commission.toStringAsFixed(2)}'),
                    _detailRow(_sellOutTr('created_at'), report.createdAt),
                  ],
                ),
                const SizedBox(height: 12),
                _detailCard(
                  _sellOutTr('product_lines'),
                  report.lines.map((line) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            line.productName.isEmpty
                                ? _sellOutTr('product')
                                : line.productName,
                            style: TextStyle(
                              color: HexColor('#011754'),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _detailRow(_sellOutTr('sku'), line.sku),
                          _detailRow('IMEI', line.imei),
                          _detailRow('IMEI2', line.imei2),
                          _detailRow(_sellOutTr('serial'), line.serialNumber),
                          _detailRow(_sellOutTr('model'), line.modelNumber),
                          _detailRow(_sellOutTr('color'), line.color),
                          _detailRow(_sellOutTr('storage'), line.storage),
                          _detailRow(_sellOutTr('qty'), line.qty.toString()),
                          _detailRow(_sellOutTr('unit_price'),
                              '\$${line.unitPrice.toStringAsFixed(2)}'),
                          _detailRow(_sellOutTr('subtotal'),
                              '\$${line.subtotal.toStringAsFixed(2)}'),
                          if (line.photoUrls.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 4,
                                crossAxisSpacing: 6,
                                mainAxisSpacing: 6,
                              ),
                              itemCount: line.photoUrls.length,
                              itemBuilder: (context, photoIndex) {
                                return GestureDetector(
                                  onTap: () => _openPhotoViewer(
                                      line.photoUrls, photoIndex),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: CachedNetworkImage(
                                      imageUrl: line.photoUrls[photoIndex],
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) => Container(
                                        color: Colors.grey.shade200,
                                        child: const Icon(Icons.broken_image,
                                            color: Colors.grey),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ),
                if (report.photoUrls.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildPhotoUrlCard(_sellOutTr('photos'), report.photoUrls),
                ],
                if (report.note.isNotEmpty ||
                    report.extractedText.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _detailCard(
                    _sellOutTr('notes'),
                    [
                      if (report.note.isNotEmpty)
                        _textBlock(_sellOutTr('note'), report.note),
                      if (report.extractedText.isNotEmpty)
                        _textBlock(
                            _sellOutTr('extracted_text'), report.extractedText),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _detailCard(String title, List<Widget> children) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: HexColor('#011754'),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _textBlock(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildPhotoUrlCard(String title, List<String> photoUrls) {
    return _detailCard(
      title,
      [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: photoUrls.length,
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () => _openPhotoViewer(photoUrls, index),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: photoUrls[index],
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _openPhotoViewer(List<String> photoUrls, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _PhotoViewerScreen(
          photoUrls: photoUrls,
          initialIndex: initialIndex,
        ),
      ),
    );
  }
}

class _PhotoViewerScreen extends StatefulWidget {
  final List<String> photoUrls;
  final int initialIndex;

  const _PhotoViewerScreen({
    required this.photoUrls,
    required this.initialIndex,
  });

  @override
  State<_PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<_PhotoViewerScreen> {
  late final PageController _pageController;
  late int _currentIndex;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _download() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);
    try {
      final url = widget.photoUrls[_currentIndex];
      final response = await KyHttp.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception(_sellOutTr('failed_to_download_photo'));
      }
      final dir = await getTemporaryDirectory();
      final ext =
          url.contains('.') ? url.split('.').last.split('?').first : 'jpg';
      final filePath =
          '${dir.path}/sell_out_photo_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);
      await Share.shareXFiles([XFile(filePath)]);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                _sellOutTrWith('download_failed', {'error': e.toString()}))),
      );
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('${_currentIndex + 1} / ${widget.photoUrls.length}'),
        actions: [
          IconButton(
            icon: _isDownloading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download_outlined),
            onPressed: _isDownloading ? null : _download,
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.photoUrls.length,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4,
            child: Center(
              child: CachedNetworkImage(
                imageUrl: widget.photoUrls[index],
                fit: BoxFit.contain,
                errorWidget: (_, __, ___) => const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white54,
                  size: 64,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LineControllers {
  final TextEditingController productName;
  final TextEditingController sku;
  final TextEditingController imei;
  final TextEditingController imei2;
  final TextEditingController serialNumber;
  final TextEditingController modelNumber;
  final TextEditingController color;
  final TextEditingController storage;
  final TextEditingController qty;
  final TextEditingController unitPrice;
  final TextEditingController ocrText;
  final List<String> photoPaths = [];
  bool isOcrLoading = false;
  bool isExpanded = true;
  bool showOcrText = false;

  _LineControllers({required SellOutReportLine line})
      : productName = TextEditingController(text: line.productName),
        sku = TextEditingController(text: line.sku),
        imei = TextEditingController(text: line.imei),
        imei2 = TextEditingController(text: line.imei2),
        serialNumber = TextEditingController(text: line.serialNumber),
        modelNumber = TextEditingController(text: line.modelNumber),
        color = TextEditingController(text: line.color),
        storage = TextEditingController(text: line.storage),
        qty = TextEditingController(text: line.qty.toString()),
        unitPrice =
            TextEditingController(text: line.unitPrice.toStringAsFixed(2)),
        ocrText = TextEditingController();

  void dispose() {
    productName.dispose();
    sku.dispose();
    imei.dispose();
    imei2.dispose();
    serialNumber.dispose();
    modelNumber.dispose();
    color.dispose();
    storage.dispose();
    qty.dispose();
    unitPrice.dispose();
    ocrText.dispose();
  }

  void syncToLine(SellOutReportLine line) {
    line.productName = productName.text.trim();
    line.sku = sku.text.trim();
    line.imei = imei.text.trim();
    line.imei2 = imei2.text.trim();
    line.serialNumber = serialNumber.text.trim();
    line.modelNumber = modelNumber.text.trim();
    line.color = color.text.trim();
    line.storage = storage.text.trim();
    line.qty = int.tryParse(qty.text.trim()) ?? 0;
    line.unitPrice = double.tryParse(unitPrice.text.trim()) ?? 0.0;
  }

  void syncFromLine(SellOutReportLine line) {
    productName.text = line.productName;
    sku.text = line.sku;
    imei.text = line.imei;
    imei2.text = line.imei2;
    serialNumber.text = line.serialNumber;
    modelNumber.text = line.modelNumber;
    color.text = line.color;
    storage.text = line.storage;
    qty.text = line.qty.toString();
    unitPrice.text = line.unitPrice.toStringAsFixed(2);
  }
}

class _SellOutReportCreateScreenState extends State<SellOutReportCreateScreen> {
  late final SellOutReport _report;
  final _imagePicker = ImagePicker();
  final _ocrService = OcrService();
  final _apiService = SellOutApiService();
  final List<String> _invoicePhotoPaths = [];
  final List<String> _iCloudPhotoPaths = [];

  bool _isSubmitting = false;
  bool _isInvoiceExpanded = true;
  bool _isICloudExpanded = true;
  bool _isICloudOcrLoading = false;
  bool _showSerialValidationErrors = false;
  bool _scanningSerial = false;
  bool _showCustomerPhoneError = false;
  bool _showLineNumberErrors = false;

  final _sellerNameCtrl = TextEditingController();
  final _branchNameCtrl = TextEditingController();
  final _customerNameCtrl = TextEditingController();
  final _customerPhoneCtrl = TextEditingController();
  final _serviceTypeCtrl = TextEditingController();
  final _paymentMethodCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _iCloudAccountNameCtrl = TextEditingController();
  final _iCloudAppleIdCtrl = TextEditingController();
  final _iCloudStorageCtrl = TextEditingController();
  final _iCloudTrustedPhoneCtrl = TextEditingController();
  final _iCloudDevicesCtrl = TextEditingController();

  List<_LineControllers> _lineControllers = [];

  bool get _isEditing => widget.existingReport != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingReport;
    if (existing != null) {
      _report = SellOutReport(
        commissionPolicy: widget.commissionPolicy ?? existing.commissionPolicy,
        id: existing.id,
        invoiceNo: existing.invoiceNo,
        originalInvoiceNo: existing.originalInvoiceNo,
        sellerName: existing.sellerName,
        sellerWorkCategory: existing.sellerWorkCategory,
        branchName: existing.branchName,
        customerName: existing.customerName,
        customerPhone: existing.customerPhone,
        serviceType: existing.serviceType,
        paymentMethod: existing.paymentMethod,
        note: existing.note,
        extractedText: existing.extractedText,
        serverTotalAmount: existing.serverTotalAmount,
        createdAt: existing.createdAt,
        lines: existing.lines.map((l) => l.copyWith()).toList(),
        photoUrls: List<String>.from(existing.photoUrls),
        photoIds: List<int?>.from(existing.photoIds),
      );
      _sellerNameCtrl.text = _report.sellerName;
      _branchNameCtrl.text = _report.branchName;
      _customerNameCtrl.text = _report.customerName;
      _customerPhoneCtrl.text = _report.customerPhone;
      _paymentMethodCtrl.text = _report.paymentMethod;
      _noteCtrl.text = _report.note;
      if (_isICloudCustomer) _restoreICloudFields(existing);
    } else {
      _report = SellOutReport(commissionPolicy: widget.commissionPolicy);
      _report.serviceType = widget.serviceType;
      _prefillCurrentUser();
    }
    _serviceTypeCtrl.text = widget.serviceType;
    _rebuildControllers();
    if (_report.commissionPolicy == null) _loadCommissionPolicy();
  }

  CommissionPolicy get _policy =>
      _report.commissionPolicy ?? const CommissionPolicy();
  Future<void> _loadCommissionPolicy() async {
    try {
      final policy = await _apiService.fetchCommissionPolicy();
      if (mounted) setState(() => _report.commissionPolicy = policy);
    } catch (_) {
      if (mounted)
        setState(() => _report.commissionPolicy = const CommissionPolicy());
    }
  }

  Future<void> _prefillCurrentUser() async {
    final preferences = Preferences();
    final sellerName = await preferences.getFullName();
    final branchName = await preferences.getBranchName();

    if (!mounted) return;

    setState(() {
      if (sellerName.trim().isNotEmpty) {
        _sellerNameCtrl.text = sellerName.trim();
        _report.sellerName = sellerName.trim();
      }
      if (branchName.trim().isNotEmpty) {
        _branchNameCtrl.text = branchName.trim();
        _report.branchName = branchName.trim();
      }
    });
  }

  void _rebuildControllers() {
    for (final c in _lineControllers) {
      c.dispose();
    }
    _lineControllers =
        _report.lines.map((l) => _LineControllers(line: l)).toList();
  }

  @override
  void dispose() {
    _ocrService.dispose();
    _sellerNameCtrl.dispose();
    _branchNameCtrl.dispose();
    _customerNameCtrl.dispose();
    _customerPhoneCtrl.dispose();
    _serviceTypeCtrl.dispose();
    _paymentMethodCtrl.dispose();
    _noteCtrl.dispose();
    _iCloudAccountNameCtrl.dispose();
    _iCloudAppleIdCtrl.dispose();
    _iCloudStorageCtrl.dispose();
    _iCloudTrustedPhoneCtrl.dispose();
    _iCloudDevicesCtrl.dispose();
    for (final c in _lineControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _syncHeaderToReport() {
    _report.serviceType = widget.serviceType;
    _report.sellerName = _sellerNameCtrl.text.trim();
    _report.branchName = _branchNameCtrl.text.trim();
    _report.customerName = _customerNameCtrl.text.trim().isEmpty
        ? _sellOutTr('walk_in_customer')
        : _customerNameCtrl.text.trim();
    _report.customerPhone = _customerPhoneCtrl.text.trim();
    _report.paymentMethod = _paymentMethodCtrl.text.trim();
    _report.note = _noteCtrl.text.trim();
    if (_isICloudCustomer) {
      _syncICloudInfoToReport();
    }
  }

  bool get _isICloudCustomer =>
      widget.serviceType == _iCloudCustomerServiceType;

  bool get _requiresSerialNumberValidation {
    final serviceType = widget.serviceType.isNotEmpty
        ? widget.serviceType
        : _report.serviceType;
    return SellOutReport.serialNumberRequiredCanonicalTypes
        .contains(SellOutReport.canonicalServiceType(serviceType));
  }

  Future<void> _scanSerialNumber(_LineControllers ctrls) async {
    if (_scanningSerial || _isSubmitting) return;
    FocusScope.of(context).unfocus();
    setState(() => _scanningSerial = true);
    try {
      final result = await (widget.serialNumberScanner?.call(context) ??
          showCustomQrScanner(context,
              title: _sellOutTr('scan_serial_number')));
      if (!mounted || !_lineControllers.contains(ctrls) || result == null)
        return;
      final serial = result.trim();
      if (serial.isEmpty) return;
      final error = _requiresSerialNumberValidation
          ? _translateSerialNumberError(
              SellOutReport.validateSerialNumber(serial))
          : null;
      if (error != null) {
        _showError(_sellOutTr('validation_error'), error);
        return;
      }
      setState(() {
        ctrls.serialNumber.value = TextEditingValue(
            text: serial,
            selection: TextSelection.collapsed(offset: serial.length));
        _report.lines[_lineControllers.indexOf(ctrls)].serialNumber = serial;
      });
      _refreshCommissionSummary();
    } catch (_) {
      if (mounted)
        _showError(_sellOutTr('scan_serial_number'),
            _sellOutTr('scanner_unavailable'));
    } finally {
      if (mounted) setState(() => _scanningSerial = false);
    }
  }

  String? _serialNumberError(_LineControllers ctrls) {
    if (!_requiresSerialNumberValidation) return null;
    final text = ctrls.serialNumber.text;
    // Don't nag with "required" until the user has tried to submit or typed
    // something — but once they've typed, validate live on every keystroke.
    if (text.isEmpty) {
      return _showSerialValidationErrors
          ? _translateSerialNumberError(
              SellOutReport.validateSerialNumber(text))
          : null;
    }
    return _translateSerialNumberError(
        SellOutReport.validateSerialNumber(text));
  }

  String? _translateSerialNumberError(String? message) {
    if (message == null) return null;
    switch (message) {
      case 'Serial Number is required.':
        return _sellOutTr('serial_required');
      case 'Serial Number must be 6-16 characters.':
        return _sellOutTr('serial_length');
      case 'Serial Number must contain only letters and numbers.':
        return _sellOutTr('serial_letters_numbers');
    }
    return message;
  }

  String? _validateSerialNumbersForDisplay() {
    if (!_report.requiresSerialNumberValidation) return null;
    for (int i = 0; i < _report.lines.length; i++) {
      final message = _translateSerialNumberError(
          SellOutReport.validateSerialNumber(_report.lines[i].serialNumber));
      if (message != null) {
        return _sellOutTrWith('product_serial_error', {
          'product': _sellOutTrWith(
            'product_number',
            {'number': (i + 1).toString()},
          ),
          'error': message,
        });
      }
    }
    return null;
  }

  String? get _customerPhoneError {
    if (!_showCustomerPhoneError) return null;
    final phone = _customerPhoneCtrl.text.trim();
    if (phone.isNotEmpty && phone.length <= 6) {
      return _sellOutTr('more_than_6_chars');
    }
    return null;
  }

  void _onCustomerPhoneChanged(String value) {
    _refreshCommissionSummary();
  }

  String? _quantityError(String text) {
    final quantity = int.tryParse(text.trim());
    return quantity == null || quantity < 1
        ? _sellOutTr('quantity_validation')
        : null;
  }

  String? _unitPriceError(String text) {
    final price = double.tryParse(text.trim());
    return price == null || !price.isFinite || price < 0
        ? _sellOutTr('unit_price_validation')
        : null;
  }

  void _refreshCommissionSummary() {
    _report.customerPhone = _customerPhoneCtrl.text.trim();
    _syncAllLines();
    setState(() {});
  }

  void _syncICloudInfoToReport() {
    final info = _formatICloudInfo();
    final note = _noteCtrl.text.trim();
    _report.note = [
      if (note.isNotEmpty) note,
      if (info.isNotEmpty) 'iCloud Info\n$info',
    ].join('\n\n');
  }

  void _restoreICloudFields(SellOutReport existing) {
    final fields = <String, String>{};
    final block =
        RegExp(r'(?:^|\n\n)iCloud Info\n([\s\S]*)$').firstMatch(existing.note);
    if (block != null) {
      _noteCtrl.text = existing.note.substring(0, block.start).trim();
      String? key;
      for (final row in block.group(1)!.split('\n')) {
        final match = RegExp(
                r'^(Account Name|Apple ID|iCloud Storage|Trusted Phone|Devices):\s*(.*)$')
            .firstMatch(row);
        if (match != null) {
          key = match.group(1)!;
          fields[key] = match.group(2)!;
        } else if (key != null) {
          fields[key] = '${fields[key]}\n$row';
        }
      }
    }
    final line = existing.lines.isEmpty ? null : existing.lines.first;
    final separator = line?.productName.indexOf(' - ') ?? -1;
    final account =
        separator >= 0 ? line!.productName.substring(separator + 3) : '';
    _iCloudAccountNameCtrl.text = fields['Account Name'] ?? account;
    _iCloudAppleIdCtrl.text = fields['Apple ID'] ?? line?.sku ?? '';
    _iCloudStorageCtrl.text = fields['iCloud Storage'] ?? line?.storage ?? '';
    _iCloudTrustedPhoneCtrl.text = fields['Trusted Phone'] ?? '';
    _iCloudDevicesCtrl.text = fields['Devices'] ?? line?.modelNumber ?? '';
  }

  String _formatICloudInfo() {
    final rows = <String>[];
    void add(String label, String value) {
      final cleaned = value.trim();
      if (cleaned.isEmpty) return;
      rows.add('$label: $cleaned');
    }

    add('Account Name', _iCloudAccountNameCtrl.text);
    add('Apple ID', _iCloudAppleIdCtrl.text);
    add('iCloud Storage', _iCloudStorageCtrl.text);
    add('Trusted Phone', _iCloudTrustedPhoneCtrl.text);
    add('Devices', _iCloudDevicesCtrl.text);
    return rows.join('\n');
  }

  void _prepareICloudReportLine() {
    final accountName = _iCloudAccountNameCtrl.text.trim();
    final appleId = _iCloudAppleIdCtrl.text.trim();
    final storage = _iCloudStorageCtrl.text.trim();
    final trustedPhone = _iCloudTrustedPhoneCtrl.text.trim();
    final devices = _iCloudDevicesCtrl.text.trim();

    final label = posServiceLabel('icloud_cus');
    final productName =
        accountName.isNotEmpty ? '$label - $accountName' : label;

    _report.lines = [
      SellOutReportLine(
        productName: productName,
        sku: appleId,
        modelNumber:
            devices.split('\n').where((e) => e.trim().isNotEmpty).join(', '),
        storage: storage,
        qty: 1,
        unitPrice: 0.0,
      ),
    ];

    if (_customerNameCtrl.text.trim().isEmpty && accountName.isNotEmpty) {
      _customerNameCtrl.text = accountName;
      _report.customerName = accountName;
    }
    if (_customerPhoneCtrl.text.trim().isEmpty && trustedPhone.isNotEmpty) {
      _customerPhoneCtrl.text = trustedPhone;
      _report.customerPhone = trustedPhone;
    }
  }

  void _syncAllLines() {
    // Draft edits must use current line totals, not the fetched header snapshot.
    _report.serverTotalAmount = null;
    _report.serverCommission = null;
    for (int i = 0; i < _report.lines.length; i++) {
      if (i < _lineControllers.length) {
        _lineControllers[i].syncToLine(_report.lines[i]);
      }
    }
  }

  Future<String> _cropPhoto(String photoPath) async {
    final cropped = await ImageCropper().cropImage(
      sourcePath: photoPath,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 75,
      maxWidth: 1600,
      maxHeight: 1600,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: _sellOutTr('crop_photo'),
          toolbarColor: _sellOutBlue,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: _sellOutBlue,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
        ),
        IOSUiSettings(
          title: _sellOutTr('crop_photo'),
          doneButtonTitle: _sellOutTr('use_photo'),
          cancelButtonTitle: _sellOutTr('cancel'),
          aspectRatioLockEnabled: false,
        ),
      ],
    );

    return cropped?.path ?? photoPath;
  }

  Future<List<String>> _cropPhotos(Iterable<XFile> photos) async {
    final paths = <String>[];
    for (final photo in photos) {
      paths.add(await _cropPhoto(photo.path));
    }
    return paths;
  }

  Future<void> _takeInvoicePhoto() async {
    final XFile? photo =
        await _imagePicker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      final croppedPhotoPath = await _cropPhoto(photo.path);
      if (!mounted) return;

      setState(() {
        _invoicePhotoPaths.add(croppedPhotoPath);
        _syncPhotoPaths();
      });
    }
  }

  Future<void> _pickInvoiceFromGallery() async {
    final List<XFile> photos = await _imagePicker.pickMultiImage();
    if (photos.isNotEmpty) {
      final croppedPhotoPaths = await _cropPhotos(photos);
      if (!mounted) return;

      setState(() {
        _invoicePhotoPaths.addAll(croppedPhotoPaths);
        _syncPhotoPaths();
      });
    }
  }

  void _removeInvoicePhoto(int index) {
    setState(() {
      _invoicePhotoPaths.removeAt(index);
      _syncPhotoPaths();
    });
  }

  Future<void> _takeProductPhoto(int index) async {
    final XFile? photo =
        await _imagePicker.pickImage(source: ImageSource.camera);
    if (photo != null && index < _lineControllers.length) {
      final croppedPhotoPath = await _cropPhoto(photo.path);
      if (!mounted || index >= _lineControllers.length) return;

      setState(() {
        _lineControllers[index].photoPaths.add(croppedPhotoPath);
        _syncPhotoPaths();
      });
      await _extractProductText(index);
    }
  }

  Future<void> _pickProductFromGallery(int index) async {
    final List<XFile> photos = await _imagePicker.pickMultiImage();
    if (photos.isNotEmpty && index < _lineControllers.length) {
      final croppedPhotoPaths = await _cropPhotos(photos);
      if (!mounted || index >= _lineControllers.length) return;

      setState(() {
        _lineControllers[index].photoPaths.addAll(croppedPhotoPaths);
        _syncPhotoPaths();
      });
      await _extractProductText(index);
    }
  }

  void _removeProductPhoto(int lineIndex, int photoIndex) {
    if (lineIndex >= _lineControllers.length) return;
    setState(() {
      _lineControllers[lineIndex].photoPaths.removeAt(photoIndex);
      _syncPhotoPaths();
    });
  }

  Future<void> _takeICloudPhoto() async {
    final XFile? photo =
        await _imagePicker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      final croppedPhotoPath = await _cropPhoto(photo.path);
      if (!mounted) return;

      setState(() {
        _iCloudPhotoPaths.add(croppedPhotoPath);
        _syncPhotoPaths();
      });
      await _extractICloudText();
    }
  }

  Future<void> _pickICloudFromGallery() async {
    final List<XFile> photos = await _imagePicker.pickMultiImage();
    if (photos.isNotEmpty) {
      final croppedPhotoPaths = await _cropPhotos(photos);
      if (!mounted) return;

      setState(() {
        _iCloudPhotoPaths.addAll(croppedPhotoPaths);
        _syncPhotoPaths();
      });
      await _extractICloudText();
    }
  }

  void _removeICloudPhoto(int index) {
    setState(() {
      _iCloudPhotoPaths.removeAt(index);
      _syncPhotoPaths();
    });
  }

  void _syncPhotoPaths() {
    final invoicePaths = <String>{};
    invoicePaths.addAll(_invoicePhotoPaths);
    invoicePaths.addAll(_iCloudPhotoPaths);

    _report.photoPaths
      ..clear()
      ..addAll(invoicePaths);

    for (int i = 0;
        i < _report.lines.length && i < _lineControllers.length;
        i++) {
      _report.lines[i].photoPaths
        ..clear()
        ..addAll(_lineControllers[i].photoPaths.toSet());
    }
  }

  Future<void> _extractProductText(int index) async {
    if (index >= _lineControllers.length) return;
    final ctrls = _lineControllers[index];
    if (ctrls.photoPaths.isEmpty) {
      _showError(_sellOutTr('no_product_photos'),
          _sellOutTr('no_product_photos_message'));
      return;
    }

    setState(() {
      ctrls.isOcrLoading = true;
      ctrls.showOcrText = true;
      ctrls.ocrText.clear();
    });

    try {
      final extracted =
          await _ocrService.extractTextFromMultipleImages(ctrls.photoPaths);
      ctrls.ocrText.text = _ocrService.formatProductOcrText(extracted);
      _replaceProductExtractedText(index, extracted);
      _autoFillProductLineFromText(index, extracted);
    } catch (e) {
      _showError(_sellOutTr('product_extract_failed'), e.toString());
    } finally {
      setState(() => ctrls.isOcrLoading = false);
    }
  }

  Future<void> _extractICloudText() async {
    if (_iCloudPhotoPaths.isEmpty) {
      _showError(_sellOutTr('no_icloud_photos'),
          _sellOutTr('no_icloud_photos_message'));
      return;
    }

    setState(() => _isICloudOcrLoading = true);

    try {
      final extracted =
          await _ocrService.extractTextFromMultipleImages(_iCloudPhotoPaths);
      _replaceICloudExtractedText(extracted);
      _autoFillICloudInfoFromText(extracted);
    } catch (e) {
      _showError(_sellOutTr('icloud_extract_failed'), e.toString());
    } finally {
      if (mounted) {
        setState(() => _isICloudOcrLoading = false);
      }
    }
  }

  void _autoFillICloudInfoFromText(String rawText) {
    final text = rawText.trim();
    if (text.isEmpty) return;

    final fields = _ocrService.autoDetectICloudFields(text);

    void apply(TextEditingController controller, String key) {
      final value = fields[key]?.trim() ?? '';
      if (value.isEmpty) return;
      controller.text = value;
    }

    apply(_iCloudAccountNameCtrl, 'account_name');
    apply(_iCloudAppleIdCtrl, 'apple_id');
    apply(_iCloudStorageCtrl, 'icloud_storage');
    apply(_iCloudTrustedPhoneCtrl, 'trusted_phone');
    apply(_iCloudDevicesCtrl, 'devices');
    _syncICloudInfoToReport();

    setState(() {});
  }

  void _replaceICloudExtractedText(String text) {
    final block = '--- iCloud Information ---\n$text'.trim();
    final current = _report.extractedText.trim();
    if (current.isEmpty) {
      _report.extractedText = block;
      return;
    }

    final iCloudBlockPattern = RegExp(
      '${RegExp.escape('--- iCloud Information ---')}\\n[\\s\\S]*?(?=\\n\\n--- Product \\d+ ---|\$)',
    );
    if (iCloudBlockPattern.hasMatch(current)) {
      _report.extractedText =
          current.replaceFirst(iCloudBlockPattern, block).trim();
      return;
    }

    _report.extractedText = '$current\n\n$block';
  }

  void _autoFillProductLineFromText(int index, String rawText) {
    if (index >= _report.lines.length || index >= _lineControllers.length) {
      return;
    }
    final text = rawText.trim();
    if (text.isEmpty) return;

    _syncAllLines();

    final fields = _ocrService.autoDetectFields(text);
    final line = _report.lines[index];
    if (fields['product_name']?.isNotEmpty == true) {
      line.productName = fields['product_name']!;
    }
    if (fields['imei']?.isNotEmpty == true) {
      line.imei = fields['imei']!;
    }
    if (fields['imei2']?.isNotEmpty == true) {
      line.imei2 = fields['imei2']!;
    }
    if (fields['serial_number']?.isNotEmpty == true) {
      line.serialNumber = fields['serial_number']!;
    }
    if (fields['color']?.isNotEmpty == true) {
      line.color = fields['color']!;
    }
    if (fields['storage']?.isNotEmpty == true) {
      line.storage = fields['storage']!;
    }
    if (fields['price']?.isNotEmpty == true) {
      final price = double.tryParse(fields['price']!);
      if (price != null) {
        line.unitPrice = price;
      }
    }

    _lineControllers[index].syncFromLine(line);

    _refreshCommissionSummary();
  }

  void _replaceProductExtractedText(int index, String text) {
    final header = '--- Product ${index + 1} ---';
    final block = '$header\n$text'.trim();
    final current = _report.extractedText.trim();
    if (current.isEmpty) {
      _report.extractedText = block;
      return;
    }

    final productBlockPattern = RegExp(
      '${RegExp.escape(header)}\\n[\\s\\S]*?(?=\\n\\n--- Product \\d+ ---|\$)',
    );
    if (productBlockPattern.hasMatch(current)) {
      _report.extractedText =
          current.replaceFirst(productBlockPattern, block).trim();
      return;
    }

    _report.extractedText = '$current\n\n$block';
  }

  void _addProductLine() {
    _syncAllLines();
    setState(() {
      _report.lines.add(SellOutReportLine());
      _lineControllers.add(_LineControllers(line: _report.lines.last));
    });
  }

  void _removeProductLine(int index) {
    if (_report.lines.length <= 1) {
      _showError(
          _sellOutTr('cannot_remove'), _sellOutTr('one_product_required'));
      return;
    }
    _syncAllLines();
    setState(() {
      _lineControllers[index].dispose();
      _lineControllers.removeAt(index);
      _report.lines.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (_isEditing && !widget.existingReport!.isCreatedToday()) {
      _showError(_sellOutTr('update_failed'), _sellOutTr('edit_today_only'));
      return;
    }
    if (!_isICloudCustomer) {
      for (final controllers in _lineControllers) {
        final error = _quantityError(controllers.qty.text) ??
            _unitPriceError(controllers.unitPrice.text);
        if (error != null) {
          setState(() => _showLineNumberErrors = true);
          _showError(_sellOutTr('validation_error'), error);
          return;
        }
      }
    }
    _syncHeaderToReport();
    _syncAllLines();
    if (_isICloudCustomer) {
      _prepareICloudReportLine();
      _syncHeaderToReport();
    }
    _syncPhotoPaths();

    if (_report.sellerName.isEmpty) {
      _showError(_sellOutTr('validation_error'), _sellOutTr('seller_required'));
      return;
    }
    if (_report.customerPhone.isNotEmpty && _report.customerPhone.length <= 6) {
      setState(() => _showCustomerPhoneError = true);
      _showError(
        _sellOutTr('validation_error'),
        _sellOutTr('customer_phone_validation'),
      );
      return;
    }
    final serialError = _validateSerialNumbersForDisplay();
    if (serialError != null) {
      setState(() => _showSerialValidationErrors = true);
      _showError(_sellOutTr('validation_error'), serialError);
      return;
    }
    setState(() => _isSubmitting = true);
    EasyLoading.show(
        status: _isEditing ? _sellOutTr('updating') : _sellOutTr('submitting'));

    try {
      final response = _isEditing
          ? await _apiService.updateReport(_report)
          : await _apiService.submitReport(_report);
      EasyLoading.dismiss();
      setState(() => _isSubmitting = false);

      if (mounted) {
        _showSuccessDialog(response);
      }
    } catch (e) {
      EasyLoading.dismiss();
      setState(() => _isSubmitting = false);
      if (mounted) {
        _showError(
            _isEditing
                ? _sellOutTr('update_failed')
                : _sellOutTr('submission_failed'),
            e.toString());
      }
    }
  }

  void _showSuccessDialog(Map<String, dynamic> response) {
    final message =
        response['message']?.toString() ?? _sellOutTr('submitted_successfully');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            Text(
              _sellOutTr('success'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: HexColor('#011754'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context, true);
            },
            child: Text(
              _sellOutTr('ok'),
              style: TextStyle(
                color: HexColor('#036eb7'),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showError(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: HexColor('#011754'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              _sellOutTr('close'),
              style: TextStyle(
                color: HexColor('#036eb7'),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PremiumBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(_isEditing
              ? _sellOutTr('edit_report')
              : (widget.serviceType.isEmpty
                  ? _sellOutTr('title')
                  : _isICloudCustomer
                      ? posServiceLabel('icloud_cus')
                      : widget.serviceType)),
          centerTitle: true,
          backgroundColor: _sellOutNavy,
          foregroundColor: Colors.white,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeaderForm(),
              const SizedBox(height: 8),
              if (_isICloudCustomer) ...[
                _buildICloudInfoSection(),
                const SizedBox(height: 12),
              ] else ...[
                _buildProductLinesSection(),
                const SizedBox(height: 8),
                _buildTotalSection(),
                const SizedBox(height: 12),
              ],
              _buildSubmitButton(),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: _sellOutText,
        ),
      ),
    );
  }

  Widget _buildCollapseHeader({
    required String title,
    required bool expanded,
    required VoidCallback onTap,
    String? trailingText,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(
          children: [
            Icon(
              expanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
              color: _sellOutBlue,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _sellOutText,
                ),
              ),
            ),
            if (trailingText != null)
              Text(
                trailingText,
                style: const TextStyle(
                  fontSize: 11,
                  color: _sellOutMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderForm() {
    return Card(
      color: _sellOutSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: _sellOutBorder),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCollapseHeader(
              title: _sellOutTr('invoice_information'),
              expanded: _isInvoiceExpanded,
              trailingText: _sellOutTrWith('photo_count',
                  {'count': _invoicePhotoPaths.length.toString()}),
              onTap: () {
                setState(() => _isInvoiceExpanded = !_isInvoiceExpanded);
              },
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  children: [
                    if (widget.serviceType.isNotEmpty) ...[
                      Row(
                        children: [
                          Expanded(
                            child: _buildCompactInfoField(
                              _sellOutTr('service_type'),
                              _displayServiceType(_serviceTypeCtrl.text),
                              Icons.category,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _buildCompactInfoField(
                              _sellOutTr('seller_name'),
                              _sellerNameCtrl.text,
                              Icons.person,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _buildCompactInfoField(
                              _sellOutTr('branch_name'),
                              _branchNameCtrl.text,
                              Icons.business,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: _buildCompactInfoField(
                              _sellOutTr('seller_name'),
                              _sellerNameCtrl.text,
                              Icons.person,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _buildCompactInfoField(
                              _sellOutTr('branch_name'),
                              _branchNameCtrl.text,
                              Icons.business,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            _customerPhoneCtrl,
                            _sellOutTr('customer_phone'),
                            Icons.phone,
                            keyboardType: TextInputType.phone,
                            errorText: _customerPhoneError,
                            onChanged: _onCustomerPhoneChanged,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildTextField(
                            _noteCtrl,
                            _sellOutTr('note'),
                            Icons.note,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildInvoicePhotosSection(),
                  ],
                ),
              ),
              crossFadeState: _isInvoiceExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 180),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactInfoField(String label, String value, IconData icon) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xfff7faff),
        border: Border.all(color: _sellOutBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: _sellOutBlue, size: 16),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _sellOutBlue,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _sellOutText,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon,
      {int maxLines = 1,
      bool readOnly = false,
      TextInputType? keyboardType,
      String? errorText,
      ValueChanged<String>? onChanged}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      readOnly: readOnly,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: const TextStyle(
        color: _sellOutText,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      cursorColor: _sellOutBlue,
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        labelStyle: const TextStyle(
          color: _sellOutMuted,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: const TextStyle(
          color: _sellOutBlue,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        isDense: true,
        prefixIcon: Icon(icon, color: _sellOutBlue, size: 20),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 38, minHeight: 38),
        filled: true,
        fillColor: readOnly ? const Color(0xfff7faff) : Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _sellOutBorder),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _sellOutBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _sellOutBlue, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
    );
  }

  Widget _buildInvoicePhotosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(_sellOutTr('invoice_photos')),
        if (_isEditing && _report.photoUrls.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            _sellOutTrWith('already_uploaded',
                {'count': _report.photoUrls.length.toString()}),
            style: const TextStyle(
              fontSize: 11,
              color: _sellOutMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          _buildUploadedPhotoGrid(
            _report.photoUrls,
            (index) => _removeUploadedPhoto(
                index, _report.photoUrls, _report.photoIds),
          ),
          const SizedBox(height: 6),
        ],
        Row(
          children: [
            Expanded(
              child: _buildPhotoButton(_sellOutTr('take_invoice'),
                  Icons.camera_alt, _takeInvoicePhoto),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildPhotoButton(_sellOutTr('from_gallery'),
                  Icons.photo_library, _pickInvoiceFromGallery),
            ),
          ],
        ),
        if (_invoicePhotoPaths.isNotEmpty) ...[
          const SizedBox(height: 6),
          _buildPhotoGrid(_invoicePhotoPaths, _removeInvoicePhoto),
        ],
        const SizedBox(height: 6),
        Text(
          _sellOutTrWith('invoice_photos_selected',
              {'count': _invoicePhotoPaths.length.toString()}),
          style: const TextStyle(
            fontSize: 11,
            color: _sellOutMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoButton(String label, IconData icon, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: _sellOutBlue,
        backgroundColor: _sellOutBlue.withValues(alpha: 0.06),
        side: BorderSide(color: _sellOutBlue.withValues(alpha: 0.45)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _buildPhotoGrid(List<String> photos, void Function(int) onRemove) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        return Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(photos[index]),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => onRemove(index),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(4),
                  child: const Icon(Icons.close, size: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildUploadedPhotoGrid(
      List<String> photoUrls, void Function(int) onRemove) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: photoUrls.length,
      itemBuilder: (context, index) {
        return Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: photoUrls[index],
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                placeholder: (context, url) => const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: const Color(0xfff7faff),
                  child: const Icon(Icons.broken_image_outlined,
                      color: _sellOutMuted),
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => onRemove(index),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(4),
                  child: const Icon(Icons.close, size: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _removeUploadedPhoto(
    int index,
    List<String> photoUrls,
    List<int?> photoIds,
  ) async {
    final reportId = _report.id;
    final photoId = index < photoIds.length ? photoIds[index] : null;
    if (reportId == null || photoId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_sellOutTr('remove_photo')),
        content: Text(_sellOutTr('remove_photo_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_sellOutTr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_sellOutTr('remove'),
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _apiService.deletePhoto(reportId, photoId);
      setState(() {
        photoUrls.removeAt(index);
        photoIds.removeAt(index);
      });
    } catch (e) {
      if (!mounted) return;
      _showError(_sellOutTr('remove_failed'), e.toString());
    }
  }

  Widget _buildICloudInfoSection() {
    return Card(
      color: _sellOutSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: _sellOutBorder),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCollapseHeader(
              title: _sellOutTr('icloud_information'),
              expanded: _isICloudExpanded,
              trailingText: _sellOutTrWith('photo_count',
                  {'count': _iCloudPhotoPaths.length.toString()}),
              onTap: () {
                setState(() => _isICloudExpanded = !_isICloudExpanded);
              },
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildPhotoButton(
                            _sellOutTr('take_icloud'),
                            Icons.camera_alt,
                            _takeICloudPhoto,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildPhotoButton(
                            _sellOutTr('from_gallery'),
                            Icons.photo_library,
                            _pickICloudFromGallery,
                          ),
                        ),
                      ],
                    ),
                    if (_iCloudPhotoPaths.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildPhotoGrid(_iCloudPhotoPaths, _removeICloudPhoto),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed:
                              _isICloudOcrLoading ? null : _extractICloudText,
                          icon: _isICloudOcrLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.text_fields),
                          label: Text(
                            _isICloudOcrLoading
                                ? _sellOutTr('extracting')
                                : _sellOutTr('extract_autofill_icloud'),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _sellOutBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    _buildTextField(
                      _iCloudAccountNameCtrl,
                      _sellOutTr('account_name'),
                      Icons.account_circle,
                    ),
                    const SizedBox(height: 6),
                    _buildTextField(
                      _iCloudAppleIdCtrl,
                      _sellOutTr('apple_id_email'),
                      Icons.alternate_email,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            _iCloudStorageCtrl,
                            _sellOutTr('icloud_storage'),
                            Icons.cloud_outlined,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildTextField(
                            _iCloudTrustedPhoneCtrl,
                            _sellOutTr('trusted_phone'),
                            Icons.phone_iphone,
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _buildTextField(
                      _iCloudDevicesCtrl,
                      _sellOutTr('devices'),
                      Icons.devices,
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              crossFadeState: _isICloudExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 180),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductLinesSection() {
    return Card(
      color: _sellOutSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: _sellOutBorder),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionTitle(_sellOutTr('product_lines')),
                Text(
                  _sellOutTrWith(
                      'line_count', {'count': _report.lines.length.toString()}),
                  style: const TextStyle(
                    fontSize: 11,
                    color: _sellOutMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            // The form already scrolls. Keep the fields mounted in that same
            // viewport when the keyboard resizes it or reveals a focused field.
            Column(
              children: [
                for (var index = 0; index < _lineControllers.length; index++)
                  _buildProductLineCard(
                      index, _report.lines[index], _lineControllers[index]),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _addProductLine,
                icon: const Icon(Icons.add, size: 18),
                label: Text(_sellOutTr('add_product_line')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _sellOutBlue,
                  backgroundColor: _sellOutBlue.withValues(alpha: 0.06),
                  side: BorderSide(color: _sellOutBlue.withValues(alpha: 0.45)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  textStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductLineCard(
      int index, SellOutReportLine line, _LineControllers ctrls) {
    return Card(
      key: ObjectKey(ctrls),
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: _sellOutBorder),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      setState(() => ctrls.isExpanded = !ctrls.isExpanded);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Icon(
                            ctrls.isExpanded
                                ? Icons.keyboard_arrow_down
                                : Icons.keyboard_arrow_right,
                            color: _sellOutBlue,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              line.productName.trim().isEmpty
                                  ? _sellOutTrWith('product_number',
                                      {'number': (index + 1).toString()})
                                  : line.productName.trim(),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: _sellOutText,
                              ),
                            ),
                          ),
                          Text(
                            '\$${line.subtotal.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: _sellOutBlue,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _removeProductLine(index),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: Text(_sellOutTr('remove')),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                    minimumSize: const Size(0, 34),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 6, color: _sellOutBorder),
                  const SizedBox(height: 4),
                  _buildProductPhotosSection(index, ctrls),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: _buildLineField(
                            ctrls.productName,
                            _sellOutTr('product_name'),
                            (v) => line.productName = v),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _buildLineField(
                            ctrls.imei, 'IMEI', (v) => line.imei = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: _buildLineField(
                          ctrls.serialNumber,
                          _sellOutTr('serial_number'),
                          (v) => line.serialNumber = v,
                          errorText: _serialNumberError(ctrls),
                          suffixIcon: (_report.serviceType.trim().isEmpty ||
                                  {'sell', 'material'}.contains(
                                      SellOutReport.canonicalServiceType(
                                          _report.serviceType)))
                              ? IconButton(
                                  key: ValueKey('sell-serial-scan-$index'),
                                  tooltip: _sellOutTr('scan_serial_number'),
                                  onPressed: _scanningSerial || _isSubmitting
                                      ? null
                                      : () => _scanSerialNumber(ctrls),
                                  icon: const Icon(Icons.qr_code_scanner,
                                      size: 20),
                                  color: _sellOutBlue)
                              : null,
                          keyboardType: TextInputType.visiblePassword,
                          inputFormatters: _requiresSerialNumberValidation
                              ? [
                                  FilteringTextInputFormatter.allow(
                                      RegExp(r'[A-Za-z0-9]')),
                                  LengthLimitingTextInputFormatter(16),
                                ]
                              : null,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _buildLineField(ctrls.color, _sellOutTr('color'),
                            (v) => line.color = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: _buildLineField(ctrls.storage,
                            _sellOutTr('storage'), (v) => line.storage = v),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _buildLineField(ctrls.qty, _sellOutTr('qty'),
                            (v) => line.qty = int.tryParse(v) ?? 0,
                            errorText: _showLineNumberErrors
                                ? _quantityError(ctrls.qty.text)
                                : null,
                            keyboardType: TextInputType.number),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _buildLineField(
                            ctrls.unitPrice,
                            _sellOutTr('unit_price'),
                            (v) => line.unitPrice = double.tryParse(v) ?? 0.0,
                            errorText: _showLineNumberErrors
                                ? _unitPriceError(ctrls.unitPrice.text)
                                : null,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _sellOutTrWith('subtotal_value',
                        {'amount': line.subtotal.toStringAsFixed(2)}),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: _sellOutBlue,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              crossFadeState: ctrls.isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 180),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductPhotosSection(int index, _LineControllers ctrls) {
    final line = _report.lines[index];
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xfff7faff),
        border: Border.all(color: const Color(0xffe5edf8)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _sellOutTr('product_photos'),
            style: const TextStyle(
              color: _sellOutText,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          if (_isEditing && line.photoUrls.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              _sellOutTrWith('already_uploaded',
                  {'count': line.photoUrls.length.toString()}),
              style: const TextStyle(
                fontSize: 11,
                color: _sellOutMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            _buildUploadedPhotoGrid(
              line.photoUrls,
              (photoIndex) => _removeUploadedPhoto(
                  photoIndex, line.photoUrls, line.photoIds),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _buildPhotoButton(
                  _sellOutTr('take_product'),
                  Icons.camera_alt,
                  () => _takeProductPhoto(index),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildPhotoButton(
                  _sellOutTr('from_gallery'),
                  Icons.photo_library,
                  () => _pickProductFromGallery(index),
                ),
              ),
              const SizedBox(width: 6),
              TextButton.icon(
                onPressed: () {
                  setState(() => ctrls.showOcrText = !ctrls.showOcrText);
                },
                icon: Icon(
                  ctrls.showOcrText ? Icons.visibility_off : Icons.visibility,
                  size: 16,
                ),
                label: Text(ctrls.showOcrText
                    ? _sellOutTr('hide')
                    : _sellOutTr('text')),
                style: TextButton.styleFrom(
                  foregroundColor: _sellOutBlue,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (ctrls.photoPaths.isNotEmpty) ...[
            const SizedBox(height: 6),
            _buildPhotoGrid(
              ctrls.photoPaths,
              (photoIndex) => _removeProductPhoto(index, photoIndex),
            ),
          ],
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Column(
              children: [
                TextField(
                  controller: ctrls.ocrText,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: _sellOutTr('product_text'),
                    hintText: _sellOutTr('product_text_hint'),
                    alignLabelWithHint: true,
                    filled: true,
                    fillColor: Colors.white,
                    labelStyle:
                        const TextStyle(color: _sellOutMuted, fontSize: 12),
                    floatingLabelStyle: const TextStyle(
                      color: _sellOutBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    hintStyle:
                        const TextStyle(color: _sellOutMuted, fontSize: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _sellOutBorder),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: _sellOutBlue, width: 1.5),
                    ),
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  ),
                  style: const TextStyle(color: _sellOutText, fontSize: 12),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: ctrls.isOcrLoading
                        ? null
                        : () => _extractProductText(index),
                    icon: ctrls.isOcrLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.text_fields),
                    label: Text(
                      ctrls.isOcrLoading
                          ? _sellOutTr('extracting')
                          : _sellOutTr('extract_autofill_product'),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _sellOutBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ),
            crossFadeState: ctrls.showOcrText
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
        ],
      ),
    );
  }

  Widget _buildLineField(TextEditingController controller, String label,
      Function(String) onChanged,
      {String? errorText,
      Widget? suffixIcon,
      TextInputType? keyboardType,
      List<TextInputFormatter>? inputFormatters}) {
    return TextField(
      controller: controller,
      onChanged: (v) {
        onChanged(v);
        _refreshCommissionSummary();
      },
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        suffixIcon: suffixIcon,
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        labelStyle: const TextStyle(color: _sellOutMuted, fontSize: 12),
        floatingLabelStyle: const TextStyle(
          color: _sellOutBlue,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _sellOutBorder),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _sellOutBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _sellOutBlue, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      ),
      cursorColor: _sellOutBlue,
      style: const TextStyle(
        color: _sellOutText,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  String _commissionStatusText() {
    if (_report.commissionPolicy != null)
      return _report.isCommissionEligible
          ? _sellOutTr('earned')
          : _sellOutTr('not_earned_yet');
    if (_report.isCommissionEligible) return _sellOutTr('earned');
    if (!_report.isCommissionable) {
      return _sellOutTr('not_earned_no_commission');
    }

    final incompletePoints = <String>[
      if (!_report.hasValidCustomerPhone) _sellOutTr('customer_phone'),
      if (!_report.hasValidMaterialInvoiceTotal)
        _sellOutTr('invoice_total_at_least_10'),
      if (!_report.hasQualifiedSellQty)
        _sellOutTrWith(
          'sell_qty_at_least',
          {'threshold': _report.sellQtyThreshold.toString()},
        ),
    ];

    if (incompletePoints.isEmpty) return _sellOutTr('not_earned_yet');
    return _sellOutTrWith(
      'not_complete',
      {'conditions': incompletePoints.join(', ')},
    );
  }

  void _showCommissionRules() => showServerCommissionRules(context, _policy);

  Widget _buildTotalSection() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 0,
      color: _sellOutNavy,
      surfaceTintColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _sellOutTr('summary'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (_policy.canCalculate)
                  IconButton(
                    tooltip: _sellOutTr('view_commission_rules'),
                    onPressed: _showCommissionRules,
                    icon: const Icon(
                      Icons.rule_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _sellOutTr('total_qty'),
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
                Text(
                  _report.totalQty.toString(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _sellOutTr('total_amount'),
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
                Text(
                  '\$${_report.totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            if (_policy.canCalculate) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _sellOutTr('commission'),
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                  Text(
                    '\$${_report.commission.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _commissionStatusText(),
                style: TextStyle(
                  fontSize: 11,
                  color: _report.isCommissionEligible
                      ? const Color(0xffb8f5d0)
                      : Colors.white70,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSubmitting ? null : _submit,
        icon: _isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.send),
        label: Text(_isSubmitting
            ? (_isEditing ? _sellOutTr('updating') : _sellOutTr('submitting'))
            : (_isEditing
                ? _sellOutTr('update_report')
                : _sellOutTr('submit_report'))),
        style: ElevatedButton.styleFrom(
          backgroundColor: _sellOutBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
