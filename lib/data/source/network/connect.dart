import 'dart:convert';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http_interceptor_plus/http_interceptor_plus.dart';

class Connect {
  /// One client for the whole app so Dart's HTTP layer can keep TCP/TLS
  /// connections alive between requests instead of reconnecting per call.
  static final http.Client _client = LoggingMiddleware(http.Client());

  Future<http.Response> getResponse(
      String url, Map<String, String> headers) async {
    Preferences preferences = Preferences();
    final storage = GetStorage();
    String language = storage.read("language") ?? "en";

    headers.addEntries({
      "language": language,
    }.entries);

    var uri = Uri.parse(await preferences.getAppUrl() + url);
    return _client.get(uri, headers: headers);
  }

  Future<http.Response> postResponse(String url, Map<String, String> headers,
      Map<String, dynamic> body) async {
    Preferences preferences = Preferences();
    final storage = GetStorage();
    String language = storage.read("language") ?? "en";

    headers.addEntries({
      "language": language,
    }.entries);

    var uri = Uri.parse(await preferences.getAppUrl() + url);
    return _client.post(uri, headers: headers, body: body);
  }

  Future<http.Response> postResponseRaw(String url, Map<String, String> headers,
      Map<String, dynamic> body) async {
    Preferences preferences = Preferences();
    final storage = GetStorage();
    String language = storage.read("language") ?? "en";

    headers.addEntries({
      "language": language,
    }.entries);

    var uri = Uri.parse(await preferences.getAppUrl() + url);
    return _client.post(uri, headers: headers, body: jsonEncode(body));
  }
}
