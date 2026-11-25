import 'dart:convert';
import 'dart:io';

import 'package:cnattendance/model/auth.dart';
import 'package:cnattendance/screen/auth/login_screen.dart';
import 'package:cnattendance/screen/profile/changepasswordscreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:provider/provider.dart';

// Keep the actual State.dispose methods while avoiding unrelated native UI.
class _Login extends LoginScreen {
  @override
  loginScreenState createState() => _LoginState();
}

class _LoginState extends loginScreenState {
  @override
  Widget build(BuildContext context) => const SizedBox();
}

class _Auth extends Auth {
  @override
  Future<void> getAppUrl() async {}
}

class _Password extends ChangePassword {
  @override
  ChangePasswordState createState() => _PasswordState();
}

class _PasswordState extends ChangePasswordState {
  @override
  Widget build(BuildContext context) => const SizedBox();
}

void main() {
  testWidgets('Login can close before its form has mounted', (tester) async {
    await tester.pumpWidget(ChangeNotifierProvider<Auth>(
        create: (_) => _Auth(), child: MaterialApp(home: _Login())));
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
  testWidgets('Change Password can close before its form has mounted',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: _Password()));
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Change Password clears Android navigation and scrolls with the keyboard',
      (tester) async {
    Localization.load(jsonDecode(File('assets/i18n/en.json').readAsStringSync())
        as Map<String, dynamic>);
    tester.view.physicalSize = const Size(320, 540);
    tester.view.devicePixelRatio = 1;
    tester.view.viewPadding = const FakeViewPadding(bottom: 48);
    tester.view.padding = const FakeViewPadding(bottom: 48);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: ChangePassword()));
    final submit = find.byType(ElevatedButton);
    expect(tester.getBottomLeft(submit).dy, 472);

    await tester.enterText(find.byType(TextFormField).first, 'old password');
    tester.view.padding = const FakeViewPadding();
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pumpAndSettle();
    final confirmation = find.byType(TextFormField).last;
    await tester.ensureVisible(confirmation);
    expect(confirmation.hitTestable(), findsOneWidget);
    expect(tester.getBottomLeft(confirmation).dy, lessThanOrEqualTo(260));
    expect(tester.takeException(), isNull);
  });
}
