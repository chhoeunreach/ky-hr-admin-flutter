class MonthlyAttendanceSummary {
  const MonthlyAttendanceSummary({
    required this.month,
    required this.lateCount,
    required this.deduction,
    required this.bonusTarget,
    required this.completedDays,
    required this.workingDays,
    this.approvedLateCount,
    this.approvedTimeLeaveCount,
    this.excusedLateCount,
    this.bonusCurrency = 'USD',
  });

  final String month;
  final int lateCount, completedDays, workingDays;
  final int? approvedLateCount, approvedTimeLeaveCount;
  final int? excusedLateCount;
  int? get totalLateCount =>
      excusedLateCount == null ? null : lateCount + excusedLateCount!;
  final double deduction, bonusTarget;
  final String bonusCurrency;

  double get progress =>
      workingDays > 0 ? (completedDays / workingDays).clamp(0.0, 1.0) : 0;

  static MonthlyAttendanceSummary? fromJson(dynamic json) {
    if (json is! Map || json['available'] != true) return null;
    final deduction = json['deduction'];
    final bonus = json['bonus'];
    if (deduction is! Map || bonus is! Map) return null;
    double? number(dynamic value) => value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '');
    final late = number(json['late_count']);
    final amount = number(deduction['amount']);
    final target = number(bonus['target_amount']);
    final complete = number(bonus['completed_days']);
    final days = number(bonus['working_days']);
    final approvedLate = number(json['approved_late_count']);
    final approvedTimeLeave = number(json['approved_time_leave_count']);
    for (final key in [
      'approved_late_count',
      'approved_time_leave_count',
      'excused_late_count'
    ]) {
      final value = number(json[key]);
      if (json[key] != null && (value == null || !value.isFinite || value < 0))
        return null;
    }
    if ([late, amount, target, complete, days]
        .any((v) => v == null || !v.isFinite || v < 0)) return null;
    final month = json['month']?.toString() ?? '';
    if (!RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(month)) return null;
    return MonthlyAttendanceSummary(
      month: month,
      lateCount: late!.toInt(),
      deduction: amount!,
      bonusTarget: target!,
      bonusCurrency: RegExp(r'^[A-Z]{3}$').hasMatch('${bonus['currency']}')
          ? bonus['currency'] as String
          : 'USD',
      completedDays: complete!.toInt(),
      workingDays: days!.toInt(),
      approvedLateCount: approvedLate?.toInt(),
      approvedTimeLeaveCount: approvedTimeLeave?.toInt(),
      excusedLateCount: number(json['excused_late_count'])?.toInt(),
    );
  }
}
