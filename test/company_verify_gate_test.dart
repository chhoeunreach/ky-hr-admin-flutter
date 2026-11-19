import 'dart:convert';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/model/auth.dart';
import 'package:cnattendance/services/server_url_resolver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storedServer = 'https://stored.example.com/';

  group('company verification gate', () {
    test('is off by default so a fresh install keeps the sign-in form',
        () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = Preferences();
      expect(await preferences.getCompanyVerifyRequired(), isFalse);
    });

    test('round-trips through preferences', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = Preferences();
      await preferences.setCompanyVerifyRequired(true);
      expect(await preferences.getCompanyVerifyRequired(), isTrue);
      await preferences.setCompanyVerifyRequired(false);
      expect(await preferences.getCompanyVerifyRequired(), isFalse);
    });

    test('clearPrefs does not change the flag', () async {
      SharedPreferences.setMockInitialValues({
        'company_verify_required': true,
      });
      final preferences = Preferences();
      await preferences.clearPrefs();
      expect(await preferences.getCompanyVerifyRequired(), isTrue);
    });

    test('Auth.getAppUrl stays empty while verification is required',
        () async {
      SharedPreferences.setMockInitialValues({
        'app_url': storedServer,
        'company_verify_required': true,
      });
      final auth = Auth();
      await auth.getAppUrl();
      expect(auth.appUrl, '');
    });

    test('Auth.resetAppUrl (logout path) requires verification again',
        () async {
      SharedPreferences.setMockInitialValues({'app_url': storedServer});
      final auth = Auth();
      auth.appUrl = storedServer;
      await auth.resetAppUrl();
      expect(auth.appUrl, '');
      expect(await auth.preferences.getCompanyVerifyRequired(), isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_url'), '');
    });

    test('Auth.skipAppUrl bypass still clears the gate', () async {
      SharedPreferences.setMockInitialValues({
        'company_verify_required': true,
      });
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'status': true,
            'message': 'Data found',
            'data': {'server_fallback_url': 'https://backup.example.com/'},
          }),
          200,
        );
      });
      final auth = Auth();
      auth.preferences =
          Preferences(serverUrlResolver: ServerUrlResolver(client: client));
      await auth.skipAppUrl();
      expect(await auth.preferences.getCompanyVerifyRequired(), isFalse);
      expect(auth.appUrl, isNotEmpty);
    });
  });
}
