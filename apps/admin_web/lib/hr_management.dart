import 'package:factoryos_core/factoryos_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HrManagementPage extends StatefulWidget {
  const HrManagementPage({
    required this.organizationId,
    required this.actorRole,
    required this.factories,
    super.key,
  });

  final String organizationId;
  final AppRole actorRole;
  final List<Map<String, dynamic>> factories;

  @override
  State<HrManagementPage> createState() => _HrManagementPageState();
}

class _HrManagementPageState extends State<HrManagementPage> {
  int section = 0;
  late Future<HrSnapshot> future;

  HrRepository get repository => HrRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    future = repository.load(widget.organizationId);
  }

  void reload() => setState(() => future = repository.load(widget.organizationId));

  void message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: error ? Theme.of(context).colorScheme.error : null),
    );
  }

  Future<void> editEmployee(HrSnapshot data, [Map<String, dynamic>? initial]) async {
    final draft = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => EmployeeEditor(snapshot: data, factories: widget.factories, initial: initial),
    );
    if (draft == null || !mounted) return;
    try {
      if (initial == null) {
        await repository.createEmployee(widget.organizationId, draft);
      } else {
        await repository.updateEmployee(initial['id'] as String, draft);
      }
      if (!mounted) return;
      message(initial == null ? 'Employee added.' : 'Employee updated.');
      reload();
    } catch (e) {
      if (mounted) message(_errorText(e), error: true);
    }
  }

  Future<void> setEmployeeStatus(Map<String, dynamic> employee, String status) async {
    try {
      await repository.updateEmployee(employee['id'] as String, {'status': status});
      if (!mounted) return;
      message(status == 'active' ? 'Employee activated.' : 'Employee deactivated.');
      reload();
    } catch (e) {
      if (mounted) message(_errorText(e), error: true);
    }
  }

  Future<void> markAttendance(Map<String, dynamic> employee, String status) async {
    try {
      await repository.markAttendance(widget.organizationId, employee, status);
      if (!mounted) return;
      message('Attendance marked $status.');
      reload();
    } catch (e) {
      if (mounted) message(_errorText(e), error: true);
    }
  }

  Future<void> decideLeave(Map<String, dynamic> request, String decision) async {
    try {
      await repository.decideLeave(request['id'] as String, decision);
      if (!mounted) return;
      message('Leave $decision.');
      reload();
    } catch (e) {
      if (mounted) message(_errorText(e), error: true);
    }
  }

  Future<void> addDepartment(HrSnapshot data, [Map<String, dynamic>? initial]) async {
    final result = await _nameCodeDialog(context, title: initial == null ? 'Add department' : 'Edit department', initial: initial);
    if (result == null) return;
    try {
      await repository.saveDepartment(widget.organizationId, result, id: initial?['id'] as String?);
      reload();
    } catch (e) {
      if (mounted) message(_errorText(e), error: true);
    }
  }

  Future<void> addDesignation(HrSnapshot data, [Map<String, dynamic>? initial]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => DesignationEditor(departments: data.departments, initial: initial),
    );
    if (result == null) return;
    try {
      await repository.saveDesignation(widget.organizationId, result, id: initial?['id'] as String?);
      reload();
    } catch (e) {
      if (mounted) message(_errorText(e), error: true);
    }
  }

  Future<void> addShift(HrSnapshot data, [Map<String, dynamic>? initial]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => ShiftEditor(factories: widget.factories, initial: initial),
    );
    if (result == null) return;
    try {
      await repository.saveShift(widget.organizationId, result, id: initial?['id'] as String?);
      reload();
    } catch (e) {
      if (mounted) message(_errorText(e), error: true);
    }
  }

  Future<void> addLeaveType(HrSnapshot data, [Map<String, dynamic>? initial]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => LeaveTypeEditor(initial: initial),
    );
    if (result == null) return;
    try {
      await repository.saveLeaveType(widget.organizationId, result, id: initial?['id'] as String?);
      reload();
    } catch (e) {
      if (mounted) message(_errorText(e), error: true);
    }
  }

  Future<void> addHoliday(HrSnapshot data, [Map<String, dynamic>? initial]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => HolidayEditor(factories: widget.factories, initial: initial),
    );
    if (result == null) return;
    try {
      await repository.saveHoliday(widget.organizationId, result, id: initial?['id'] as String?);
      reload();
    } catch (e) {
      if (mounted) message(_errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<HrSnapshot>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return _ErrorState(message: '${snapshot.error}', onRetry: reload);
          final data = snapshot.requireData;
          final sections = <_HrSection>[
            _HrSection('Dashboard', Icons.dashboard_outlined, _Dashboard(snapshot: data)),
            _HrSection('Employees', Icons.badge_outlined, _Employees(snapshot: data, onEdit: (row) => editEmployee(data, row), onAdd: () => editEmployee(data), onStatus: setEmployeeStatus)),
            _HrSection('Attendance', Icons.how_to_reg_outlined, _Attendance(snapshot: data, onMark: markAttendance)),
            _HrSection('Leave', Icons.event_busy_outlined, _Leave(snapshot: data, onDecision: decideLeave)),
            _HrSection('Masters', Icons.account_tree_outlined, _Masters(snapshot: data, canEditOrgMasters: widget.actorRole.canManageOrganizationSetup, onDepartment: (row) => addDepartment(data, row), onDesignation: (row) => addDesignation(data, row), onShift: (row) => addShift(data, row), onLeaveType: (row) => addLeaveType(data, row))),
            _HrSection('Holidays', Icons.celebration_outlined, _Holidays(snapshot: data, onEdit: (row) => addHoliday(data, row), onAdd: () => addHoliday(data))),
            _HrSection('Reports', Icons.analytics_outlined, HrReports(organizationId: widget.organizationId, factories: widget.factories)),
          ];
          if (section >= sections.length) section = 0;
          final narrow = MediaQuery.sizeOf(context).width < 900;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(FactorySpacing.lg, FactorySpacing.lg, FactorySpacing.lg, 0),
                child: Row(
                  children: [
                    const Icon(Icons.groups_2_outlined, color: FactoryColors.blue),
                    const SizedBox(width: FactorySpacing.sm),
                    Expanded(child: Text('HR & Employees', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900))),
                    IconButton(tooltip: 'Refresh', onPressed: reload, icon: const Icon(Icons.refresh)),
                  ],
                ),
              ),
              SizedBox(
                height: 56,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: FactorySpacing.lg, vertical: FactorySpacing.sm),
                  scrollDirection: Axis.horizontal,
                  itemCount: sections.length,
                  separatorBuilder: (_, __) => const SizedBox(width: FactorySpacing.xs),
                  itemBuilder: (context, i) => ChoiceChip(
                    selected: section == i,
                    avatar: Icon(sections[i].icon, size: 18),
                    label: Text(narrow ? sections[i].label : sections[i].label),
                    onSelected: (_) => setState(() => section = i),
                  ),
                ),
              ),
              Expanded(child: sections[section].page),
            ],
          );
        },
      );
}

