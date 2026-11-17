import 'package:cnattendance/model/auth.dart';
import 'package:cnattendance/screen/auth/login_screen.dart';
import 'package:cnattendance/screen/profile/changepasswordscreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
