// To parse this JSON data, do
//
//     final assetListResponse = assetListResponseFromJson(jsonString);

import 'dart:convert';

AssetListResponse assetListResponseFromJson(String str) =>
    AssetListResponse.fromJson(json.decode(str));

String assetListResponseToJson(AssetListResponse data) =>
    json.encode(data.toJson());

class AssetListResponse {
  bool status;
  String message;
  int statusCode;
  List<AssetData> data;

  AssetListResponse({
    required this.status,
    required this.message,
    required this.statusCode,
    required this.data,
  });

  factory AssetListResponse.fromJson(Map<String, dynamic> json) {
    final rawData = json["data"];
    final items = <AssetData>[];
    if (rawData is List) {
      for (final item in rawData) {
        if (item is Map<String, dynamic>) {
          try {
            items.add(AssetData.fromJson(item));
          } catch (_) {
            // Skip malformed rows instead of failing the whole list.
          }
        } else if (item is Map) {
          try {
            items.add(AssetData.fromJson(Map<String, dynamic>.from(item)));
          } catch (_) {
            // Skip malformed rows instead of failing the whole list.
          }
        }
      }
    }

    return AssetListResponse(
      status: json["status"] == true,
      message: json["message"]?.toString() ?? '',
      statusCode: (json["status_code"] as num?)?.toInt() ?? 200,
      data: items,
    );
  }

  Map<String, dynamic> toJson() => {
        "status": status,
        "message": message,
        "status_code": statusCode,
        "data": List<dynamic>.from(data.map((x) => x.toJson())),
      };
}

class AssetData {
  int id;
  String asset;
  String assignedDate;
  String? returnedDate;
  String status;
  String? returnCondition;
  String? notes;

  AssetData({
    required this.id,
    required this.asset,
    required this.assignedDate,
    required this.returnedDate,
    required this.status,
    required this.returnCondition,
    required this.notes,
  });

  factory AssetData.fromJson(Map<String, dynamic> json) => AssetData(
        id: json["id"] is int
            ? json["id"] as int
            : (json["id"] is num)
                ? (json["id"] as num).toInt()
                : int.tryParse('${json["id"]}') ?? 0,
        asset: json["asset"]?.toString() ?? '',
        assignedDate: json["assigned_date"]?.toString() ?? '',
        returnedDate: json["returned_date"]?.toString(),
        status: json["status"]?.toString() ?? '',
        returnCondition: json["return_condition"]?.toString(),
        notes: json["notes"]?.toString(),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "asset": asset,
        "assigned_date": assignedDate,
        "returned_date": returnedDate,
        "status": status,
        "return_condition": returnCondition,
        "notes": notes,
      };
}