class HrRepository {
  HrRepository(this.client);
  final SupabaseClient client;

  Future<HrSnapshot> load(String organizationId) async {
    final summaryRaw = await client.rpc('hr_dashboard_summary', params: {
      'p_organization_id': organizationId,
      'p_factory_id': null,
      'p_work_date': _date(DateTime.now()),
    });
    final departments = await client.from('departments').select().eq('organization_id', organizationId).eq('is_active', true).order('name');
    final designations = await client.from('designations').select().eq('organization_id', organizationId).eq('is_active', true).order('name');
    final shifts = await client.from('shifts').select().eq('organization_id', organizationId).eq('is_active', true).order('name');
    final employees = await client.from('employees').select().eq('organization_id', organizationId).order('full_name');
    final leaveTypes = await client.from('leave_types').select().eq('organization_id', organizationId).eq('is_active', true).order('name');
    final leaveRequests = await client.from('leave_requests').select().eq('organization_id', organizationId).order('created_at', ascending: false).limit(80);
    final holidays = await client.from('holidays').select().eq('organization_id', organizationId).eq('is_active', true).order('holiday_date');
    final attendance = await client.from('attendance_records').select().eq('organization_id', organizationId).order('work_date', ascending: false).limit(120);
    List<Map<String, dynamic>> members = const [];
    try {
      final raw = await client.rpc('list_organization_members', params: {'p_organization_id': organizationId});
      members = (raw as List<dynamic>).map((row) => Map<String, dynamic>.from(row as Map)).toList();
    } catch (_) {
      // Factory managers are intentionally not allowed to list organization-wide access.
    }
    return HrSnapshot(
      summary: Map<String, dynamic>.from(summaryRaw as Map),
      departments: List<Map<String, dynamic>>.from(departments),
      designations: List<Map<String, dynamic>>.from(designations),
      shifts: List<Map<String, dynamic>>.from(shifts),
      employees: List<Map<String, dynamic>>.from(employees),
      leaveTypes: List<Map<String, dynamic>>.from(leaveTypes),
      leaveRequests: List<Map<String, dynamic>>.from(leaveRequests),
      holidays: List<Map<String, dynamic>>.from(holidays),
      attendance: List<Map<String, dynamic>>.from(attendance),
      members: members,
    );
  }

  Future<void> createEmployee(String organizationId, Map<String, dynamic> values) async {
    await client.from('employees').insert({'organization_id': organizationId, ...values});
  }

  Future<void> updateEmployee(String id, Map<String, dynamic> values) async {
    await client.from('employees').update(values).eq('id', id);
  }

  Future<void> markAttendance(String organizationId, Map<String, dynamic> employee, String status) async {
    final now = DateTime.now();
    final body = <String, dynamic>{
      'organization_id': organizationId,
      'factory_id': employee['primary_factory_id'],
      'employee_id': employee['id'],
      'shift_id': employee['shift_id'],
      'work_date': _date(now),
      'status': status,
      'source': 'admin',
      'updated_by': client.auth.currentUser?.id,
      if (status == 'present') 'check_in_at': now.toUtc().toIso8601String(),
      if (status == 'present') 'created_by': client.auth.currentUser?.id,
    };
    await client.from('attendance_records').upsert(body, onConflict: 'employee_id,work_date');
  }

  Future<void> decideLeave(String id, String decision) async {
    await client.rpc('decide_leave_request', params: {'p_request_id': id, 'p_decision': decision, 'p_note': null});
  }

  Future<void> saveDepartment(String orgId, Map<String, dynamic> values, {String? id}) async {
    if (id == null) {
      await client.from('departments').insert({'organization_id': orgId, ...values});
    } else {
      await client.from('departments').update(values).eq('id', id);
    }
  }

