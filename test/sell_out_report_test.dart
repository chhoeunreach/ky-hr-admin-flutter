import 'package:cnattendance/models/sell_out_report.dart';
import 'package:cnattendance/models/sell_out_report_line.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SellOutReport commission', () {
    test('sell earns commission when customer phone is valid', () {
      final report = SellOutReport(
        serviceType: 'Sell',
        customerPhone: '01234567',
        lines: [
          SellOutReportLine(qty: 2, unitPrice: 51),
          SellOutReportLine(qty: 1, unitPrice: 52),
        ],
      );

      expect(report.commission, 0.75);
    });

    test('material earns 0.25 commission per item when customer phone is valid',
        () {
      final report = SellOutReport(
        serviceType: 'Material',
        customerPhone: '01234567',
        lines: [
          SellOutReportLine(qty: 2),
        ],
      );

      expect(report.commission, 0.50);
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

    test('sell gets no commission when unit price is 50 or less', () {
      final report = SellOutReport(
        serviceType: 'Sell',
        customerPhone: '01234567',
        lines: [
          SellOutReportLine(qty: 2, unitPrice: 50),
        ],
      );

      expect(report.commission, 0);
    });

    test('sell gets no commission when any line unit price is 50 or less', () {
      final report = SellOutReport(
        serviceType: 'Sell',
        customerPhone: '01234567',
        lines: [
          SellOutReportLine(qty: 2, unitPrice: 51),
          SellOutReportLine(qty: 1, unitPrice: 50),
        ],
      );

      expect(report.commission, 0);
    });

    test('non-commissionable services stay at zero with a valid phone', () {
      final report = SellOutReport(
        serviceType: 'Repair',
        customerPhone: '01234567',
        lines: [
          SellOutReportLine(qty: 2),
        ],
      );

      expect(report.commission, 0);
    });
  });
}
