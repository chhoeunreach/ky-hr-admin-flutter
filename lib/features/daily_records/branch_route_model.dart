import 'dart:convert';

class RouteCheckpoint {
  final String id;
  final String branchName;
  final DateTime arrivedAt;
  final double? latitude;
  final double? longitude;
  final String notes;
  final List<String> photoPaths;

  RouteCheckpoint({
    required this.id,
    required this.branchName,
    required this.arrivedAt,
    this.latitude,
    this.longitude,
    this.notes = '',
    this.photoPaths = const [],
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'branch_name': branchName,
        'arrived_at': arrivedAt.toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
        'notes': notes,
        'photo_paths': photoPaths,
      };

  factory RouteCheckpoint.fromMap(Map<String, dynamic> map) {
    return RouteCheckpoint(
      id: (map['id'] ?? '').toString(),
      branchName: (map['branch_name'] ?? '').toString(),
      arrivedAt: map['arrived_at'] != null
          ? DateTime.tryParse(map['arrived_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      latitude: map['latitude'] != null
          ? double.tryParse(map['latitude'].toString())
          : null,
      longitude: map['longitude'] != null
          ? double.tryParse(map['longitude'].toString())
          : null,
      notes: (map['notes'] ?? '').toString(),
      photoPaths:
          (map['photo_paths'] as List?)?.map((e) => '$e').toList() ?? [],
    );
  }
}

class BranchRoute {
  final String id;
  final String purpose;
  final String originBranch;
  final List<String> targetBranches;
  final String status; // 'processing' | 'completed' | 'cancelled'
  final DateTime startTime;
  final double? startLatitude;
  final double? startLongitude;
  final String? startSelfiePath;
  final String? startAddress;
  final List<RouteCheckpoint> checkpoints;
  final DateTime? endTime;
  final double? endLatitude;
  final double? endLongitude;
  final String? endSelfiePath;
  final String? finalSummary;
  final int totalMinutes;
  final bool isSynced;

  BranchRoute({
    required this.id,
    required this.purpose,
    required this.originBranch,
    required this.targetBranches,
    required this.status,
    required this.startTime,
    this.startLatitude,
    this.startLongitude,
    this.startSelfiePath,
    this.startAddress,
    this.checkpoints = const [],
    this.endTime,
    this.endLatitude,
    this.endLongitude,
    this.endSelfiePath,
    this.finalSummary,
    this.totalMinutes = 0,
    this.isSynced = false,
  });

  bool get isProcessing => status == 'processing';
  bool get isCompleted => status == 'completed';

  Duration get currentDuration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  String get formattedDuration {
    final d = currentDuration;
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours > 0) {
      return '$hours ម៉ោង $minutes នាទី';
    }
    return '$minutes នាទី';
  }

  String get liveTimerString {
    final d = currentDuration;
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  BranchRoute copyWith({
    String? id,
    String? purpose,
    String? originBranch,
    List<String>? targetBranches,
    String? status,
    DateTime? startTime,
    double? startLatitude,
    double? startLongitude,
    String? startSelfiePath,
    String? startAddress,
    List<RouteCheckpoint>? checkpoints,
    DateTime? endTime,
    double? endLatitude,
    double? endLongitude,
    String? endSelfiePath,
    String? finalSummary,
    int? totalMinutes,
    bool? isSynced,
  }) {
    return BranchRoute(
      id: id ?? this.id,
      purpose: purpose ?? this.purpose,
      originBranch: originBranch ?? this.originBranch,
      targetBranches: targetBranches ?? this.targetBranches,
      status: status ?? this.status,
      startTime: startTime ?? this.startTime,
      startLatitude: startLatitude ?? this.startLatitude,
      startLongitude: startLongitude ?? this.startLongitude,
      startSelfiePath: startSelfiePath ?? this.startSelfiePath,
      startAddress: startAddress ?? this.startAddress,
      checkpoints: checkpoints ?? this.checkpoints,
      endTime: endTime ?? this.endTime,
      endLatitude: endLatitude ?? this.endLatitude,
      endLongitude: endLongitude ?? this.endLongitude,
      endSelfiePath: endSelfiePath ?? this.endSelfiePath,
      finalSummary: finalSummary ?? this.finalSummary,
      totalMinutes: totalMinutes ?? this.totalMinutes,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'purpose': purpose,
        'origin_branch': originBranch,
        'target_branches': targetBranches,
        'status': status,
        'start_time': startTime.toIso8601String(),
        'start_latitude': startLatitude,
        'start_longitude': startLongitude,
        'start_selfie_path': startSelfiePath,
        'start_address': startAddress,
        'checkpoints': checkpoints.map((c) => c.toMap()).toList(),
        'end_time': endTime?.toIso8601String(),
        'end_latitude': endLatitude,
        'end_longitude': endLongitude,
        'end_selfie_path': endSelfiePath,
        'final_summary': finalSummary,
        'total_minutes': totalMinutes,
        'is_synced': isSynced,
      };

  factory BranchRoute.fromMap(Map<String, dynamic> map) {
    return BranchRoute(
      id: (map['id'] ?? '').toString(),
      purpose: (map['purpose'] ?? '').toString(),
      originBranch: (map['origin_branch'] ?? '').toString(),
      targetBranches:
          (map['target_branches'] as List?)?.map((e) => '$e').toList() ?? [],
      status: (map['status'] ?? 'processing').toString(),
      startTime: map['start_time'] != null
          ? DateTime.tryParse(map['start_time'].toString()) ?? DateTime.now()
          : DateTime.now(),
      startLatitude: map['start_latitude'] != null
          ? double.tryParse(map['start_latitude'].toString())
          : null,
      startLongitude: map['start_longitude'] != null
          ? double.tryParse(map['start_longitude'].toString())
          : null,
      startSelfiePath: map['start_selfie_path']?.toString(),
      startAddress: map['start_address']?.toString(),
      checkpoints: (map['checkpoints'] as List?)
              ?.map((c) => RouteCheckpoint.fromMap(c as Map<String, dynamic>))
              .toList() ??
          [],
      endTime: map['end_time'] != null
          ? DateTime.tryParse(map['end_time'].toString())
          : null,
      endLatitude: map['end_latitude'] != null
          ? double.tryParse(map['end_latitude'].toString())
          : null,
      endLongitude: map['end_longitude'] != null
          ? double.tryParse(map['end_longitude'].toString())
          : null,
      endSelfiePath: map['end_selfie_path']?.toString(),
      finalSummary: map['final_summary']?.toString(),
      totalMinutes: map['total_minutes'] != null
          ? int.tryParse(map['total_minutes'].toString()) ?? 0
          : 0,
      isSynced: map['is_synced'] == true,
    );
  }

  String toJson() => jsonEncode(toMap());
  factory BranchRoute.fromJson(String source) =>
      BranchRoute.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
