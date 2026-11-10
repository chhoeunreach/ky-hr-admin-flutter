import 'package:cnattendance/models/report_commission_calculation.dart';
import 'package:cnattendance/models/sell_out_report.dart';
import 'package:cnattendance/models/sell_out_report_line.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SellOutReport sell(int qty,
          {String seller = 'Seller A',
          String category = '',
          String phone = '012345678',
          double? saved}) =>
      SellOutReport(
        serviceType: 'Sell',
        sellerName: seller,
        sellerWorkCategory: category,
        customerPhone: phone,
        serverCommission: saved,
        lines: [SellOutReportLine(qty: qty, unitPrice: 2)],
      );

  test('full-time quantity qualifies across invoices in selected period', () {
    final a = sell(60, saved: 0), b = sell(40, saved: 0);
    final monthly = ReportCommissionCalculation([a]);
    expect(monthly.commission(a), 0);
    final yearly = ReportCommissionCalculation([a, b]);
    expect(yearly.periodSellQty(a), 100);
    expect(yearly.isEligible(a), isTrue);
    expect(yearly.commission(a), 15);
    expect(yearly.commission(b), 10);
    // Server per-invoice zeros do not override the report preview.
    expect(a.commission, 0);
  });

  test('part-time quantity threshold is 50 across invoices', () {
    final a = sell(20, category: 'part_timer');
    final b = sell(30, category: 'part_timer');
    final calc = ReportCommissionCalculation([a, b]);
    expect(calc.commission(a) + calc.commission(b), 12.5);
  });

  test('different sellers and work categories cannot share a threshold', () {
    final a = sell(60), b = sell(40, seller: 'Seller B');
    final c = sell(40, category: 'part_timer');
    final calc = ReportCommissionCalculation([a, b, c]);
    expect(calc.isEligible(a), isFalse);
    expect(calc.isEligible(b), isFalse);
    expect(calc.isEligible(c), isFalse);
  });

  test('phone failures do not contribute qualifying quantity', () {
    final valid = sell(60), invalid = sell(40, phone: '');
    final calc = ReportCommissionCalculation([valid, invalid]);
    expect(calc.periodSellQty(valid), 60);
    expect(calc.commission(valid), 0);
    expect(calc.failureKeys(invalid), contains('failed_phone_required'));
  });

  test('without conditions skips phone, period threshold and minimum amount',
      () {
    final sale = sell(2, phone: '');
    final material = SellOutReport(
        serviceType: 'Material',
        lines: [SellOutReportLine(qty: 1, unitPrice: 1)]);
    final repair = SellOutReport(serviceType: 'Repair');
    final iron = SellOutReport(serviceType: 'Iron');
    final other = SellOutReport(serviceType: 'Buy In');
    final calc = ReportCommissionCalculation(
        [sale, material, repair, iron, other],
        mode: ReportCommissionMode.withoutConditions);
    expect(calc.commission(sale), .5);
    expect(calc.commission(material), .25);
    expect(calc.commission(repair), .2);
    expect(calc.commission(iron), .2);
    expect(calc.commission(other), 0);
    expect(calc.isEligible(other), isFalse);
  });

  test('with conditions still enforces material minimum and phone', () {
    final material = SellOutReport(
        serviceType: 'Material',
        customerPhone: '012345678',
        lines: [SellOutReportLine(qty: 1, unitPrice: 9)]);
    final calc = ReportCommissionCalculation([material]);
    expect(calc.failureKeys(material), ['failed_material_total']);
    expect(calc.commission(material), 0);
  });
  test('service rules retain their rates and qualifying conditions', () {
    final reports = ['Material', 'Iron', 'Repair', 'Buy In']
        .map((service) => SellOutReport(
              serviceType: service,
              customerPhone: '012345678',
              lines: [SellOutReportLine(qty: 1, unitPrice: 10)],
            ))
        .toList();
    final calculation = ReportCommissionCalculation(reports);
    expect(reports.map(calculation.commission).toList(), [.25, .20, .20, 0]);
    reports.first.lines.first.unitPrice = 9.99;
    expect(calculation.commission(reports.first), 0);
    for (final report in reports) {
      report.customerPhone = '';
      expect(calculation.commission(report), 0);
    }
  });
}
