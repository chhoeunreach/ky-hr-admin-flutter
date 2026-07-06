import 'package:flutter_test/flutter_test.dart';
import 'package:cnattendance/services/ocr_service.dart';

void main() {
  group('OcrService autoDetectFields', () {
    late OcrService service;

    setUp(() {
      service = OcrService();
    });

    test('extracts product name from text', () {
      final result = service.autoDetectFields('iPhone 15 Pro Max');
      expect(result['product_name'], 'iPhone 15 Pro Max');
    });

    test('extracts model name from labeled form', () {
      final result = service.autoDetectFields('Model Name iPhone 13 Pro Max');
      expect(result['product_name'], 'iPhone 13 Pro Max');
    });

    test('extracts serial number - Apple format', () {
      final result =
          service.autoDetectFields('(S) Serial No. H39VT6FQJJ');
      expect(result['serial_number'], 'H39VT6FQJJ');
    });

    test('extracts serial number - Serial Number format', () {
      final result =
          service.autoDetectFields('Serial Number WDNQFYHC21');
      expect(result['serial_number'], 'WDNQFYHC21');
    });

    test('extracts serial number - N7FXFTH5CX', () {
      final result =
          service.autoDetectFields('Serial Number N7FXFTH5CX');
      expect(result['serial_number'], 'N7FXFTH5CX');
    });

    test('extracts serial number - Samsung S/N', () {
      final result = service.autoDetectFields('S/N : R5GL14G69KE');
      expect(result['serial_number'], 'R5GL14G69KE');
    });

    test('extracts serial number - OPPO S/N', () {
      final result = service.autoDetectFields('S/N: HE5DDANFAQHMU4EQ');
      expect(result['serial_number'], 'HE5DDANFAQHMU4EQ');
    });

    test('accepts 6-char serial', () {
      final result = service.autoDetectFields('Serial Number ABCDEF');
      expect(result['serial_number'], 'ABCDEF');
    });

    test('extracts serial from SN: prefix', () {
      final result = service.autoDetectFields('SN: X7Y8Z9W0');
      expect(result['serial_number'], 'X7Y8Z9W0');
    });

    test('extracts serial from Serial # prefix', () {
      final result = service.autoDetectFields('Serial # H39VT6FQJJ');
      expect(result['serial_number'], 'H39VT6FQJJ');
    });

    test('rejects serial shorter than 6 chars', () {
      final result = service.autoDetectFields('Serial Number ABC12');
      expect(result['serial_number'], '');
    });

    test('rejects serial longer than 16 chars', () {
      final result = service.autoDetectFields('Serial Number ABCDEF12345678901');
      expect(result['serial_number'], '');
    });

    test('accepts 16-char serial', () {
      final result = service.autoDetectFields('Serial Number ABCDEF1234567890');
      expect(result['serial_number'], 'ABCDEF1234567890');
    });

    test('accepts 13-char serial', () {
      final result = service.autoDetectFields('S/N: HOCHNO047N70G');
      expect(result['serial_number'], 'HOCHNO047N70G');
    });

    test('standalone 12-char value goes to serial not model', () {
      final result = service.autoDetectFields('ABCDEF123456');
      expect(result['serial_number'], 'ABCDEF123456');
      expect(result['model_number'], '');
    });

    test('ignores photo separator as product name', () {
      final result = service.autoDetectFields('--- Photo 1 ---');
      expect(result['product_name'], '');
    });

    test('ignores photo separator line', () {
      final result = service.autoDetectFields('Model Name iPhone 13\n--- Photo 1 ---\nSerial Number ABCDEF1234');
      expect(result['product_name'], 'iPhone 13');
      expect(result['serial_number'], 'ABCDEF1234');
    });

    test('model number with slash is ignored (model_number removed)', () {
      final result = service.autoDetectFields('Model Number MLKP3LL/A');
      expect(result['serial_number'], '');
      expect(result['model_number'], '');
    });

    test('model number SM-S928B/DS is ignored', () {
      final result = service.autoDetectFields('Model Number SM-S928B/DS');
      expect(result['model_number'], '');
    });

    test('Model : label value ignored (model_number removed)', () {
      final result = service.autoDetectFields('Model : SM-F766B');
      expect(result['model_number'], '');
    });

    test('Model No. label value ignored (model_number removed)', () {
      final result = service.autoDetectFields('Model No. A3257');
      expect(result['model_number'], '');
    });

    test('Model Number label with 10-char value becomes serial', () {
      final result = service.autoDetectFields('Model Number : NZFXFTH5CX');
      expect(result['serial_number'], 'NZFXFTH5CX');
      expect(result['model_number'], '');
    });

    test('Model Number label with 9-char value ignored (< 10, no redirect)', () {
      final result = service.autoDetectFields('Model Number : MLKP3LLJA');
      expect(result['model_number'], '');
      expect(result['serial_number'], '');
    });

    test('Model Number label with 8-char value ignored', () {
      final result = service.autoDetectFields('Model Number : NWG2LLJA');
      expect(result['model_number'], '');
      expect(result['serial_number'], '');
    });

    test('Model Number label with dash is ignored', () {
      final result = service.autoDetectFields('Model Number : SM-F766B');
      expect(result['model_number'], '');
      expect(result['serial_number'], '');
    });

    test('Model Number label with slash is ignored', () {
      final result = service.autoDetectFields('Model Number : MLKP3LL/A');
      expect(result['model_number'], '');
      expect(result['serial_number'], '');
    });

    test('13-char under Model label becomes serial, 8-char under Serial stays serial', () {
      final result = service.autoDetectFields(
        'Model Number: HOCHNO047N70G\nSerial Number: NWG2LLJA',
      );
      expect(result['serial_number'], 'HOCHNO047N70G');
      expect(result['model_number'], '');
    });

    test('9-char value under Serial Number label stays serial (no model redirect)', () {
      final result = service.autoDetectFields('Serial Number: MLKP3LLJA');
      expect(result['serial_number'], 'MLKP3LLJA');
      expect(result['model_number'], '');
    });

    test('extracts IMEI from text', () {
      final result = service.autoDetectFields('IMEI: 123456789012345');
      expect(result['imei'], '123456789012345');
    });

    test('extracts IMEI with spaces', () {
      final result = service.autoDetectFields('354667 221 484221');
      expect(result['imei'], '354667221484221');
    });

    test('extracts IMEI1 and IMEI2', () {
      final result = service.autoDetectFields(
          'IMEI1: 123456789012345\nIMEI2: 543210987654321');
      expect(result['imei'], '123456789012345');
      expect(result['imei2'], '543210987654321');
    });

    test('extracts color', () {
      final result = service.autoDetectFields('Galaxy S24 Ultra Titanium Gray 512GB');
      expect(result['color'], 'Titanium Gray');
    });

    test('extracts color Natural Titanium', () {
      final result = service.autoDetectFields('iPhone 15 Pro Max Natural Titanium 256GB');
      expect(result['color'], 'Natural Titanium');
    });

    test('extracts storage - Capacity labeled', () {
      final result = service.autoDetectFields('Capacity128 GB');
      expect(result['storage'], '128GB');
    });

    test('extracts storage - Capacity with colon', () {
      final result = service.autoDetectFields('Capacity: 128 GB');
      expect(result['storage'], '128GB');
    });

    test('extracts storage - standalone', () {
      final result = service.autoDetectFields('Storage: 256GB');
      expect(result['storage'], '256GB');
    });

    test('extracts storage - no label 128GB', () {
      final result = service.autoDetectFields('128GB');
      expect(result['storage'], '128GB');
    });

    test('extracts storage - 512GB', () {
      final result = service.autoDetectFields('Capacity: 512GB');
      expect(result['storage'], '512GB');
    });

    test('extracts storage - 1TB', () {
      final result = service.autoDetectFields('Capacity: 1TB');
      expect(result['storage'], '1TB');
    });

    test('full form extraction', () {
      final result = service.autoDetectFields(
        'Model Name iPhone 13 Pro Max\nModel Number MLKP3LL/A\nSerial Number N7FXFTH5CX\nCapacity128 GB',
      );
      expect(result['product_name'], 'iPhone 13 Pro Max');
      expect(result['model_number'], '');
      expect(result['serial_number'], 'N7FXFTH5CX');
      expect(result['storage'], '128GB');
    });

    test('Galaxy S24 Ultra full extraction', () {
      final result = service.autoDetectFields(
        'Galaxy S24 Ultra Titanium Gray 512GB\nS/N: R5GL14G69KE\nModel Number SM-S928B/DS',
      );
      expect(result['product_name'], 'Galaxy S24 Ultra');
      expect(result['color'], 'Titanium Gray');
      expect(result['storage'], '512GB');
      expect(result['serial_number'], 'R5GL14G69KE');
      expect(result['model_number'], '');
    });

    test('extracts multiple fields from mixed text', () {
      final result = service.autoDetectFields(
        'iPhone 15 Pro Max\n(S) Serial No. H39VT6FQJJ\nModel : SM-F766B\nIMEI: 123456789012345\nStorage: 256GB',
      );
      expect(result['product_name'], 'iPhone 15 Pro Max');
      expect(result['serial_number'], 'H39VT6FQJJ');
      expect(result['model_number'], '');
      expect(result['imei'], '123456789012345');
      expect(result['storage'], '256GB');
    });

    test('skips IMEI as serial number', () {
      final result = service.autoDetectFields(
        'Serial: 123456789012345\nS/N: ABCDEF1234',
      );
      expect(result['imei'], '123456789012345');
      expect(result['serial_number'], 'ABCDEF1234');
    });

    test('returns empty strings for unknown text', () {
      final result = service.autoDetectFields('Some random text here');
      expect(result['product_name'], '');
      expect(result['serial_number'], '');
    });
  });
}
