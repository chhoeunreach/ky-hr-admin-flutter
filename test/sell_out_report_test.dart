import 'package:cnattendance/models/sell_out_report.dart';
import 'package:cnattendance/models/sell_out_report_line.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SellOutReport commission', () {
    test('Sale API service alias calculates the same commission as Sell', () {
      final report = SellOutReport.fromJson({
        'service_type': 'Sale',
        'customer_phone': '012345678',
        'seller_work_category': 'part_timer',
        'lines': [
          {'qty': 50, 'unit_price': 2}
        ],
      });
      expect(report.isCommissionEligible, isTrue);
      expect(report.calculatedCommission, 12.50);
      expect(report.commission, 12.50);
    });

    test('server commission remains authoritative, including zero', () {
      final report = SellOutReport(
        serviceType: 'Sell',
        customerPhone: '012345678',
        lines: [SellOutReportLine(qty: 100, unitPrice: 2)],
        serverCommission: 0,
      );
      expect(report.calculatedCommission, 25);
      expect(report.commission, 0);
      report.serverCommission = 30;
      expect(report.commission, 30);
    });

    test('sell earns commission when full-time qty reaches 100', () {
      final report = SellOutReport(
        serviceType: 'Sell',
        customerPhone: '01234567',
        lines: [
          SellOutReportLine(qty: 100, unitPrice: 1),
        ],
      );

      expect(report.commission, 25.00);
    });

    test('sell earns commission when part-time qty reaches 50', () {
      final report = SellOutReport(
        serviceType: 'Sell',
        customerPhone: '01234567',
        sellerWorkCategory: 'part_timer',
        lines: [
          SellOutReportLine(qty: 50, unitPrice: 1),
        ],
      );

      expect(report.commission, 12.50);
    });

    test('material earns 0.25 commission per report when invoice total is 10',
        () {
      final report = SellOutReport(
        serviceType: 'Material',
        customerPhone: '01234567',
        lines: [
          SellOutReportLine(qty: 1, unitPrice: 10),
        ],
      );

      expect(report.commission, 0.25);
    });

    test('iron earns 0.20 commission per report when customer phone is valid',
        () {
      final report = SellOutReport(
        serviceType: 'Iron',
        customerPhone: '01234567',
        lines: [
          SellOutReportLine(qty: 2),
        ],
      );

      expect(report.commission, 0.20);
    });

    test('khmer iron with invisible spacing earns 0.20 commission per report',
        () {
      final report = SellOutReport(
        serviceType: 'អ៊ុត\u200B',
        customerPhone: '01234567',
        lines: [
          SellOutReportLine(qty: 2),
        ],
      );

      expect(report.commission, 0.20);
    });

    test('sell gets no commission without customer phone', () {
      final report = SellOutReport(
        serviceType: 'Sell',
        customerPhone: '',
        lines: [
          SellOutReportLine(qty: 2, unitPrice: 51),
        ],
      );

      expect(report.commission, 0);
    });

    test('sell gets no commission when customer phone is too short', () {
      final report = SellOutReport(
        serviceType: 'Sell',
        customerPhone: '123456',
        lines: [
          SellOutReportLine(qty: 2, unitPrice: 51),
        ],
      );

      expect(report.commission, 0);
    });

    test('repair earns 0.20 commission per report when customer phone is valid',
        () {
      final report = SellOutReport(
        serviceType: 'Repair',
        customerPhone: '01234567',
        lines: [
          SellOutReportLine(qty: 2),
        ],
      );

      expect(report.commission, 0.20);
    });

    test('material gets no commission when invoice total is less than 10', () {
      final report = SellOutReport(
        serviceType: 'Material',
        customerPhone: '01234567',
        lines: [
          SellOutReportLine(qty: 1, unitPrice: 9.99),
        ],
      );

      expect(report.commission, 0);
    });

    test('sell gets no commission when full-time qty is less than 100', () {
      final report = SellOutReport(
        serviceType: 'Sell',
        customerPhone: '01234567',
        lines: [
          SellOutReportLine(qty: 99, unitPrice: 1),
        ],
      );

      expect(report.commission, 0);
    });

    test('non-commissionable services stay at zero with a valid phone', () {
      final report = SellOutReport(
        serviceType: 'Buy In',
        customerPhone: '01234567',
        lines: [
          SellOutReportLine(qty: 2),
        ],
      );

      expect(report.commission, 0);
    });
  });
}
