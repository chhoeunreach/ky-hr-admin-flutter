import 'dart:convert';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:get_storage/get_storage.dart';
import 'package:cnattendance/core/ky_security/ky_http.dart';
import 'package:http/http.dart' as http;

class Connect {
  /// One client for the whole app so Dart's HTTP layer can keep TCP/TLS
  /// connections alive between requests instead of reconnecting per call.
  static final http.Client _client = http.Client();

  Future<http.Response> getResponse(
      String url, Map<String, String> headers) async {
    final preferences = Preferences();
    final storage = GetStorage();
    final String language = storage.read("language") ?? "en";

    headers.addEntries({
      "language": language,
    }.entries);

    final uri = Uri.parse(await preferences.getAppUrl() + url);
    return KyHttp.getWithClient(_client, uri, headers: headers);
  }

  Future<http.Response> postResponse(String url, Map<String, String> headers,
      Map<String, dynamic> body) async {
    final preferences = Preferences();
    final storage = GetStorage();
    final String language = storage.read("language") ?? "en";

    headers.addEntries({
      "language": language,
    }.entries);

    final uri = Uri.parse(await preferences.getAppUrl() + url);
    return KyHttp.postWithClient(_client, uri, headers: headers, body: body);
  }

  Future<http.Response> postResponseRaw(String url, Map<String, String> headers,
      Map<String, dynamic> body) async {
    final preferences = Preferences();
    final storage = GetStorage();
    final String language = storage.read("language") ?? "en";

    headers.addEntries({
      "language": language,
    }.entries);

    final uri = Uri.parse(await preferences.getAppUrl() + url);
    final encodedBody = jsonEncode(body);
    return KyHttp.postWithClient(_client, uri,
        headers: headers, body: encodedBody);
  }

  Future<http.Response> deleteResponse(
      String url, Map<String, String> headers) async {
    final preferences = Preferences();
    final storage = GetStorage();
    final String language = storage.read("language") ?? "en";

    headers.addEntries({
      "language": language,
    }.entries);

    final uri = Uri.parse(await preferences.getAppUrl() + url);
    return KyHttp.deleteWithClient(_client, uri, headers: headers);
  }
}
