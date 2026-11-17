import 'package:cnattendance/data/source/network/model/dashboard/EmployeeTodayAttendance.dart';
import 'package:cnattendance/data/source/network/model/dashboard/Overview.dart';
import 'package:cnattendance/provider/dashboardprovider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bulk dashboard updates emit a single notification', () {
    final provider = DashboardProvider();
    addTearDown(provider.dispose);

    var notifications = 0;
    provider.addListener(() => notifications++);

    provider.updateOverView(
      Overview(
        presentDays: 5,
        totalPaidLeaves: 0,
        totalHolidays: 2,
        totalPendingLeaves: 1,
        totalLeaveTaken: 3,
        total_assigned_projects: 4,
        total_pending_tasks: 6,
        total_awards: 0,
        active_training: 0,
        active_event: 0,
      ),
      notify: false,
    );
    provider.updateAttendanceStatus(
      EmployeeTodayAttendance(
        checkInAt: '09:00',
        checkOutAt: '-',
        productionTime: 120,
      ),
      notify: false,
    );
    provider.makeWeeklyReport(
      List.generate(7, (i) => {'productive_time_in_min': i * 60}),
      notify: false,
    );

    // Intermediate writes must not rebuild the home screen.
    expect(notifications, 0);
    expect(provider.overviewList['present'], '5');
    expect(provider.attendanceList['check-in'], '09:00');
    expect(provider.weeklyReport.length, 7);

    provider.notifyListeners();
    expect(notifications, 1);
  });
}
