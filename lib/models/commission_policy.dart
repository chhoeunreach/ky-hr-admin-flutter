/// Effective server policy for the signed-in role. Missing metadata fails closed.
class CommissionPolicy {
  const CommissionPolicy(
      {this.visible = false,
      this.canCalculate = false,
      this.canChangeMode = false,
      this.enabled = false,
      this.defaultMode = 'with_conditions',
      this.rules = const {}});
  final bool visible, canCalculate, canChangeMode, enabled;
  final String defaultMode;
  final Map<String, CommissionRule> rules;
  factory CommissionPolicy.fromJson(dynamic value) {
    final json = value is Map ? value : const {};
    final rules = json['rules'] is Map ? json['rules'] as Map : const {};
    return CommissionPolicy(
        visible: json['visible'] == true,
        canCalculate: json['can_calculate'] == true,
        canChangeMode: json['can_change_mode'] == true,
        enabled: json['enabled'] == true,
        defaultMode: json['default_mode'] == 'without_conditions'
            ? 'without_conditions'
            : 'with_conditions',
        rules: {
          for (final entry in rules.entries)
            if (entry.value is Map)
              '${entry.key}': CommissionRule.fromJson(entry.value as Map)
        });
  }
  // Used by standalone calculations and fixtures. Network screens use server metadata.
  factory CommissionPolicy.defaults() => CommissionPolicy(
          visible: true,
          canCalculate: true,
          canChangeMode: true,
          enabled: true,
          rules: {
            for (final type in [
              'sell',
              'material',
              'iron',
              'repair',
              'buy_in',
              'icloud_cus'
            ])
              type: CommissionRule(
                  enabled:
                      ['sell', 'material', 'iron', 'repair'].contains(type),
                  rate: {
                        'sell': .25,
                        'material': .25,
                        'iron': .2,
                        'repair': .2
                      }[type] ??
                      0,
                  perItem: type == 'sell',
                  requirePhone: true,
                  minimumAmount: type == 'material' ? 10 : 0,
                  partTimeQuantity: type == 'sell' ? 50 : 0,
                  fullTimeQuantity: type == 'sell' ? 100 : 0)
          });
  bool isEnabled(String type) => enabled && (rules[type]?.enabled ?? false);
  List<String> failures(
      String type, int quantity, double amount, String phone, String category,
      {int? periodQuantity, bool? conditions}) {
    if (!isEnabled(type)) return const ['no_commission_condition'];
    final r = rules[type]!;
    if (!(conditions ?? defaultMode == 'with_conditions')) return const [];
    return [
      if (r.requirePhone && phone.trim().length <= 6) 'failed_phone_required',
      if (amount < r.minimumAmount)
        r.minimumAmount == 10 && type == 'material'
            ? 'failed_material_total'
            : 'failed_minimum_amount',
      if ((periodQuantity ?? quantity) < r.threshold(category))
        type == 'sell' ? 'failed_period_sell_qty' : 'failed_period_qty'
    ];
  }

  double calculate(
      String type, int quantity, double amount, String phone, String category,
      {int? periodQuantity, bool? conditions}) {
    if (!visible ||
        failures(type, quantity, amount, phone, category,
                periodQuantity: periodQuantity, conditions: conditions)
            .isNotEmpty) return 0;
    final r = rules[type]!;
    return double.parse(
        ((r.perItem ? quantity : 1) * r.rate).toStringAsFixed(2));
  }
}

class CommissionRule {
  const CommissionRule(
      {required this.enabled,
      required this.rate,
      required this.perItem,
      required this.requirePhone,
      required this.minimumAmount,
      required this.partTimeQuantity,
      required this.fullTimeQuantity});
  final bool enabled, perItem, requirePhone;
  final double rate, minimumAmount;
  final int partTimeQuantity, fullTimeQuantity;
  factory CommissionRule.fromJson(Map json) => CommissionRule(
      enabled: json['enabled'] == true,
      rate: num.tryParse('${json['rate']}')?.toDouble() ?? 0,
      perItem: json['basis'] == 'item',
      requirePhone: json['require_phone'] == true,
      minimumAmount: num.tryParse('${json['minimum_amount']}')?.toDouble() ?? 0,
      partTimeQuantity:
          num.tryParse('${json['part_time_quantity']}')?.toInt() ?? 0,
      fullTimeQuantity:
          num.tryParse('${json['full_time_quantity']}')?.toInt() ?? 0);
  int threshold(String category) => category
              .replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '')
              .trim()
              .toLowerCase() ==
          'part_timer'
      ? partTimeQuantity
      : fullTimeQuantity;
}
