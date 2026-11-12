import 'package:cnattendance/data/source/network/model/dashboard/Feature.dart';
import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('missing snapshot never grants legacy default access', () async {
    SharedPreferences.setMockInitialValues({'attendance': '1', 'meeting': '1'});
    expect(await Preferences().getFeatures(), isEmpty);
  });

  test(
      'snapshot preserves all function permissions and replaces revoked grants',
      () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = Preferences();
    await preferences.setFeatures({
      'attendance': '1',
      'mobile.function.GroupChat.destroy': '1',
      'id-card': '1',
    });
    expect(
        (await preferences.getFeatures())['mobile.function.GroupChat.destroy'],
        '1');
    await preferences.setFeatures({'attendance': '0'});
    expect(await preferences.getFeatures(), {'attendance': '0'});
  });

  test('logout removes all cached role permissions', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = Preferences();
    await preferences.setFeatures({'attendance': '1', 'id-card': '1'});
    await preferences.clearPrefs();
    expect(await preferences.getFeatures(), isEmpty);
  });

  test('feature statuses normalize booleans and default to denied', () {
    for (final value in [true, 1, '1', 'true']) {
      expect(
          Feature.fromJson({'key': 'attendance', 'status': value}).status, '1');
    }
    for (final value in [false, 0, '0', null, 'unknown']) {
      expect(
          Feature.fromJson({'key': 'attendance', 'status': value}).status, '0');
    }
  });

  test('malformed snapshot denies access', () async {
    SharedPreferences.setMockInitialValues({'role_features_v2': '{broken'});
    expect(await Preferences().getFeatures(), isEmpty);
  });
}
