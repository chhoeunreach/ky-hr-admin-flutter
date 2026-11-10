import 'package:flutter/material.dart';
import 'package:cnattendance/models/commission_policy.dart';
import 'package:intl/intl.dart';
import 'package:cnattendance/models/sell_out_report.dart';

const posModules = ['sell', 'material', 'iron', 'repair', 'buy_in'];

class PosFilters {
  final DateTime from;
  final DateTime to;
  final String type, branch, employee, search, status, commissionMode, bucket;
  final int page, perPage;
  const PosFilters(
      {required this.from,
      required this.to,
      this.type = 'all',
      this.branch = '',
      this.employee = '',
      this.search = '',
      this.status = 'all',
      this.commissionMode = '',
      this.bucket = '',
      this.page = 1,
      this.perPage = 20});
  factory PosFilters.today({String type = 'all'}) {
    final now = DateUtils.dateOnly(DateTime.now());
    return PosFilters(from: now, to: now, type: type);
  }
  PosFilters copyWith(
          {DateTime? from,
          DateTime? to,
          String? type,
          String? branch,
          String? employee,
          String? search,
          String? status,
          String? commissionMode,
          String? bucket,
          int? page,
          int? perPage}) =>
      PosFilters(
          from: from ?? this.from,
          to: to ?? this.to,
          type: type ?? this.type,
          branch: branch ?? this.branch,
          employee: employee ?? this.employee,
          search: search ?? this.search,
          status: status ?? this.status,
          commissionMode: commissionMode ?? this.commissionMode,
          bucket: bucket ?? this.bucket,
          page: page ?? this.page,
          perPage: perPage ?? this.perPage);
  Map<String, dynamic> toQuery() => {
        'paginated': 1,
        'date_from': DateFormat('yyyy-MM-dd').format(from),
        'date_to': DateFormat('yyyy-MM-dd').format(to),
        'type': type,
        if (branch.isNotEmpty) 'branch_name': branch,
        if (employee.isNotEmpty) 'seller_name': employee,
        if (search.trim().isNotEmpty) 'search': search.trim(),
        'report_status': status,
        if (commissionMode.isNotEmpty) 'commission_mode': commissionMode,
        if (bucket.isNotEmpty) 'bucket': bucket,
        'page': page,
        'per_page': perPage,
      };
  DateTimeRange get range => DateTimeRange(start: from, end: to);
}

Map<String, dynamic> posMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};
List<Map<String, dynamic>> posMaps(dynamic value) => value is List
    ? value.whereType<Map>().map((v) => Map<String, dynamic>.from(v)).toList()
    : [];
double posNumber(dynamic value) => num.tryParse('$value')?.toDouble() ?? 0;

class PosTransaction {
  final SellOutReport report;
  final String type, status;
  final int quantity, periodQuantity;
  final double commission;
  final bool canEdit;
  PosTransaction.fromJson(Map<String, dynamic> json)
      : report = SellOutReport.fromJson(json),
        type = '${json['type'] ?? 'other'}',
        status = '${json['report_status'] ?? 'not_applicable'}',
        quantity = posNumber(json['total_qty']).toInt(),
        periodQuantity = posNumber(json['period_qty']).toInt(),
        commission = posNumber(json['report_commission']),
        canEdit = json['can_edit'] == true;
}

class PosCategory {
  final String type;
  final int transactions, quantity;
  final double amount;
  final double? commission;
  final bool isPurchase;
  PosCategory.fromJson(Map<String, dynamic> json)
      : type = '${json['type']}',
        transactions = posNumber(json['transactions']).toInt(),
        quantity = posNumber(json['quantity']).toInt(),
        amount = posNumber(json['amount']),
        commission =
            json['commission'] == null ? null : posNumber(json['commission']),
        isPurchase = json['is_purchase'] == true;
}

class PosChartPoint {
  final DateTime date;
  final double amount, purchases, quantity;
  PosChartPoint.fromJson(Map<String, dynamic> json)
      : date = DateTime.parse('${json['date']}'),
        amount = posNumber(json['amount']),
        purchases = posNumber(json['buy_in_amount']),
        quantity = posNumber(json['quantity']);
}

class PosReport {
  final CommissionPolicy commissionPolicy;
  final String effectiveCommissionMode;
  final List<PosTransaction> transactions;
  final List<PosCategory> categories;
  final List<PosChartPoint> points;
  final Map<String, dynamic> summary;
  final List<String> branches, employees, modules;
  final int page, perPage, total, lastPage;
  final String currency, businessName, bucket;
  final bool canCreate;
  PosReport.fromJson(Map<String, dynamic> json)
      : commissionPolicy = CommissionPolicy.fromJson(json['commission_policy']),
        effectiveCommissionMode =
            '${posMap(json['filters'])['commission_mode'] ?? posMap(json['commission_policy'])['default_mode'] ?? 'with_conditions'}',
        transactions =
            posMaps(json['data']).map(PosTransaction.fromJson).toList(),
        categories =
            posMaps(json['categories']).map(PosCategory.fromJson).toList(),
        points = posMaps(posMap(json['chart'])['points'])
            .map(PosChartPoint.fromJson)
            .toList(),
        summary = posMap(json['summary']),
        branches = (posMap(json['options'])['branches'] as List? ?? [])
            .map((v) => '$v')
            .toList(),
        employees = (posMap(json['options'])['employees'] as List? ?? [])
            .map((v) => '$v')
            .toList(),
        modules = (posMap(json['permissions'])['modules'] as List? ?? [])
            .map((v) => '$v')
            .where(posModules.contains)
            .toList(),
        page = posNumber(posMap(json['meta'])['current_page']).toInt(),
        perPage = posNumber(posMap(json['meta'])['per_page']).toInt(),
        total = posNumber(posMap(json['meta'])['total']).toInt(),
        lastPage = posNumber(posMap(json['meta'])['last_page']).toInt(),
        currency = '${json['currency_symbol'] ?? ''}',
        businessName = '${json['business_name'] ?? 'KNEAYERNG'}',
        bucket = '${posMap(json['chart'])['bucket'] ?? 'day'}',
        canCreate = posMap(json['permissions'])['can_create'] == true;
  double metric(String key) => posNumber(summary[key]);
}
