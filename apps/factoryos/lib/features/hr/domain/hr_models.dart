class AttendanceSummary {
  const AttendanceSummary({
    required this.employeeCode,
    required this.employeeName,
    required this.department,
    required this.shiftLabel,
    required this.checkInLabel,
    required this.checkOutLabel,
    required this.workedHours,
    required this.status,
  });

  final String employeeCode;
  final String employeeName;
  final String department;
  final String shiftLabel;
  final String checkInLabel;
  final String checkOutLabel;
  final double workedHours;
  final String status;

  bool get isLate => status == 'Late';
  bool get isAbsent => status == 'Absent';
}

class LeaveRequestSummary {
  const LeaveRequestSummary({
    required this.employeeName,
    required this.leaveType,
    required this.dateLabel,
    required this.days,
    required this.balanceAfter,
    required this.status,
  });

  final String employeeName;
  final String leaveType;
  final String dateLabel;
  final double days;
  final double balanceAfter;
  final String status;

  bool get pending => status == 'Pending';
}

class DepartmentHeadcount {
  const DepartmentHeadcount({required this.department, required this.count});
  final String department;
  final int count;
}

class HolidaySummary {
  const HolidaySummary({
    required this.name,
    required this.dateLabel,
    required this.scopeLabel,
    required this.mandatory,
    this.paid = true,
  });

  final String name;
  final String dateLabel;
  final String scopeLabel;
  final bool mandatory;
  final bool paid;
}

class HrOverview {
  const HrOverview({
    required this.activeEmployees,
    required this.presentToday,
    required this.pendingLeaveRequests,
    required this.attendance,
    required this.leaveRequests,
    required this.headcount,
    required this.holidays,
  });

  final int activeEmployees;
  final int presentToday;
  final int pendingLeaveRequests;
  final List<AttendanceSummary> attendance;
  final List<LeaveRequestSummary> leaveRequests;
  final List<DepartmentHeadcount> headcount;
  final List<HolidaySummary> holidays;

  double get attendanceRate => activeEmployees == 0 ? 0 : presentToday / activeEmployees;
  int get lateCount => attendance.where((item) => item.isLate).length;
  int get absentCount => attendance.where((item) => item.isAbsent).length;
}

class LeaveBalance {
  const LeaveBalance({
    required this.leaveType,
    required this.allocated,
    required this.used,
    required this.pending,
  });

  final String leaveType;
  final double allocated;
  final double used;
  final double pending;

  double get available => (allocated - used - pending).clamp(0, double.infinity).toDouble();
}

class EmployeeDetail {
  const EmployeeDetail({
    required this.employeeCode,
    required this.name,
    required this.designation,
    required this.department,
    required this.shiftLabel,
    required this.status,
    required this.maskedMobile,
    required this.joiningDateLabel,
    required this.reportsTo,
    required this.workLocation,
    required this.employeeType,
    required this.grade,
    required this.presentDays,
    required this.workingDays,
    required this.lateCount,
    required this.overtimeHours,
    required this.todayAttendance,
    required this.leaveBalances,
    required this.lastLeaveLabel,
  });

  final String employeeCode;
  final String name;
  final String designation;
  final String department;
  final String shiftLabel;
  final String status;
  final String maskedMobile;
  final String joiningDateLabel;
  final String reportsTo;
  final String workLocation;
  final String employeeType;
  final String grade;
  final int presentDays;
  final int workingDays;
  final int lateCount;
  final double overtimeHours;
  final String todayAttendance;
  final List<LeaveBalance> leaveBalances;
  final String lastLeaveLabel;

  double get attendanceRate => workingDays == 0 ? 0 : presentDays / workingDays;
}

class AttendanceLeaveOverview {
  const AttendanceLeaveOverview({
    required this.attendance,
    required this.leaveRequests,
    required this.missingCheckoutCount,
  });

  final List<AttendanceSummary> attendance;
  final List<LeaveRequestSummary> leaveRequests;
  final int missingCheckoutCount;

  int get lateCount => attendance.where((item) => item.isLate).length;
  int get absentCount => attendance.where((item) => item.isAbsent).length;
}
