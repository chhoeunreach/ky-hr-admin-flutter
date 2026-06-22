import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/models/sell_out_report.dart';
import 'package:cnattendance/models/sell_out_report_line.dart';
import 'package:cnattendance/screen/invoice_live_text_scanner_screen.dart';
import 'package:cnattendance/services/ocr_service.dart';
import 'package:cnattendance/services/sell_out_api_service.dart';
import 'package:cnattendance/widget/premium_background.dart';

const Color _sellOutNavy = Color(0xff011754);
const Color _sellOutBlue = Color(0xff036eb7);
const Color _sellOutSurface = Colors.white;
const Color _sellOutText = Color(0xff172033);
const Color _sellOutMuted = Color(0xff697386);
const Color _sellOutBorder = Color(0xffdde6f2);
const String _iCloudCustomerServiceType = 'iCloud Cus';

class SellOutReportScreen extends StatefulWidget {
  static const String routeName = '/sell-out-report';

  final String serviceType;

  const SellOutReportScreen({Key? key, this.serviceType = ''})
      : super(key: key);

  @override
  State<SellOutReportScreen> createState() => _SellOutReportListScreenState();
}

class _SellOutReportListScreenState extends State<SellOutReportScreen> {
  final _apiService = SellOutApiService();
  late Future<List<SellOutReport>> _reportsFuture;
  late DateTimeRange _dateRange;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    _dateRange = DateTimeRange(start: todayDate, end: todayDate);
    _reportsFuture = _apiService.fetchReports();
  }

  Future<void> _refresh() async {
    setState(() {
      _reportsFuture = _apiService.fetchReports();
    });
    await _reportsFuture;
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SellOutReportCreateScreen(
          serviceType: widget.serviceType,
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
      setState(() => _dateRange = DateTimeRange(
            start: _dateOnly(selected.start),
            end: _dateOnly(selected.end),
          ));
    }
  }

  void _resetDateRangeToToday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    setState(() => _dateRange = DateTimeRange(start: today, end: today));
  }

  @override
  Widget build(BuildContext context) {
    return PremiumBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(widget.serviceType.isEmpty
              ? 'Sell Out Report'
              : 'Sell Out - ${widget.serviceType}'),
          centerTitle: true,
          backgroundColor: _sellOutNavy,
          foregroundColor: Colors.white,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          elevation: 0,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: _openCreate,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text(
                  'Add New',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
        body: FutureBuilder<List<SellOutReport>>(
          future: _reportsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _buildErrorState(snapshot.error.toString());
            }

            final reports = snapshot.data ?? [];
            final filteredReports = _filterReportsByDate(reports);
            return RefreshIndicator(
              color: _sellOutBlue,
              onRefresh: _refresh,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 104),
                itemCount:
                    filteredReports.isEmpty ? 2 : filteredReports.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildFilterSummary(filteredReports);
                  }
                  if (index == 1 && filteredReports.isEmpty) {
                    return _buildEmptyCard();
                  }
                  return _buildReportCard(filteredReports[index - 1]);
                },
              ),
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openCreate,
          backgroundColor: _sellOutBlue,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          elevation: 3,
          label: const Text(
            'Add New',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  List<SellOutReport> _filterReportsByDate(List<SellOutReport> reports) {
    return reports.where((report) {
      if (widget.serviceType.isNotEmpty &&
          report.serviceType != widget.serviceType) {
        return false;
      }
      final created = DateTime.tryParse(report.createdAt);
      if (created == null) return false;
      final createdDate = _dateOnly(created.toLocal());
      return !createdDate.isBefore(_dateRange.start) &&
          !createdDate.isAfter(_dateRange.end);
    }).toList();
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  Widget _buildFilterSummary(List<SellOutReport> reports) {
    final totalQty =
        reports.fold<int>(0, (sum, report) => sum + report.totalQty);

    return Card(
      color: _sellOutSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: _sellOutBorder),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _sellOutBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.assessment_outlined,
                    color: _sellOutBlue,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sell Summary',
                        style: TextStyle(
                          color: _sellOutText,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDateRange(_dateRange),
                        style: const TextStyle(
                          color: _sellOutMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildDateAction(
                  tooltip: 'Today',
                  icon: Icons.today_outlined,
                  onPressed: _resetDateRangeToToday,
                ),
                const SizedBox(width: 8),
                _buildDateAction(
                  tooltip: 'Filter date',
                  icon: Icons.date_range_outlined,
                  onPressed: _pickDateRange,
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: (constraints.maxWidth - 10) / 2,
                      child: _buildSummaryTile(
                        'Reports',
                        reports.length.toString(),
                        Icons.receipt_long_outlined,
                      ),
                    ),
                    SizedBox(
                      width: (constraints.maxWidth - 10) / 2,
                      child: _buildSummaryTile(
                        'Qty',
                        totalQty.toString(),
                        Icons.inventory_2_outlined,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateAction({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: _sellOutBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, color: _sellOutBlue, size: 21),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryTile(String label, String value, IconData icon) {
    return Container(
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xfff7faff),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xffe5edf8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _sellOutBlue, size: 20),
          const SizedBox(height: 14),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _sellOutNavy,
              fontWeight: FontWeight.w800,
              fontSize: value.length > 8 ? 15 : 18,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _sellOutMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateRange(DateTimeRange range) {
    final start = _formatDateOnly(range.start);
    final end = _formatDateOnly(range.end);
    return start == end ? start : '$start to $end';
  }

  String _formatDateOnly(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
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
              'Unable to load sell out reports',
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
              label: const Text('Retry'),
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
            const Text(
              'No sell out reports found',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _sellOutText,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try another date range or add a new report.',
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
              label: const Text('Add New'),
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

  Widget _buildReportCard(SellOutReport report) {
    final originalInvoice = report.originalInvoiceNo.isNotEmpty
        ? report.originalInvoiceNo
        : _extractOriginalInvoiceFromNote(report.note);

    return Card(
      color: _sellOutSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: _sellOutBorder),
      ),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _openDetail(report),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      report.invoiceNo.isEmpty
                          ? 'Invoice pending'
                          : report.invoiceNo,
                      style: TextStyle(
                        color: _sellOutText,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Text(
                    '\$${report.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: _sellOutBlue,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              if (originalInvoice.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Original: $originalInvoice',
                  style: const TextStyle(color: _sellOutMuted, fontSize: 12),
                ),
              ],
              if (report.lines.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...report.lines.map(_buildReportLineSummary),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _buildChip(Icons.people,
                      report.customerName.isEmpty ? '-' : report.customerName),
                  if (report.customerPhone.isNotEmpty)
                    _buildChip(Icons.phone, report.customerPhone),
                  _buildChip(Icons.inventory_2, '${report.itemCount} item(s)'),
                  _buildChip(Icons.payments_outlined,
                      'Commission \$${report.commission.toStringAsFixed(2)}'),
                ],
              ),
              if (report.createdAt.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  _formatDate(report.createdAt),
                  style: const TextStyle(color: _sellOutMuted, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportLineSummary(SellOutReportLine line) {
    final productName =
        line.productName.trim().isEmpty ? 'Product pending' : line.productName;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              productName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _sellOutText,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Qty ${line.qty}',
            style: const TextStyle(
              color: _sellOutMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '\$${line.unitPrice.toStringAsFixed(2)}',
            style: const TextStyle(
              color: _sellOutBlue,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: _sellOutBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _sellOutBlue.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _sellOutBlue),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: _sellOutText,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    return '${parsed.year.toString().padLeft(4, '0')}-'
        '${parsed.month.toString().padLeft(2, '0')}-'
        '${parsed.day.toString().padLeft(2, '0')} '
        '${parsed.hour.toString().padLeft(2, '0')}:'
        '${parsed.minute.toString().padLeft(2, '0')}';
  }

  String _extractOriginalInvoiceFromNote(String note) {
    final match = RegExp(r'Invoice:\s*([A-Za-z0-9\-]+)', caseSensitive: false)
        .firstMatch(note);
    return match?.group(1) ?? '';
  }
}

class SellOutReportCreateScreen extends StatefulWidget {
  final String serviceType;

  const SellOutReportCreateScreen({Key? key, this.serviceType = ''})
      : super(key: key);

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
          title: const Text('Sell Out Detail'),
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
                  'Header',
                  [
                    _detailRow('Invoice', report.invoiceNo),
                    _detailRow('Original Invoice', report.originalInvoiceNo),
                    _detailRow('Seller', report.sellerName),
                    _detailRow('Branch', report.branchName),
                    _detailRow('Customer', report.customerName),
                    _detailRow('Customer Phone', report.customerPhone),
                    _detailRow('Service Type', report.serviceType),
                    _detailRow('Payment', report.paymentMethod),
                    _detailRow(
                        'Total', '\$${report.totalAmount.toStringAsFixed(2)}'),
                    _detailRow('Commission',
                        '\$${report.commission.toStringAsFixed(2)}'),
                    _detailRow('Created At', report.createdAt),
                  ],
                ),
                const SizedBox(height: 12),
                _detailCard(
                  'Product Lines',
                  report.lines.map((line) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            line.productName.isEmpty
                                ? 'Product'
                                : line.productName,
                            style: TextStyle(
                              color: HexColor('#011754'),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _detailRow('SKU', line.sku),
                          _detailRow('IMEI', line.imei),
                          _detailRow('IMEI2', line.imei2),
                          _detailRow('Serial', line.serialNumber),
                          _detailRow('Model', line.modelNumber),
                          _detailRow('Color', line.color),
                          _detailRow('Storage', line.storage),
                          _detailRow('Qty', line.qty.toString()),
                          _detailRow('Unit Price',
                              '\$${line.unitPrice.toStringAsFixed(2)}'),
                          _detailRow('Subtotal',
                              '\$${line.subtotal.toStringAsFixed(2)}'),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                if (report.photoUrls.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildPhotoUrlCard(report.photoUrls),
                ],
                if (report.note.isNotEmpty ||
                    report.extractedText.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _detailCard(
                    'Notes',
                    [
                      if (report.note.isNotEmpty)
                        _textBlock('Note', report.note),
                      if (report.extractedText.isNotEmpty)
                        _textBlock('OCR Text', report.extractedText),
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

  Widget _buildPhotoUrlCard(List<String> photoUrls) {
    return _detailCard(
      'Photos',
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
            return ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                photoUrls[index],
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            );
          },
        ),
      ],
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
  final _report = SellOutReport();
  final _imagePicker = ImagePicker();
  final _ocrService = OcrService();
  final _apiService = SellOutApiService();
  final _extractedTextController = TextEditingController();
  final _iCloudOcrTextController = TextEditingController();
  final List<String> _invoicePhotoPaths = [];
  final List<String> _iCloudPhotoPaths = [];

  bool _isInvoiceOcrLoading = false;
  bool _isICloudOcrLoading = false;
  bool _isSubmitting = false;
  bool _isInvoiceExpanded = true;
  bool _isICloudExpanded = true;
  bool _showInvoiceOcrText = false;
  bool _showICloudOcrText = false;

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

  @override
  void initState() {
    super.initState();
    _report.serviceType = widget.serviceType;
    _serviceTypeCtrl.text = widget.serviceType;
    _rebuildControllers();
    _prefillCurrentUser();
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
    _extractedTextController.dispose();
    _iCloudOcrTextController.dispose();
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
        ? 'Walk-In Customer'
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

  void _syncICloudInfoToReport() {
    final info = _formatICloudInfo();
    final note = _noteCtrl.text.trim();
    _report.note = [
      if (note.isNotEmpty) note,
      if (info.isNotEmpty) 'iCloud Info\n$info',
    ].join('\n\n');

    final ocrText = _iCloudOcrTextController.text.trim();
    final current = _report.extractedText.trim();
    const header = '--- iCloud Info ---';
    final block = ocrText.isEmpty ? '' : '$header\n$ocrText';
    if (block.isEmpty) return;

    final iCloudBlockPattern = RegExp(
      '${RegExp.escape(header)}\\n[\\s\\S]*?(?=\\n\\n--- Product \\d+ ---|\$)',
    );
    if (iCloudBlockPattern.hasMatch(current)) {
      _report.extractedText =
          current.replaceFirst(iCloudBlockPattern, block).trim();
      return;
    }

    _report.extractedText = [
      if (current.isNotEmpty) current,
      block,
    ].join('\n\n');
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

    final productName =
        accountName.isNotEmpty ? 'iCloud Cus - $accountName' : 'iCloud Cus';

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
      compressQuality: 92,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Photo',
          toolbarColor: _sellOutBlue,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: _sellOutBlue,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
        ),
        IOSUiSettings(
          title: 'Crop Photo',
          doneButtonTitle: 'Use Photo',
          cancelButtonTitle: 'Cancel',
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
    final result = await Navigator.push<InvoiceLiveTextResult>(
      context,
      MaterialPageRoute(
        builder: (_) => const InvoiceLiveTextScannerScreen(),
      ),
    );
    if (result == null) return;

    final croppedPhotoPath = await _cropPhoto(result.photoPath);
    if (!mounted) return;

    setState(() {
      _invoicePhotoPaths.add(croppedPhotoPath);
      _syncPhotoPaths();
      _showInvoiceOcrText = true;
    });

    final scannerText = result.text.trim();
    if (scannerText.isNotEmpty) {
      _extractedTextController.text = scannerText;
      _report.extractedText = scannerText;
      _autoFillInvoiceFromText(scannerText);
    } else {
      await _extractInvoiceText();
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
      await _extractInvoiceText();
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
    final allPaths = <String>[];
    allPaths.addAll(_invoicePhotoPaths);
    allPaths.addAll(_iCloudPhotoPaths);
    for (final ctrls in _lineControllers) {
      allPaths.addAll(ctrls.photoPaths);
    }

    _report.photoPaths
      ..clear()
      ..addAll(allPaths.toSet());
  }

  Future<void> _extractInvoiceText() async {
    if (_invoicePhotoPaths.isEmpty) {
      _showError(
          'No Invoice Photos', 'Please take or select invoice photos first.');
      return;
    }

    setState(() {
      _isInvoiceOcrLoading = true;
      _showInvoiceOcrText = true;
      _extractedTextController.clear();
      _report.extractedText = '';
    });

    try {
      final extracted =
          await _ocrService.extractTextFromMultipleImages(_invoicePhotoPaths);
      _extractedTextController.text = extracted;
      _report.extractedText = extracted;
      _autoFillInvoiceFromText(extracted);
    } catch (e) {
      _showError('Invoice OCR Failed', e.toString());
    } finally {
      setState(() => _isInvoiceOcrLoading = false);
    }
  }

  void _autoFillInvoiceFromText(String rawText) {
    final text = rawText.trim();
    if (text.isEmpty) {
      return;
    }

    final fields = _ocrService.autoDetectFields(text);

    if (fields['customer_name']?.isNotEmpty == true) {
      _customerNameCtrl.text = fields['customer_name']!;
      _report.customerName = fields['customer_name']!;
    }
    if (fields['phone_number']?.isNotEmpty == true) {
      _customerPhoneCtrl.text = fields['phone_number']!;
      _report.customerPhone = fields['phone_number']!;
    }
    if (fields['invoice_no']?.isNotEmpty == true &&
        !_noteCtrl.text.contains(fields['invoice_no']!)) {
      _appendNoteLine('Invoice: ${fields['invoice_no']}');
    }
  }

  void _autoFillInvoiceFromOcr() {
    final text = _extractedTextController.text.trim();
    if (text.isEmpty) {
      _showError('No Invoice OCR Text', 'Extract invoice text first.');
      return;
    }

    _autoFillInvoiceFromText(text);
    setState(() {});
  }

  Future<void> _copyInvoiceOcrText() async {
    final text = _extractedTextController.text.trim();
    if (text.isEmpty) {
      _showError('No Invoice OCR Text', 'Extract invoice text first.');
      return;
    }

    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invoice OCR text copied'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _extractICloudText() async {
    if (_iCloudPhotoPaths.isEmpty) {
      _showError(
          'No iCloud Photos', 'Please take or select iCloud photos first.');
      return;
    }

    setState(() {
      _isICloudOcrLoading = true;
      _showICloudOcrText = true;
      _iCloudOcrTextController.clear();
    });

    try {
      final extracted =
          await _ocrService.extractTextFromMultipleImages(_iCloudPhotoPaths);
      _iCloudOcrTextController.text =
          _ocrService.formatICloudOcrText(extracted);
      _autoFillICloudFromText(extracted);
    } catch (e) {
      _showError('iCloud OCR Failed', e.toString());
    } finally {
      setState(() => _isICloudOcrLoading = false);
    }
  }

  void _autoFillICloudFromText(String rawText) {
    final fields = _ocrService.autoDetectICloudFields(rawText);
    if (fields['account_name']?.isNotEmpty == true) {
      _iCloudAccountNameCtrl.text = fields['account_name']!;
    }
    if (fields['apple_id']?.isNotEmpty == true) {
      _iCloudAppleIdCtrl.text = fields['apple_id']!;
    }
    if (fields['icloud_storage']?.isNotEmpty == true) {
      _iCloudStorageCtrl.text = fields['icloud_storage']!;
    }
    if (fields['trusted_phone']?.isNotEmpty == true) {
      _iCloudTrustedPhoneCtrl.text = fields['trusted_phone']!;
      if (_customerPhoneCtrl.text.trim().isEmpty) {
        _customerPhoneCtrl.text = fields['trusted_phone']!;
        _report.customerPhone = fields['trusted_phone']!;
      }
    }
    if (fields['devices']?.isNotEmpty == true) {
      _iCloudDevicesCtrl.text = fields['devices']!;
    }
    setState(() {});
  }

  void _autoFillICloudFromOcr() {
    final text = _iCloudOcrTextController.text.trim();
    if (text.isEmpty) {
      _showError('No iCloud OCR Text', 'Extract iCloud text first.');
      return;
    }
    _autoFillICloudFromText(text);
  }

  Future<void> _extractProductText(int index) async {
    if (index >= _lineControllers.length) return;
    final ctrls = _lineControllers[index];
    if (ctrls.photoPaths.isEmpty) {
      _showError(
          'No Product Photos', 'Please take or select product photos first.');
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
      _showError('Product OCR Failed', e.toString());
    } finally {
      setState(() => ctrls.isOcrLoading = false);
    }
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
    if (fields['model_number']?.isNotEmpty == true) {
      line.modelNumber = fields['model_number']!;
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

    setState(() {});
  }

  void _autoFillProductFromOcr(int index) {
    if (index >= _lineControllers.length) return;
    final text = _lineControllers[index].ocrText.text.trim();
    if (text.isEmpty) {
      _showError('No Product OCR Text', 'Extract product text first.');
      return;
    }
    _autoFillProductLineFromText(index, text);
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

  void _appendNoteLine(String line) {
    final current = _noteCtrl.text.trim();
    _noteCtrl.text = current.isEmpty ? line : '$current\n$line';
    _report.note = _noteCtrl.text.trim();
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
      _showError('Cannot Remove', 'At least one product line is required.');
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
    _syncHeaderToReport();
    _syncAllLines();
    if (_isICloudCustomer) {
      _prepareICloudReportLine();
      _syncHeaderToReport();
    }
    _syncPhotoPaths();

    if (_report.sellerName.isEmpty) {
      _showError('Validation Error', 'Seller name is required.');
      return;
    }
    setState(() => _isSubmitting = true);
    EasyLoading.show(status: 'Submitting...');

    try {
      final response = await _apiService.submitReport(_report);
      EasyLoading.dismiss();
      setState(() => _isSubmitting = false);

      if (mounted) {
        _showSuccessDialog(response);
      }
    } catch (e) {
      EasyLoading.dismiss();
      setState(() => _isSubmitting = false);
      if (mounted) {
        _showError('Submission Failed', e.toString());
      }
    }
  }

  void _showSuccessDialog(Map<String, dynamic> response) {
    final message = response['message']?.toString() ??
        'Sell Out Report submitted successfully!';
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
              'Success',
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
              'OK',
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
              'Close',
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
          title: Text(widget.serviceType.isEmpty
              ? 'Sell Out Report'
              : 'Sell Out - ${widget.serviceType}'),
          centerTitle: true,
          backgroundColor: _sellOutNavy,
          foregroundColor: Colors.white,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeaderForm(),
              const SizedBox(height: 16),
              if (_isICloudCustomer) ...[
                _buildICloudInfoSection(),
                const SizedBox(height: 24),
              ] else ...[
                _buildProductLinesSection(),
                const SizedBox(height: 16),
                _buildTotalSection(),
                const SizedBox(height: 24),
              ],
              _buildSubmitButton(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
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
        padding: const EdgeInsets.symmetric(vertical: 2),
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
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _sellOutText,
                ),
              ),
            ),
            if (trailingText != null)
              Text(
                trailingText,
                style: const TextStyle(
                  fontSize: 13,
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCollapseHeader(
              title: 'Invoice Information',
              expanded: _isInvoiceExpanded,
              trailingText: '${_invoicePhotoPaths.length} photo(s)',
              onTap: () {
                setState(() => _isInvoiceExpanded = !_isInvoiceExpanded);
              },
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  children: [
                    if (widget.serviceType.isNotEmpty) ...[
                      _buildTextField(
                        _serviceTypeCtrl,
                        'Service Type',
                        Icons.category,
                        readOnly: true,
                      ),
                      const SizedBox(height: 12),
                    ],
                    _buildTextField(
                      _sellerNameCtrl,
                      'Seller Name',
                      Icons.person,
                      readOnly: true,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      _branchNameCtrl,
                      'Branch Name',
                      Icons.business,
                      readOnly: true,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      _customerPhoneCtrl,
                      'Customer Phone',
                      Icons.phone,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(_noteCtrl, 'Note', Icons.note, maxLines: 3),
                    const SizedBox(height: 16),
                    _buildInvoiceOcrContent(),
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

  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon,
      {int maxLines = 1, bool readOnly = false, TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      readOnly: readOnly,
      keyboardType: keyboardType,
      style: const TextStyle(
        color: _sellOutText,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      cursorColor: _sellOutBlue,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: _sellOutMuted,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: const TextStyle(
          color: _sellOutBlue,
          fontWeight: FontWeight.w700,
        ),
        prefixIcon: Icon(icon, color: _sellOutBlue),
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _buildInvoiceOcrContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Invoice Photos'),
        Row(
          children: [
            Expanded(
              child: _buildPhotoButton(
                  'Take Invoice', Icons.camera_alt, _takeInvoicePhoto),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildPhotoButton(
                  'From Gallery', Icons.photo_library, _pickInvoiceFromGallery),
            ),
          ],
        ),
        if (_invoicePhotoPaths.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildPhotoGrid(_invoicePhotoPaths, _removeInvoicePhoto),
        ],
        const SizedBox(height: 8),
        Text(
          '${_invoicePhotoPaths.length} invoice photo(s) selected',
          style: const TextStyle(
            fontSize: 12,
            color: _sellOutMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () {
              setState(() => _showInvoiceOcrText = !_showInvoiceOcrText);
            },
            icon: Icon(
              _showInvoiceOcrText ? Icons.visibility_off : Icons.visibility,
              size: 18,
            ),
            label:
                Text(_showInvoiceOcrText ? 'Hide OCR Text' : 'Show OCR Text'),
            style: TextButton.styleFrom(
              foregroundColor: _sellOutBlue,
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Column(
            children: [
              TextField(
                controller: _extractedTextController,
                enableInteractiveSelection: true,
                maxLines: 5,
                onChanged: (value) => _report.extractedText = value,
                decoration: InputDecoration(
                  labelText: 'Invoice OCR Text',
                  hintText: 'Invoice OCR text will appear here...',
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: Colors.white,
                  labelStyle: const TextStyle(color: _sellOutMuted),
                  floatingLabelStyle: const TextStyle(
                    color: _sellOutBlue,
                    fontWeight: FontWeight.w700,
                  ),
                  hintStyle: const TextStyle(color: _sellOutMuted),
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
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                style: const TextStyle(color: _sellOutText, fontSize: 13),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isInvoiceOcrLoading ? null : _extractInvoiceText,
                  icon: _isInvoiceOcrLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.text_fields),
                  label: Text(_isInvoiceOcrLoading
                      ? 'Extracting...'
                      : 'Extract Invoice Info'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _sellOutBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _autoFillInvoiceFromOcr,
                  icon: const Icon(Icons.auto_fix_high, size: 18),
                  label: const Text('Auto Fill Invoice Info'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _sellOutBlue,
                    backgroundColor: _sellOutBlue.withValues(alpha: 0.06),
                    side:
                        BorderSide(color: _sellOutBlue.withValues(alpha: 0.45)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _copyInvoiceOcrText,
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy OCR Text'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _sellOutBlue,
                    backgroundColor: _sellOutBlue.withValues(alpha: 0.06),
                    side:
                        BorderSide(color: _sellOutBlue.withValues(alpha: 0.45)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
          crossFadeState: _showInvoiceOcrText
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 180),
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
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: _sellOutBlue,
        backgroundColor: _sellOutBlue.withValues(alpha: 0.06),
        side: BorderSide(color: _sellOutBlue.withValues(alpha: 0.45)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCollapseHeader(
              title: 'iCloud Information',
              expanded: _isICloudExpanded,
              trailingText: '${_iCloudPhotoPaths.length} photo(s)',
              onTap: () {
                setState(() => _isICloudExpanded = !_isICloudExpanded);
              },
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildPhotoButton(
                            'Take iCloud',
                            Icons.camera_alt,
                            _takeICloudPhoto,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildPhotoButton(
                            'From Gallery',
                            Icons.photo_library,
                            _pickICloudFromGallery,
                          ),
                        ),
                      ],
                    ),
                    if (_iCloudPhotoPaths.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildPhotoGrid(_iCloudPhotoPaths, _removeICloudPhoto),
                    ],
                    const SizedBox(height: 12),
                    _buildTextField(
                      _iCloudAccountNameCtrl,
                      'Account Name',
                      Icons.account_circle,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      _iCloudAppleIdCtrl,
                      'Apple ID / Email',
                      Icons.alternate_email,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            _iCloudStorageCtrl,
                            'iCloud Storage',
                            Icons.cloud_outlined,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildTextField(
                            _iCloudTrustedPhoneCtrl,
                            'Trusted Phone',
                            Icons.phone_iphone,
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      _iCloudDevicesCtrl,
                      'Devices',
                      Icons.devices,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () {
                          setState(
                              () => _showICloudOcrText = !_showICloudOcrText);
                        },
                        icon: Icon(
                          _showICloudOcrText
                              ? Icons.visibility_off
                              : Icons.visibility,
                          size: 18,
                        ),
                        label: Text(_showICloudOcrText
                            ? 'Hide OCR Text'
                            : 'Show OCR Text'),
                        style: TextButton.styleFrom(
                          foregroundColor: _sellOutBlue,
                          textStyle:
                              const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    AnimatedCrossFade(
                      firstChild: const SizedBox(width: double.infinity),
                      secondChild: Column(
                        children: [
                          TextField(
                            controller: _iCloudOcrTextController,
                            maxLines: 5,
                            decoration: InputDecoration(
                              labelText: 'iCloud OCR Text',
                              hintText: 'iCloud OCR text will appear here...',
                              alignLabelWithHint: true,
                              filled: true,
                              fillColor: Colors.white,
                              labelStyle: const TextStyle(color: _sellOutMuted),
                              floatingLabelStyle: const TextStyle(
                                color: _sellOutBlue,
                                fontWeight: FontWeight.w700,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    const BorderSide(color: _sellOutBorder),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                    color: _sellOutBlue, width: 1.5),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                            ),
                            style: const TextStyle(
                                color: _sellOutText, fontSize: 13),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isICloudOcrLoading
                                  ? null
                                  : _extractICloudText,
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
                              label: Text(_isICloudOcrLoading
                                  ? 'Extracting...'
                                  : 'Extract iCloud Info'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _sellOutBlue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                textStyle: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _autoFillICloudFromOcr,
                              icon: const Icon(Icons.auto_fix_high, size: 18),
                              label: const Text('Auto Fill iCloud Info'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _sellOutBlue,
                                backgroundColor:
                                    _sellOutBlue.withValues(alpha: 0.06),
                                side: BorderSide(
                                    color:
                                        _sellOutBlue.withValues(alpha: 0.45)),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                textStyle: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ],
                      ),
                      crossFadeState: _showICloudOcrText
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 180),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionTitle('Product Lines'),
                Text(
                  '${_report.lines.length} line(s)',
                  style: const TextStyle(
                    fontSize: 13,
                    color: _sellOutMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _lineControllers.length,
              itemBuilder: (context, index) {
                return _buildProductLineCard(
                    index, _report.lines[index], _lineControllers[index]);
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _addProductLine,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Product Line'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _sellOutBlue,
                  backgroundColor: _sellOutBlue.withValues(alpha: 0.06),
                  side: BorderSide(color: _sellOutBlue.withValues(alpha: 0.45)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
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
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: _sellOutBorder),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
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
                      padding: const EdgeInsets.symmetric(vertical: 4),
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
                                  ? 'Product #${index + 1}'
                                  : line.productName.trim(),
                              style: TextStyle(
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
                              fontSize: 13,
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
                  label: const Text('Remove'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 4, color: _sellOutBorder),
                  const SizedBox(height: 8),
                  _buildProductOcrControls(index, ctrls),
                  const SizedBox(height: 12),
                  _buildLineField(ctrls.productName, 'Product Name',
                      (v) => line.productName = v),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildLineField(
                            ctrls.sku, 'SKU', (v) => line.sku = v),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildLineField(ctrls.modelNumber,
                            'Model Number', (v) => line.modelNumber = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildLineField(
                            ctrls.imei, 'IMEI', (v) => line.imei = v),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildLineField(
                            ctrls.imei2, 'IMEI2', (v) => line.imei2 = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildLineField(ctrls.serialNumber,
                            'Serial Number', (v) => line.serialNumber = v),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildLineField(
                            ctrls.color, 'Color', (v) => line.color = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildLineField(
                            ctrls.storage, 'Storage', (v) => line.storage = v),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildLineField(ctrls.qty, 'Qty',
                            (v) => line.qty = int.tryParse(v) ?? 0),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildLineField(ctrls.unitPrice, 'Unit Price',
                            (v) => line.unitPrice = double.tryParse(v) ?? 0.0),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Subtotal: \$${line.subtotal.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: _sellOutBlue,
                      fontSize: 14,
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

  Widget _buildProductOcrControls(int index, _LineControllers ctrls) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xfff7faff),
        border: Border.all(color: const Color(0xffe5edf8)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Product Photos',
            style: const TextStyle(
              color: _sellOutText,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildPhotoButton(
                  'Take Product',
                  Icons.camera_alt,
                  () => _takeProductPhoto(index),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildPhotoButton(
                  'From Gallery',
                  Icons.photo_library,
                  () => _pickProductFromGallery(index),
                ),
              ),
            ],
          ),
          if (ctrls.photoPaths.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildPhotoGrid(
              ctrls.photoPaths,
              (photoIndex) => _removeProductPhoto(index, photoIndex),
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                setState(() => ctrls.showOcrText = !ctrls.showOcrText);
              },
              icon: Icon(
                ctrls.showOcrText ? Icons.visibility_off : Icons.visibility,
                size: 18,
              ),
              label:
                  Text(ctrls.showOcrText ? 'Hide OCR Text' : 'Show OCR Text'),
              style: TextButton.styleFrom(
                foregroundColor: _sellOutBlue,
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Column(
              children: [
                TextField(
                  controller: ctrls.ocrText,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Product OCR Text',
                    hintText: 'Product OCR text will appear here...',
                    alignLabelWithHint: true,
                    filled: true,
                    fillColor: Colors.white,
                    labelStyle: const TextStyle(color: _sellOutMuted),
                    floatingLabelStyle: const TextStyle(
                      color: _sellOutBlue,
                      fontWeight: FontWeight.w700,
                    ),
                    hintStyle: const TextStyle(color: _sellOutMuted),
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
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  style: const TextStyle(color: _sellOutText, fontSize: 13),
                ),
                const SizedBox(height: 8),
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
                          ? 'Extracting...'
                          : 'Extract & Auto Fill Product',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _sellOutBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _autoFillProductFromOcr(index),
                    icon: const Icon(Icons.auto_fix_high, size: 18),
                    label: const Text('Auto Fill Product From OCR'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _sellOutBlue,
                      backgroundColor: Colors.white,
                      side: BorderSide(
                          color: _sellOutBlue.withValues(alpha: 0.45)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
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
      Function(String) onChanged) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        labelStyle: const TextStyle(color: _sellOutMuted),
        floatingLabelStyle: const TextStyle(
          color: _sellOutBlue,
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      ),
      cursorColor: _sellOutBlue,
      style: const TextStyle(
        color: _sellOutText,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildTotalSection() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 0,
      color: _sellOutNavy,
      surfaceTintColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Summary',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Qty',
                  style: TextStyle(fontSize: 15, color: Colors.white70),
                ),
                Text(
                  _report.totalQty.toString(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Amount',
                  style: TextStyle(fontSize: 15, color: Colors.white70),
                ),
                Text(
                  '\$${_report.totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Commission',
                  style: TextStyle(fontSize: 15, color: Colors.white70),
                ),
                Text(
                  '\$${_report.commission.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
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
        label: Text(_isSubmitting ? 'Submitting...' : 'Submit Report'),
        style: ElevatedButton.styleFrom(
          backgroundColor: _sellOutBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
