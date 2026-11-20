import 'package:cnattendance/core/ky_security/ky_http.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('account logout preserves the Passport bearer for server revocation', () async {
    final uri = Uri.https('kneayerng.test', '/api/logout');
    var requestCount = 0;
    final client = MockClient((request) async {
      requestCount++;
      expect(request.method, 'GET');
      expect(request.url, uri);
      expect(request.headers['Authorization'], 'Bearer test-passport-token');
      return http.Response('{"statusCode":200}', 200,
          headers: {'content-type': 'application/json'});
    });

    final response = await KyHttp.accountLogout(
      uri,
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer test-passport-token'},
      client: client,
    );

    expect(response.statusCode, 200);
    expect(requestCount, 1);
  });
}
