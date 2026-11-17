import 'dart:async';

import 'package:cnattendance/data/source/network/model/leavetype/Leavetyperesponse.dart';
import 'package:cnattendance/data/source/network/model/leavetypedetail/Leavetypedetailreponse.dart';
import 'package:cnattendance/provider/leaveprovider.dart';
import 'package:cnattendance/screen/dashboard/leavescreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _LeaveProvider extends LeaveProvider {
  final List<Completer<Leavetyperesponse>> requests = [];
  int detailCalls = 0;

  @override
  Future<Leavetyperesponse> getLeaveType() {
    final request = Completer<Leavetyperesponse>();
    requests.add(request);
    return request.future;
  }

  @override
  Future<Leavetypedetailreponse> getLeaveTypeDetail() async {
    detailCalls++;
    return Leavetypedetailreponse(
        status: true, message: '', statusCode: 200, data: []);
  }
}

// Exercise the screen's loading lifecycle independently of profile plugins.
class _LeaveScreen extends LeaveScreen {
  @override
  LeaveScreenState createState() => _LeaveState();
}

class _LeaveState extends LeaveScreenState {
  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox());
}

Leavetyperesponse _response() =>
    Leavetyperesponse(status: true, message: '', statusCode: 200, data: []);

void main() {
  testWidgets(
      'initialization and visibility refresh share the pending leave request',
      (tester) async {
    final provider = _LeaveProvider();
    await tester.pumpWidget(ChangeNotifierProvider<LeaveProvider>.value(
      value: provider,
      child: MaterialApp(home: _LeaveScreen()),
    ));
    final state = tester.state<LeaveScreenState>(find.byType(_LeaveScreen));
    final refresh = state.initialState();
    expect(provider.requests, hasLength(1));
    provider.requests.first.complete(_response());
    await refresh;
    await tester.pump();
    expect(provider.detailCalls, 1);
    final next = state.initialState();
    expect(provider.requests, hasLength(2));
    provider.requests.last.complete(_response());
    await next;
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
  });

  testWidgets('a failed leave refresh shows an error and can be retried',
      (tester) async {
    final provider = _LeaveProvider();
    await tester.pumpWidget(ChangeNotifierProvider<LeaveProvider>.value(
      value: provider,
      child: MaterialApp(home: _LeaveScreen()),
    ));
    final state = tester.state<LeaveScreenState>(find.byType(_LeaveScreen));
    final pending = state.initialState();
    provider.requests.first.completeError(StateError('Offline'));
    await pending;
    await tester.pump();
    expect(find.textContaining('Offline'), findsOneWidget);
    final retry = state.initialState();
    provider.requests.last.complete(_response());
    await retry;
    expect(provider.detailCalls, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
  });
}
