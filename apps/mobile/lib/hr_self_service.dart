import 'package:factoryos_core/factoryos_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HrSelfServicePage extends StatefulWidget {
  const HrSelfServicePage({super.key});

  @override
  State<HrSelfServicePage> createState() => _HrSelfServicePageState();
}

class _HrSelfServicePageState extends State<HrSelfServicePage> {
  late Future<SelfHrSnapshot> future;
  bool actionBusy = false;

  @override
  void initState() {
    super.initState();
    future = SelfHrRepository(Supabase.instance.client).load();
  }

  void reload() => setState(() => future = SelfHrRepository(Supabase.instance.client).load());

  void message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: error ? Theme.of(context).colorScheme.error : null),
    );
  }

  Future<void> mark(String action) async {
    if (actionBusy) return;
    setState(() => actionBusy = true);
    try {
      await Supabase.instance.client.rpc('mark_my_attendance', params: {'p_action': action});
      if (!mounted) return;
      message(action == 'check_in' ? 'Checked in successfully.' : 'Checked out successfully.');
      reload();
    } catch (e) {
      if (mounted) message(_errorText(e), error: true);
    } finally {
      if (mounted) setState(() => actionBusy = false);
    }
  }

  Future<void> requestLeave(SelfHrSnapshot data) async {
    if (data.leaveTypes.isEmpty) {
      message('No leave types are configured.', error: true);
      return;
    }
    final draft = await showDialog<LeaveDraft>(
      context: context,
      builder: (_) => LeaveRequestDialog(leaveTypes: data.leaveTypes),
    );
    if (draft == null || !mounted) return;
    try {
      await Supabase.instance.client.rpc('request_my_leave', params: {
        'p_leave_type_id': draft.leaveTypeId,
        'p_start_date': _date(draft.startDate),
        'p_end_date': _date(draft.endDate),
        'p_reason': draft.reason,
      });
      if (!mounted) return;
      message('Leave request submitted.');
      reload();
    } catch (e) {
      if (mounted) message(_errorText(e), error: true);
    }
  }

  Future<void> cancelLeave(String id) async {
    try {
      await Supabase.instance.client.rpc('cancel_my_leave', params: {'p_request_id': id});
      if (!mounted) return;
      message('Leave request cancelled.');
      reload();
    } catch (e) {
      if (mounted) message(_errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('HR & Attendance')),
        body: FutureBuilder<SelfHrSnapshot>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError) return _ErrorState(message: '${snapshot.error}', onRetry: reload);
            final data = snapshot.requireData;
            if (data.employee == null) {
              return _NoEmployee(onRetry: reload);
            }
            return RefreshIndicator(
              onRefresh: () async => reload(),
              child: ListView(
                padding: const EdgeInsets.all(FactorySpacing.md),
                children: [
                  _ProfileCard(employee: data.employee!),
                  const SizedBox(height: FactorySpacing.md),
                  _AttendanceCard(attendance: data.todayAttendance, busy: actionBusy, onCheckIn: () => mark('check_in'), onCheckOut: () => mark('check_out')),
                  const SizedBox(height: FactorySpacing.md),
                  Row(children: [Expanded(child: Text('Leave', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))), FilledButton.icon(onPressed: () => requestLeave(data), icon: const Icon(Icons.add), label: const Text('Request'))]),
                  const SizedBox(height: FactorySpacing.sm),
                  if (data.leaveRequests.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(FactorySpacing.md), child: Text('No leave requests yet.'))),
                  ...data.leaveRequests.take(8).map((row) => Card(child: ListTile(
                        leading: Icon(_leaveIcon(row['status'] as String? ?? 'pending')),
                        title: Text('${data.leaveTypeName(row['leave_type_id'] as String?)} · ${_title(row['status'] as String? ?? '')}'),
                        subtitle: Text('${row['start_date']} → ${row['end_date']} · ${row['requested_days']} day(s)${row['reason'] == null ? '' : '\n${row['reason']}'}'),
                        isThreeLine: row['reason'] != null,
                        trailing: row['status'] == 'pending' ? TextButton(onPressed: () => cancelLeave(row['id'] as String), child: const Text('Cancel')) : null,
                      ))),
                  const SizedBox(height: FactorySpacing.md),
                  Text('Upcoming holidays', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: FactorySpacing.sm),
                  if (data.holidays.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(FactorySpacing.md), child: Text('No upcoming holidays.'))),
                  ...data.holidays.take(8).map((row) => Card(child: ListTile(leading: const Icon(Icons.celebration_outlined), title: Text(row['name'] as String), subtitle: Text('${row['holiday_date']} · ${_title(row['holiday_type'] as String? ?? '')}')))),
                  const SizedBox(height: FactorySpacing.lg),
                  Text('Recent attendance', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: FactorySpacing.sm),
                  ...data.recentAttendance.take(14).map((row) => Card(child: ListTile(
                        leading: Icon(_attendanceIcon(row['status'] as String? ?? 'absent')),
                        title: Text('${row['work_date']} · ${_title(row['status'] as String? ?? '')}'),
                        subtitle: Text(_attendanceTimes(row)),
                        trailing: row['worked_minutes'] == null ? null : Text('${row['worked_minutes']} min'),
                      ))),
                ],
              ),
            );
          },
        ),
      );
}

