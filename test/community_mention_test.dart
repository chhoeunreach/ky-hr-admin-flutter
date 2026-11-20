import 'dart:convert';
import 'dart:io';

import 'package:cnattendance/features/community/community_api.dart';
import 'package:cnattendance/features/community/mention_directory.dart';
import 'package:cnattendance/features/community/mention_field.dart';
import 'package:cnattendance/features/community/social_feed_screen.dart';
import 'package:cnattendance/model/chat_contact.dart';
import 'package:cnattendance/provider/dashboardprovider.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'community_feature_test.dart' show postFixture;

class FakeCommunityApi extends CommunityApi {
  final List<String> calls = [];
  final List<Map<String, dynamic>?> payloads = [];
  final Map<String, Map<String, dynamic>> responses = {};
  @override
  Future<Map<String, dynamic>> request(String method, String path,
      {Map<String, dynamic>? data,
      String? filePath,
      String? fileMime,
      List<String>? filePaths,
      List<String>? fileMimes}) async {
    calls.add('$method $path');
    payloads.add(data);
    return responses['$method $path'] ?? {'data': [], 'next_page_url': null};
  }
}

List<ChatContact> directoryFixture() => [
      ChatContact.fromJson({'id': 7, 'name': 'Sokha Dara', 'department': 'HR'}),
      ChatContact.fromJson({'id': 8, 'name': 'Dara Sok', 'department': 'IT'}),
      ChatContact.fromJson(
          {'id': 9, 'name': 'Chan Vibol', 'department': 'Finance'}),
    ];

