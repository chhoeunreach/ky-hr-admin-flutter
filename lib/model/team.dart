import 'package:flutter/material.dart';

class Team with ChangeNotifier {
  int id;
  String username;
  String name;
  String post;
  String avatar;
  String phone;
  String email;
  String active;
  String department;
  String branch;
  String role;
  String userType;
  String isAdmin;

  Team({
    required this.id,
    required this.username,
    required this.name,
    required this.post,
    required this.avatar,
    required this.phone,
    required this.email,
    required this.active,
    required this.department,
    required this.branch,
    required this.role,
    required this.userType,
    required this.isAdmin,
  });

  bool get isAdminUser {
    final adminFields = [
      role,
      userType,
      isAdmin,
      post,
      department,
    ].map((value) => value.trim().toLowerCase());

    return adminFields.any((value) =>
        value == '1' ||
        value == 'true' ||
        value == 'admin' ||
        value == 'administrator' ||
        value.contains('admin'));
  }
}
