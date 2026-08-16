import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cnattendance/data/source/network/model/teamsheet/Branch.dart';
import 'package:cnattendance/data/source/network/model/teamsheet/Department.dart';
import 'package:cnattendance/data/source/network/model/teamsheet/Employee.dart';
import 'package:cnattendance/model/chat_contact.dart';
import 'package:cnattendance/model/team.dart';
import 'package:cnattendance/repositories/teamsheetrepository.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class TeamSheetProvider with ChangeNotifier {
  TeamSheetRepository repository = TeamSheetRepository();
  final List<Team> _teamList = [];

  final List<Team> mainTeamList = [];
  final List<ChatContact> chatContacts = [];
  final List<ChatContact> onlineChatContacts = [];

  final List<Branch> _branches = [];
  final List<Department> _department = [];

  int selectedBranch = 0;
  int selectedDepartment = 0;

  List<Team> get teamList {
    return [..._teamList];
  }

  List<Branch> get branches {
    return [..._branches];
  }

  List<Department> get department {
    return [..._department];
  }

  void setDepartment(List<Department> department) {
    _department.clear();
    _department.add(Department(id: 0, name: "All"));
    _department.addAll(department);
  }

  Branch? get selectedBranchItem {
    return _firstWhereOrNull(
      _branches,
      (element) => element.id == selectedBranch,
    );
  }

  Department? get selectedDepartmentItem {
    return _firstWhereOrNull(
      _department,
      (element) => element.id == selectedDepartment,
    );
  }

  void createTeam(List<Employee> employees) {
    for (var employee in employees) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(employee.username.toString())
          .set({
        'name': employee.name,
        'phone': employee.phone,
        'email': employee.email,
        'username': employee.username,
        'id': employee.id,
        'avatar': employee.avatar,
        'department': employee.department,
        'post': employee.post,
        'role': employee.role,
        'user_type': employee.userType,
        'is_admin': employee.isAdmin,
        'gender': employee.gender,
      });
    }
  }

  Future<void> getTeam() async {
    try {
      final response = await repository.getTeam();
      makeTeamSheet(response.data.companyDetail.employee);
      makeChatContacts(response.data.chatContacts.isNotEmpty
          ? response.data.chatContacts
          : response.data.companyDetail.chatContacts);
      createTeam(response.data.companyDetail.employee);

      _branches.clear();
      _branches.addAll(response.data.branch);

      if (_branches.isNotEmpty) {
        setDepartment(_branches.first.department);
      } else {
        setDepartment([]);
      }

      if (_branches.isEmpty) {
        selectedDepartment = _department.isNotEmpty ? _department.first.id : 0;
        selectedBranch = 0;
        makeTeamList();
        notifyListeners();
        return;
      }

      final arguments = Get.arguments;
      if (arguments is Map) {
        final argumentBranch = (arguments["branch"] ?? '').toString();
        final argumentDepartment = (arguments["department"] ?? '').toString();
        final branch = _firstWhereOrNull(
          _branches,
          (element) => element.name == argumentBranch,
        );
        if (branch != null && argumentDepartment.isNotEmpty) {
          selectedBranch = branch.id;
          setDepartment(branch.department);
          final department = _firstWhereOrNull(
            _department,
            (element) => element.name == argumentDepartment,
          );
          selectedDepartment = department?.id ?? _department.first.id;
        } else {
          selectedDepartment = _department.first.id;
          selectedBranch = _branches.first.id;
        }
      } else {
        selectedDepartment = _department.first.id;
        selectedBranch = _branches.first.id;
      }
      makeTeamList();
      notifyListeners();
    } catch (error) {
      rethrow;
    }
  }

  Future<void> getChatContacts() async {
    try {
      final payload = await repository.getChatContacts();
      makeChatContacts(payload.contacts);
      makeOnlineChatContacts(payload.onlineContacts);
    } catch (error) {
      rethrow;
    }
  }

  void makeTeamList() {
    _teamList.clear();
    if (mainTeamList.isEmpty) {
      notifyListeners();
      return;
    }
    if (_branches.isEmpty || _department.isEmpty) {
      _teamList.addAll(mainTeamList);
      notifyListeners();
      return;
    }
    final branch = selectedBranchItem ?? _branches.first;
    final department = selectedDepartmentItem ?? _department.first;
    selectedBranch = branch.id;
    selectedDepartment = department.id;
    if (selectedDepartment == 0) {
      _teamList.addAll(mainTeamList.where((element) =>
          element.branch.toLowerCase() == branch.name.toLowerCase()));
    } else {
      _teamList.addAll(mainTeamList.where((element) =>
          element.department.toLowerCase() == department.name.toLowerCase()));
    }
    notifyListeners();
  }

  void makeTeamSheet(List<Employee> employee) {
    mainTeamList.clear();
    for (var value in employee) {
      mainTeamList.add(Team(
          id: value.id,
          username: value.username,
          name: value.name,
          post: value.post,
          avatar: value.avatar,
          phone: value.phone,
          email: value.email,
          active: value.onlineStatus,
          department: value.department,
          branch: value.branch,
          role: value.role,
          userType: value.userType,
          isAdmin: value.isAdmin));
    }
    notifyListeners();
  }

  void makeChatContacts(List<ChatContact> contacts) {
    chatContacts
      ..clear()
      ..addAll(contacts);
    notifyListeners();
  }

  void makeOnlineChatContacts(List<ChatContact> contacts) {
    onlineChatContacts
      ..clear()
      ..addAll(contacts);
    notifyListeners();
  }

  T? _firstWhereOrNull<T>(Iterable<T> values, bool Function(T) test) {
    for (final value in values) {
      if (test(value)) {
        return value;
      }
    }
    return null;
  }
}