  Future<void> saveDesignation(String orgId, Map<String, dynamic> values, {String? id}) async {
    if (id == null) {
      await client.from('designations').insert({'organization_id': orgId, ...values});
    } else {
      await client.from('designations').update(values).eq('id', id);
    }
  }

  Future<void> saveShift(String orgId, Map<String, dynamic> values, {String? id}) async {
    if (id == null) {
      await client.from('shifts').insert({'organization_id': orgId, ...values});
    } else {
      await client.from('shifts').update(values).eq('id', id);
    }
  }

  Future<void> saveLeaveType(String orgId, Map<String, dynamic> values, {String? id}) async {
    if (id == null) {
      await client.from('leave_types').insert({'organization_id': orgId, ...values});
    } else {
      await client.from('leave_types').update(values).eq('id', id);
    }
  }

  Future<void> saveHoliday(String orgId, Map<String, dynamic> values, {String? id}) async {
    if (id == null) {
      await client.from('holidays').insert({'organization_id': orgId, ...values});
    } else {
      await client.from('holidays').update(values).eq('id', id);
    }
  }
}

class HrSnapshot {
  const HrSnapshot({required this.summary, required this.departments, required this.designations, required this.shifts, required this.employees, required this.leaveTypes, required this.leaveRequests, required this.holidays, required this.attendance, required this.members});
  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> departments;
  final List<Map<String, dynamic>> designations;
  final List<Map<String, dynamic>> shifts;
  final List<Map<String, dynamic>> employees;
  final List<Map<String, dynamic>> leaveTypes;
  final List<Map<String, dynamic>> leaveRequests;
  final List<Map<String, dynamic>> holidays;
  final List<Map<String, dynamic>> attendance;
  final List<Map<String, dynamic>> members;

  String employeeName(String? id) => employees.where((e) => e['id'] == id).map((e) => e['full_name'] as String).firstOrNull ?? 'Unknown employee';
  String departmentName(String? id) => departments.where((e) => e['id'] == id).map((e) => e['name'] as String).firstOrNull ?? '—';
  String designationName(String? id) => designations.where((e) => e['id'] == id).map((e) => e['name'] as String).firstOrNull ?? '—';
  String shiftName(String? id) => shifts.where((e) => e['id'] == id).map((e) => e['name'] as String).firstOrNull ?? '—';
  String leaveTypeName(String? id) => leaveTypes.where((e) => e['id'] == id).map((e) => e['name'] as String).firstOrNull ?? 'Leave';
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.snapshot});
  final HrSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final s = snapshot.summary;
    return ListView(
      padding: const EdgeInsets.all(FactorySpacing.lg),
      children: [
        Wrap(
          spacing: FactorySpacing.md,
          runSpacing: FactorySpacing.md,
          children: [
            _Metric('Employees', '${s['employees'] ?? 0}', Icons.groups_outlined),
            _Metric('Present today', '${s['present'] ?? 0}', Icons.check_circle_outline),
            _Metric('Absent', '${s['absent'] ?? 0}', Icons.person_off_outlined),
            _Metric('On leave', '${s['on_leave'] ?? 0}', Icons.event_busy_outlined),
            _Metric('Pending leave', '${s['pending_leave'] ?? 0}', Icons.pending_actions_outlined),
            _Metric('Late today', '${s['late'] ?? 0}', Icons.schedule_outlined),
          ],
        ),
        const SizedBox(height: FactorySpacing.xl),
        Text('Recent attendance', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: FactorySpacing.sm),
        ...snapshot.attendance.take(8).map((row) => Card(child: ListTile(
              leading: Icon(_attendanceIcon(row['status'] as String? ?? 'absent')),
              title: Text(snapshot.employeeName(row['employee_id'] as String?)),
              subtitle: Text('${row['work_date']} · ${_title(row['status'] as String? ?? '')}'),
              trailing: Text(row['late_minutes'] == null || row['late_minutes'] == 0 ? '' : '${row['late_minutes']} min late'),
            ))),
      ],
    );
  }
}

class _Employees extends StatelessWidget {
  const _Employees({required this.snapshot, required this.onEdit, required this.onAdd, required this.onStatus});
  final HrSnapshot snapshot;
  final ValueChanged<Map<String, dynamic>> onEdit;
  final VoidCallback onAdd;
  final void Function(Map<String, dynamic>, String) onStatus;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(FactorySpacing.lg),
        children: [
          Row(children: [Expanded(child: Text('Employees', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))), FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.person_add_alt_1), label: const Text('Add employee'))]),
          const SizedBox(height: FactorySpacing.md),
          ...snapshot.employees.map((employee) {
            final active = employee['status'] == 'active';
            return Card(
              child: ListTile(
                leading: CircleAvatar(child: Text(_initials(employee['full_name'] as String? ?? 'E'))),
                title: Text(employee['full_name'] as String),
                subtitle: Text([
                  employee['employee_code'],
                  snapshot.departmentName(employee['department_id'] as String?),
                  snapshot.designationName(employee['designation_id'] as String?),
                  snapshot.shiftName(employee['shift_id'] as String?),
                  _title(employee['status'] as String? ?? ''),
                ].whereType<String>().join(' · ')),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) => value == 'edit' ? onEdit(employee) : onStatus(employee, active ? 'inactive' : 'active'),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit employee')),
                    PopupMenuItem(value: 'status', child: Text(active ? 'Deactivate' : 'Activate')),
                  ],
                ),
              ),
            );
          }),
        ],
      );
}

