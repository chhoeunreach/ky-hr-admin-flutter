import 'package:cnattendance/data/source/network/model/attendancereport/EmployeeTodayAttendance.dart';
import 'package:cnattendance/data/source/network/model/attendancereport/AttendanceSummary.dart';
import 'package:cnattendance/data/source/network/model/login/User.dart';
import 'package:cnattendance/data/source/network/model/profile/Profile.dart';
import 'package:cnattendance/data/source/network/model/leavetype/LeaveType.dart';
import 'package:cnattendance/provider/leaveprovider.dart';
import 'package:cnattendance/provider/profileprovider.dart';
import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NepaliPreferences extends Preferences {
  @override
  Future<bool> getEnglishDate() async => false;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('missing attendance values use display and numeric fallbacks', () {
    final attendance = EmployeeTodayAttendance.fromJson({});
    expect(attendance.checkInAt, '-');
    expect(attendance.checkOutAt, '-');
    expect(int.parse(attendance.productiveTime), 0);
    final summary = AttendanceSummary.fromJson({});
    expect(summary.totalPresent, '-');
    expect(summary.totalWorkedHours, '-');
  });

  test('missing profile and login values stay empty rather than literal null',
      () {
    final user = User.fromJson({});
    expect(
        [user.name, user.email, user.username, user.avatar], everyElement(''));
    final profile = Profile.fromJson({'id': 1});
    expect([profile.post, profile.bankName, profile.bankAccountNo, profile.dob],
        everyElement(''));
  });

  test('leave list conversion grows and missing allocation stays usable', () {
    final leave =
        LeaveType.fromJson({'leave_type_id': 2, 'leave_type_slug': 'annual'});
    final leaves = leave.getList([
      {'leave_type_id': 2},
      {'leave_type_id': 3}
    ]);
    expect(leaves, hasLength(2));
    expect(leave.leaveTypeSlug, 'annual');
    expect(leave.toJson()['leave_type_slug'], 'annual');
    final provider = LeaveProvider();
    addTearDown(provider.dispose);
    provider.makeLeaveList([leave]);
    expect(provider.leaveList.single.total, 0);
  });

  test('Nepali profile dates tolerate missing and invalid optional values',
      () async {
    final provider = ProfileProvider(preferences: _NepaliPreferences());
    addTearDown(provider.dispose);
    await provider.parseUser(
        Profile.fromJson({'id': 1, 'dob': null, 'joining_date': 'invalid'}));
    expect(provider.profile.dob, '');
    expect(provider.profile.joinedDate, '');
  });
}
