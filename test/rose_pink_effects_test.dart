import 'package:cnattendance/theme/app_theme_mode.dart';
import 'package:cnattendance/theme/theme_provider.dart';
import 'package:cnattendance/widget/enterprise/rose_pink_effects.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _ThemeSettings extends ThemeProvider {
  @override
  AppThemeMode mode = AppThemeMode.rosePink;
  final effects = <String>{};

  @override
  bool effectEnabled(String key) => effects.contains(key);

  @override
  Future<void> setMode(AppThemeMode mode) async {
    this.mode = mode;
    notifyListeners();
  }

  @override
  Future<void> setEffect(String key, bool enabled) async {
    enabled ? effects.add(key) : effects.remove(key);
    notifyListeners();
  }
}

Widget _app(_ThemeSettings settings, Widget home, {bool systemReduce = false}) {
  return ChangeNotifierProvider<ThemeProvider>.value(
    value: settings,
    child: MaterialApp(
      home: home,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: systemReduce),
        child: RosePinkEffectsOverlay(child: child!),
      ),
    ),
  );
}

void main() {
  final layer = find.byType(RosePinkEffects);
  final paint = find.descendant(of: layer, matching: find.byType(CustomPaint));

  testWidgets('one layer covers routes, drawers, and menus without taking taps',
      (tester) async {
    final settings = _ThemeSettings()
      ..effects.addAll({'floating_hearts', 'reduce_animations'});
    addTearDown(settings.dispose);
    await tester.pumpWidget(_app(
      settings,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            child: const Text('Open details'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (context) => Scaffold(
                drawer: const Drawer(child: Center(child: Text('Menu drawer'))),
                appBar: AppBar(
                  title: const Text('Details'),
                  actions: [
                    PopupMenuButton<String>(
                      onSelected: (value) => showDialog<void>(
                        context: context,
                        builder: (_) => AlertDialog(content: Text(value)),
                      ),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'Menu dialog',
                          child: Text('Open dialog'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )),
          ),
        ),
      ),
    ));
    final state = tester.state(layer);
    expect(paint, findsOneWidget);

    await tester.tap(find.text('Open details'));
    await tester.pumpAndSettle();
    expect(find.text('Details'), findsOneWidget);
    expect(tester.state(layer), same(state));

    tester.state<ScaffoldState>(find.byType(Scaffold).last).openDrawer();
    await tester.pumpAndSettle();
    expect(find.text('Menu drawer'), findsOneWidget);
    expect(tester.state(layer), same(state));
    tester.state<ScaffoldState>(find.byType(Scaffold).last).closeDrawer();
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(tester.state(layer), same(state));
    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
    expect(tester.state(layer), same(state));
    expect(find.text('Menu dialog'), findsOneWidget);

    // Effects are admin-controlled and theme-independent: leaving rose pink
    // keeps the enabled layer mounted.
    await settings.setMode(AppThemeMode.dark);
    await tester.pumpAndSettle();
    expect(layer, findsOneWidget);
    expect(find.text('Menu dialog'), findsOneWidget);
  });

  testWidgets('each Rose Pink effect paints independently', (tester) async {
    final settings = _ThemeSettings()..effects.add('reduce_animations');
    addTearDown(settings.dispose);
    await tester.pumpWidget(_app(settings, const Scaffold()));
    expect(paint, findsNothing);

    for (final (effect, expectedPaint) in [
      ('heart_glow', paints..path(hasMaskFilter: true)),
      ('floating_hearts', paints..path(hasMaskFilter: false)),
      (
        'rose_petals',
        paints..path(color: const Color(0xfffb7ca5).withValues(alpha: 0.24))
      ),
      ('sparkle_effects', paints..line()),
    ]) {
      await settings.setEffect(effect, true);
      await tester.pump();
      expect(paint, expectedPaint);
      await settings.setEffect(effect, false);
      await tester.pump();
      expect(paint, findsNothing);
    }
  });

  testWidgets('animation stops with motion restrictions or all effects off',
      (tester) async {
    final settings = _ThemeSettings()..effects.add('floating_hearts');
    addTearDown(settings.dispose);
    await tester.pumpWidget(_app(settings, const Scaffold()));
    expect(tester.hasRunningAnimations, isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(tester.hasRunningAnimations, isTrue);

    await settings.setEffect('reduce_animations', true);
    await tester.pump();
    expect(paint, findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);

    await settings.setEffect('reduce_animations', false);
    await tester
        .pumpWidget(_app(settings, const Scaffold(), systemReduce: true));
    expect(paint, findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);

    await tester.pumpWidget(_app(settings, const Scaffold()));
    await settings.setEffect('floating_hearts', false);
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    expect(paint, findsNothing);
  });
}
