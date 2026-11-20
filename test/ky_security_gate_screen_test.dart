import 'package:cnattendance/core/ky_security/security_gate_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('registration-required screen explains secure key recovery',
      (tester) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: SecurityGateScreen(
          initialState: {'state': 'registrationRequired'},
        ),
      ),
    );

    expect(find.textContaining('reinstalled the app'), findsOneWidget);
    expect(find.textContaining('lost or reset its secure key'), findsOneWidget);
    expect(find.textContaining('retire the old device registration'),
        findsOneWidget);
    expect(find.text('Check again'), findsOneWidget);
  });
}
