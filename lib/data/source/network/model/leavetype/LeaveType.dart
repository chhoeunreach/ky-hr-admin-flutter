class LeaveType {
  LeaveType({
    required this.leaveTypeId,
    required this.leaveTypeName,
    required this.leaveTypeSlug,
    required this.leaveTypeStatus,
    required this.earlyExit,
    required this.totalLeaveAllocated,
    required this.leaveTaken,
  });

  factory LeaveType.fromJson(dynamic json) {
    return LeaveType(
        leaveTypeId: json['leave_type_id']?.toString() ?? "0",
        leaveTypeName: json['leave_type_name']?.toString() ?? "Time Leave",
        leaveTypeSlug:
            (json['leave_type_slug'] ?? json['leave_type_slug '])?.toString() ??
                "",
        leaveTypeStatus: json['leave_type_status'] ?? false,
        earlyExit: json['early_exit'] ?? false,
        totalLeaveAllocated: json['total_leave_allocated']?.toString() ?? "0",
        leaveTaken: json['leave_taken']?.toString() ?? "0");
  }

  List<LeaveType> getList(List<dynamic> leaveList) {
    final list = <LeaveType>[];

    for (var item in leaveList) {
      list.add(LeaveType.fromJson(item));
    }

    return list;
  }

  String leaveTypeId;
  String leaveTypeName;
  String leaveTypeSlug;
  bool leaveTypeStatus;
  bool earlyExit;
  String totalLeaveAllocated;
  String leaveTaken;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['leave_type_id'] = leaveTypeId;
    map['leave_type_name'] = leaveTypeName;
    map['leave_type_slug'] = leaveTypeSlug;
    map['leave_type_status'] = leaveTypeStatus;
    map['early_exit'] = earlyExit;
    map['total_leave_allocated'] = totalLeaveAllocated;
    map['leave_taken'] = leaveTaken;
    return map;
  }
}
