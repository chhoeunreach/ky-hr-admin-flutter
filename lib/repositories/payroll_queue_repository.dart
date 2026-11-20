import 'dart:convert';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/data/source/network/connect.dart';
import 'package:cnattendance/utils/constant.dart';

class PayrollQueueJoinResult {
  const PayrollQueueJoinResult({
    required this.status,
    required this.message,
    this.ticket,
  });

  final String status;
  final String message;
  final PayrollQueueTicket? ticket;
}

class PayrollQueueTicket {
  const PayrollQueueTicket({
    required this.id,
    required this.number,
    required this.status,
    required this.peopleAhead,
    this.counter,
  });

  final int id;
  final String number;
  final String status;
  final int peopleAhead;
  final int? counter;

  bool get isActive =>
      status == 'waiting' || status == 'calling' || status == 'serving';

  static PayrollQueueTicket? fromResponse(Map<String, dynamic> response) {
    final ticket = response['ticket'];
    if (ticket is! Map || ticket['id'] is! int) return null;

    return PayrollQueueTicket(
      id: ticket['id'] as int,
      number: ticket['ticket_number']?.toString() ?? '',
      status: ticket['status']?.toString() ?? '',
      peopleAhead: (response['people_ahead'] as num?)?.toInt() ?? 0,
      counter: (ticket['counter_number'] as num?)?.toInt(),
    );
  }
}

class PayrollQueueRepository {
  /// Joins the payroll session encoded in the admin-created QR, as the
  /// signed-in employee.
  Future<PayrollQueueJoinResult> join(String qrToken) async {
    final response = await Connect().postResponse(
      '${Constant.PAYROLL_QUEUE_URL}/join',
      await _authorizedHeaders(),
      {'qr_token': qrToken},
    );
    final data = _decodeResponseBody(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return PayrollQueueJoinResult(
        status: data['status']?.toString() ?? 'success',
        message: data['message']?.toString() ??
            'Joined the payroll queue successfully.',
        ticket: PayrollQueueTicket.fromResponse(data),
      );
    }

    throw _errorMessage(data, 'Unable to join the payroll queue');
  }

  Future<PayrollQueueTicket> getTicket(int id) async {
    final response = await Connect().getResponse(
      '${Constant.PAYROLL_QUEUE_URL}/ticket/$id',
      await _authorizedHeaders(),
    );
    final data = _decodeResponseBody(response.body);
    final ticket = PayrollQueueTicket.fromResponse(data);
    if (response.statusCode == 200 && ticket != null) return ticket;

    throw _errorMessage(data, 'Unable to refresh the payroll ticket.');
  }

  String _errorMessage(Map<String, dynamic> data, String fallback) {
    final errors = data['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) return first.first.toString();
    }
    return data['message']?.toString() ?? fallback;
  }

  Future<Map<String, String>> _authorizedHeaders() async {
    final preferences = Preferences();
    final token = await preferences.getToken();

    return {
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _decodeResponseBody(String body) {
    try {
      final decoded = json.decode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return {'message': decoded?.toString() ?? 'Invalid server response'};
    } on FormatException {
      return {
        'message': body.trim().isEmpty
            ? 'Empty server response'
            : 'Invalid server response. Please check the API endpoint.',
      };
    }
  }
}
