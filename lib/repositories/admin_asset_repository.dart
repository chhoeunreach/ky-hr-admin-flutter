import 'dart:convert';
import 'package:cnattendance/core/ky_security/ky_http.dart';
import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/data/source/network/connect.dart';
import 'package:cnattendance/model/admin_asset.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AdminAssetRepository {
  Future<Map<String, String>> _getHeaders() async {
    final Preferences preferences = Preferences();
    final String token = await preferences.getToken();
    return {
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token',
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

      if (response.statusCode == 200 && responseData['status'] == true) {
        final list = (responseData['data'] as List)
            .map((e) => AdminAsset.fromJson(e as Map<String, dynamic>))
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

      if (response.statusCode == 200 && responseData['status'] == true) {
        return AdminAsset.fromJson(responseData['data'] as Map<String, dynamic>);
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

      if (response.statusCode == 200 && responseData['status'] == true) {
        return AdminAssetFormData.fromJson(
            responseData['data'] as Map<String, dynamic>);
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
  }) async {
    final preferences = Preferences();
    final appUrl = await preferences.getAppUrl();
    final uri = Uri.parse(appUrl + Constant.ADMIN_ASSETS_URL);
    final headers = await _getHeaders();

    try {
      if (imageFile != null) {
        final request = http.MultipartRequest('POST', uri);
        request.headers.addAll(headers);

        for (final entry in fields.entries) {
          if (entry.value != null) {
            request.fields[entry.key] = '${entry.value}';
          }
        }

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

        final streamed = await KyHttp.sendMultipart(request);
        final response = await http.Response.fromStream(streamed);
        final responseData = json.decode(response.body);

        if (response.statusCode == 200 && responseData['status'] == true) {
          return (true, responseData['message']?.toString() ?? 'Asset added successfully');
        } else {
          return (false, responseData['message']?.toString() ?? 'Failed to add asset');
        }
      } else {
        final response = await Connect().postResponse(Constant.ADMIN_ASSETS_URL, headers, fields);
        final responseData = json.decode(response.body);

        if (response.statusCode == 200 && responseData['status'] == true) {
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
  }) async {
    final preferences = Preferences();
    final appUrl = await preferences.getAppUrl();
    final uri = Uri.parse("$appUrl${Constant.ADMIN_ASSETS_URL}$id");
    final headers = await _getHeaders();

    try {
      if (imageFile != null) {
        final request = http.MultipartRequest('POST', uri);
        request.headers.addAll(headers);

        for (final entry in fields.entries) {
          if (entry.value != null) {
            request.fields[entry.key] = '${entry.value}';
          }
        }

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

        final streamed = await KyHttp.sendMultipart(request);
        final response = await http.Response.fromStream(streamed);
        final responseData = json.decode(response.body);

        if (response.statusCode == 200 && responseData['status'] == true) {
          return (true, responseData['message']?.toString() ?? 'Asset updated successfully');
        } else {
          return (false, responseData['message']?.toString() ?? 'Failed to update asset');
        }
      } else {
        final response = await Connect().postResponse("${Constant.ADMIN_ASSETS_URL}$id", headers, fields);
        final responseData = json.decode(response.body);

        if (response.statusCode == 200 && responseData['status'] == true) {
          return (true, responseData['message']?.toString() ?? 'Asset updated successfully');
        } else {
          return (false, responseData['message']?.toString() ?? 'Failed to update asset');
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint(e.toString());
      return (false, e.toString());
    }
  }

  Future<(bool, String)> deleteAsset(int id) async {
    final headers = await _getHeaders();
    final url = "${Constant.ADMIN_ASSETS_URL}$id";

    try {
      final response = await Connect().deleteResponse(url, headers);
      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['status'] == true) {
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