class SelfHrRepository {
  SelfHrRepository(this.client);
  final SupabaseClient client;

  Future<SelfHrSnapshot> load() async {
    final employeeRaw = await client.rpc('my_employee_record');
    final employeeRows = employeeRaw as List<dynamic>;
    if (employeeRows.isEmpty) return const SelfHrSnapshot();
    final employee = Map<String, dynamic>.from(employeeRows.first as Map);
    final employeeId = employee['employee_id'] as String;
    final orgId = employee['organization_id'] as String;
    final factoryId = employee['factory_id'] as String;
    final today = _date(DateTime.now());

    final attendance = await client
        .from('attendance_records')
        .select()
        .eq('employee_id', employeeId)
        .order('work_date', ascending: false)
        .limit(31);
    final leaveTypes = await client.from('leave_types').select().eq('organization_id', orgId).eq('is_active', true).order('name');
    final leaveRequests = await client.from('leave_requests').select().eq('employee_id', employeeId).order('created_at', ascending: false).limit(30);
    final holidays = await client
        .from('holidays')
        .select()
        .eq('organization_id', orgId)
        .eq('is_active', true)
        .gte('holiday_date', today)
        .or('factory_id.is.null,factory_id.eq.$factoryId')
        .order('holiday_date')
        .limit(20);

    final attendanceRows = List<Map<String, dynamic>>.from(attendance);
    Map<String, dynamic>? todayAttendance;
    for (final row in attendanceRows) {
      if (row['work_date'] == today) {
        todayAttendance = row;
        break;
      }
    }
    return SelfHrSnapshot(
      employee: employee,
      todayAttendance: todayAttendance,
      recentAttendance: attendanceRows,
      leaveTypes: List<Map<String, dynamic>>.from(leaveTypes),
      leaveRequests: List<Map<String, dynamic>>.from(leaveRequests),
      holidays: List<Map<String, dynamic>>.from(holidays),
    );
  }
}

class SelfHrSnapshot {
  const SelfHrSnapshot({this.employee, this.todayAttendance, this.recentAttendance = const [], this.leaveTypes = const [], this.leaveRequests = const [], this.holidays = const []});
  final Map<String, dynamic>? employee;
  final Map<String, dynamic>? todayAttendance;
  final List<Map<String, dynamic>> recentAttendance;
  final List<Map<String, dynamic>> leaveTypes;
  final List<Map<String, dynamic>> leaveRequests;
  final List<Map<String, dynamic>> holidays;

  String leaveTypeName(String? id) => leaveTypes.where((row) => row['id'] == id).map((row) => row['name'] as String).firstOrNull ?? 'Leave';
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.employee});
  final Map<String, dynamic> employee;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(FactorySpacing.md),
          child: Row(children: [
            CircleAvatar(radius: 28, child: Text(_initials(employee['full_name'] as String? ?? 'E'))),
            const SizedBox(width: FactorySpacing.md),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(employee['full_name'] as String, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              Text('${employee['employee_code']} · ${employee['factory_name']}'),
              Text([employee['department_name'], employee['designation_name'], employee['shift_name']].where((e) => e != null && '$e'.isNotEmpty).join(' · ')),
            ])),
          ]),
        ),
      );
}

class _AttendanceCard extends StatelessWidget {
  const _AttendanceCard({required this.attendance, required this.busy, required this.onCheckIn, required this.onCheckOut});
  final Map<String, dynamic>? attendance;
  final bool busy;
  final VoidCallback onCheckIn;
  final VoidCallback onCheckOut;

  @override
  Widget build(BuildContext context) {
    final checkedIn = attendance?['check_in_at'] != null;
    final checkedOut = attendance?['check_out_at'] != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(FactorySpacing.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [const Icon(Icons.how_to_reg_outlined, color: FactoryColors.blue), const SizedBox(width: FactorySpacing.sm), Text('Today’s attendance', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))]),
          const SizedBox(height: FactorySpacing.sm),
          Text(attendance == null ? 'Not checked in yet' : _title(attendance!['status'] as String? ?? 'present')),
          if (checkedIn) Text('Check in: ${_clock(attendance!['check_in_at'])}'),
          if (checkedOut) Text('Check out: ${_clock(attendance!['check_out_at'])}'),
          if ((attendance?['late_minutes'] as int? ?? 0) > 0) Text('${attendance!['late_minutes']} min late'),
          const SizedBox(height: FactorySpacing.md),
          if (!checkedIn) FilledButton.icon(onPressed: busy ? null : onCheckIn, icon: const Icon(Icons.login), label: Text(busy ? 'Saving…' : 'Check in')),
          if (checkedIn && !checkedOut) FilledButton.icon(onPressed: busy ? null : onCheckOut, icon: const Icon(Icons.logout), label: Text(busy ? 'Saving…' : 'Check out')),
          if (checkedOut) const Row(children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: FactorySpacing.xs), Text('Attendance completed for today')]),
        ]),
      ),
    );
  }
}