class _Attendance extends StatelessWidget {
  const _Attendance({required this.snapshot, required this.onMark});
  final HrSnapshot snapshot;
  final void Function(Map<String, dynamic>, String) onMark;

  @override
  Widget build(BuildContext context) {
    final today = _date(DateTime.now());
    final rows = {for (final row in snapshot.attendance.where((r) => r['work_date'] == today)) row['employee_id']: row};
    return ListView(
      padding: const EdgeInsets.all(FactorySpacing.lg),
      children: [
        Text('Attendance · $today', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: FactorySpacing.md),
        ...snapshot.employees.where((e) => e['status'] == 'active').map((employee) {
          final row = rows[employee['id']];
          final status = row?['status'] as String? ?? 'not_marked';
          return Card(child: ListTile(
            title: Text(employee['full_name'] as String),
            subtitle: Text('${employee['employee_code']} · ${snapshot.shiftName(employee['shift_id'] as String?)} · ${_title(status)}'),
            trailing: Wrap(spacing: FactorySpacing.xs, children: [
              IconButton(tooltip: 'Present', onPressed: () => onMark(employee, 'present'), icon: const Icon(Icons.check_circle_outline)),
              IconButton(tooltip: 'Absent', onPressed: () => onMark(employee, 'absent'), icon: const Icon(Icons.person_off_outlined)),
              IconButton(tooltip: 'Half day', onPressed: () => onMark(employee, 'half_day'), icon: const Icon(Icons.timelapse_outlined)),
            ]),
          ));
        }),
      ],
    );
  }
}

class _Leave extends StatelessWidget {
  const _Leave({required this.snapshot, required this.onDecision});
  final HrSnapshot snapshot;
  final void Function(Map<String, dynamic>, String) onDecision;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(FactorySpacing.lg),
        children: [
          Text('Leave requests', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: FactorySpacing.md),
          if (snapshot.leaveRequests.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(FactorySpacing.lg), child: Text('No leave requests.'))),
          ...snapshot.leaveRequests.map((request) {
            final pending = request['status'] == 'pending';
            return Card(child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.event_note_outlined)),
              title: Text(snapshot.employeeName(request['employee_id'] as String?)),
              subtitle: Text('${snapshot.leaveTypeName(request['leave_type_id'] as String?)} · ${request['start_date']} → ${request['end_date']} · ${request['requested_days']} day(s) · ${_title(request['status'] as String? ?? '')}${request['reason'] == null ? '' : '\n${request['reason']}'}'),
              isThreeLine: request['reason'] != null,
              trailing: pending ? Wrap(spacing: FactorySpacing.xs, children: [IconButton(tooltip: 'Approve', onPressed: () => onDecision(request, 'approved'), icon: const Icon(Icons.check_circle_outline)), IconButton(tooltip: 'Reject', onPressed: () => onDecision(request, 'rejected'), icon: const Icon(Icons.cancel_outlined))]) : null,
            ));
          }),
        ],
      );
}

class _Masters extends StatelessWidget {
  const _Masters({required this.snapshot, required this.canEditOrgMasters, required this.onDepartment, required this.onDesignation, required this.onShift, required this.onLeaveType});
  final HrSnapshot snapshot;
  final bool canEditOrgMasters;
  final ValueChanged<Map<String, dynamic>?> onDepartment;
  final ValueChanged<Map<String, dynamic>?> onDesignation;
  final ValueChanged<Map<String, dynamic>?> onShift;
  final ValueChanged<Map<String, dynamic>?> onLeaveType;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(FactorySpacing.lg),
        children: [
          _MasterCard(title: 'Departments', rows: snapshot.departments, canAdd: canEditOrgMasters, onAdd: () => onDepartment(null), onEdit: canEditOrgMasters ? (row) => onDepartment(row) : null),
          _MasterCard(title: 'Designations', rows: snapshot.designations, canAdd: canEditOrgMasters, onAdd: () => onDesignation(null), onEdit: canEditOrgMasters ? (row) => onDesignation(row) : null),
          _MasterCard(title: 'Shifts', rows: snapshot.shifts, canAdd: true, onAdd: () => onShift(null), onEdit: (row) => onShift(row), subtitle: (row) => '${row['code']} · ${row['start_time']}–${row['end_time']}'),
          _MasterCard(title: 'Leave types', rows: snapshot.leaveTypes, canAdd: canEditOrgMasters, onAdd: () => onLeaveType(null), onEdit: canEditOrgMasters ? (row) => onLeaveType(row) : null, subtitle: (row) => '${row['code']} · ${row['is_paid'] == true ? 'Paid' : 'Unpaid'}'),
        ],
      );
}

