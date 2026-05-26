class Employee {
  Employee({
    required this.id,
    required this.name,
    required this.email,
    required this.username,
    required this.phone,
    required this.dob,
    required this.gender,
    required this.branch,
    required this.department,
    required this.post,
    required this.avatar,
    required this.onlineStatus,
    required this.role,
    required this.userType,
    required this.isAdmin,
  });

  factory Employee.fromJson(dynamic json) {
    final map = json is Map<String, dynamic> ? json : <String, dynamic>{};
    return Employee(
        id: _intValue(map['id']),
        name: (map['name'] ?? '').toString(),
        email: (map['email'] ?? '').toString(),
        username: (map['username'] ?? '').toString(),
        phone: (map['phone'] ?? '').toString(),
        dob: (map['dob'] ?? '').toString(),
        gender: (map['gender'] ?? '').toString(),
        branch: (map['branch'] ?? '').toString(),
        department: (map['department'] ?? '').toString(),
        post: (map['post'] ?? '').toString(),
        avatar: (map['avatar'] ?? '').toString(),
        onlineStatus: (map['online_status'] ?? '0').toString(),
        role: (map['role'] ?? '').toString(),
        userType: (map['user_type'] ?? '').toString(),
        isAdmin: (map['is_admin'] ?? map['admin'] ?? '').toString());
  }

  int id;
  String name;
  String email;
  String phone;
  String username;
  String dob;
  String gender;
  String branch;
  String department;
  String post;
  String avatar;
  String onlineStatus;
  String role;
  String userType;
  String isAdmin;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['id'] = id;
    map['name'] = name;
    map['email'] = email;
    map['phone'] = phone;
    map['dob'] = dob;
    map['gender'] = gender;
    map['department'] = department;
    map['post'] = post;
    map['avatar'] = avatar;
    map['online_status'] = onlineStatus;
    map['role'] = role;
    map['user_type'] = userType;
    map['is_admin'] = isAdmin;
    return map;
  }

  static int _intValue(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse((value ?? '').toString()) ?? 0;
  }
}
