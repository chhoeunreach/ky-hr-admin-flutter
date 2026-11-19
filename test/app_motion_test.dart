import 'dart:convert';
import 'dart:io';

import 'package:cnattendance/theme/theme_provider.dart';
import 'package:cnattendance/widget/enterprise/app_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get_storage/get_storage.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/chat_storage_test_env.dart';

void main() {
  setUpAll(ChatStorageTestEnv.install);
  tearDownAll(ChatStorageTestEnv.uninstall);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await GetStorage().remove('animation');
    Localization.load(jsonDecode(File('assets/i18n/en.json').readAsStringSync())
        as Map<String, dynamic>);
  });

  test('restores the animation preference from existing installs', () async {
    await GetStorage().write('animation', false);
    final settings = ThemeProvider();
    addTearDown(settings.dispose);
    await settings.load();
    expect(settings.animationsEnabled, isFalse);
  });

  testWidgets('switch and row taps apply motion settings on the current route',
      (tester) async {
    final settings = ThemeProvider();
    addTearDown(settings.dispose);
    var reduceMotion = false;
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: settings,
      child: MaterialApp(
        builder: (context, child) => AppMotion(child: child!),
        home: Scaffold(
          body: Builder(builder: (context) {
            reduceMotion = MediaQuery.disableAnimationsOf(context);
            return const AnimationSettingsTile();
          }),
        ),
      ),
    ));

    final tile = find.byType(SwitchListTile);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    expect(tester.widget<SwitchListTile>(tile).value, isTrue);
    expect(reduceMotion, isFalse);

    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(tester.widget<SwitchListTile>(tile).value, isFalse);
    expect(reduceMotion, isTrue);
    expect(GetStorage().read('animation'), isFalse);

    await tester.tap(find.text('Animation'));
    await tester.pump();
    expect(tester.widget<SwitchListTile>(tile).value, isTrue);
    expect(reduceMotion, isFalse);
    expect(GetStorage().read('animation'), isTrue);

    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pump();
    expect(reduceMotion, isTrue);
    expect(tester.state(find.byType(Navigator)), same(navigator));
    expect(tester.takeException(), isNull);
  });
}