class _MasterCard extends StatelessWidget {
  const _MasterCard({required this.title, required this.rows, required this.canAdd, required this.onAdd, this.onEdit, this.subtitle});
  final String title;
  final List<Map<String, dynamic>> rows;
  final bool canAdd;
  final VoidCallback onAdd;
  final ValueChanged<Map<String, dynamic>>? onEdit;
  final String Function(Map<String, dynamic>)? subtitle;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: FactorySpacing.lg),
        child: Padding(
          padding: const EdgeInsets.all(FactorySpacing.md),
          child: Column(children: [
            Row(children: [Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))), if (canAdd) IconButton(onPressed: onAdd, icon: const Icon(Icons.add_circle_outline))]),
            const Divider(),
            if (rows.isEmpty) const Padding(padding: EdgeInsets.all(FactorySpacing.sm), child: Text('No records.')),
            ...rows.map((row) => ListTile(dense: true, title: Text(row['name'] as String? ?? ''), subtitle: Text(subtitle?.call(row) ?? (row['code'] as String? ?? '')), trailing: onEdit == null ? null : IconButton(onPressed: () => onEdit!(row), icon: const Icon(Icons.edit_outlined)))),
          ]),
        ),
      );
}

class _Holidays extends StatelessWidget {
  const _Holidays({required this.snapshot, required this.onEdit, required this.onAdd});
  final HrSnapshot snapshot;
  final ValueChanged<Map<String, dynamic>> onEdit;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(FactorySpacing.lg), children: [
        Row(children: [Expanded(child: Text('Holidays', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))), FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Add holiday'))]),
        const SizedBox(height: FactorySpacing.md),
        ...snapshot.holidays.map((row) => Card(child: ListTile(leading: const Icon(Icons.calendar_month_outlined), title: Text(row['name'] as String), subtitle: Text('${row['holiday_date']} · ${_title(row['holiday_type'] as String? ?? '')}${row['factory_id'] == null ? ' · All factories' : ''}'), trailing: IconButton(onPressed: () => onEdit(row), icon: const Icon(Icons.edit_outlined))))
      ]);
}

class HrReports extends StatefulWidget {
  const HrReports({required this.organizationId, required this.factories, super.key});
  final String organizationId;
  final List<Map<String, dynamic>> factories;
  @override
  State<HrReports> createState() => _HrReportsState();
}

class _HrReportsState extends State<HrReports> {
  DateTime from = DateTime.now().subtract(const Duration(days: 30));
  DateTime to = DateTime.now();
  String? factoryId;
  bool busy = false;
  String? error;
  List<Map<String, dynamic>> rows = const [];

  Future<void> run() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final raw = await Supabase.instance.client.rpc('hr_attendance_report', params: {'p_organization_id': widget.organizationId, 'p_factory_id': factoryId, 'p_from': _date(from), 'p_to': _date(to)});
      rows = (raw as List<dynamic>).map((row) => Map<String, dynamic>.from(row as Map)).toList();
    } catch (e) {
      error = _errorText(e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(FactorySpacing.lg), children: [
        Wrap(spacing: FactorySpacing.sm, runSpacing: FactorySpacing.sm, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(width: 260, child: DropdownButtonFormField<String?>(initialValue: factoryId, decoration: const InputDecoration(labelText: 'Factory'), items: [const DropdownMenuItem<String?>(value: null, child: Text('All permitted factories')), ...widget.factories.map((f) => DropdownMenuItem<String?>(value: f['id'] as String, child: Text(f['name'] as String)))], onChanged: (v) => setState(() => factoryId = v))),
          OutlinedButton.icon(onPressed: () async { final value = await showDatePicker(context: context, initialDate: from, firstDate: DateTime(2020), lastDate: DateTime(2100)); if (value != null) setState(() => from = value); }, icon: const Icon(Icons.date_range), label: Text('From ${_date(from)}')),
          OutlinedButton.icon(onPressed: () async { final value = await showDatePicker(context: context, initialDate: to, firstDate: DateTime(2020), lastDate: DateTime(2100)); if (value != null) setState(() => to = value); }, icon: const Icon(Icons.date_range), label: Text('To ${_date(to)}')),
          FilledButton.icon(onPressed: busy ? null : run, icon: const Icon(Icons.analytics_outlined), label: Text(busy ? 'Loading…' : 'Run report')),
        ]),
        if (error != null) Padding(padding: const EdgeInsets.only(top: FactorySpacing.md), child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        const SizedBox(height: FactorySpacing.md),
        if (rows.isEmpty && !busy) const Card(child: Padding(padding: EdgeInsets.all(FactorySpacing.lg), child: Text('Choose a date range and run the attendance report.'))),
        ...rows.map((row) => Card(child: ListTile(title: Text('${row['employee_name']} · ${row['employee_code']}'), subtitle: Text('${row['work_date']} · ${_title(row['attendance_status'] as String? ?? '')} · ${row['department_name']}'), trailing: Text(row['worked_minutes'] == null ? '—' : '${row['worked_minutes']} min')))),
      ]);
}

class EmployeeEditor extends StatefulWidget {
  const EmployeeEditor({required this.snapshot, required this.factories, this.initial, super.key});
  final HrSnapshot snapshot;
  final List<Map<String, dynamic>> factories;
  final Map<String, dynamic>? initial;
  @override
  State<EmployeeEditor> createState() => _EmployeeEditorState();
}

class _EmployeeEditorState extends State<EmployeeEditor> {
  late final TextEditingController code = TextEditingController(text: widget.initial?['employee_code'] as String? ?? '');
  late final TextEditingController name = TextEditingController(text: widget.initial?['full_name'] as String? ?? '');
  late final TextEditingController email = TextEditingController(text: widget.initial?['email'] as String? ?? '');
  late final TextEditingController phone = TextEditingController(text: widget.initial?['phone'] as String? ?? '');
  String? factoryId;
  String? departmentId;
  String? designationId;
  String? shiftId;
  String? userId;
  String employmentType = 'full_time';

