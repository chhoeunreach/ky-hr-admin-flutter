import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/data/source/network/model/employeedetailresponse/Data.dart';
import 'package:cnattendance/model/chat_contact.dart';
import 'package:cnattendance/provider/employeedetailcontroller.dart';
import 'package:cnattendance/repositories/teamsheetrepository.dart';
import 'package:cnattendance/screen/profile/employeedetailscreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Preferences extends Preferences {
  @override
  Future<String> getAppUrl({bool forceCheck = false}) async =>
      'https://example.test/';

  @override
  Future<String> getToken() async => 'token';

  @override
  Future<int> getUserId() async => 1;
}

class _TeamSheetRepository extends TeamSheetRepository {
  @override
  Future<ChatContactsPayload> getChatContacts() async => ChatContactsPayload(
        contacts: [
          ChatContact.fromJson({'id': 2, 'username': 'other'}),
          ChatContact.fromJson({'id': 3, 'username': 'dara', 'role': 'admin'}),
        ],
        onlineContacts: [
          ChatContact.fromJson({'employee_id': 42, 'username': 'dara'}),
        ],
      );
}

class _EmployeeDetailController extends EmployeeDetailController {
  final requests = <Completer<EmployeeDetail>>[];

  @override
  Future<EmployeeDetail> getEmployeeDetail(
    String employeeId, {
    String username = '',
  }) {
    expect(employeeId, isEmpty);
    expect(username, 'dara');
    final request = Completer<EmployeeDetail>();
    requests.add(request);
    return request.future;
  }
}

void main() {
  test('A notification chat resolves the employee ID through its username',
      () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/users/profile-detail/42');
      return http.Response(
        jsonEncode({
          'status': true,
          'status_code': 200,
          'message': 'OK',
          'data': {'name': 'Dara', 'username': 'dara'},
        }),
        200,
      );
    });
    addTearDown(client.close);
    final controller = EmployeeDetailController(
      preferences: _Preferences(),
      teamRepository: _TeamSheetRepository(),
    );
    final details = await http.runWithClient(
      () => controller.getEmployeeDetail('', username: 'dara'),
      () => client,
    );
    expect(details.employeeId, '42');
    expect(details.profile.name, 'Dara');
    expect(details.canViewPrivateDetails, isFalse);
  });

  testWidgets(
      'Chat profile keeps the contact visible and retries missing details',
      (tester) async {
    Localization.load(jsonDecode(File('assets/i18n/en.json').readAsStringSync())
        as Map<String, dynamic>);
    final controller = _EmployeeDetailController();

    await tester.pumpWidget(MaterialApp(
      home: EmployeeDetailScreen(
        chatName: 'Dara',
        chatUsername: 'dara',
        controller: controller,
      ),
    ));

    expect(find.text('Dara'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    controller.requests.single.completeError(StateError('Offline'));
    await tester.pumpAndSettle();
    expect(find.text('Dara'), findsOneWidget);
    expect(find.text('Could not load profile details.'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    controller.requests.last.complete((
      employeeId: '42',
      profile: Data.fromJson({
        'name': 'Dara',
        'username': 'dara',
        'post': null,
        'department': 'Engineering',
        'joining_date': '2024-01-02',
        'address': 'Private address',
      }),
      canViewPrivateDetails: false,
    ));
    await tester.pumpAndSettle();

    expect(controller.requests, hasLength(2));
    expect(find.text('Engineering'), findsOneWidget);
    expect(find.text('2024-01-02'), findsOneWidget);
    expect(find.text('Private address'), findsNothing);
    expect(find.byIcon(Icons.message), findsNothing);
    expect(find.text('Retry'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
