import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/data/source/network/model/asssetlistresponse/assetlistresponse.dart';
import 'package:cnattendance/model/admin_asset.dart';
import 'package:cnattendance/utils/asset_permissions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AssetPermissions.canOpenAdmin', () {
    test('allows when all keys absent', () {
      expect(AssetPermissions.canOpenAdmin({}), isTrue);
    });

    test('allows when keys present and not "0"', () {
      expect(
        AssetPermissions.canOpenAdmin({
          'assets-admin': '1',
          'asset_management': '1',
          'asset-management': '1',
        }),
        isTrue,
      );
    });

    test('blocks when any known key is "0"', () {
      expect(
        AssetPermissions.canOpenAdmin({'assets-admin': '0'}),
        isFalse,
      );
      expect(
        AssetPermissions.canOpenAdmin({'asset_management': '0'}),
        isFalse,
      );
      expect(
        AssetPermissions.canOpenAdmin({'asset-management': '0'}),
        isFalse,
      );
      expect(
        AssetPermissions.canOpenAdmin({'list_assets': '0'}),
        isFalse,
      );
    });
  });

  group('AssetPermissions.crud', () {
    test('defaults to full access when features empty', () async {
      final result = await AssetPermissions.crud();
      expect(result.create, isTrue);
      expect(result.edit, isTrue);
      expect(result.delete, isTrue);
    });

    test('honours explicit deny keys', () async {
      await Preferences().setFeatures({
        'create_assets': '0',
        'edit_assets': '0',
        'delete_assets': '0',
        'assets-admin': '0',
        'asset-management': '0',
        'asset_management': '0',
        'assets': '0',
        'ASSETS': '0',
        'list_assets': '0',
      });
      final result = await AssetPermissions.crud();
      expect(result.create, isFalse);
      expect(result.edit, isFalse);
      expect(result.delete, isFalse);
    });

    test('admin grant opens all abilities', () async {
      await Preferences().setFeatures({
        'assets-admin': '1',
        'create_assets': '0',
        'edit_assets': '0',
        'delete_assets': '0',
      });
      final result = await AssetPermissions.crud();
      expect(result.create, isTrue);
      expect(result.edit, isTrue);
      expect(result.delete, isTrue);
    });
  });

  group('AssetListResponse defensive parsing', () {
    test('parses a valid payload', () {
      final response = AssetListResponse.fromJson({
        'status': true,
        'message': 'ok',
        'status_code': 200,
        'data': [
          {
            'id': 1,
            'asset': 'MacBook',
            'assigned_date': '2025-01-01',
            'returned_date': null,
            'status': 'assigned',
            'return_condition': null,
            'notes': null,
          },
        ],
      });
      expect(response.status, isTrue);
      expect(response.data, hasLength(1));
      expect(response.data.first.asset, 'MacBook');
      expect(response.data.first.notes, isNull);
    });

    test('skips malformed rows instead of throwing', () {
      final response = AssetListResponse.fromJson({
        'status': true,
        'message': 'ok',
        'status_code': 200,
        'data': [
          null,
          'not-a-map',
          {
            'id': '42',
            'asset': 123,
            'assigned_date': null,
          },
          {
            'id': 7,
            'asset': 'Good row',
            'assigned_date': '2025-02-02',
          },
        ],
      });
      expect(response.data, hasLength(2));
      expect(response.data.first.id, 42);
      expect(response.data.first.asset, '123');
      expect(response.data.last.id, 7);
      expect(response.data.last.asset, 'Good row');
    });

    test('missing keys do not throw', () {
      final response = AssetListResponse.fromJson({});
      expect(response.status, isFalse);
      expect(response.message, '');
      expect(response.statusCode, 200);
      expect(response.data, isEmpty);
    });

    test('notes empty-string is preserved for return-state checks', () {
      final row = AssetData.fromJson({
        'id': 1,
        'asset': 'Phone',
        'assigned_date': '2025-01-01',
        'notes': '',
      });
      expect(row.notes, '');
      final isReturned =
          row.notes != null && row.notes!.trim().isNotEmpty;
      expect(isReturned, isFalse);
    });
  });

  group('AdminAsset defensive parsing', () {
    test('accepts yes/true string booleans', () {
      final asset = AdminAsset.fromJson({
        'id': 1,
        'name': 'Laptop',
        'is_available': 'yes',
        'warranty_available': 'true',
        'is_working': 'yes',
      });
      expect(asset.isAvailable, isTrue);
      expect(asset.warrantyAvailable, isTrue);
    });

    test('skips non-map assignment history entries', () {
      final asset = AdminAsset.fromJson({
        'id': 1,
        'name': 'Laptop',
        'assignment_history': [
          null,
          'bad',
          {
            'id': 1,
            'user_id': 9,
            'employee_name': 'Alice',
            'assigned_date': '2025-01-01',
            'status': 'assigned',
          },
        ],
      });
      expect(asset.assignmentHistory, hasLength(1));
      expect(asset.assignmentHistory.first.employeeName, 'Alice');
    });

    test('skips null image entries', () {
      final asset = AdminAsset.fromJson({
        'id': 1,
        'name': 'Laptop',
        'images': [null, 'https://x/a.jpg', ''],
      });
      expect(asset.images, ['https://x/a.jpg']);
    });
  });
}
