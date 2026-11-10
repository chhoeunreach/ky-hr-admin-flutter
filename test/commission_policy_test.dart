import 'package:cnattendance/models/commission_policy.dart';
import 'package:cnattendance/models/report_commission_calculation.dart';
import 'package:cnattendance/models/sell_out_report.dart';
import 'package:cnattendance/models/sell_out_report_line.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  CommissionPolicy policy(Map<String, CommissionRule> rules,
          {bool calculate = true,
          bool changeMode = true,
          String mode = 'with_conditions'}) =>
      CommissionPolicy(
          visible: true,
          enabled: true,
          canCalculate: calculate,
          canChangeMode: changeMode,
          defaultMode: mode,
          rules: rules);
  const rule = CommissionRule(
      enabled: true,
      rate: .3333,
      perItem: false,
      requirePhone: false,
      minimumAmount: 0,
      partTimeQuantity: 0,
      fullTimeQuantity: 0);
  SellOutReport report(String type, int qty,
          {String phone = '', double? saved}) =>
      SellOutReport(
          serviceType: type,
          sellerName: 'Employee',
          customerPhone: phone,
          serverCommission: saved,
          lines: [SellOutReportLine(qty: qty, unitPrice: 1)]);

  test('unknown server policy fails closed', () {
    final p = CommissionPolicy.fromJson(null);
    expect(p.visible, isFalse);
    expect(p.canCalculate, isFalse);
    expect(p.calculate('sell', 100, 100, '012345678', 'full_timer'), 0);
  });
  test('configured invoice rates round each invoice before period aggregation',
      () {
    final rows = [report('Iron', 1), report('Iron', 1), report('Iron', 1)];
    final calculation =
        ReportCommissionCalculation(rows, policy: policy({'iron': rule}));
    expect(rows.map(calculation.commission), everyElement(.33));
    expect(rows.fold<double>(0, (sum, r) => sum + calculation.commission(r)),
        closeTo(.99, .0001));
  });
  test('each service supports configured item rates and period thresholds', () {
    const itemRule = CommissionRule(
        enabled: true,
        rate: 2,
        perItem: true,
        requirePhone: false,
        minimumAmount: 0,
        partTimeQuantity: 3,
        fullTimeQuantity: 5);
    final rows = [
      report('Material', 2),
      report('Material', 3),
      report('Iron', 100)
    ];
    final calculation = ReportCommissionCalculation(rows,
        policy: policy({'material': itemRule}));
    expect(calculation.commission(rows[0]), 4);
    expect(calculation.commission(rows[1]), 6);
    expect(calculation.commission(rows[2]), 0);
  });
  test(
      'disallowed mode changes use the server default and saved amounts remain authoritative',
      () {
    final row = report('Iron', 1, saved: 7.5);
    const phoneRule = CommissionRule(
        enabled: true,
        rate: 2,
        perItem: false,
        requirePhone: true,
        minimumAmount: 10,
        partTimeQuantity: 0,
        fullTimeQuantity: 0);
    var p = policy({'iron': phoneRule},
        changeMode: false, mode: 'without_conditions');
    row.commissionPolicy = p;
    expect(row.commission, 7.5);
    expect(ReportCommissionCalculation([row], policy: p).commission(row), 2);
    p = policy({'iron': phoneRule}, calculate: false);
    expect(ReportCommissionCalculation([row], policy: p).commission(row), 7.5);
    expect(
        ReportCommissionCalculation([row], policy: const CommissionPolicy())
            .commission(row),
        0);
  });
  test(
      'new records can enable Buy In only when the admin explicitly configures it',
      () {
    final row = report('Buy In', 1);
    expect(ReportCommissionCalculation([row]).commission(row), 0);
    expect(
        ReportCommissionCalculation([row], policy: policy({'buy_in': rule}))
            .commission(row),
        .33);
  });
  test(
      'saved commissions remain qualified when calculation is disabled and rules changed',
      () {
    final row = report('Iron', 1, saved: 7.5);
    row.commissionPolicy = policy({}, calculate: false);
    expect(row.isCommissionable, isTrue);
    expect(
        ReportCommissionCalculation([row], policy: row.commissionPolicy)
            .isEligible(row),
        isTrue);
    expect(
        ReportCommissionCalculation([row], policy: row.commissionPolicy)
            .commission(row),
        7.5);
  });
}
