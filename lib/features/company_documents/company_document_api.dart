import 'dart:convert';
import 'dart:io';

import 'package:cnattendance/core/ky_security/ky_http.dart';
import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/features/company_documents/company_document_model.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class CompanyDocumentApi {
  CompanyDocumentApi({Preferences? preferences, http.Client? client})
      : _preferences = preferences ?? Preferences(),
        _transport = client ?? _client;

  static final http.Client _client = http.Client();
  final Preferences _preferences;
  final http.Client _transport;

  Future<Uri> _buildUri(String path, [Map<String, String>? query]) async {
    final base = Uri.parse(await _preferences.getAppUrl());
    final directory = base.path.endsWith('/') ? base.path : '${base.path}/';
    return base.replace(
      path: '$directory${Constant.API_URL}/v1/company-documents$path',
      queryParameters: query,
    );
  }

  Future<Map<String, String>> _headers() async => {
        'Accept': 'application/json',
        'Authorization': 'Bearer ${await _preferences.getToken()}',
      };

  /// Fetch list of documents with summary metrics & pagination
  Future<Map<String, dynamic>> getDocuments({
    String? category,
    String? docSubType,
    String? status,
    String? search,
    int? branchId,
    int page = 1,
  }) async {
    final query = <String, String>{
      'page': page.toString(),
    };
    if (category != null && category.isNotEmpty && category != 'all') {
      query['category'] = category;
    }
    if (docSubType != null && docSubType.isNotEmpty) {
      query['doc_sub_type'] = docSubType;
    }
    if (status != null && status.isNotEmpty && status != 'all') {
      query['status'] = status;
    }
    if (search != null && search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }
    if (branchId != null && branchId > 0) {
      query['branch_id'] = branchId.toString();
    }

    final uri = await _buildUri('', query);
    final response = await KyHttp.getWithClient(
      _transport,
      uri,
      headers: await _headers(),
    ).timeout(const Duration(seconds: 30));

    final json = _decode(response);
    final dataList = (json['data'] as List? ?? [])
        .map((item) => CompanyDocumentItem.fromJson(item as Map<String, dynamic>))
        .toList();

    final summary = json['summary'] != null
        ? CompanyDocumentSummary.fromJson(json['summary'] as Map<String, dynamic>)
        : CompanyDocumentSummary.empty();

    final pagination = json['pagination'] as Map<String, dynamic>? ?? {};

    return {
      'documents': dataList,
      'summary': summary,
      'pagination': pagination,
    };
  }

  /// Fetch metadata for dropdowns (categories, sub-types, branches)
  Future<Map<String, dynamic>> getMeta() async {
    final uri = await _buildUri('/meta');
    final response = await KyHttp.getWithClient(
      _transport,
      uri,
      headers: await _headers(),
    ).timeout(const Duration(seconds: 20));

    final json = _decode(response);
    final data = json['data'] as Map<String, dynamic>? ?? {};

    final categories = (data['categories'] as List? ?? [])
        .map((c) => CompanyDocumentCategoryItem.fromJson(c as Map<String, dynamic>))
        .toList();

    final branches = (data['branches'] as List? ?? [])
        .map((b) => CompanyDocumentBranchItem.fromJson(b as Map<String, dynamic>))
        .toList();

    final rawSubTypes = data['sub_types'] as Map<String, dynamic>? ?? {};
    final subTypes = <String, List<CompanyDocumentSubTypeItem>>{};
    rawSubTypes.forEach((key, list) {
      if (list is List) {
        subTypes[key] = list
            .map((s) => CompanyDocumentSubTypeItem.fromJson(s as Map<String, dynamic>))
            .toList();
      }
    });

    return {
      'categories': categories,
      'branches': branches,
      'sub_types': subTypes,
      'currencies': (data['currencies'] as List? ?? ['USD', 'KHR']).cast<String>(),
    };
  }

  /// Fetch expiring and expired documents for alerts
  Future<Map<String, dynamic>> getAlerts() async {
    final uri = await _buildUri('/alerts');
    final response = await KyHttp.getWithClient(
      _transport,
      uri,
      headers: await _headers(),
    ).timeout(const Duration(seconds: 20));

    final json = _decode(response);
    final data = json['data'] as Map<String, dynamic>? ?? {};

    final expiringSoon = (data['expiring_soon'] as List? ?? [])
        .map((item) => CompanyDocumentItem.fromJson(item as Map<String, dynamic>))
        .toList();

    final expired = (data['expired'] as List? ?? [])
        .map((item) => CompanyDocumentItem.fromJson(item as Map<String, dynamic>))
        .toList();

    return {
      'expiring_soon': expiringSoon,
      'expired': expired,
      'expiring_soon_count': data['expiring_soon_count'] ?? expiringSoon.length,
      'expired_count': data['expired_count'] ?? expired.length,
    };
  }

  /// Fetch single document details
  Future<CompanyDocumentItem> getDocument(int id) async {
    final uri = await _buildUri('/$id');
    final response = await KyHttp.getWithClient(
      _transport,
      uri,
      headers: await _headers(),
    ).timeout(const Duration(seconds: 20));

    final json = _decode(response);
    return CompanyDocumentItem.fromJson(json['data'] as Map<String, dynamic>);
  }

  /// Upload and create a new document via camera or file picker
  Future<CompanyDocumentItem> uploadDocument({
    required String categoryCode,
    String? docSubType,
    required String title,
    String? holderName,
    String? docNumber,
    int? branchId,
    String? issuingAuthority,
    String? issueDate,
    String? expiryDate,
    int? alertBeforeDays,
    double? costAmount,
    String currency = 'USD',
    String? receiptNumber,
    String confidentialityLevel = 'internal',
    String? description,
    File? file,
    List<File>? files,
    XFile? xFile,
    List<XFile>? xFiles,
    PlatformFile? platformFile,
    List<PlatformFile>? platformFiles,
  }) async {
    final uri = await _buildUri('');
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(await _headers());

    request.fields['category_code'] = categoryCode;
    if (docSubType != null && docSubType.isNotEmpty) {
      request.fields['doc_sub_type'] = docSubType;
    }
    request.fields['title'] = title;
    if (holderName != null && holderName.isNotEmpty) {
      request.fields['holder_name'] = holderName;
    }
    if (docNumber != null && docNumber.isNotEmpty) {
      request.fields['doc_number'] = docNumber;
    }
    if (branchId != null && branchId > 0) {
      request.fields['branch_id'] = branchId.toString();
    }
    if (issuingAuthority != null && issuingAuthority.isNotEmpty) {
      request.fields['issuing_authority'] = issuingAuthority;
    }
    if (issueDate != null && issueDate.isNotEmpty) {
      request.fields['issue_date'] = issueDate;
    }
    if (expiryDate != null && expiryDate.isNotEmpty) {
      request.fields['expiry_date'] = expiryDate;
    }
    if (alertBeforeDays != null && alertBeforeDays > 0) {
      request.fields['alert_before_days'] = alertBeforeDays.toString();
    }
    if (costAmount != null) {
      request.fields['cost_amount'] = costAmount.toString();
    }
    request.fields['currency'] = currency;
    if (receiptNumber != null && receiptNumber.isNotEmpty) {
      request.fields['receipt_number'] = receiptNumber;
    }
    request.fields['confidentiality_level'] = confidentialityLevel;
    if (description != null && description.isNotEmpty) {
      request.fields['description'] = description;
    }

    // Attach files (supports multiple files as well as single file)
    if (files != null && files.isNotEmpty) {
      for (final f in files) {
        request.files.add(await http.MultipartFile.fromPath('files[]', f.path));
      }
      request.files.add(await http.MultipartFile.fromPath('file', files.first.path));
    } else if (file != null) {
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
      request.files.add(await http.MultipartFile.fromPath('files[]', file.path));
    } else if (xFiles != null && xFiles.isNotEmpty) {
      for (final xf in xFiles) {
        request.files.add(await http.MultipartFile.fromPath('files[]', xf.path));
      }
      request.files.add(await http.MultipartFile.fromPath('file', xFiles.first.path));
    } else if (xFile != null) {
      request.files.add(await http.MultipartFile.fromPath('file', xFile.path));
      request.files.add(await http.MultipartFile.fromPath('files[]', xFile.path));
    } else if (platformFiles != null && platformFiles.isNotEmpty) {
      for (final pf in platformFiles) {
        if (pf.bytes != null) {
          request.files.add(http.MultipartFile.fromBytes('files[]', pf.bytes!, filename: pf.name));
        } else if (pf.path != null) {
          request.files.add(await http.MultipartFile.fromPath('files[]', pf.path!));
        }
      }
      final firstPf = platformFiles.first;
      if (firstPf.bytes != null) {
        request.files.add(http.MultipartFile.fromBytes('file', firstPf.bytes!, filename: firstPf.name));
      } else if (firstPf.path != null) {
        request.files.add(await http.MultipartFile.fromPath('file', firstPf.path!));
      }
    } else if (platformFile != null) {
      if (platformFile.bytes != null) {
        request.files.add(http.MultipartFile.fromBytes('file', platformFile.bytes!, filename: platformFile.name));
        request.files.add(http.MultipartFile.fromBytes('files[]', platformFile.bytes!, filename: platformFile.name));
      } else if (platformFile.path != null) {
        request.files.add(await http.MultipartFile.fromPath('file', platformFile.path!));
        request.files.add(await http.MultipartFile.fromPath('files[]', platformFile.path!));
      }
    } else {
      throw const CompanyDocumentException('Please select or capture a document file.');
    }

    final streamedResponse = await KyHttp.sendMultipart(request, client: _transport)
        .then(http.Response.fromStream)
        .timeout(const Duration(seconds: 90));

    final json = _decode(streamedResponse);
    return CompanyDocumentItem.fromJson(json['data'] as Map<String, dynamic>);
  }

  /// Delete document
  Future<bool> deleteDocument(int id) async {
    final uri = await _buildUri('/$id');
    final response = await KyHttp.deleteWithClient(
      _transport,
      uri,
      headers: await _headers(),
    ).timeout(const Duration(seconds: 20));

    final json = _decode(response);
    return json['status'] == true;
  }

  Map<String, dynamic> _decode(http.Response response) {
    Object? parsed;
    try {
      parsed = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      parsed = null;
    }

    final body = parsed is Map<String, dynamic> ? parsed : const <String, dynamic>{};
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final validation = body['errors'];
      final first = validation is Map && validation.isNotEmpty
          ? validation.values.first
          : null;
      throw CompanyDocumentException(
        first is List && first.isNotEmpty
            ? first.first.toString()
            : body['message']?.toString() ?? 'Request failed with status ${response.statusCode}.',
      );
    }
    return body;
  }
}

class CompanyDocumentException implements Exception {
  final String message;
  const CompanyDocumentException(this.message);

  @override
  String toString() => message;
}
