import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/hr_repository.dart';
import '../domain/hr_models.dart';

class HrDashboardPage extends StatelessWidget {
  const HrDashboardPage({super.key, required this.repository});
  final HrRepository repository;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('HR & Workforce', style: TextStyle(fontWeight: FontWeight.w800)),
              Text('Main Manufacturing Plant • 14 Oct 2026', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
            ],
          ),
          actions: [
            TextButton.icon(onPressed: () => Navigator.of(context).pushNamed('/hr/attendance-leave'), icon: const Icon(Icons.schedule), label: const Text('Attendance & leave')),
            TextButton.icon(onPressed: () => Navigator.of(context).pushNamed('/hr/holidays'), icon: const Icon(Icons.event), label: const Text('Holidays')),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.person_add_alt_1), label: const Text('Add employee')),
            ),
          ],
        ),
        body: FutureBuilder<HrOverview>(
          future: repository.loadOverview(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (!snapshot.hasData) return const Center(child: Text('Unable to load HR data.'));
            final data = snapshot.requireData;
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    _Metric(label: 'Active employees', value: '${data.activeEmployees}', supporting: '${data.presentToday} present today'),
                    _Metric(label: 'Attendance rate', value: '${(data.attendanceRate * 100).toStringAsFixed(1)}%', supporting: 'Today across active workforce', accent: AppTheme.success),
                    _Metric(label: 'Leave requests', value: '${data.leaveRequests.length}', supporting: '${data.pendingLeaveRequests} pending approval', accent: AppTheme.warning),
                    _Metric(label: 'Late / absent', value: '${data.lateCount + data.absentCount}', supporting: '${data.lateCount} late • ${data.absentCount} absent', accent: AppTheme.danger),
                  ],
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final attendance = _AttendancePanel(items: data.attendance);
                    final approvals = _ApprovalPanel(items: data.leaveRequests);
                    if (constraints.maxWidth > 930) {
                      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 2, child: attendance), const SizedBox(width: 16), Expanded(child: approvals)]);
                    }
                    return Column(children: [attendance, const SizedBox(height: 16), approvals]);
                  },
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final departments = _HeadcountPanel(items: data.headcount);
                    final holidays = _HolidayPreview(items: data.holidays);
                    if (constraints.maxWidth > 930) {
                      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: departments), const SizedBox(width: 16), Expanded(child: holidays)]);
                    }
                    return Column(children: [departments, const SizedBox(height: 16), holidays]);
                  },
                ),
              ],
            );
          },
        ),
      );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.supporting, this.accent = AppTheme.text});
  final String label;
  final String value;
  final String supporting;
  final Color accent;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 245,
        height: 148,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(label, style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
              const SizedBox(height: 7),
              Text(value, style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800, color: accent)),
              const SizedBox(height: 4),
              Text(supporting, style: const TextStyle(color: AppTheme.muted, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ),
      );
}

class _AttendancePanel extends StatelessWidget {
  const _AttendancePanel({required this.items});
  final List<AttendanceSummary> items;

  Color _statusColor(AttendanceSummary item) {
    if (item.isAbsent) return AppTheme.danger;
    if (item.isLate) return AppTheme.warning;
    return AppTheme.success;
  }

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Today attendance', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ...items.map((item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: item.employeeCode == 'EMP-0018' ? () => Navigator.of(context).pushNamed('/hr/employee') : null,
                  title: Text(item.employeeName, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${item.department} • ${item.checkInLabel}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(item.status, style: TextStyle(color: _statusColor(item), fontWeight: FontWeight.w800)),
                    if (item.employeeCode == 'EMP-0018') const Icon(Icons.chevron_right),
                  ]),
                )),
          ]),
        ),
      );
}

class _ApprovalPanel extends StatelessWidget {
  const _ApprovalPanel({required this.items});
  final List<LeaveRequestSummary> items;

  @override
  Widget build(BuildContext context) {
    final pending = items.where((item) => item.pending).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Pending approvals', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...pending.map((item) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Leave • ${item.employeeName}', style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${item.dateLabel} • ${item.leaveType} leave'),
                trailing: const Text('Review', style: TextStyle(color: AppTheme.warning, fontWeight: FontWeight.w800)),
              )),
          const Divider(),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Attendance correction', style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('Ravi Patil • 13 Oct checkout'),
            trailing: Text('Review', style: TextStyle(color: AppTheme.warning, fontWeight: FontWeight.w800)),
          ),
        ]),
      ),
    );
  }
}

class _HeadcountPanel extends StatelessWidget {
  const _HeadcountPanel({required this.items});
  final List<DepartmentHeadcount> items;

  @override
  Widget build(BuildContext context) {
    final maxCount = items.fold<int>(1, (value, item) => item.count > value ? item.count : value);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Department headcount', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(children: [
                  SizedBox(width: 126, child: Text(item.department, style: const TextStyle(color: AppTheme.muted))),
                  Expanded(child: LinearProgressIndicator(value: item.count / maxCount, minHeight: 12, borderRadius: BorderRadius.circular(8))),
                  const SizedBox(width: 12),
                  SizedBox(width: 28, child: Text('${item.count}', style: const TextStyle(fontWeight: FontWeight.w800))),
                ]),
              )),
        ]),
      ),
    );
  }
}

class _HolidayPreview extends StatelessWidget {
  const _HolidayPreview({required this.items});
  final List<HolidaySummary> items;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Upcoming holidays & leave', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ...items.take(3).map((item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${item.dateLabel} • ${item.name}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(item.scopeLabel),
                )),
            TextButton(onPressed: () => Navigator.of(context).pushNamed('/hr/holidays'), child: const Text('Open holiday calendar')),
          ]),
        ),
      );
}
