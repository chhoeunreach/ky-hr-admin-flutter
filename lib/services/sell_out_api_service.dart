import 'package:dio/dio.dart';
import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/models/sell_out_report.dart';
import 'package:cnattendance/utils/constant.dart';

class SellOutApiService {
  final Dio _dio;
  final Preferences _preferences;

  SellOutApiService()
      : _dio = Dio(),
        _preferences = Preferences();

  Future<List<SellOutReport>> fetchReports() async {
    final token = await _preferences.getToken();
    final baseUrl = await _preferences.getAppUrl();

    final response = await _dio.get(
      '${baseUrl}${Constant.SELL_OUT_REPORT_URL}',
      options: Options(
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ),
    );

    final items = _extractList(response.data);
    return items
        .whereType<Map>()
        .map((item) => SellOutReport.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<SellOutReport> fetchReport(int id) async {
    final token = await _preferences.getToken();
    final baseUrl = await _preferences.getAppUrl();

    final response = await _dio.get(
      '${baseUrl}${Constant.SELL_OUT_REPORT_URL}/$id',
      options: Options(
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ),
    );

    final data = response.data;
    if (data is Map && data['data'] is Map) {
      return SellOutReport.fromJson(Map<String, dynamic>.from(data['data']));
    }
    if (data is Map) {
      return SellOutReport.fromJson(Map<String, dynamic>.from(data));
    }
    throw Exception('Invalid report response');
  }

  Future<Map<String, dynamic>> submitReport(SellOutReport report) async {
    _validateReport(report);
    final token = await _preferences.getToken();
    final baseUrl = await _preferences.getAppUrl();
    final formData = await _buildFormData(report);

    try {
      final response = await _dio.post(
        '${baseUrl}${Constant.SELL_OUT_REPORT_URL}',
        data: formData,
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );

      return response.data is Map
          ? response.data as Map<String, dynamic>
          : {'status': true, 'message': 'Submitted successfully'};
    } on DioException catch (e) {
      throw _toException(e, 'Submission failed');
    }
  }

  Future<Map<String, dynamic>> updateReport(SellOutReport report) async {
    _validateReport(report);
    final token = await _preferences.getToken();
    final baseUrl = await _preferences.getAppUrl();
    final formData = await _buildFormData(report);
    formData.fields.add(const MapEntry('_method', 'PUT'));

    try {
      final response = await _dio.post(
        '${baseUrl}${Constant.SELL_OUT_REPORT_URL}/${report.id}',
        data: formData,
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );

      return response.data is Map
          ? response.data as Map<String, dynamic>
          : {'status': true, 'message': 'Updated successfully'};
    } on DioException catch (e) {
      throw _toException(e, 'Update failed');
    }
  }

  Future<void> deletePhoto(int reportId, int photoId) async {
    final token = await _preferences.getToken();
    final baseUrl = await _preferences.getAppUrl();

    try {
      await _dio.delete(
        '${baseUrl}${Constant.SELL_OUT_REPORT_URL}/$reportId/photos/$photoId',
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );
    } on DioException catch (e) {
      throw _toException(e, 'Failed to remove photo');
    }
  }

  Future<FormData> _buildFormData(SellOutReport report) async {
    final formData = FormData();

    formData.fields.add(MapEntry('seller_name', report.sellerName));
    formData.fields.add(MapEntry('branch_name', report.branchName));
    formData.fields.add(MapEntry('customer_name', report.customerName));
    formData.fields.add(MapEntry('customer_phone', report.customerPhone));
    formData.fields.add(MapEntry('service_type', report.serviceType));
    formData.fields.add(MapEntry('payment_method', report.paymentMethod));
    formData.fields.add(MapEntry('note', report.note));
    formData.fields.add(MapEntry('extracted_text', report.extractedText));
    formData.fields.add(MapEntry(
      'commission',
      report.commission.toStringAsFixed(2),
    ));

    for (int i = 0; i < report.lines.length; i++) {
      final line = report.lines[i];
      final lineMap = line.toMap(i);
      for (final entry in lineMap.entries) {
        formData.fields.add(MapEntry(entry.key, entry.value));
      }

      for (int p = 0; p < line.photoPaths.length; p++) {
        final path = line.photoPaths[p];
        final ext = _getExtension(path);
        final file = await MultipartFile.fromFile(
          path,
          filename: 'line_${i}_photo_$p$ext',
        );
        formData.files.add(MapEntry('lines[$i][photos][]', file));
      }
    }

    for (int i = 0; i < report.photoPaths.length; i++) {
      final path = report.photoPaths[i];
      final ext = _getExtension(path);
      final file = await MultipartFile.fromFile(
        path,
        filename: 'photo_$i$ext',
      );
      formData.files.add(MapEntry('photos[]', file));
    }

    return formData;
  }

  void _validateReport(SellOutReport report) {
    final serialError = report.validateSerialNumbers();
    if (serialError != null) {
      throw Exception(serialError);
    }
  }

  Exception _toException(DioException e, String fallbackMessage) {
    if (e.response != null) {
      final data = e.response!.data;
      if (data is Map) {
        final message = data['message'] ?? fallbackMessage;
        final errors = data['errors'];
        if (errors is Map) {
          final errorMessages = (errors as Map<String, dynamic>)
              .values
              .map((e) => e is List ? e.join(', ') : e.toString())
              .join('\n');
          return Exception('$message\n$errorMessages');
        }
        return Exception(message.toString());
      }
      return Exception('$fallbackMessage (${e.response!.statusCode})');
    }
    return Exception('Network error: ${e.message}');
  }

  String _getExtension(String path) {
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == path.length - 1) {
      return '.jpg';
    }
    return path.substring(dotIndex);
  }

  List<dynamic> _extractList(dynamic responseData) {
    if (responseData is List) return responseData;
    if (responseData is! Map) return const [];

    final data = responseData['data'];
    if (data is List) return data;
    if (data is Map && data['data'] is List) return data['data'] as List;
    if (data is Map && data['reports'] is List) return data['reports'] as List;
    if (responseData['reports'] is List) return responseData['reports'] as List;

    return const [];
  }
}
