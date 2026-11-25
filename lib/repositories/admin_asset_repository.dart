import 'dart:convert';
import 'dart:io';
import 'package:cnattendance/core/ky_security/ky_http.dart';
import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/data/source/network/connect.dart';
import 'package:cnattendance/model/admin_asset.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

class AdminAssetRepository {
  Future<Map<String, String>> _getHeaders() async {
    final Preferences preferences = Preferences();
    final String token = await preferences.getToken();
    return {
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token',
      'language': GetStorage().read("language") ?? "en",
    };
  }

  Future<({List<AdminAsset> assets, int total, int lastPage})> getAssets({
    String? search,
    int? typeId,
    int? branchId,
    int? isAvailable,
    String? isWorking,
    int page = 1,
  }) async {
    final headers = await _getHeaders();
    final query = <String>[
      'page=$page',
      if (search != null && search.trim().isNotEmpty)
        'search=${Uri.encodeComponent(search.trim())}',
      if (typeId != null) 'type_id=$typeId',
      if (branchId != null) 'branch_id=$branchId',
      if (isAvailable != null) 'is_available=$isAvailable',
      if (isWorking != null && isWorking.isNotEmpty) 'is_working=$isWorking',
    ].join('&');

    final url = "${Constant.ADMIN_ASSETS_URL}?$query";

    try {
      final response = await Connect().getResponse(url, headers);
      final responseData = json.decode(response.body);

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          responseData['status'] == true) {
        final rawList = responseData['data'];
        if (rawList is! List) {
          throw 'Unexpected assets payload';
        }
        final list = rawList
            .whereType<Map>()
            .map((e) => AdminAsset.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        final pagination = responseData['pagination'] as Map<String, dynamic>?;
        final total = (pagination?['total'] as num?)?.toInt() ?? list.length;
        final lastPage = (pagination?['last_page'] as num?)?.toInt() ?? 1;

        return (assets: list, total: total, lastPage: lastPage);
      } else {
        throw responseData['message'] ?? 'Failed to load assets';
      }
    } catch (e) {
      if (kDebugMode) debugPrint(e.toString());
      rethrow;
    }
  }

