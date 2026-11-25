import 'dart:convert';

import 'package:cnattendance/core/ky_security/ky_http.dart';
import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/features/delivery/delivery_model.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class DeliveryApiException implements Exception {
  final String message;
  final int? statusCode;
  const DeliveryApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class DeliveryApi {
  DeliveryApi({Preferences? preferences, http.Client? client})
      : _preferences = preferences ?? Preferences(),
        _transport = client ?? _client;

  static final http.Client _client = http.Client();
  final Preferences _preferences;
  final http.Client _transport;

  Future<Uri> _buildUri(String path, [Map<String, String>? query]) async {
    final base = Uri.parse(await _preferences.getAppUrl());
    final directory = base.path.endsWith('/') ? base.path : '${base.path}/';
    return base.replace(
      path: '$directory${Constant.API_URL}/v1/delivery$path',
      queryParameters: query,
    );
  }

  Future<Map<String, String>> _headers() async => {
        'Accept': 'application/json',
        'Authorization': 'Bearer ${await _preferences.getToken()}',
      };

  Map<String, dynamic> _decode(http.Response response) {
    try {
      final json = jsonDecode(response.body);
      if (json is Map<String, dynamic>) {
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return json;
        }
        final message = json['message']?.toString() ??
            'Request failed with status ${response.statusCode}';
        throw DeliveryApiException(message, statusCode: response.statusCode);
      }
      throw DeliveryApiException('Invalid server response format.',
          statusCode: response.statusCode);
    } on FormatException {
      throw DeliveryApiException(
          'Failed to parse server response (${response.statusCode})',
          statusCode: response.statusCode);
    }
  }

  /// Get driver's current active delivery if any
  Future<DeliveryModel?> getActiveDelivery() async {
    final uri = await _buildUri('/active');
    final response = await KyHttp.getWithClient(
      _transport,
      uri,
      headers: await _headers(),
    );

    if (response.statusCode == 404) return null;
    final json = _decode(response);
    final data = json['data'];
    if (data == null || (data is Map && data.isEmpty)) return null;
    return DeliveryModel.fromJson(data as Map<String, dynamic>);
  }

  /// List deliveries (active, completed, all)
  Future<List<DeliveryModel>> getDeliveries({
    String status = 'all',
    int page = 1,
  }) async {
    final uri = await _buildUri('/', {
      'status': status,
      'page': page.toString(),
    });
    final response = await KyHttp.getWithClient(
      _transport,
      uri,
      headers: await _headers(),
    );

    final json = _decode(response);
    final list = json['data'] as List<dynamic>? ?? [];
    return list
        .map((e) => DeliveryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Get list of company branches for inter-branch transfer
  Future<List<Map<String, dynamic>>> getBranches() async {
    final uri = await _buildUri('/branches');
    final response = await KyHttp.getWithClient(
      _transport,
      uri,
      headers: await _headers(),
    );
    final json = _decode(response);
    final list = json['data'] as List<dynamic>? ?? [];
    return list.map((e) => e as Map<String, dynamic>).toList();
  }

  /// Start a new delivery
  Future<DeliveryModel> startDelivery({
    required XFile driverSelfie,
    List<XFile> productPhotos = const [],
    String deliveryType = 'customer',
    int? destinationBranchId,
    String? customerName,
    String? customerPhone,
    String? invoiceNumber,
    String? destinationAddress,
    double? destinationLatitude,
    double? destinationLongitude,
    String? originAddress,
    double? originLatitude,
    double? originLongitude,
    String? notes,
  }) async {
    final uri = await _buildUri('/start');
    final body = <String, dynamic>{
      'delivery_type': deliveryType,
      if (destinationBranchId != null)
        'destination_branch_id': destinationBranchId,
      'customer_name': customerName != null && customerName.trim().isNotEmpty
          ? customerName.trim()
          : 'អតិថិជនទូទៅ (General Customer)',
      'customer_phone': customerPhone?.trim() ?? '',
      if (invoiceNumber != null && invoiceNumber.trim().isNotEmpty)
        'invoice_number': invoiceNumber.trim(),
      if (destinationAddress != null && destinationAddress.isNotEmpty)
        'destination_address': destinationAddress,
      if (destinationLatitude != null)
        'destination_latitude': destinationLatitude,
      if (destinationLongitude != null)
        'destination_longitude': destinationLongitude,
      if (originAddress != null && originAddress.isNotEmpty)
        'origin_address': originAddress,
      if (originLatitude != null) 'origin_latitude': originLatitude,
      if (originLongitude != null) 'origin_longitude': originLongitude,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    };

    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(await _headers());
    for (final entry in body.entries) {
      request.fields[entry.key] = '${entry.value}';
    }
    request.files.add(await http.MultipartFile.fromPath(
      'driver_selfie',
      driverSelfie.path,
    ));
    for (final photo in productPhotos) {
      request.files.add(await http.MultipartFile.fromPath(
        'product_photos[]',
        photo.path,
      ));
    }

    final response = await KyHttp.sendMultipart(request, client: _transport)
        .then(http.Response.fromStream)
        .timeout(const Duration(seconds: 90));

    final json = _decode(response);
    return DeliveryModel.fromJson(json['data'] as Map<String, dynamic>);
  }

  /// Ping current GPS position (sent every 15-20s while delivery is active)
  Future<bool> pingLocation({
    required int deliveryId,
    required double latitude,
    required double longitude,
    double? heading,
    double? speed,
  }) async {
    try {
      final uri = await _buildUri('/ping-location');
      final body = <String, dynamic>{
        'delivery_id': deliveryId,
        'latitude': latitude,
        'longitude': longitude,
        if (heading != null) 'heading': heading,
        if (speed != null) 'speed': speed,
      };

      final headers = await _headers();
      headers['Content-Type'] = 'application/json';

      final response = await KyHttp.postWithClient(
        _transport,
        uri,
        headers: headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 12));

      return response.statusCode == 200;
    } catch (_) {
      // Background ping shouldn't throw to disrupt driver UI
      return false;
    }
  }

  /// Mark delivery as arrived or complete delivery with optional proof photo
  Future<DeliveryModel> completeDelivery({
    required int deliveryId,
    required XFile completionSelfie,
    XFile? proofPhoto,
    String? notes,
  }) async {
    final uri = await _buildUri('/$deliveryId/complete');
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(await _headers());
    if (notes != null && notes.isNotEmpty) {
      request.fields['notes'] = notes;
    }
    request.files.add(await http.MultipartFile.fromPath(
      'completion_selfie',
      completionSelfie.path,
    ));
    if (proofPhoto != null) {
      request.files.add(await http.MultipartFile.fromPath(
        'proof_photo',
        proofPhoto.path,
      ));
    }

    final streamedResponse = await KyHttp.sendMultipart(
      request,
      client: _transport,
    ).then(http.Response.fromStream).timeout(const Duration(seconds: 45));

    final json = _decode(streamedResponse);
    return DeliveryModel.fromJson(json['data'] as Map<String, dynamic>);
  }

  /// Cancel delivery
  Future<bool> cancelDelivery({
    required int deliveryId,
    String? reason,
  }) async {
    final uri = await _buildUri('/$deliveryId/cancel');
    final headers = await _headers();
    headers['Content-Type'] = 'application/json';
    final body = <String, dynamic>{
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    };

    final response = await KyHttp.postWithClient(
      _transport,
      uri,
      headers: headers,
      body: jsonEncode(body),
    );

    return response.statusCode == 200;
  }
}
