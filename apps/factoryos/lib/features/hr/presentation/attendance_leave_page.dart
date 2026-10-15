import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/hr_repository.dart';
import '../domain/hr_models.dart';

class AttendanceLeavePage extends StatelessWidget {
  const AttendanceLeavePage({super.key, required this.repository});
  final HrRepository repository;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Attendance & Leave', style: TextStyle(fontWeight: FontWeight.w800)),
            Text('Workforce time, exceptions and approvals', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
          ]),
          actions: [Padding(padding: const EdgeInsets.only(right: 16), child: OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.download_outlined), label: const Text('Export report')))],
        ),
        body: FutureBuilder<AttendanceLeaveOverview>(
          future: repository.loadAttendanceLeave(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (!snapshot.hasData) return const Center(child: Text('Unable to load attendance data.'));
            final data = snapshot.requireData;
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const _FilterBar(),
                const SizedBox(height: 18),
                LayoutBuilder(builder: (context, constraints) {
                  final register = _AttendanceRegister(items: data.attendance);
                  final exceptions = _ExceptionsCard(lateCount: data.lateCount, absentCount: data.absentCount, missingCheckoutCount: data.missingCheckoutCount);
                  if (constraints.maxWidth > 930) return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 2, child: register), const SizedBox(width: 16), Expanded(child: exceptions)]);
                  return Column(children: [register, const SizedBox(height: 16), exceptions]);
                }),
                const SizedBox(height: 18),
                _LeaveRequestsCard(items: data.leaveRequests),
              ],
            );
          },
        ),
      );
}

class _FilterBar extends StatelessWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(spacing: 28, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
            const Text('14 Oct 2026', style: TextStyle(fontWeight: FontWeight.w800)),
            const Text('Main Manufacturing Plant', style: TextStyle(color: AppTheme.muted)),
            const Text('All departments', style: TextStyle(color: AppTheme.muted)),
            const Text('All shifts', style: TextStyle(color: AppTheme.muted)),
            TextButton(onPressed: () {}, child: const Text('Apply filters')),
          ]),
        ),
      );
}

class _AttendanceRegister extends StatelessWidget {
  const _AttendanceRegister({required this.items});
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
            const Text('Daily attendance register', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ...items.map((item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.employeeName, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${item.shiftLabel} • ${item.checkInLabel} / ${item.checkOutLabel} • ${item.workedHours.toStringAsFixed(1)}h'),
                  trailing: Text(item.status, style: TextStyle(color: _statusColor(item), fontWeight: FontWeight.w800)),
                )),
            const Align(alignment: Alignment.centerLeft, child: Text('View all 40 employees', style: TextStyle(color: AppTheme.brand, fontWeight: FontWeight.w800))),
          ]),
        ),
      );
}

class _ExceptionsCard extends StatelessWidget {
  const _ExceptionsCard({required this.lateCount, required this.absentCount, required this.missingCheckoutCount});
  final int lateCount;
  final int absentCount;
  final int missingCheckoutCount;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Exceptions', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            _ExceptionRow(label: 'Late arrivals', support: 'Threshold > 10 minutes', value: lateCount, color: AppTheme.warning),
            const Divider(),
            _ExceptionRow(label: 'Absent employees', support: 'No approved leave', value: absentCount, color: AppTheme.danger),
            const Divider(),
            _ExceptionRow(label: 'Missing checkout', support: 'Previous day corrections', value: missingCheckoutCount, color: AppTheme.warning),
            const SizedBox(height: 12),
            TextButton(onPressed: () {}, child: const Text('Review attendance corrections')),
          ]),
        ),
      );
}

class _ExceptionRow extends StatelessWidget {
  const _ExceptionRow({required this.label, required this.support, required this.value, required this.color});
  final String label;
  final String support;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(support),
        trailing: Text('$value', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
      );
}

class _LeaveRequestsCard extends StatelessWidget {
  const _LeaveRequestsCard({required this.items});
  final List<LeaveRequestSummary> items;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Leave requests', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ...items.map((item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.employeeName, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${item.leaveType} • ${item.dateLabel} • ${item.days.toStringAsFixed(item.days % 1 == 0 ? 0 : 1)} day${item.days == 1 ? '' : 's'} • balance ${item.balanceAfter.toStringAsFixed(0)}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(item.status, style: TextStyle(color: item.pending ? AppTheme.warning : AppTheme.success, fontWeight: FontWeight.w800)),
                    if (item.pending) ...[const SizedBox(width: 14), TextButton(onPressed: () {}, child: const Text('Review'))],
                  ]),
                )),
          ]),
        ),
      );
}
