import 'package:cnattendance/features/company_documents/company_document_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Company Document Model & Multi-Attachment Tests', () {
    test('Parses multiple attachments correctly from API response', () {
      final json = {
        'id': 101,
        'category_code': 'contract',
        'category_name': 'Contracts',
        'category_icon': 'file-text',
        'category_color': '#7c3aed',
        'title': 'Lease Agreement 2026',
        'holder_name': 'KNEAYERNG HQ',
        'doc_number': 'KNY-LEASE-01',
        'branch_name': 'Phnom Penh Branch',
        'issue_date': '2026-01-01',
        'expiry_date': '2026-12-31',
        'alert_before_days': 30,
        'status': 'valid',
        'calculated_status': 'valid',
        'currency': 'USD',
        'file_url': 'https://example.com/page1.jpg',
        'file_name': 'page1.jpg',
        'file_type': 'image',
        'file_size': 102400,
        'is_pdf': false,
        'is_image': true,
        'attachments': [
          {
            'id': 1,
            'file_url': 'https://example.com/page1.jpg',
            'file_name': 'page1.jpg',
            'file_type': 'image',
            'file_size': 102400,
            'is_pdf': false,
            'is_image': true,
          },
          {
            'id': 2,
            'file_url': 'https://example.com/page2.jpg',
            'file_name': 'page2.jpg',
            'file_type': 'image',
            'file_size': 122880,
            'is_pdf': false,
            'is_image': true,
          },
          {
            'id': 3,
            'file_url': 'https://example.com/annex.pdf',
            'file_name': 'annex.pdf',
            'file_type': 'pdf',
            'file_size': 512000,
            'is_pdf': true,
            'is_image': false,
          },
        ],
      };

      final doc = CompanyDocumentItem.fromJson(json);

      expect(doc.id, equals(101));
      expect(doc.title, equals('Lease Agreement 2026'));
      expect(doc.attachments.length, equals(3));
      expect(doc.attachments[0].fileName, equals('page1.jpg'));
      expect(doc.attachments[1].fileName, equals('page2.jpg'));
      expect(doc.attachments[2].isPdf, isTrue);
      expect(doc.attachments[2].fileName, equals('annex.pdf'));
    });

    test('Falls back to main file_url when attachments list is empty', () {
      final json = {
        'id': 102,
        'category_code': 'tax',
        'category_name': 'Taxation',
        'title': 'Monthly Tax Nov 2026',
        'file_url': 'https://example.com/tax_nov.pdf',
        'file_name': 'tax_nov.pdf',
        'file_type': 'pdf',
        'file_size': 204800,
        'is_pdf': true,
        'is_image': false,
        'attachments': [],
      };

      final doc = CompanyDocumentItem.fromJson(json);

      expect(doc.attachments.length, equals(1));
      expect(doc.attachments[0].fileUrl, equals('https://example.com/tax_nov.pdf'));
      expect(doc.attachments[0].isPdf, isTrue);
    });
  });
}
