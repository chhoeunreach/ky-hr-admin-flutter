import 'dart:async';

import 'package:cnattendance/repositories/payroll_queue_repository.dart';
import 'package:flutter/material.dart';

class PayrollQueueTicketDialog extends StatefulWidget {
  const PayrollQueueTicketDialog({
    super.key,
    required this.message,
    required this.initialTicket,
    required this.loadTicket,
  });

  final String message;
  final PayrollQueueTicket initialTicket;
  final Future<PayrollQueueTicket> Function() loadTicket;

  @override
  State<PayrollQueueTicketDialog> createState() =>
      _PayrollQueueTicketDialogState();
}

class _PayrollQueueTicketDialogState extends State<PayrollQueueTicketDialog> {
  late PayrollQueueTicket _ticket = widget.initialTicket;
  Timer? _refreshTimer;
  bool _refreshFailed = false;

  @override
  void initState() {
    super.initState();
    _scheduleRefresh();
  }

  void _scheduleRefresh() {
    if (_ticket.isActive) {
      _refreshTimer = Timer(const Duration(seconds: 5), _refresh);
    }
  }

  Future<void> _refresh() async {
    try {
      final ticket = await widget.loadTicket();
      if (!mounted) return;
      setState(() {
        _ticket = ticket;
        _refreshFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _refreshFailed = true);
    }
    _scheduleRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = switch (_ticket.status) {
      'waiting' => '${_ticket.peopleAhead} ahead',
      'calling' || 'serving' => _ticket.counter == null
          ? 'You have been called'
          : 'Go to counter ${_ticket.counter}',
      'paid' => 'Paid',
      'skipped' => 'Skipped',
      'cancelled' => 'Cancelled',
      _ => _ticket.status,
    };

    return AlertDialog(
      title: Text('Ticket ${_ticket.number}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.message),
          if (status.isNotEmpty) Text(status),
          if (_refreshFailed) const Text('Could not refresh. Retrying…'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
      ],
    );
  }
}
