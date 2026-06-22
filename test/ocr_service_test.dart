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

    test('extracts all-letter Apple serial numbers from iOS About text', () {
      final service = OcrService();

      final fields = service.autoDetectFields('''
About
iOS Version
26.2
Model Name
iPhone 17 Pro
Model Number
MG7K4LL/A
Serial Number
JXWKTQPGDG
Capacity
256 GB
Available
233.85 GB
''');

      expect(fields['product_name'], 'iPhone 17 Pro');
      expect(fields['model_number'], 'MG7K4LL/A');
      expect(fields['serial_number'], 'JXWKTQPGDG');
      expect(fields['storage'], '256 GB');
    });

    test('extracts Apple box product identifiers with serial as primary field',
        () {
      final service = OcrService();

      final fields = service.autoDetectFields('''
MG7K4LL/A iPhone 17 Pro, Silver, 256GB Model A3256
EID 89049032020008885500239606153170
(S) Serial No. JYXOMYFGM9
IMEI/MEID 355832512293090
UPC 1 95950 62616 2
IMEI2 355832512421253
''');

      expect(fields['serial_number'], 'JYXOMYFGM9');
      expect(fields['product_name'], 'iPhone 17 Pro');
      expect(fields['model_number'], 'A3256');
      expect(fields['imei'], '355832512293090');
      expect(fields['imei2'], '355832512421253');
      expect(fields['color'], 'silver');
      expect(fields['storage'], '256GB');
    });

    test('copies only the value after serial labels', () {
      final service = OcrService();

      final aboutSerial =
          service.autoDetectFields('Serial Number H0CHN047N70G');
      final boxSerial = service.autoDetectFields('(S) Serial No. JYX0MYFGM9');
      final slashSerial = service.autoDetectFields('S/N ABC1234567');

      expect(aboutSerial['serial_number'], 'H0CHN047N70G');
      expect(boxSerial['serial_number'], 'JYX0MYFGM9');
      expect(slashSerial['serial_number'], 'ABC1234567');
    });

    test('formats product OCR text into clear product information', () {
      final service = OcrService();

      final formatted = service.formatProductOcrText('''
Model Name iPhone 11 Pro Max
Model Number NWGJ2LL/A
Serial Number HOCHN047N70G
Coverage Expired
Parts & Service History
Songs 0
Videos 517
Photos 1,723
Applications 35
Capacity 64 GB
Available 1.85 GB
''');

      expect(
        formatted,
        '''
Model Name: iPhone 11 Pro Max
Model Number: NWGJ2LL/A
Serial Number: HOCHN047N70G
Coverage: Expired
Parts & Service History
Songs: 0
Videos: 517
Photos: 1,723
Applications: 35
Capacity: 64 GB
Available: 1.85 GB
'''
            .trim(),
      );
    });

    test('extracts iCloud account info from Apple Account OCR text', () {
      final service = OcrService();

      final fields = service.autoDetectICloudFields('''
Apple Account
CHHOEUN REACH
chhoeunreach@gmail.com
Personal Information
Sign-In & Security
iCloud 5 GB
Find My
Two-Factor Authentication
Verify Using
Vireak
This iPhone 11 Pro Max
CHHOEUN's MacBook Pro
MacBook Pro 16"
iPad
iPad Pro
+855 16 469 756
Trusted phone number
''');

      expect(fields['account_name'], 'CHHOEUN REACH');
      expect(fields['apple_id'], 'chhoeunreach@gmail.com');
      expect(fields['icloud_storage'], '5 GB');
      expect(fields['trusted_phone'], '+85516469756');
      expect(fields['devices'], contains('This iPhone 11 Pro Max'));
      expect(fields['devices'], contains('MacBook Pro 16"'));
      expect(fields['devices'], contains('iPad Pro'));
    });
  });
}