bool _spanHas(InlineSpan span, String text) {
  if (span is! TextSpan) return false;
  if (span.text == text) return true;
  return span.children?.any((child) => _spanHas(child, text)) ?? false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues(
        {'user_id': 10, 'user_token': 'test'});
    Localization.load(jsonDecode(File('assets/i18n/en.json').readAsStringSync())
        as Map<String, dynamic>);
    MentionDirectory.resetForTest();
    MentionDirectory.debugSeed(directoryFixture());
  });
  tearDown(MentionDirectory.resetForTest);

  Widget app(Widget screen) => ChangeNotifierProvider(
        create: (_) =>
            DashboardProvider()..features = {'social_feed.comment': '1'},
        child: MaterialApp(home: screen),
      );

  test('mention directory lists everyone first and filters by name', () {
    final all = MentionDirectory.query('');
    expect(all.first.isEveryone, isTrue);
    expect(all.map((row) => row.name),
        containsAll(['Sokha Dara', 'Dara Sok', 'Chan Vibol']));

    final filtered = MentionDirectory.query('dara');
    expect(filtered.map((row) => row.name),
        containsAll(['Sokha Dara', 'Dara Sok']));
    expect(filtered.map((row) => row.name), isNot(contains('Chan Vibol')));

    expect(MentionDirectory.query('eve').first.isEveryone, isTrue);
    expect(MentionDirectory.query('zzz'), isEmpty);
  });

  test('formatted span highlights everyone and known employee names', () {
    final span = communityFormattedSpan(
        'Hi @everyone and @Sokha Dara with **bold**', const TextStyle());
    expect(span.toPlainText(), 'Hi @everyone and @Sokha Dara with bold');

    final children = span.children!.whereType<TextSpan>().toList();
    expect(children.map((child) => child.text), contains('@everyone'));
    expect(children.map((child) => child.text), contains('@Sokha Dara'));

    final mention = children.firstWhere((child) => child.text == '@Sokha Dara');
    expect(mention.style?.fontWeight, FontWeight.w700);
    expect(mention.style?.color, const Color(0xff2563eb));

    final bold = children.firstWhere((child) => child.text == 'bold');
    expect(bold.style?.fontWeight, FontWeight.w800);
  });

  test('formatted span keeps emails plain and falls back before loading', () {
    final loaded = communityFormattedSpan(
        'mail foo@bar.com to @Sokha Dara', const TextStyle());
    final loadedChildren = loaded.children!.whereType<TextSpan>().toList();
    expect(loadedChildren.map((child) => child.text), isNot(contains('@bar')));
    expect(loadedChildren.map((child) => child.text), contains('@Sokha Dara'));

    MentionDirectory.resetForTest();
    final fallback = communityFormattedSpan('ping @dave', const TextStyle());
    final fallbackChildren = fallback.children!.whereType<TextSpan>().toList();
    expect(fallbackChildren.map((child) => child.text), contains('@dave'));
  });

  test('findByName resolves known people but not everyone or strangers', () {
    expect(MentionDirectory.findByName('Chan Vibol')?.id, '9');
    expect(MentionDirectory.findByName('chan vibol')?.name, 'Chan Vibol');
    expect(MentionDirectory.findByName('everyone')?.isEveryone, isTrue);
    expect(MentionDirectory.findByName('nobody here'), isNull);
    expect(MentionDirectory.findByName('  '), isNull);
  });

  test('mention spans are tappable only for known people', () {
    final taps = <String>[];
    final recognizers = <TapGestureRecognizer>[];
    final span = communityFormattedSpan(
        'Hi @Sokha Dara and @everyone, mail foo@bar.com',
        const TextStyle(),
        onMentionTap: taps.add,
        recognizers: recognizers);

    // Known employee gets a recognizer; @everyone and emails do not.
    expect(recognizers, hasLength(1));
    final mention = span.children!.whereType<TextSpan>().firstWhere(
        (child) => child.text == '@Sokha Dara',
        orElse: () => const TextSpan());
    expect(mention.recognizer, same(recognizers.first));

    recognizers.first.onTap!();
    expect(taps, ['Sokha Dara']);

    // Without a tap handler nothing is wired up.
    final plain = communityFormattedSpan(
        'Hi @Sokha Dara', const TextStyle());
    final plainMention = plain.children!.whereType<TextSpan>().firstWhere(
        (child) => child.text == '@Sokha Dara',
        orElse: () => const TextSpan());
    expect(plainMention.recognizer, isNull);
    for (final recognizer in recognizers) {
      recognizer.dispose();
    }
  });

  testWidgets('composer suggests people and inserts the picked mention',
      (tester) async {
    await tester.pumpWidget(app(SocialPostComposer(api: FakeCommunityApi())));
    await tester.pumpAndSettle();
    expect(find.byType(MentionField), findsOneWidget);

    final body = find.byType(TextField).first;
    await tester.enterText(body, '@');
    await tester.pump();
    expect(find.text('Everyone'), findsOneWidget);
    expect(find.text('Sokha Dara'), findsOneWidget);
    expect(find.text('No matching people'), findsNothing);

    await tester.enterText(body, '@zzz');
    await tester.pump();
    expect(find.text('No matching people'), findsOneWidget);

    await tester.enterText(body, '@dara');
    await tester.pump();
    final sokha = find.text('Sokha Dara');
    expect(sokha, findsOneWidget);
    await tester.ensureVisible(sokha);
    await tester.pump();
    await tester.tap(sokha);
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.controller?.text, '@Sokha Dara ');
    expect(find.text('No matching people'), findsNothing);
    expect(find.text('Sokha Dara'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('comment box shows the panel above the input and inserts',
      (tester) async {
    final api = FakeCommunityApi();
    await tester.pumpWidget(app(SocialCommentsScreen(postId: 1, api: api)));
    await tester.pumpAndSettle();

    final input = find.byType(TextField);
    expect(find.byType(MentionField), findsOneWidget);
    expect(tester.widget<MentionField>(find.byType(MentionField)).panelAbove,
        isTrue);

    await tester.enterText(input, '@');
    await tester.pump();
    final everyone = find.text('Everyone');
    expect(everyone, findsOneWidget);
    expect(
        tester.getTopLeft(everyone).dy, lessThan(tester.getTopLeft(input).dy));

    await tester.enterText(input, '@chan');
    await tester.pump();
    final vibol = find.text('Chan Vibol');
    expect(vibol, findsOneWidget);
    await tester.ensureVisible(vibol);
    await tester.pump();
    await tester.tap(vibol);
    await tester.pump();

    final field = tester.widget<TextField>(input);
    expect(field.controller?.text, '@Chan Vibol ');
    expect(tester.takeException(), isNull);
  });

  testWidgets('send key picks the active mention instead of commenting',
      (tester) async {
    final api = FakeCommunityApi();
    await tester.pumpWidget(app(SocialCommentsScreen(postId: 1, api: api)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '@eve');
    await tester.pump();
    expect(find.text('Everyone'), findsOneWidget);
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, '@everyone ');
    expect(
        api.calls.any(
            (call) => call.startsWith('POST') && call.contains('/comments')),
        isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('comment bodies render mentions highlighted', (tester) async {
    final api = FakeCommunityApi();
    api.responses['GET social-feed/1/comments?page=1'] = {
      'data': [
        {
          'id': 1,
          'body': 'Thanks @Chan Vibol',
          'parent_id': null,
          'author': {'name': 'Dara'},
          'created_at': '2026-11-11T02:00:00Z',
          'replies_count': 0,
          'reactions': <String, dynamic>{},
          'reactions_count': 0,
          'my_reaction': null,
          'can_edit': false,
          'can_delete': false,
        }
      ],
      'next_page_url': null,
    };
    await tester.pumpWidget(app(SocialCommentsScreen(postId: 1, api: api)));
    await tester.pumpAndSettle();

    expect(
        find.byWidgetPredicate((widget) =>
            widget is Text &&
            widget.textSpan != null &&
            _spanHas(widget.textSpan!, '@Chan Vibol')),
        findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a mention in a post opens that person\'s profile',
      (tester) async {
    final api = FakeCommunityApi()
      ..responses['GET social-feed?page=1'] = {
        'data': [
          {...postFixture(), 'body': 'Thanks @Chan Vibol'}
        ],
        'next_page_url': null,
      };
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) =>
          DashboardProvider()..features = {'social_feed.view': '1'},
      child: MaterialApp(home: SocialFeedScreen(api: api)),
    ));
    await tester.pumpAndSettle();

    final body = find.byWidgetPredicate((widget) =>
        widget is SelectableText &&
        (widget.textSpan?.toPlainText().contains('@Chan Vibol') ?? false));
    expect(body, findsOneWidget);

    // Measure where the mention sits so the tap lands on its glyphs.
    final selectable = tester.widget<SelectableText>(body);
    final painter = TextPainter(
        text: selectable.textSpan!,
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling)
      ..layout(maxWidth: tester.getSize(body).width);
    final plain = selectable.textSpan!.toPlainText();
    final mentionOffset = painter.getOffsetForCaret(
        TextPosition(offset: plain.indexOf('@Chan Vibol') + 4), Rect.zero);
    painter.dispose();

    await tester.tapAt(
        tester.getTopLeft(body) + mentionOffset + const Offset(2, 8));
    await tester.pumpAndSettle();

    // The Facebook-style profile of the mentioned person is pushed on top.
    expect(find.byType(SocialFeedScreen, skipOffstage: false),
        findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
