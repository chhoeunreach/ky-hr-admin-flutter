import 'dart:io';

import 'package:cnattendance/data/source/network/connect.dart';
import 'package:cnattendance/repositories/admin_asset_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Localhost with a closed port: the server-URL probe fails instantly
  // without touching the real network, and the resolver still returns
  // this base URL so update requests reach the injected MockClient.
  const testBaseUrl = 'http://127.0.0.1:9/';

  setUpAll(() async {
    // GetStorage resolves its file location through path_provider, which
    // has no native implementation under `flutter test`.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => Directory.systemTemp.createTempSync('gstorage').path,
    );
    await GetStorage.init();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({'app_url': testBaseUrl});
  });

  tearDown(() {
    Connect.overrideClient(null);
  });

  http.Response jsonResponse(String body, int status) => http.Response(
        body,
        status,
        headers: {'content-type': 'application/json'},
      );

  test('updateAsset falls back to PUT when the server rejects POST with 405',
      () async {
    final seen = <String>[];
    Connect.overrideClient(MockClient((request) async {
      seen.add('${request.method} ${request.url.path}');
      if (request.method == 'POST') {
        return jsonResponse(
          '{"message":"The POST method is not supported for this route."}',
          405,
        );
      }
      return jsonResponse(
        '{"status":true,"message":"Asset updated successfully"}',
        200,
      );
    }));

    final (ok, message) =
        await AdminAssetRepository().updateAsset(1, {'name': 'Laptop'});

    expect(ok, isTrue);
    expect(message, 'Asset updated successfully');
    expect(seen, ['POST /api/admin/assets/1', 'PUT /api/admin/assets/1']);
  });

  test('updateAsset keeps a plain POST 200 without retrying', () async {
    final seen = <String>[];
    Connect.overrideClient(MockClient((request) async {
      seen.add('${request.method} ${request.url.path}');
      return jsonResponse(
        '{"status":true,"message":"Asset updated successfully"}',
        200,
      );
    }));

    final (ok, message) =
        await AdminAssetRepository().updateAsset(2, {'name': 'Mouse'});

    expect(ok, isTrue);
    expect(message, 'Asset updated successfully');
    expect(seen, ['POST /api/admin/assets/2']);
  });

  test('updateAsset surfaces a non-405 failure without retrying', () async {
    final seen = <String>[];
    Connect.overrideClient(MockClient((request) async {
      seen.add('${request.method} ${request.url.path}');
      return jsonResponse('{"status":false,"message":"Validation failed"}', 422);
    }));

    final (ok, message) =
        await AdminAssetRepository().updateAsset(3, {'name': ''});

    expect(ok, isFalse);
    expect(message, 'Validation failed');
    expect(seen, ['POST /api/admin/assets/3']);
  });

  test('updateAsset retries PUT but still reports failure when PUT also fails',
      () async {
    final seen = <String>[];
    Connect.overrideClient(MockClient((request) async {
      seen.add('${request.method} ${request.url.path}');
      if (request.method == 'POST') {
        return jsonResponse('{"message":"Method Not Allowed"}', 405);
      }
      return jsonResponse('{"message":"Server exploded"}', 500);
    }));

    final (ok, message) =
        await AdminAssetRepository().updateAsset(4, {'name': 'Desk'});

    expect(ok, isFalse);
    expect(message, 'Server exploded');
    expect(seen, ['POST /api/admin/assets/4', 'PUT /api/admin/assets/4']);
  });

  test('updateAsset treats a non-JSON 405 body as method-unsupported', () async {
    final seen = <String>[];
    Connect.overrideClient(MockClient((request) async {
      seen.add('${request.method} ${request.url.path}');
      if (request.method == 'POST') {
        return http.Response('<html>Method Not Allowed</html>', 405);
      }
      return jsonResponse(
        '{"status":true,"message":"Asset updated successfully"}',
        200,
      );
    }));

    final (ok, _) = await AdminAssetRepository().updateAsset(5, {'name': 'X'});

    expect(ok, isTrue);
    expect(seen, ['POST /api/admin/assets/5', 'PUT /api/admin/assets/5']);
  });
}