class LeaveRequestDialog extends StatefulWidget {
  const LeaveRequestDialog({required this.leaveTypes, super.key});
  final List<Map<String, dynamic>> leaveTypes;
  @override
  State<LeaveRequestDialog> createState() => _LeaveRequestDialogState();
}

class _LeaveRequestDialogState extends State<LeaveRequestDialog> {
  late String leaveTypeId = widget.leaveTypes.first['id'] as String;
  DateTime start = DateTime.now().add(const Duration(days: 1));
  DateTime end = DateTime.now().add(const Duration(days: 1));
  final reason = TextEditingController();

  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  Future<void> pickStart() async {
    final value = await showDatePicker(context: context, initialDate: start, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 730)));
    if (value == null) return;
    setState(() {
      start = value;
      if (end.isBefore(start)) end = start;
    });
  }

  Future<void> pickEnd() async {
    final value = await showDatePicker(context: context, initialDate: end, firstDate: start, lastDate: DateTime.now().add(const Duration(days: 730)));
    if (value != null) setState(() => end = value);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Request leave'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(initialValue: leaveTypeId, decoration: const InputDecoration(labelText: 'Leave type'), items: widget.leaveTypes.map((row) => DropdownMenuItem(value: row['id'] as String, child: Text(row['name'] as String))).toList(), onChanged: (value) => setState(() => leaveTypeId = value ?? leaveTypeId)),
            const SizedBox(height: FactorySpacing.sm),
            ListTile(contentPadding: EdgeInsets.zero, title: const Text('From'), subtitle: Text(_date(start)), trailing: const Icon(Icons.calendar_month), onTap: pickStart),
            ListTile(contentPadding: EdgeInsets.zero, title: const Text('To'), subtitle: Text(_date(end)), trailing: const Icon(Icons.calendar_month), onTap: pickEnd),
            TextField(controller: reason, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Reason (optional)')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, LeaveDraft(leaveTypeId: leaveTypeId, startDate: start, endDate: end, reason: reason.text.trim())), child: const Text('Submit')),
        ],
      );
}

class LeaveDraft {
  const LeaveDraft({required this.leaveTypeId, required this.startDate, required this.endDate, required this.reason});
  final String leaveTypeId;
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
}

class _NoEmployee extends StatelessWidget {
  const _NoEmployee({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(FactorySpacing.lg), child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.badge_outlined, size: 56),
        const SizedBox(height: FactorySpacing.md),
        Text('Employee profile not linked', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: FactorySpacing.xs),
        const Text('Ask your factory administrator to link your FactoryOS user to your employee record.', textAlign: TextAlign.center),
        const SizedBox(height: FactorySpacing.md),
        OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
      ])));
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(FactorySpacing.lg), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.error_outline, size: 48), const SizedBox(height: FactorySpacing.md), Text(message, textAlign: TextAlign.center), const SizedBox(height: FactorySpacing.md), OutlinedButton(onPressed: onRetry, child: const Text('Retry'))])));
}

String _date(DateTime value) => '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
String _title(String value) => value.replaceAll('_', ' ').split(' ').where((part) => part.isNotEmpty).map((part) => '${part[0].toUpperCase()}${part.substring(1)}').join(' ');
String _initials(String value) { final parts = value.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList(); return parts.isEmpty ? 'E' : parts.take(2).map((e) => e[0].toUpperCase()).join(); }
IconData _leaveIcon(String value) => switch (value) {'approved' => Icons.check_circle_outline, 'rejected' => Icons.cancel_outlined, 'cancelled' => Icons.block_outlined, _ => Icons.pending_actions_outlined};
IconData _attendanceIcon(String value) => switch (value) {'present' => Icons.check_circle_outline, 'on_leave' => Icons.event_busy_outlined, 'half_day' => Icons.timelapse_outlined, _ => Icons.person_off_outlined};
String _attendanceTimes(Map<String, dynamic> row) { final input = row['check_in_at']; final output = row['check_out_at']; if (input == null && output == null) return 'No check-in/out time'; return 'In ${_clock(input)}${output == null ? '' : ' · Out ${_clock(output)}'}'; }
String _clock(dynamic value) { if (value == null) return '—'; final parsed = DateTime.tryParse('$value')?.toLocal(); if (parsed == null) return '$value'; final h = parsed.hour.toString().padLeft(2, '0'); final m = parsed.minute.toString().padLeft(2, '0'); return '$h:$m'; }
String _errorText(Object error) { if (error is PostgrestException) return error.message; return '$error'; }