  Future<AdminAsset> getAssetDetail(int id) async {
    final headers = await _getHeaders();
    final url = "${Constant.ADMIN_ASSETS_URL}$id";

    try {
      final response = await Connect().getResponse(url, headers);
      final responseData = json.decode(response.body);

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          responseData['status'] == true) {
        final raw = responseData['data'];
        if (raw is! Map) throw 'Unexpected asset detail payload';
        return AdminAsset.fromJson(Map<String, dynamic>.from(raw));
      } else {
        throw responseData['message'] ?? 'Failed to load asset details';
      }
    } catch (e) {
      if (kDebugMode) debugPrint(e.toString());
      rethrow;
    }
  }

  Future<AdminAssetFormData> getFormData({int? branchId}) async {
    final headers = await _getHeaders();
    final query = branchId != null ? '?branch_id=$branchId' : '';
    final url = "${Constant.ADMIN_ASSET_FORM_DATA_URL}$query";

    try {
      final response = await Connect().getResponse(url, headers);
      final responseData = json.decode(response.body);

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          responseData['status'] == true) {
        final raw = responseData['data'];
        if (raw is! Map) throw 'Unexpected form-data payload';
        return AdminAssetFormData.fromJson(Map<String, dynamic>.from(raw));
      } else {
        throw responseData['message'] ?? 'Failed to load form options';
      }
    } catch (e) {
      if (kDebugMode) debugPrint(e.toString());
      rethrow;
    }
  }

  Future<(bool, String)> createAsset(
    Map<String, dynamic> fields, {
    PlatformFile? imageFile,
    List<File>? imageFiles,
  }) async {
    final preferences = Preferences();
    final appUrl = await preferences.getAppUrl();
    final uri = Uri.parse(appUrl + Constant.ADMIN_ASSETS_URL);
    final headers = await _getHeaders();

    try {
      final hasFiles = (imageFiles != null && imageFiles.isNotEmpty) || imageFile != null;
      if (hasFiles) {
        final request = http.MultipartRequest('POST', uri);
        request.headers.addAll(headers);

        for (final entry in fields.entries) {
          if (entry.value != null) {
            request.fields[entry.key] = '${entry.value}';
          }
        }

        if (imageFiles != null && imageFiles.isNotEmpty) {
          // Primary image only once.
          final first = imageFiles.first;
          request.files.add(await http.MultipartFile.fromPath(
            'image',
            first.path,
            filename: p.basename(first.path),
          ));

          // Remaining images as array for multi-upload endpoints.
          for (final f in imageFiles.skip(1)) {
            request.files.add(await http.MultipartFile.fromPath(
              'images[]',
              f.path,
              filename: p.basename(f.path),
            ));
          }
        } else if (imageFile != null) {
          if (imageFile.bytes != null) {
            request.files.add(http.MultipartFile.fromBytes(
              'image',
              imageFile.bytes!,
              filename: imageFile.name,
            ));
          } else if (imageFile.path != null) {
            request.files.add(await http.MultipartFile.fromPath(
              'image',
              imageFile.path!,
              filename: imageFile.name,
            ));
          }
        }

        final streamed = await KyHttp.sendMultipart(request);
        final response = await http.Response.fromStream(streamed);
        final responseData = json.decode(response.body);

        if (response.statusCode >= 200 &&
            response.statusCode < 300 &&
            responseData['status'] == true) {
          return (true, responseData['message']?.toString() ?? 'Asset added successfully');
        } else {
          return (false, responseData['message']?.toString() ?? 'Failed to add asset');
        }
      } else {
        final response = await Connect().postResponse(Constant.ADMIN_ASSETS_URL, headers, fields);
        final responseData = json.decode(response.body);

        if (response.statusCode >= 200 &&
            response.statusCode < 300 &&
            responseData['status'] == true) {
          return (true, responseData['message']?.toString() ?? 'Asset added successfully');
        } else {
          return (false, responseData['message']?.toString() ?? 'Failed to add asset');
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint(e.toString());
      return (false, e.toString());
    }
  }

  Future<(bool, String)> updateAsset(
    int id,
    Map<String, dynamic> fields, {
    PlatformFile? imageFile,
    List<File>? imageFiles,
  }) async {
    final preferences = Preferences();
    final appUrl = await preferences.getAppUrl();
    final path = "${Constant.ADMIN_ASSETS_URL}$id";
    final uri = Uri.parse("$appUrl$path");
    final headers = await _getHeaders();

    try {
      final hasFiles = (imageFiles != null && imageFiles.isNotEmpty) || imageFile != null;
      http.Response response;

      if (hasFiles) {
        Future<http.Response> send(String method) async {
          final request = http.MultipartRequest(method, uri);
          request.headers.addAll(headers);

          for (final entry in fields.entries) {
            if (entry.value != null) {
              request.fields[entry.key] = '${entry.value}';
            }
          }

          if (imageFiles != null && imageFiles.isNotEmpty) {
            // Primary image only once.
            final first = imageFiles.first;
            request.files.add(await http.MultipartFile.fromPath(
              'image',
              first.path,
              filename: p.basename(first.path),
            ));

            // Remaining images as array for multi-upload endpoints.
            for (final f in imageFiles.skip(1)) {
              request.files.add(await http.MultipartFile.fromPath(
                'images[]',
                f.path,
                filename: p.basename(f.path),
              ));
            }
          } else if (imageFile != null) {
            if (imageFile.bytes != null) {
              request.files.add(http.MultipartFile.fromBytes(
                'image',
                imageFile.bytes!,
                filename: imageFile.name,
              ));
            } else if (imageFile.path != null) {
              request.files.add(await http.MultipartFile.fromPath(
                'image',
                imageFile.path!,
                filename: imageFile.name,
              ));
            }
          }

          final streamed = await KyHttp.sendMultipart(request);
          return http.Response.fromStream(streamed);
        }

        response = await send('POST');
        // Some backends expose updates under PUT only; retry once on 405.
        if (_isMethodUnsupported(response)) {
          response = await send('PUT');
        }
      } else {
        response = await Connect().postResponse(path, headers, fields);
        if (_isMethodUnsupported(response)) {
          response = await Connect().putResponse(path, headers, fields);
        }
      }

      final responseData = _decodeBody(response.body);
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          responseData['status'] == true) {
        return (true, responseData['message']?.toString() ?? 'Asset updated successfully');
      }
      return (false, responseData['message']?.toString() ?? 'Failed to update asset');
    } catch (e) {
      if (kDebugMode) debugPrint(e.toString());
      return (false, e.toString());
    }
  }

  /// 405 means the HTTP verb itself was rejected, so the endpoint is
  /// served under a different method (typically PUT for updates).
  bool _isMethodUnsupported(http.Response response) {
    if (response.statusCode != 405) return false;
    try {
      final data = json.decode(response.body);
      if (data is Map && data['message'] != null) {
        final message = data['message'].toString().toLowerCase();
        // Laravel-style bodies confirm the verb issue; an absent message
        // still counts because 405 alone is unambiguous.
        return message.isEmpty ||
            message.contains('method') ||
            message.contains('not supported');
      }
    } catch (_) {
      // Non-JSON 405 body: the status code alone is enough.
    }
    return true;
  }

  Map<String, dynamic> _decodeBody(String body) {
    try {
      final data = json.decode(body);
      return data is Map<String, dynamic> ? data : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<(bool, String)> deleteAsset(int id) async {
    final headers = await _getHeaders();
    final url = "${Constant.ADMIN_ASSETS_URL}$id";

    try {
      final response = await Connect().deleteResponse(url, headers);
      final responseData = json.decode(response.body);

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          responseData['status'] == true) {
        return (true, responseData['message']?.toString() ?? 'Asset deleted successfully');
      } else {
        return (false, responseData['message']?.toString() ?? 'Failed to delete asset');
      }
    } catch (e) {
      if (kDebugMode) debugPrint(e.toString());
      return (false, e.toString());
    }
  }
}
