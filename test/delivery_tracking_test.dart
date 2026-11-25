import 'package:flutter_test/flutter_test.dart';
import 'package:cnattendance/features/delivery/delivery_model.dart';

void main() {
  group('DeliveryModel Tests', () {
    test('Correctly parses full delivery JSON payload', () {
      final json = {
        'id': 101,
        'user_id': 5,
        'branch_id': 2,
        'tracking_code': 'DEL-20261125-9988',
        'tracking_token': 'test_token_abc123',
        'invoice_number': 'INV-2026-99',
        'customer_name': 'Sokha Chan',
        'customer_phone': '012345678',
        'destination_address': 'Building 12, St 271, Phnom Penh',
        'destination_latitude': 11.5448,
        'destination_longitude': 104.9123,
        'origin_address': 'Head Office Toul Kork',
        'origin_latitude': 11.5682,
        'origin_longitude': 104.8992,
        'current_latitude': 11.5555,
        'current_longitude': 104.9050,
        'heading': 180.5,
        'speed': 35.2,
        'status': 'in_transit',
        'status_label': 'កំពុងធ្វើដំណើរ (In Transit)',
        'is_active': true,
        'started_at': '2026-11-25T10:00:00.000Z',
        'notes': 'Call 5 mins before arrival',
        'tracking_url': 'https://kneayerng.com/track/live/test_token_abc123',
        'driver': {
          'name': 'Dara Driver',
          'phone': '098765432',
          'avatar': 'https://kneayerng.com/avatars/dara.jpg',
        },
      };

      final delivery = DeliveryModel.fromJson(json);

      expect(delivery.id, equals(101));
      expect(delivery.userId, equals(5));
      expect(delivery.trackingCode, equals('DEL-20261125-9988'));
      expect(delivery.customerName, equals('Sokha Chan'));
      expect(delivery.customerPhone, equals('012345678'));
      expect(delivery.destinationLatitude, equals(11.5448));
      expect(delivery.destinationLongitude, equals(104.9123));
      expect(delivery.currentLatitude, equals(11.5555));
      expect(delivery.currentLongitude, equals(104.9050));
      expect(delivery.heading, equals(180.5));
      expect(delivery.speed, equals(35.2));
      expect(delivery.status, equals('in_transit'));
      expect(delivery.isActive, isTrue);
      expect(delivery.driverName, equals('Dara Driver'));
      expect(delivery.driverPhone, equals('098765432'));
      expect(delivery.trackingUrl, contains('test_token_abc123'));
    });

    test('Correctly falls back when optional fields are null or strings', () {
      final json = {
        'id': '50',
        'user_id': '3',
        'tracking_code': 'DEL-MINIMAL',
        'tracking_token': 'tok_min',
        'customer_name': 'Reach',
        'customer_phone': '011223344',
        'destination_latitude': '11.5',
        'destination_longitude': '104.9',
        'status': 'delivered',
        'status_label': 'បានប្រគល់',
      };

      final delivery = DeliveryModel.fromJson(json);

      expect(delivery.id, equals(50));
      expect(delivery.userId, equals(3));
      expect(delivery.customerName, equals('Reach'));
      expect(delivery.destinationLatitude, equals(11.5));
      expect(delivery.destinationLongitude, equals(104.9));
      expect(delivery.status, equals('delivered'));
      expect(delivery.invoiceNumber, isNull);
      expect(delivery.driverName, isNull);
    });

    test('copyWith produces updated values preserving originals', () {
      final delivery = DeliveryModel(
        id: 1,
        userId: 2,
        trackingCode: 'C1',
        trackingToken: 'T1',
        customerName: 'A',
        customerPhone: '012',
        status: 'pending',
        statusLabel: 'Pending',
        isActive: true,
      );

      final updated = delivery.copyWith(
        status: 'delivered',
        statusLabel: 'Delivered',
        isActive: false,
      );

      expect(updated.id, equals(1));
      expect(updated.customerName, equals('A'));
      expect(updated.status, equals('delivered'));
      expect(updated.isActive, isFalse);
    });
  });
}
