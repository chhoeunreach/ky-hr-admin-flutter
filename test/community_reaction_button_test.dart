import 'package:cnattendance/features/community/reaction_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_translate/flutter_translate.dart';

void main() {
  setUpAll(() => Localization.load({}));

  Future<void> open(WidgetTester tester, List<String?> changes,
      {String? reaction, bool enabled = true}) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Align(
                alignment: Alignment.bottomLeft,
                child: CommunityReactionButton(
                    reaction: reaction,
                    enabled: enabled,
                    onChanged: changes.add)))));
  }

  testWidgets('tap likes immediately without opening picker', (tester) async {
    final changes = <String?>[];
    await open(tester, changes);
    await tester.tap(find.text('Like'));
    await tester.pumpAndSettle();
    expect(changes, ['like']);
    expect(find.byKey(const ValueKey('reaction-choice-love')), findsNothing);
  });

  testWidgets('tap selected reaction removes it and shows its label',
      (tester) async {
    for (final reaction in communityReactions.keys) {
      final changes = <String?>[];
      await open(tester, changes, reaction: reaction);
      final label = '${reaction[0].toUpperCase()}${reaction.substring(1)}';
      expect(find.text(label), findsOneWidget);
      await tester.tap(find.text(label));
      expect(changes, [null]);
    }
  });

  testWidgets('long press opens all choices without sending a Like',
      (tester) async {
    final changes = <String?>[];
    await open(tester, changes);
    await tester.longPress(find.text('Like'));
    await tester.pumpAndSettle();
    expect(changes, isEmpty);
    for (final reaction in communityReactions.keys) {
      expect(find.byKey(ValueKey('reaction-choice-$reaction')), findsOneWidget);
    }
    await tester.tap(find.byKey(const ValueKey('reaction-choice-angry')));
    await tester.pumpAndSettle();
    expect(changes, ['angry']);
    expect(find.byKey(const ValueKey('reaction-choice-angry')), findsNothing);
  });

  testWidgets(
      'picker fits narrow screens and dismisses without changing reaction',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final changes = <String?>[];
    await open(tester, changes);
    await tester.longPress(find.text('Like'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tapAt(const Offset(280, 100));
    await tester.pumpAndSettle();
    expect(changes, isEmpty);
    expect(find.byKey(const ValueKey('reaction-choice-love')), findsNothing);
  });

  testWidgets('busy or unauthorized button cannot react or open picker',
      (tester) async {
    final changes = <String?>[];
    await open(tester, changes, enabled: false);
    await tester.tap(find.text('Like'));
    await tester.longPress(find.text('Like'));
    await tester.pumpAndSettle();
    expect(changes, isEmpty);
    expect(find.byKey(const ValueKey('reaction-choice-love')), findsNothing);
  });
}
