import 'package:cnattendance/services/ocr_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OcrService autoDetectFields', () {
    test('prefers valid Cambodian phone numbers over unrelated digit runs', () {
      final service = OcrService();

      final fields = service.autoDetectFields('''
Customer Phone
1234567891
016469756
Invoice No: OICE
''');

      expect(fields['phone_number'], '016469756');
    });

    test('does not treat bare invoice digits as phone numbers', () {
      final service = OcrService();

      final fields = service.autoDetectFields('Invoice No: 1234567891');

      expect(fields['phone_number'], isEmpty);
    });

    test('detects customer phone numbers that start with 855', () {
      final service = OcrService();

      final fields = service.autoDetectFields('Customer Phone: 85516469756');

      expect(fields['phone_number'], '85516469756');
    });

    test('detects customer phone numbers that start with +855', () {
      final service = OcrService();

      final fields = service.autoDetectFields('Customer Phone: +85516469756');

      expect(fields['phone_number'], '+85516469756');
    });

    test('does not detect 885 as a customer phone country code', () {
      final service = OcrService();

      final fields = service.autoDetectFields('Customer Phone: 88516469756');

      expect(fields['phone_number'], isEmpty);
    });

    test('does not read the word INVOICE as an invoice number', () {
      final service = OcrService();

      final fields = service.autoDetectFields('INVOICE / 发票');

      expect(fields['invoice_no'], isEmpty);
    });

    test('extracts invoice number when a real invoice label is present', () {
      final service = OcrService();

      final fields = service.autoDetectFields('Invoice No: A12345');

      expect(fields['invoice_no'], 'A12345');
    });
  });
}
