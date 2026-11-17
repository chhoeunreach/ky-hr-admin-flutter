import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:persistent_bottom_nav_bar_v2/persistent_bottom_nav_bar_v2.dart';

Widget dashboard(ValueNotifier<int> count,
        {PersistentTabController? controller, int revision = 0}) =>
    MaterialApp(
      home: ValueListenableBuilder<int>(
        valueListenable: count,
        builder: (context, tabCount, _) => PersistentTabView(
          key: ValueKey('tabs-$revision'),
          controller: controller,
          screenTransitionAnimation:
              const ScreenTransitionAnimation(duration: Duration.zero),
          tabs: List.generate(
            tabCount,
            (index) => PersistentTabConfig(
              item: ItemConfig(icon: const Icon(Icons.home)),
              screen: Scaffold(
                body: Center(
                  child: Builder(
                    builder: (context) => ElevatedButton(
                      onPressed: () =>
                          Navigator.of(context, rootNavigator: true).push(
                              MaterialPageRoute<void>(
                                  builder: (_) => const Scaffold(
                                      body: TextField(
                                          key: ValueKey('report-input'))))),
                      child: const Text('Open report'),
                    ),
                  ),
                ),
              ),
            ),
          ),
          navBarBuilder: (_) => const SizedBox(height: 56),
        ),
      ),
    );

void main() {
  testWidgets(
      'dashboard does not steal focus from a report when keyboard opens',
      (tester) async {
    final count = ValueNotifier(2);
    final controller = PersistentTabController();
    addTearDown(count.dispose);
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(dashboard(count, controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open report'));
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('report-input'));
    await tester.tap(field);
    await tester.pumpAndSettle();
    final editable = tester.state<EditableTextState>(
        find.descendant(of: field, matching: find.byType(EditableText)));
    expect(editable.widget.focusNode.hasFocus, isTrue);
    // Permission refreshes replace the tab configuration while a root report
    // route is open, reparenting the controller's globally keyed scaffold.
    await tester
        .pumpWidget(dashboard(count, controller: controller, revision: 1));
    await tester.pumpAndSettle();
    expect(editable.widget.focusNode.hasFocus, isTrue);
    for (final inset in [100.0, 200.0, 300.0]) {
      tester.view.viewInsets =
          FakeViewPadding(bottom: inset * tester.view.devicePixelRatio);
      await tester.pumpAndSettle();
      expect(editable.mounted, isTrue);
      expect(editable.widget.focusNode.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
    }
    await tester.enterText(field, '123');
    await tester.pumpAndSettle();
    expect(editable.widget.controller.text, '123');
    expect(editable.widget.focusNode.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard can add and remove tabs after permissions load',
      (tester) async {
    final count = ValueNotifier(2);
    final controller = PersistentTabController();
    addTearDown(count.dispose);
    addTearDown(controller.dispose);
    await tester.pumpWidget(dashboard(count, controller: controller));
    await tester.pumpAndSettle();
    count.value = 3;
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    controller.jumpToTab(2);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Open report'), findsOneWidget);
    controller.jumpToTab(0);
    await tester.pumpAndSettle();
    count.value = 2;
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Open report'), findsOneWidget);
  });
}
