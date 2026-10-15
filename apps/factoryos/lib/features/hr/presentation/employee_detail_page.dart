import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/hr_repository.dart';
import '../domain/hr_models.dart';

class EmployeeDetailPage extends StatelessWidget {
  const EmployeeDetailPage({super.key, required this.repository, required this.employeeCode});
  final HrRepository repository;
  final String employeeCode;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Employee Detail', style: TextStyle(fontWeight: FontWeight.w800)),
            Text('Operational HR profile', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
          ]),
          actions: [Padding(padding: const EdgeInsets.only(right: 16), child: FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.edit_outlined), label: const Text('Edit employee')))],
        ),
        body: FutureBuilder<EmployeeDetail>(
          future: repository.loadEmployee(employeeCode),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (!snapshot.hasData) return const Center(child: Text('Unable to load employee.'));
            final employee = snapshot.requireData;
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _IdentityCard(employee: employee),
                const SizedBox(height: 18),
                LayoutBuilder(builder: (context, constraints) {
                  final attendance = _AttendanceCard(employee: employee);
                  final leave = _LeaveCard(employee: employee);
                  if (constraints.maxWidth > 900) return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: attendance), const SizedBox(width: 16), Expanded(child: leave)]);
                  return Column(children: [attendance, const SizedBox(height: 16), leave]);
                }),
                const SizedBox(height: 18),
                _EmploymentCard(employee: employee),
              ],
            );
          },
        ),
      );
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.employee});
  final EmployeeDetail employee;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Wrap(
            spacing: 28,
            runSpacing: 20,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              CircleAvatar(radius: 36, backgroundColor: const Color(0xFFDCE7FB), child: Text(_initials(employee.name), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.brand))),
              SizedBox(width: 290, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(employee.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                Text('${employee.designation} • ${employee.department}', style: const TextStyle(color: AppTheme.muted)),
                const SizedBox(height: 7),
                Text(employee.status, style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.w800)),
              ])),
              _Field(label: 'MOBILE', value: employee.maskedMobile),
              _Field(label: 'JOINING DATE', value: employee.joiningDateLabel),
              _Field(label: 'REPORTS TO', value: employee.reportsTo),
              _Field(label: 'WORK LOCATION', value: employee.workLocation),
              _Field(label: 'EMPLOYEE TYPE', value: employee.employeeType),
              _Field(label: 'GRADE', value: employee.grade),
            ],
          ),
        ),
      );

  static String _initials(String name) {
    final parts = name.split(' ').where((part) => part.isNotEmpty).toList();
    return parts.take(2).map((part) => part[0]).join();
  }
}

class _AttendanceCard extends StatelessWidget {
  const _AttendanceCard({required this.employee});
  final EmployeeDetail employee;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Attendance summary', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 18),
            Wrap(spacing: 34, runSpacing: 18, children: [
              _Stat(label: 'THIS MONTH', value: '${employee.presentDays} / ${employee.workingDays}', support: 'Days present'),
              _Stat(label: 'LATE', value: '${employee.lateCount}', support: 'Late arrival', accent: AppTheme.warning),
              _Stat(label: 'OVERTIME', value: '${employee.overtimeHours}h', support: 'Approved', accent: AppTheme.brand),
            ]),
            const Divider(height: 34),
            Text('Today • ${employee.todayAttendance}', style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(employee.shiftLabel, style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
          ]),
        ),
      );
}

class _LeaveCard extends StatelessWidget {
  const _LeaveCard({required this.employee});
  final EmployeeDetail employee;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Leave balance', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 18),
            Wrap(spacing: 34, runSpacing: 18, children: employee.leaveBalances.map((balance) => _Stat(label: balance.leaveType.toUpperCase(), value: balance.available.toStringAsFixed(0), support: 'days available')).toList()),
            const Divider(height: 34),
            Text('Last leave • ${employee.lastLeaveLabel}', style: const TextStyle(fontWeight: FontWeight.w800)),
          ]),
        ),
      );
}

class _EmploymentCard extends StatelessWidget {
  const _EmploymentCard({required this.employee});
  final EmployeeDetail employee;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Employment & compliance', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 18),
            Wrap(spacing: 36, runSpacing: 20, children: [
              _Field(label: 'DEPARTMENT', value: employee.department),
              _Field(label: 'DESIGNATION', value: employee.designation),
              _Field(label: 'SHIFT', value: employee.shiftLabel),
              const _Field(label: 'WEEKLY OFF', value: 'Sunday'),
              _Field(label: 'STATUS', value: employee.status),
            ]),
            const Divider(height: 34),
            const Text('Documents', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            const Wrap(spacing: 32, runSpacing: 12, children: [
              Text('Identity proof • Verified', style: TextStyle(color: AppTheme.muted)),
              Text('Bank details • Verified', style: TextStyle(color: AppTheme.muted)),
              Text('Emergency contact • Available', style: TextStyle(color: AppTheme.muted)),
              Text('Safety training • Valid until Feb 2027', style: TextStyle(color: AppTheme.muted)),
            ]),
            const SizedBox(height: 18),
            const Text('Sensitive identity/payment values are masked in normal operational views.', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
          ]),
        ),
      );
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(width: 180, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
        const SizedBox(height: 5),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ]));
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.support, this.accent = AppTheme.text});
  final String label;
  final String value;
  final String support;
  final Color accent;

  @override
  Widget build(BuildContext context) => SizedBox(width: 130, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
        const SizedBox(height: 7),
        Text(value, style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800, color: accent)),
        const SizedBox(height: 4),
        Text(support, style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
      ]));
}