  @override
  void initState() {
    super.initState();
    factoryId = widget.initial?['primary_factory_id'] as String? ?? (widget.factories.isEmpty ? null : widget.factories.first['id'] as String);
    departmentId = widget.initial?['department_id'] as String?;
    designationId = widget.initial?['designation_id'] as String?;
    shiftId = widget.initial?['shift_id'] as String?;
    userId = widget.initial?['user_id'] as String?;
    employmentType = widget.initial?['employment_type'] as String? ?? 'full_time';
  }

  @override
  void dispose() {
    code.dispose();
    name.dispose();
    email.dispose();
    phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.initial == null ? 'Add employee' : 'Edit employee'),
        content: SizedBox(width: 620, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name *')),
          const SizedBox(height: FactorySpacing.sm),
          TextField(controller: code, decoration: const InputDecoration(labelText: 'Employee ID *')),
          const SizedBox(height: FactorySpacing.sm),
          Row(children: [Expanded(child: TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone'))), const SizedBox(width: FactorySpacing.sm), Expanded(child: TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')))]),
          const SizedBox(height: FactorySpacing.sm),
          DropdownButtonFormField<String>(initialValue: factoryId, decoration: const InputDecoration(labelText: 'Primary factory *'), items: widget.factories.map((f) => DropdownMenuItem(value: f['id'] as String, child: Text(f['name'] as String))).toList(), onChanged: (v) => setState(() => factoryId = v)),
          const SizedBox(height: FactorySpacing.sm),
          Row(children: [
            Expanded(child: DropdownButtonFormField<String?>(initialValue: departmentId, decoration: const InputDecoration(labelText: 'Department'), items: [const DropdownMenuItem<String?>(value: null, child: Text('None')), ...widget.snapshot.departments.map((r) => DropdownMenuItem<String?>(value: r['id'] as String, child: Text(r['name'] as String)))], onChanged: (v) => setState(() => departmentId = v))),
            const SizedBox(width: FactorySpacing.sm),
            Expanded(child: DropdownButtonFormField<String?>(initialValue: designationId, decoration: const InputDecoration(labelText: 'Designation'), items: [const DropdownMenuItem<String?>(value: null, child: Text('None')), ...widget.snapshot.designations.map((r) => DropdownMenuItem<String?>(value: r['id'] as String, child: Text(r['name'] as String)))], onChanged: (v) => setState(() => designationId = v))),
          ]),
          const SizedBox(height: FactorySpacing.sm),
          Row(children: [
            Expanded(child: DropdownButtonFormField<String?>(initialValue: shiftId, decoration: const InputDecoration(labelText: 'Shift'), items: [const DropdownMenuItem<String?>(value: null, child: Text('None')), ...widget.snapshot.shifts.map((r) => DropdownMenuItem<String?>(value: r['id'] as String, child: Text(r['name'] as String)))], onChanged: (v) => setState(() => shiftId = v))),
            const SizedBox(width: FactorySpacing.sm),
            Expanded(child: DropdownButtonFormField<String>(initialValue: employmentType, decoration: const InputDecoration(labelText: 'Employment type'), items: const ['full_time','part_time','contract','temporary','intern'].map((v) => DropdownMenuItem(value: v, child: Text(_title(v)))).toList(), onChanged: (v) => setState(() => employmentType = v ?? 'full_time'))),
          ]),
          if (widget.snapshot.members.isNotEmpty) ...[
            const SizedBox(height: FactorySpacing.sm),
            DropdownButtonFormField<String?>(initialValue: userId, decoration: const InputDecoration(labelText: 'Linked FactoryOS user (optional)'), items: [const DropdownMenuItem<String?>(value: null, child: Text('Not linked')), ...widget.snapshot.members.map((m) => DropdownMenuItem<String?>(value: m['user_id'] as String, child: Text((m['full_name'] as String? ?? '').isEmpty ? m['email'] as String : '${m['full_name']} · ${m['email']}')))], onChanged: (v) => setState(() => userId = v)),
          ],
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () {
            if (name.text.trim().length < 2 || code.text.trim().length < 2 || factoryId == null) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name, employee ID and factory are required.')));
              return;
            }
            Navigator.pop(context, {
              'employee_code': code.text.trim().toUpperCase(),
              'full_name': name.text.trim(),
              'email': _nullable(email.text),
              'phone': _nullable(phone.text),
              'primary_factory_id': factoryId,
              'department_id': departmentId,
              'designation_id': designationId,
              'shift_id': shiftId,
              'user_id': userId,
              'employment_type': employmentType,
              'join_date': widget.initial?['join_date'] ?? _date(DateTime.now()),
              'status': widget.initial?['status'] ?? 'active',
            });
          }, child: const Text('Save employee')),
        ],
      );
}

class DesignationEditor extends StatefulWidget {
  const DesignationEditor({required this.departments, this.initial, super.key});
  final List<Map<String, dynamic>> departments;
  final Map<String, dynamic>? initial;
  @override
  State<DesignationEditor> createState() => _DesignationEditorState();
}

