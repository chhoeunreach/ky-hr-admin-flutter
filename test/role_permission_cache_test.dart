import 'package:cnattendance/data/source/network/model/dashboard/Feature.dart';
import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/provider/dashboardprovider.dart';
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
    await preferences.cacheRoleMobileLayout(
      true,
      {'attendance': ['bottom'], 'holiday': ['sidebar']},
      positions: {
        'attendance': {'bottom': 1},
        'holiday': {'sidebar': 0},
      },
    );
    await preferences.clearPrefs();
    expect(await preferences.getFeatures(), isEmpty);
    expect(await preferences.getRoleMobileLayout(), isEmpty);
    expect(await preferences.getRoleMobileLayoutPositions(), isEmpty);
  });

  test('role layout cache retains placements and per-zone ordering', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = Preferences();
    await preferences.cacheRoleMobileLayout(
      true,
      {'attendance': ['bottom', 'home_quick'], 'holiday': ['bottom']},
      positions: {
        'attendance': {'bottom': 1, 'home_quick': 0},
        'holiday': {'bottom': 0},
      },
    );

    expect(await preferences.isRoleMobileLayoutConfigured(), isTrue);
    expect(await preferences.getRoleMobileLayout(), {
      'attendance': ['bottom', 'home_quick'],
      'holiday': ['bottom'],
    });
    expect(await preferences.getRoleMobileLayoutPositions(), {
      'attendance': {'bottom': 1, 'home_quick': 0},
      'holiday': {'bottom': 0},
    });
  });

  test('dashboard role menus follow saved placement order and visibility', () {
    final dashboard = DashboardProvider()
      ..mobileLayoutConfigured = true
      ..mobileLayout = {
        'attendance': ['bottom', 'home_quick'],
        'holiday': ['bottom'],
        'notice': [],
      }
      ..mobileLayoutPositions = {
        'attendance': {'bottom': 1, 'home_quick': 0},
        'holiday': {'bottom': 0},
        'notice': {},
      };

    expect(dashboard.mobileMenusAt('bottom'), ['holiday', 'attendance']);
    expect(dashboard.mobileMenusAt('home_quick'), ['attendance']);
    expect(dashboard.isMobileMenuAt('notice', 'sidebar'), isFalse);
    dashboard.dispose();
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
