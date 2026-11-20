import 'package:cnattendance/repositories/payroll_queue_repository.dart';
import 'package:cnattendance/widget/homescreen/payroll_queue_ticket_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('updates the queue position and stops polling once paid',
      (tester) async {
    var requests = 0;
    await tester.pumpWidget(MaterialApp(
      home: PayrollQueueTicketDialog(
        message: 'Joined.',
        initialTicket: const PayrollQueueTicket(
          id: 1,
          number: 'A-001',
          status: 'waiting',
          peopleAhead: 2,
        ),
        loadTicket: () async {
          requests++;
          if (requests == 1) throw StateError('temporary outage');

          return PayrollQueueTicket(
            id: 1,
            number: 'A-001',
            status: requests == 2 ? 'calling' : 'paid',
            peopleAhead: 0,
            counter: 3,
          );
        },
      ),
    ));

    expect(find.text('2 ahead'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(find.text('Could not refresh. Retrying…'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(find.text('Go to counter 3'), findsOneWidget);
    expect(find.text('Could not refresh. Retrying…'), findsNothing);

    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(find.text('Paid'), findsOneWidget);

    await tester.pump(const Duration(seconds: 10));
    expect(requests, 3);
  });
}
