class TopBonusEmployee {
  const TopBonusEmployee({
    required this.id,
    required this.name,
    required this.avatar,
    required this.completedDays,
    required this.workingDays,
    required this.progressPercent,
  });

  final int id;
  final String name;
  final String avatar;
  final int completedDays;
  final int workingDays;
  final double progressPercent;

  static TopBonusEmployee? fromJson(dynamic json) {
    if (json is! Map) return null;
    final name = json['name']?.toString().trim() ?? '';
    final id = int.tryParse(json['id']?.toString() ?? '');
    if (name.isEmpty || id == null || id <= 0) return null;
    int readInt(dynamic value) => value is num
        ? value.toInt()
        : int.tryParse(value?.toString() ?? '') ?? 0;
    double readDouble(dynamic value) => value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0;

    return TopBonusEmployee(
      id: id,
      name: name,
      avatar: json['avatar']?.toString() ?? '',
      completedDays: readInt(json['completed_days']),
      workingDays: readInt(json['working_days']),
      progressPercent:
          readDouble(json['progress_percent']).clamp(0, 100).toDouble(),
    );
  }
}
