import 'package:factoryos/features/hr/domain/hr_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('HR attendance rate handles active and zero employee counts', () {
    const active = HrOverview(
      activeEmployees: 40,
      presentToday: 37,
      pendingLeaveRequests: 0,
      attendance: [],
      leaveRequests: [],
      headcount: [],
      holidays: [],
    );
    const empty = HrOverview(
      activeEmployees: 0,
      presentToday: 0,
      pendingLeaveRequests: 0,
      attendance: [],
      leaveRequests: [],
      headcount: [],
      holidays: [],
    );

    expect(active.attendanceRate, closeTo(.925, .0001));
    expect(empty.attendanceRate, 0);
  });

  test('leave available balance never becomes negative', () {
    const balance = LeaveBalance(leaveType: 'Casual', allocated: 8, used: 7, pending: 3);
    expect(balance.available, 0);
  });

  test('attendance exceptions derive late and absent counts', () {
    const overview = AttendanceLeaveOverview(
      attendance: [
        AttendanceSummary(employeeCode: '1', employeeName: 'A', department: 'Production', shiftLabel: '09:00–18:00', checkInLabel: '09:01', checkOutLabel: '—', workedHours: 4, status: 'Present'),
        AttendanceSummary(employeeCode: '2', employeeName: 'B', department: 'Warehouse', shiftLabel: '09:00–18:00', checkInLabel: '09:18', checkOutLabel: '—', workedHours: 3.8, status: 'Late'),
        AttendanceSummary(employeeCode: '3', employeeName: 'C', department: 'Sales', shiftLabel: '09:30–18:30', checkInLabel: '—', checkOutLabel: '—', workedHours: 0, status: 'Absent'),
      ],
      leaveRequests: [],
      missingCheckoutCount: 2,
    );

    expect(overview.lateCount, 1);
    expect(overview.absentCount, 1);
  });
}
