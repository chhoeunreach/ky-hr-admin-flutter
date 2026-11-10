import 'dart:math' as math;
import 'dart:convert';
import 'package:cnattendance/features/pos/models/pos_report.dart';

Map<String, dynamic> posFixture(PosFilters filters,
    {int total = 21, List<String>? modules}) {
  final start = (filters.page - 1) * filters.perPage;
  final count = math.max(0, math.min(filters.perPage, total - start));
  return {
    'status': true,
    'commission_policy': jsonDecode(
        r'''{"visible": true, "can_calculate": true, "can_change_mode": true, "enabled": true, "default_mode": "with_conditions", "rules": {"sell": {"enabled": true, "rate": 0.25, "basis": "item", "require_phone": true, "minimum_amount": 0, "part_time_quantity": 50, "full_time_quantity": 100}, "material": {"enabled": true, "rate": 0.25, "basis": "invoice", "require_phone": true, "minimum_amount": 10, "part_time_quantity": 0, "full_time_quantity": 0}, "iron": {"enabled": true, "rate": 0.2, "basis": "invoice", "require_phone": true, "minimum_amount": 0, "part_time_quantity": 0, "full_time_quantity": 0}, "repair": {"enabled": true, "rate": 0.2, "basis": "invoice", "require_phone": true, "minimum_amount": 0, "part_time_quantity": 0, "full_time_quantity": 0}, "buy_in": {"enabled": false, "rate": 0, "basis": "invoice", "require_phone": true, "minimum_amount": 0, "part_time_quantity": 0, "full_time_quantity": 0}, "icloud_cus": {"enabled": false, "rate": 0, "basis": "invoice", "require_phone": true, "minimum_amount": 0, "part_time_quantity": 0, "full_time_quantity": 0}}}'''),
    'data': List.generate(
        count,
        (i) => {
              'id': start + i + 1,
              'invoice_no': 'POS-${start + i + 1}',
              'customer_name': 'Customer ${start + i + 1}',
              'customer_phone': '012345678',
              'seller_name': 'Employee',
              'branch_name': 'HQ',
              'service_type': filters.type == 'all' ? 'Sell' : filters.type,
              'type': filters.type == 'all' ? 'sell' : filters.type,
              'total_qty': 2,
              'total_amount': 10,
              'report_commission': filters.type == 'buy_in' ? 0 : .5,
              'report_status':
                  filters.type == 'buy_in' ? 'not_applicable' : 'qualified',
              'created_at':
                  '${filters.from.toIso8601String().substring(0, 10)} 11:30:00',
              'can_edit': false,
            }),
    'meta': {
      'current_page': filters.page,
      'per_page': filters.perPage,
      'total': total,
      'last_page': math.max(1, (total / filters.perPage).ceil())
    },
    'summary': {
      'reports': total,
      'quantity': total * 2,
      'qualified': total,
      'failed': 0,
      'sales_amount': filters.type == 'buy_in' ? 0 : total * 10,
      'commission': total * .5,
      'total_transactions': total,
      'module_quantity': total * 2,
      'module_amount': total * 10,
      'module_qualified': total,
      'module_failed': 0,
      'gross_profit': null,
      'gross_profit_available': false
    },
    'categories': [
      for (final type in posModules)
        {
          'type': type,
          'transactions': total,
          'quantity': total * 2,
          'amount': total * 10,
          'commission': type == 'buy_in'
              ? 0
              : total *
                  ({
                        'sell': .5,
                        'material': .25,
                        'iron': .2,
                        'repair': .2
                      }[type] ??
                      0),
          'is_purchase': type == 'buy_in'
        }
    ],
    'chart': {
      'bucket': 'day',
      'points': [
        {
          'date': filters.from.toIso8601String().substring(0, 10),
          'amount': total * 10,
          'buy_in_amount': total * 3,
          'quantity': total * 2
        }
      ]
    },
    'options': {
      'branches': ['HQ'],
      'employees': ['Employee'],
      'types': posModules,
      'statuses': ['qualified', 'failed', 'not_applicable']
    },
    'permissions': {
      'scope': 'own_reports',
      'can_create': true,
      'modules': modules ?? posModules
    },
    'currency_symbol': '\$',
    'business_name': 'KNEAYERNG HQ',
    'capabilities': {
      'gross_profit': false,
      'operational_status': false,
      'payment_status': false,
      'repair_orders': false
    },
  };
}
