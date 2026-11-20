import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/provider/dashboardprovider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the mobile app replaces revoked grants when refreshing from admin',
      () async {
    SharedPreferences.setMockInitialValues({
      'app_url': '/test/',
      'user_token': 'test-token',
      'role_features_v2': '{"attendance":"1","check_in":"1"}',
    });
    final provider = DashboardProvider();
    addTearDown(provider.dispose);
    await provider.getFeatures();

    var statusCode = 200;
    await http.runWithClient(() async {
      await provider.refreshMobileFeatures();
      expect(provider.features, {'attendance': '0', 'check_in': '0'});
      expect(await Preferences().getFeatures(), provider.features);

      statusCode = 503;
      await provider.refreshMobileFeatures();
      expect(provider.features, {'attendance': '0', 'check_in': '0'});
    },
        () => MockClient((request) async {
              expect(request.url.path, '/test/api/mobile-features');
              expect(request.headers['authorization'], 'Bearer test-token');
              return http.Response(
                '{"data":[{"key":"attendance","status":"0"},{"key":"check_in","status":"0"}]}',
                statusCode,
              );
            }));
  });
}