class _DesignationEditorState extends State<DesignationEditor> {
  late final name = TextEditingController(text: widget.initial?['name'] as String? ?? '');
  late final code = TextEditingController(text: widget.initial?['code'] as String? ?? '');
  String? departmentId;
  @override void initState(){super.initState();departmentId=widget.initial?['department_id'] as String?;}
  @override void dispose(){name.dispose();code.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>AlertDialog(title:Text(widget.initial==null?'Add designation':'Edit designation'),content:SizedBox(width:480,child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:name,decoration:const InputDecoration(labelText:'Name')),const SizedBox(height:FactorySpacing.sm),TextField(controller:code,decoration:const InputDecoration(labelText:'Code')),const SizedBox(height:FactorySpacing.sm),DropdownButtonFormField<String?>(initialValue:departmentId,decoration:const InputDecoration(labelText:'Department'),items:[const DropdownMenuItem<String?>(value:null,child:Text('Any department')),...widget.departments.map((r)=>DropdownMenuItem<String?>(value:r['id'] as String,child:Text(r['name'] as String)))],onChanged:(v)=>setState(()=>departmentId=v))])),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(context,{'name':name.text.trim(),'code':code.text.trim().toUpperCase(),'department_id':departmentId,'is_active':true}),child:const Text('Save'))]);
}

class ShiftEditor extends StatefulWidget {
  const ShiftEditor({required this.factories, this.initial, super.key});
  final List<Map<String, dynamic>> factories;
  final Map<String, dynamic>? initial;
  @override State<ShiftEditor> createState()=>_ShiftEditorState();
}
class _ShiftEditorState extends State<ShiftEditor>{
  late final name=TextEditingController(text:widget.initial?['name'] as String? ?? '');
  late final code=TextEditingController(text:widget.initial?['code'] as String? ?? '');
  late final start=TextEditingController(text:_timeShort(widget.initial?['start_time']) ?? '06:00');
  late final end=TextEditingController(text:_timeShort(widget.initial?['end_time']) ?? '14:00');
  String? factoryId;
  bool crosses=false;
  @override void initState(){super.initState();factoryId=widget.initial?['factory_id'] as String? ?? (widget.factories.isEmpty?null:widget.factories.first['id'] as String);crosses=widget.initial?['crosses_midnight'] as bool? ?? false;}
  @override void dispose(){name.dispose();code.dispose();start.dispose();end.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>AlertDialog(title:Text(widget.initial==null?'Add shift':'Edit shift'),content:SizedBox(width:500,child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:name,decoration:const InputDecoration(labelText:'Shift name')),const SizedBox(height:FactorySpacing.sm),TextField(controller:code,decoration:const InputDecoration(labelText:'Code')),const SizedBox(height:FactorySpacing.sm),DropdownButtonFormField<String?>(initialValue:factoryId,decoration:const InputDecoration(labelText:'Factory'),items:widget.factories.map((f)=>DropdownMenuItem<String?>(value:f['id'] as String,child:Text(f['name'] as String))).toList(),onChanged:(v)=>setState(()=>factoryId=v)),const SizedBox(height:FactorySpacing.sm),Row(children:[Expanded(child:TextField(controller:start,decoration:const InputDecoration(labelText:'Start HH:mm'))),const SizedBox(width:FactorySpacing.sm),Expanded(child:TextField(controller:end,decoration:const InputDecoration(labelText:'End HH:mm')))]),SwitchListTile(contentPadding:EdgeInsets.zero,value:crosses,title:const Text('Crosses midnight'),onChanged:(v)=>setState(()=>crosses=v))])),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(context,{'name':name.text.trim(),'code':code.text.trim().toUpperCase(),'factory_id':factoryId,'start_time':start.text.trim(),'end_time':end.text.trim(),'crosses_midnight':crosses,'grace_minutes':10,'half_day_after_minutes':240,'is_active':true}),child:const Text('Save'))]);
}

