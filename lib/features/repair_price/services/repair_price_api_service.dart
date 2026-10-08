import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:http/http.dart' as http;

import '../config/repair_price_config.dart';
import '../models/repair_brand.dart';
import '../models/repair_category.dart';
import '../models/repair_device.dart';
import '../models/repair_service.dart';

class RepairApiException implements Exception {
  final String message;
  final int? statusCode;

  const RepairApiException(this.message, {this.statusCode});

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;

  @override
  String toString() => message;
}

class RepairPriceApiService {
  RepairPriceApiService({Preferences? preferences, http.Client? client})
      : _preferences = preferences ?? Preferences(),
        _client = client ?? http.Client();

  final Preferences _preferences;
  final http.Client _client;

  // 1. GET /api/repair-price/brands
  Future<List<RepairBrand>> getBrands() async {
    final response = await _get('/brands');
    return _list(response)
        .map((item) => RepairBrand.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  // 2. GET /api/repair-price/device-types
  Future<List<RepairDeviceType>> getDeviceTypes() async {
    final response = await _get('/device-types');
    return _list(response)
        .map((item) =>
            RepairDeviceType.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<RepairDeviceType> createDeviceType(Map<String, dynamic> data) async {
    try {
      final response = await _post('/device-types', data);
      if (response is Map && response['data'] is Map) {
        return RepairDeviceType.fromJson(
            Map<String, dynamic>.from(response['data']));
      }
      return RepairDeviceType.fromJson(
          Map<String, dynamic>.from(response is Map ? response : data));
    } catch (_) {
      return RepairDeviceType(
        id: DateTime.now().millisecondsSinceEpoch % 100000,
        name: data['name'] ?? '',
        slug: data['slug'] ?? '',
        icon: data['icon'] ?? '',
      );
    }
  }

  // 3. GET /api/repair-price/series
  Future<List<RepairDeviceSeries>> getSeries({
    int? brandId,
    int? deviceTypeId,
  }) async {
    final response = await _get('/series', {
      'brand_id': brandId,
      'device_type_id': deviceTypeId,
    });
    return _list(response)
        .map((item) =>
            RepairDeviceSeries.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  // 4. GET /api/repair-price/devices
  Future<List<RepairDevice>> getDevices({
    String? search,
    int? brandId,
    int? deviceTypeId,
    int? seriesId,
    int page = 1,
    int perPage = 20,
  }) async {
    final response = await _get('/devices', {
      'search': search,
      'brand_id': brandId,
      'device_type_id': deviceTypeId,
      'series_id': seriesId,
      'page': page,
      'per_page': perPage,
    });
    return _list(response)
        .map((item) => RepairDevice.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  // 5. GET /api/repair-price/devices/{id}
  Future<RepairDevice> getDevice(int id) async {
    final response = await _get('/devices/$id');
    if (response is Map && response['data'] is Map) {
      return RepairDevice.fromJson(Map<String, dynamic>.from(response['data']));
    }
    throw const RepairApiException('Invalid repair device response');
  }

  // 6. GET /api/repair-price/devices/{id}/services
  Future<List<RepairService>> getDeviceServices(
    int deviceId, {
    String? search,
    int? categoryId,
  }) async {
    final response = await _get('/devices/$deviceId/services', {
      'search': search,
      'category_id': categoryId,
    });
    return _list(response)
        .map((item) => RepairService.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  // 7. GET /api/repair-price/categories
  Future<List<RepairCategory>> getCategories() async {
    final response = await _get('/categories');
    return _list(response)
        .map((item) => RepairCategory.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  // 8. GET /api/repair-price/services
  Future<List<RepairService>> getAllServices({
    String? search,
    int? categoryId,
  }) async {
    final response = await _get('/services', {
      'search': search,
      'category_id': categoryId,
    });
    return _list(response)
        .map((item) => RepairService.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  // 9. GET /api/repair-price/search
  Future<List<RepairDevice>> searchDevices(String query) async {
    final response = await _get('/search', {'query': query});
    return _list(response)
        .map((item) => RepairDevice.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  // 10. GET /api/repair-price/permissions (Load user role & permissions from web)
  Future<Map<String, dynamic>?> getPermissions() async {
    final response = await _get('/permissions');
    if (response != null && response['data'] != null) {
      return Map<String, dynamic>.from(response['data']);
    }
    return null;
  }

  // --- Brand CRUD ---
  // POST /api/repair-price/brands
  Future<RepairBrand> createBrand(Map<String, dynamic> data) async {
    final response = await _post('/brands', data);
    if (response is Map && response['data'] is Map) {
      return RepairBrand.fromJson(Map<String, dynamic>.from(response['data']));
    }
    return RepairBrand(
      id: int.tryParse('${response['id'] ?? 0}') ?? 0,
      name: data['name'] ?? '',
      slug: data['slug'] ?? '',
      logo: data['logo'] ?? '',
      status: data['status'] == 1 || data['status'] == true,
    );
  }

  // PUT /api/repair-price/brands/{id}
  Future<RepairBrand> updateBrand(int id, Map<String, dynamic> data) async {
    final response = await _put('/brands/$id', data);
    if (response is Map && response['data'] is Map) {
      return RepairBrand.fromJson(Map<String, dynamic>.from(response['data']));
    }
    return RepairBrand(
      id: id,
      name: data['name'] ?? '',
      slug: data['slug'] ?? '',
      logo: data['logo'] ?? '',
      status: data['status'] == 1 || data['status'] == true,
    );
  }

  // DELETE /api/repair-price/brands/{id}
  Future<bool> deleteBrand(int id) async {
    await _delete('/brands/$id');
    return true;
  }

  // --- Device CRUD ---
  // POST /api/repair-price/admin/devices
  Future<RepairDevice> createDevice(Map<String, dynamic> data) async {
    final response = await _post('/admin/devices', data);
    if (response is Map && response['data'] is Map) {
      return RepairDevice.fromJson(Map<String, dynamic>.from(response['data']));
    }
    return RepairDevice.fromJson(
        Map<String, dynamic>.from(response is Map ? response : data));
  }

  // PUT /api/repair-price/admin/devices/{id}
  Future<RepairDevice> updateDevice(int id, Map<String, dynamic> data) async {
    final response = await _put('/admin/devices/$id', data);
    if (response is Map && response['data'] is Map) {
      return RepairDevice.fromJson(Map<String, dynamic>.from(response['data']));
    }
    return RepairDevice.fromJson(
        Map<String, dynamic>.from(response is Map ? response : data));
  }

  // DELETE /api/repair-price/admin/devices/{id}
  Future<bool> deleteDevice(int id) async {
    await _delete('/admin/devices/$id');
    return true;
  }

  // --- Category CRUD ---
  // POST /api/repair-price/categories
  Future<RepairCategory> createCategory(Map<String, dynamic> data) async {
    final response = await _post('/categories', data);
    if (response is Map && response['data'] is Map) {
      return RepairCategory.fromJson(
          Map<String, dynamic>.from(response['data']));
    }
    return RepairCategory(
      id: int.tryParse('${response['id'] ?? 0}') ?? 0,
      name: data['name'] ?? '',
      nameKh: data['name_kh'] ?? '',
      slug: data['slug'] ?? '',
      icon: data['icon'] ?? '',
      sortOrder: int.tryParse('${data['sort_order'] ?? 0}') ?? 0,
      status: data['status'] == 1 || data['status'] == true,
    );
  }

  // PUT /api/repair-price/categories/{id}
  Future<RepairCategory> updateCategory(
      int id, Map<String, dynamic> data) async {
    final response = await _put('/categories/$id', data);
    if (response is Map && response['data'] is Map) {
      return RepairCategory.fromJson(
          Map<String, dynamic>.from(response['data']));
    }
    return RepairCategory(
      id: id,
      name: data['name'] ?? '',
      nameKh: data['name_kh'] ?? '',
      slug: data['slug'] ?? '',
      icon: data['icon'] ?? '',
      sortOrder: int.tryParse('${data['sort_order'] ?? 0}') ?? 0,
      status: data['status'] == 1 || data['status'] == true,
    );
  }

  // DELETE /api/repair-price/categories/{id}
  Future<bool> deleteCategory(int id) async {
    await _delete('/categories/$id');
    return true;
  }

  // PUT /api/repair-price/admin/prices/{id}
  Future<RepairService> updatePrice({
    required int priceId,
    required int deviceId,
    required RepairService service,
  }) async {
    final response = await _put(
      '/admin/prices/$priceId',
      service.toPriceUpdateJson(deviceId: deviceId),
    );
    if (response is Map && response['data'] is Map) {
      return RepairService.fromJson(
          Map<String, dynamic>.from(response['data']));
    }
    throw const RepairApiException('Invalid repair price update response');
  }

  // --- HTTP Helpers ---
  Future<dynamic> _get(String path, [Map<String, dynamic>? queryParams]) async {
    final uri = await _buildUri(path, queryParams);
    final headers = await _headers();

    try {
      final response = await _client
          .get(uri, headers: headers)
          .timeout(RepairPriceConfig.requestTimeout);
      final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded;
      }

      throw RepairApiException(
        decoded is Map && decoded['message'] != null
            ? decoded['message'].toString()
            : 'Server returned status code: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    } on SocketException {
      throw const RepairApiException(
          'No internet connection or server unreachable');
    } on TimeoutException {
      throw const RepairApiException('Connection timed out');
    } on RepairApiException {
      rethrow;
    } catch (error) {
      throw RepairApiException(error.toString());
    }
  }

  Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    final uri = await _buildUri(path);
    final headers = await _headers();

    try {
      final response = await _client
          .post(uri, headers: headers, body: jsonEncode(body))
          .timeout(RepairPriceConfig.requestTimeout);
      final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded;
      }

      throw RepairApiException(
        decoded is Map && decoded['message'] != null
            ? decoded['message'].toString()
            : 'Server returned status code: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    } on SocketException {
      throw const RepairApiException(
          'No internet connection or server unreachable');
    } on TimeoutException {
      throw const RepairApiException('Connection timed out');
    } on RepairApiException {
      rethrow;
    } catch (error) {
      throw RepairApiException(error.toString());
    }
  }

  Future<dynamic> _put(String path, Map<String, dynamic> body) async {
    final uri = await _buildUri(path);
    final headers = await _headers();

    try {
      final response = await _client
          .put(uri, headers: headers, body: jsonEncode(body))
          .timeout(RepairPriceConfig.requestTimeout);
      final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded;
      }

      throw RepairApiException(
        decoded is Map && decoded['message'] != null
            ? decoded['message'].toString()
            : 'Server returned status code: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    } on SocketException {
      throw const RepairApiException(
          'No internet connection or server unreachable');
    } on TimeoutException {
      throw const RepairApiException('Connection timed out');
    } on RepairApiException {
      rethrow;
    } catch (error) {
      throw RepairApiException(error.toString());
    }
  }

  Future<dynamic> _delete(String path) async {
    final uri = await _buildUri(path);
    final headers = await _headers();

    try {
      final response = await _client
          .delete(uri, headers: headers)
          .timeout(RepairPriceConfig.requestTimeout);
      final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded;
      }

      throw RepairApiException(
        decoded is Map && decoded['message'] != null
            ? decoded['message'].toString()
            : 'Server returned status code: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    } on SocketException {
      throw const RepairApiException(
          'No internet connection or server unreachable');
    } on TimeoutException {
      throw const RepairApiException('Connection timed out');
    } on RepairApiException {
      rethrow;
    } catch (error) {
      throw RepairApiException(error.toString());
    }
  }

  Future<Map<String, String>> _headers() async {
    final token = await _preferences.getToken();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<Uri> _buildUri(String path,
      [Map<String, dynamic>? queryParams]) async {
    final savedBaseUrl = (await _preferences.getAppUrl()).trim();
    final parsedBaseUrl = Uri.tryParse(savedBaseUrl);
    final baseUrl = parsedBaseUrl != null &&
            parsedBaseUrl.hasScheme &&
            parsedBaseUrl.hasAuthority
        ? savedBaseUrl
        : Constant.appUrl;
    final cleanBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$cleanBase${RepairPriceConfig.apiPrefix}$cleanPath');
    final cleanParams = <String, String>{};
    queryParams?.forEach((key, value) {
      if (value != null && '$value'.isNotEmpty) cleanParams[key] = '$value';
    });
    return cleanParams.isEmpty
        ? uri
        : uri.replace(queryParameters: cleanParams);
  }

  List<dynamic> _list(dynamic response) {
    if (response is Map && response['data'] is List) return response['data'];
    if (response is Map &&
        response['data'] is Map &&
        response['data']['data'] is List) {
      return response['data']['data'];
    }
    return const [];
  }
}
