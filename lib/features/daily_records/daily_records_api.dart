import 'dart:convert';
import 'dart:typed_data';

import 'package:cnattendance/core/ky_security/ky_http.dart';
import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

typedef RecordData = Map<String, dynamic>;

class DailyRecordsApi {
  DailyRecordsApi({Preferences? preferences, http.Client? client})
      : _preferences = preferences ?? Preferences(),
        _transport = client ?? _client;

  static final http.Client _client = http.Client();
  final Preferences _preferences;
  final http.Client _transport;

  Future<bool> canAssign() async =>
      (await get('capabilities'))['assign_tasks'] == true;

  Future<RecordData> postWork(
    String path,
    RecordData fields, {
    List<PlatformFile> files = const [],
  }) =>
      post(path, files.isEmpty ? fields : {'payload': jsonEncode(fields)},
          files: files);

  Future<RecordData> get(String path, [Map<String, String>? query]) async =>
      _decode(await _request(path, query: query));

  Future<RecordData> post(
    String path,
    RecordData fields, {
    List<PlatformFile> files = const [],
  }) async {
    if (files.isEmpty) return _decode(await _request(path, body: fields));
    final request = http.MultipartRequest('POST', await _uri(path, null))
      ..headers.addAll(await _headers());
    for (final entry in fields.entries) {
      final value = entry.value;
      if (value is List) {
        for (var i = 0; i < value.length; i++) {
          request.fields['${entry.key}[$i]'] = '${value[i]}';
        }
      } else {
        request.fields[entry.key] =
            value is bool ? (value ? '1' : '0') : '$value';
      }
    }
    for (final file in files) {
      final path = file.path;
      if (file.bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes('files[]', file.bytes!,
              filename: file.name),
        );
      } else if (path != null) {
        request.files.add(
          await http.MultipartFile.fromPath('files[]', path,
              filename: file.name),
        );
      } else {
        throw const DailyRecordsError(
            'One of the selected files is unavailable.');
      }
    }
    final result = await KyHttp.sendMultipart(request, client: _transport)
        .then(http.Response.fromStream)
        .timeout(const Duration(seconds: 90));
    return _decode(result);
  }

  Future<Uint8List> attachment(String path) async {
    final response = await _request(path);
    if (response.statusCode != 200) _decode(response);
    return response.bodyBytes;
  }

  Future<http.Response> _request(
    String path, {
    Map<String, String>? query,
    RecordData? body,
  }) async {
    final headers = await _headers();
    final uri = await _uri(path, query);
    return (body == null
            ? KyHttp.getWithClient(_transport, uri, headers: headers)
            : KyHttp.postWithClient(
                _transport,
                uri,
                headers: headers..['Content-Type'] = 'application/json',
                body: jsonEncode(body),
              ))
        .timeout(const Duration(seconds: 30));
  }

  Future<Uri> _uri(String path, Map<String, String>? query) async {
    final base = Uri.parse(await _preferences.getAppUrl());
    final directory = base.path.endsWith('/') ? base.path : '${base.path}/';
    return base.replace(
        path: '$directory${Constant.API_URL}/v1/daily-records/$path',
        queryParameters: query);
  }

  Future<Map<String, String>> _headers() async => {
        'Accept': 'application/json',
        'Authorization': 'Bearer ${await _preferences.getToken()}',
      };

  RecordData _decode(http.Response response) {
    Object? parsed;
    try {
      parsed = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      parsed = null;
    }
    final body = parsed is RecordData ? parsed : const <String, dynamic>{};
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final validation = body['errors'];
      final first = validation is Map && validation.isNotEmpty
          ? validation.values.first
          : null;
      throw DailyRecordsError(
        first is List && first.isNotEmpty
            ? first.first.toString()
            : body['message']?.toString() ??
                (response.statusCode == 404
                    ? 'Daily Records is unavailable on this server.'
                    : 'Daily Records request failed. Try again.'),
      );
    }
    final data = body['data'];
    if (data is RecordData) return data;
    throw const DailyRecordsError('The server returned an invalid response.');
  }
}

class DailyRecordsError implements Exception {
  const DailyRecordsError(this.message);
  final String message;

  @override
  String toString() => message;
}

List<RecordData> recordRows(Object? rows) =>
    rows is List ? rows.whereType<RecordData>().toList() : [];

RecordData recordMap(Object? data) =>
    data is RecordData ? data : const <String, dynamic>{};

int recordNumber(Object? value) => int.tryParse('$value') ?? 0;

bool recordFlag(Object? value) => value == true || value == 1 || value == '1';

String recordLabel(Object? value) {
  if (value == 'returned') return 'Returned for correction';
  final text = (value ?? 'Recorded').toString().replaceAll('_', ' ');
  return text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';
}

DateTime? recordBusinessTime(Object? value) {
  if (value == null) return null;
  final stamp = value.toString().replaceFirst(' ', 'T');
  return DateTime.tryParse('${stamp}Z')?.add(const Duration(hours: 7));
}

String recordDate(Object? value) {
  final local = recordBusinessTime(value);
  return local == null
      ? '—'
      : '${DateFormat('dd MMM yyyy, HH:mm').format(local)} ICT';
}