class LeaveTypeEditor extends StatefulWidget{const LeaveTypeEditor({this.initial,super.key});final Map<String,dynamic>? initial;@override State<LeaveTypeEditor> createState()=>_LeaveTypeEditorState();}
class _LeaveTypeEditorState extends State<LeaveTypeEditor>{late final name=TextEditingController(text:widget.initial?['name'] as String? ?? '');late final code=TextEditingController(text:widget.initial?['code'] as String? ?? '');late final maxDays=TextEditingController(text:'${widget.initial?['max_days_per_year'] ?? ''}');bool paid=true;@override void initState(){super.initState();paid=widget.initial?['is_paid'] as bool? ?? true;}@override void dispose(){name.dispose();code.dispose();maxDays.dispose();super.dispose();}@override Widget build(BuildContext context)=>AlertDialog(title:Text(widget.initial==null?'Add leave type':'Edit leave type'),content:SizedBox(width:460,child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:name,decoration:const InputDecoration(labelText:'Name')),const SizedBox(height:FactorySpacing.sm),TextField(controller:code,decoration:const InputDecoration(labelText:'Code')),const SizedBox(height:FactorySpacing.sm),TextField(controller:maxDays,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Max days/year (optional)')),SwitchListTile(contentPadding:EdgeInsets.zero,value:paid,title:const Text('Paid leave'),onChanged:(v)=>setState(()=>paid=v))])),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(context,{'name':name.text.trim(),'code':code.text.trim().toUpperCase(),'is_paid':paid,'max_days_per_year':double.tryParse(maxDays.text.trim()),'requires_approval':true,'is_active':true}),child:const Text('Save'))]);}

class HolidayEditor extends StatefulWidget{const HolidayEditor({required this.factories,this.initial,super.key});final List<Map<String,dynamic>> factories;final Map<String,dynamic>? initial;@override State<HolidayEditor> createState()=>_HolidayEditorState();}
class _HolidayEditorState extends State<HolidayEditor>{late final name=TextEditingController(text:widget.initial?['name'] as String? ?? '');DateTime date=DateTime.now();String? factoryId;String type='company';@override void initState(){super.initState();if(widget.initial?['holiday_date']!=null)date=DateTime.parse(widget.initial!['holiday_date'] as String);factoryId=widget.initial?['factory_id'] as String?;type=widget.initial?['holiday_type'] as String? ?? 'company';}@override void dispose(){name.dispose();super.dispose();}@override Widget build(BuildContext context)=>AlertDialog(title:Text(widget.initial==null?'Add holiday':'Edit holiday'),content:SizedBox(width:500,child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:name,decoration:const InputDecoration(labelText:'Holiday name')),const SizedBox(height:FactorySpacing.sm),DropdownButtonFormField<String?>(initialValue:factoryId,decoration:const InputDecoration(labelText:'Scope'),items:[const DropdownMenuItem<String?>(value:null,child:Text('All factories')),...widget.factories.map((f)=>DropdownMenuItem<String?>(value:f['id'] as String,child:Text(f['name'] as String)))],onChanged:(v)=>setState(()=>factoryId=v)),const SizedBox(height:FactorySpacing.sm),DropdownButtonFormField<String>(initialValue:type,decoration:const InputDecoration(labelText:'Type'),items:const ['national','state','festival','company','optional'].map((v)=>DropdownMenuItem(value:v,child:Text(_title(v)))).toList(),onChanged:(v)=>setState(()=>type=v??'company')),const SizedBox(height:FactorySpacing.sm),ListTile(contentPadding:EdgeInsets.zero,title:const Text('Date'),subtitle:Text(_date(date)),trailing:const Icon(Icons.calendar_month),onTap:()async{final v=await showDatePicker(context:context,initialDate:date,firstDate:DateTime(2020),lastDate:DateTime(2100));if(v!=null)setState(()=>date=v);})])),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(context,{'name':name.text.trim(),'holiday_date':_date(date),'factory_id':factoryId,'holiday_type':type,'is_active':true}),child:const Text('Save'))]);}

class _Metric extends StatelessWidget{const _Metric(this.label,this.value,this.icon);final String label;final String value;final IconData icon;@override Widget build(BuildContext context)=>SizedBox(width:210,child:Card(child:Padding(padding:const EdgeInsets.all(FactorySpacing.md),child:Row(children:[CircleAvatar(child:Icon(icon)),const SizedBox(width:FactorySpacing.sm),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(value,style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w900)),Text(label)]))]))));}
class _HrSection{const _HrSection(this.label,this.icon,this.page);final String label;final IconData icon;final Widget page;}
class _ErrorState extends StatelessWidget{const _ErrorState({required this.message,required this.onRetry});final String message;final VoidCallback onRetry;@override Widget build(BuildContext context)=>Center(child:Padding(padding:const EdgeInsets.all(FactorySpacing.lg),child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.error_outline,size:44),const SizedBox(height:FactorySpacing.sm),Text(message,textAlign:TextAlign.center),const SizedBox(height:FactorySpacing.md),OutlinedButton(onPressed:onRetry,child:const Text('Retry'))])));}

Future<Map<String,dynamic>?> _nameCodeDialog(BuildContext context,{required String title,Map<String,dynamic>? initial}) async{final name=TextEditingController(text:initial?['name'] as String? ?? '');final code=TextEditingController(text:initial?['code'] as String? ?? '');final result=await showDialog<Map<String,dynamic>>(context:context,builder:(ctx)=>AlertDialog(title:Text(title),content:SizedBox(width:460,child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:name,decoration:const InputDecoration(labelText:'Name')),const SizedBox(height:FactorySpacing.sm),TextField(controller:code,decoration:const InputDecoration(labelText:'Code'))])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,{'name':name.text.trim(),'code':code.text.trim().toUpperCase(),'is_active':true}),child:const Text('Save'))]));name.dispose();code.dispose();return result;}

String _date(DateTime date)=>'${date.year.toString().padLeft(4,'0')}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}';
String _title(String value)=>value.replaceAll('_',' ').split(' ').where((p)=>p.isNotEmpty).map((p)=>'${p[0].toUpperCase()}${p.substring(1)}').join(' ');
String? _nullable(String value)=>value.trim().isEmpty?null:value.trim();
String _initials(String value){final parts=value.trim().split(RegExp(r'\s+')).where((e)=>e.isNotEmpty).toList();if(parts.isEmpty)return 'E';return parts.take(2).map((e)=>e[0].toUpperCase()).join();}
IconData _attendanceIcon(String value)=>switch(value){'present'=>Icons.check_circle_outline,'on_leave'=>Icons.event_busy_outlined,'half_day'=>Icons.timelapse_outlined,_=>Icons.person_off_outlined};
String? _timeShort(dynamic value){if(value==null)return null;final text='$value';return text.length>=5?text.substring(0,5):text;}
String _errorText(Object error){if(error is PostgrestException)return error.message;if(error is FunctionException){final details=error.details;if(details is Map&&details['error']!=null)return '${details['error']}';}return '$error';}
