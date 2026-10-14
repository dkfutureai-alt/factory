import '../domain/hr_models.dart';

abstract interface class HrRepository {
  Future<HrOverview> loadOverview();
  Future<EmployeeDetail> loadEmployee(String employeeCode);
  Future<AttendanceLeaveOverview> loadAttendanceLeave();
  Future<List<HolidaySummary>> loadHolidays();
}

final class PreviewHrRepository implements HrRepository {
  const PreviewHrRepository();

  static const _attendance = [
    AttendanceSummary(employeeCode: 'EMP-0018', employeeName: 'Ravi Patil', department: 'Production', shiftLabel: '09:00–18:00', checkInLabel: '09:01', checkOutLabel: '—', workedHours: 4.2, status: 'Present'),
    AttendanceSummary(employeeCode: 'EMP-0007', employeeName: 'Sneha Kulkarni', department: 'Quality Control', shiftLabel: '08:30–17:30', checkInLabel: '08:54', checkOutLabel: '—', workedHours: 4.3, status: 'Present'),
    AttendanceSummary(employeeCode: 'EMP-0024', employeeName: 'Akash More', department: 'Warehouse', shiftLabel: '09:00–18:00', checkInLabel: '09:18', checkOutLabel: '—', workedHours: 3.9, status: 'Late'),
    AttendanceSummary(employeeCode: 'EMP-0032', employeeName: 'Meera Jadhav', department: 'Sales', shiftLabel: '09:30–18:30', checkInLabel: '—', checkOutLabel: '—', workedHours: 0, status: 'Absent'),
  ];

  static const _leaveRequests = [
    LeaveRequestSummary(employeeName: 'Priya Shinde', leaveType: 'Casual', dateLabel: '18–19 Oct', days: 2, balanceAfter: 3, status: 'Pending'),
    LeaveRequestSummary(employeeName: 'Sunil Pawar', leaveType: 'Sick', dateLabel: '21 Oct', days: 1, balanceAfter: 4, status: 'Pending'),
    LeaveRequestSummary(employeeName: 'Ravi Patil', leaveType: 'Casual', dateLabel: '04 Oct', days: 1, balanceAfter: 5, status: 'Approved'),
  ];

  static const _holidays = [
    HolidaySummary(name: 'Diwali', dateLabel: '20 Oct 2026', scopeLabel: 'All Maharashtra plants', mandatory: true),
    HolidaySummary(name: 'Bhau Beej', dateLabel: '22 Oct 2026', scopeLabel: 'All Maharashtra plants', mandatory: true),
    HolidaySummary(name: 'Christmas', dateLabel: '25 Dec 2026', scopeLabel: 'All plants', mandatory: true),
    HolidaySummary(name: 'Diwali Eve', dateLabel: '19 Oct 2026', scopeLabel: 'Optional / local observance', mandatory: false),
  ];

  @override
  Future<HrOverview> loadOverview() async => const HrOverview(
        activeEmployees: 40,
        presentToday: 37,
        pendingLeaveRequests: 3,
        attendance: _attendance,
        leaveRequests: _leaveRequests,
        headcount: [
          DepartmentHeadcount(department: 'Production', count: 16),
          DepartmentHeadcount(department: 'Warehouse', count: 8),
          DepartmentHeadcount(department: 'Quality', count: 6),
          DepartmentHeadcount(department: 'Other departments', count: 10),
        ],
        holidays: _holidays,
      );

  @override
  Future<EmployeeDetail> loadEmployee(String employeeCode) async => const EmployeeDetail(
        employeeCode: 'EMP-0018',
        name: 'Ravi Patil',
        designation: 'Production Operator',
        department: 'Production',
        shiftLabel: 'Morning • 09:00–18:00',
        status: 'Active',
        maskedMobile: '+91 98••• ••210',
        joiningDateLabel: '03 Feb 2025',
        reportsTo: 'S. Kulkarni',
        workLocation: 'Pune Plant • LINE-02',
        employeeType: 'Full-time',
        grade: 'OP-2',
        presentDays: 12,
        workingDays: 13,
        lateCount: 1,
        overtimeHours: 6.5,
        todayAttendance: 'Checked in 09:01 • Mobile app',
        leaveBalances: [
          LeaveBalance(leaveType: 'Casual leave', allocated: 8, used: 3, pending: 0),
          LeaveBalance(leaveType: 'Sick leave', allocated: 6, used: 2, pending: 0),
          LeaveBalance(leaveType: 'Paid leave', allocated: 12, used: 4, pending: 0),
        ],
        lastLeaveLabel: '04 Oct 2026 • 1 day • Casual leave • Approved',
      );

  @override
  Future<AttendanceLeaveOverview> loadAttendanceLeave() async => const AttendanceLeaveOverview(
        attendance: _attendance,
        leaveRequests: _leaveRequests,
        missingCheckoutCount: 3,
      );

  @override
  Future<List<HolidaySummary>> loadHolidays() async => _holidays;
}
