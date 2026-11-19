import 'package:cnattendance/provider/dashboardprovider.dart';
import 'package:cnattendance/theme/app_theme_mode.dart';
import 'package:cnattendance/theme/theme_layout.dart';
import 'package:cnattendance/theme/theme_provider.dart';
import 'package:cnattendance/widgets/theme_layout_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('layout round trips without changing navigation destinations', () {
    final layout = const ThemeLayout.defaults()
        .reorder(LayoutArea.tabs, LayoutItem.repair, LayoutItem.home)
        .setVisible(LayoutItem.social, false)
        .setVisible(LayoutItem.more, false)
        .setVisible(LayoutItem.chatShortcut, true)
        .setMenuOnRight(true)
        .setShowMenuButton(false)
        .setSeparateBanner(true)
        .setColors(
          background: const Color(0xff750f2b),
          accent: const Color(0xffe6b857),
        );
    final restored = ThemeLayout.decode(layout.encode());

    expect(
        restored.visibleTabIndices([
          LayoutItem.home,
          LayoutItem.social,
          LayoutItem.repair,
          LayoutItem.more,
        ]),
        [2, 0, 3]);
    expect(
        restored.visibleTabIndices([LayoutItem.home, LayoutItem.more]), [0, 1]);
    expect(restored.shows(LayoutItem.chatShortcut), isTrue);
    expect(LayoutItem.chatShortcut.allowed({}), isFalse);
    expect(LayoutItem.chatShortcut.allowed({'chat': '1'}), isTrue);
    expect(restored.menuOnRight, isTrue);
    expect(restored.showMenuButton, isFalse);
    expect(restored.separatesBanner(AppThemeMode.light), isTrue);
    expect(restored.background, const Color(0xff750f2b));
    expect(restored.accent, const Color(0xffe6b857));
  });

  test('invalid and future entries do not remove available defaults', () {
    final layout = ThemeLayout.decode(
        '{"order":{"home":["stories","future","stories","chatShortcut"]},"visibility":{"more":false}}');
    expect(layout.items(LayoutArea.home).first, LayoutItem.stories);
    expect(
        layout
            .items(LayoutArea.home)
            .where((item) => item == LayoutItem.stories),
        hasLength(1));
    expect(layout.items(LayoutArea.home),
        isNot(contains(LayoutItem.chatShortcut)));
    expect(layout.shows(LayoutItem.more), isTrue);
    expect(ThemeLayout.decode('{').showMenuButton, isTrue);
  });

  testWidgets('editor saves and resets a customized layout', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final provider = ThemeProvider();
    final dashboard = DashboardProvider();
    addTearDown(provider.dispose);
    addTearDown(dashboard.dispose);
    await tester.binding.setSurfaceSize(const Size(390, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await provider.saveLayout(
      AppThemeMode.khmerHeritage,
      const ThemeLayout.defaults().setVisible(LayoutItem.profile, false),
    );
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: provider),
        ChangeNotifierProvider<DashboardProvider>.value(value: dashboard),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const ThemeLayoutEditor(),
              )),
              child: const Text('Open editor'),
            ),
          ),
        ),
      ),
    ));

    Future<void> open() async {
      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();
    }

    await open();
    final profile = find.byKey(const ValueKey(LayoutItem.profile));
    final banner = find.byKey(const ValueKey(LayoutItem.banner));
    final handle =
        find.descendant(of: banner, matching: find.byIcon(Icons.drag_handle));
    final drag = await tester.startGesture(tester.getCenter(handle));
    await drag.moveBy(const Offset(0, -10));
    await tester.pump();
    await drag.moveBy(const Offset(0, -30));
    await tester.pump();
    await drag.moveBy(const Offset(0, -70));
    await tester.pump(const Duration(milliseconds: 300));
    await drag.up();
    await tester.pumpAndSettle();
    expect(
        tester.getTopLeft(banner).dy, lessThan(tester.getTopLeft(profile).dy));

    await tester.tap(
        find.descendant(of: profile, matching: find.byType(SwitchListTile)));
    await tester.pumpAndSettle();
    final appearance = find.text('Colors & placement');
    await tester.ensureVisible(appearance);
    await tester.tap(appearance);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accent color'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '#E6B857');
    await tester.tap(find.text('Use color'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Right'));
    await tester.tap(find.text('Right'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Separate banner, quote and clock'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save layout'));
    await tester.pumpAndSettle();
    expect(provider.layout.shows(LayoutItem.profile), isFalse);
    expect(provider.layout.visible(LayoutArea.home).first, LayoutItem.banner);
    expect(provider.layout.accent, const Color(0xffe6b857));
    expect(provider.layout.menuOnRight, isTrue);
    expect(provider.layout.separatesBanner(AppThemeMode.light), isTrue);

    await open();
    await tester.tap(find.text('Reset to default'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save layout'));
    await tester.pumpAndSettle();
    expect(provider.layout.shows(LayoutItem.profile), isTrue);
    expect(provider.layout.visible(LayoutArea.home).first, LayoutItem.profile);
    expect(provider.layout.accent, isNull);
    expect(provider.layout.menuOnRight, isFalse);
    expect(provider.layout.separatesBanner(AppThemeMode.light), isFalse);

    final prefs = await SharedPreferences.getInstance();
    final heritage =
        ThemeLayout.decode(prefs.getString('theme_layout_khmer_heritage'));
    expect(heritage.shows(LayoutItem.profile), isFalse);
  });
}
