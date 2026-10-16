import 'package:factoryos_core/factoryos_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'hr_editors.dart';

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

  void reload() {
    setState(() => future = repository.load(widget.organizationId));
  }

  void message(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  Future<void> editEmployee(
    HrSnapshot data, [
    Map<String, dynamic>? initial,
  ]) async {
    final draft = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => EmployeeEditor(
        departments: data.departments,
        designations: data.designations,
        shifts: data.shifts,
        factories: widget.factories,
        members: data.members,
        initial: initial,
      ),
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
    } catch (error) {
      if (mounted) message(_errorText(error), isError: true);
    }
  }

  Future<void> toggleEmployee(Map<String, dynamic> employee) async {
    final active = employee['status'] == 'active';
    try {
      await repository.updateEmployee(employee['id'] as String, {
        'status': active ? 'inactive' : 'active',
      });
      if (!mounted) return;
      message(active ? 'Employee deactivated.' : 'Employee activated.');
      reload();
    } catch (error) {
      if (mounted) message(_errorText(error), isError: true);
    }
  }

  Future<void> markAttendance(
    Map<String, dynamic> employee,
    String status,
  ) async {
    try {
      await repository.markAttendance(widget.organizationId, employee, status);
      if (!mounted) return;
      message('Attendance marked ${hrTitle(status).toLowerCase()}.');
      reload();
    } catch (error) {
      if (mounted) message(_errorText(error), isError: true);
    }
  }

  Future<void> decideLeave(
    Map<String, dynamic> request,
    String decision,
  ) async {
    try {
      await repository.decideLeave(request['id'] as String, decision);
      if (!mounted) return;
      message('Leave ${hrTitle(decision).toLowerCase()}.');
      reload();
    } catch (error) {
      if (mounted) message(_errorText(error), isError: true);
    }
  }

  Future<void> editDepartment([Map<String, dynamic>? initial]) async {
    final draft = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => NameCodeEditor(
        title: initial == null ? 'Add department' : 'Edit department',
        initial: initial,
      ),
    );
    if (draft == null) return;
    try {
      await repository.saveDepartment(
        widget.organizationId,
        draft,
        id: initial?['id'] as String?,
      );
      reload();
    } catch (error) {
      if (mounted) message(_errorText(error), isError: true);
    }
  }

  Future<void> editDesignation(
    HrSnapshot data, [
    Map<String, dynamic>? initial,
  ]) async {
    final draft = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) =>
          DesignationEditor(departments: data.departments, initial: initial),
    );
    if (draft == null) return;
    try {
      await repository.saveDesignation(
        widget.organizationId,
        draft,
        id: initial?['id'] as String?,
      );
      reload();
    } catch (error) {
      if (mounted) message(_errorText(error), isError: true);
    }
  }

  Future<void> editShift([Map<String, dynamic>? initial]) async {
    final draft = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) =>
          ShiftEditor(factories: widget.factories, initial: initial),
    );
    if (draft == null) return;
    try {
      await repository.saveShift(
        widget.organizationId,
        draft,
        id: initial?['id'] as String?,
      );
      reload();
    } catch (error) {
      if (mounted) message(_errorText(error), isError: true);
    }
  }

  Future<void> editLeaveType([Map<String, dynamic>? initial]) async {
    final draft = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => LeaveTypeEditor(initial: initial),
    );
    if (draft == null) return;
    try {
      await repository.saveLeaveType(
        widget.organizationId,
        draft,
        id: initial?['id'] as String?,
      );
      reload();
    } catch (error) {
      if (mounted) message(_errorText(error), isError: true);
    }
  }

  Future<void> editHoliday([Map<String, dynamic>? initial]) async {
    final draft = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) =>
          HolidayEditor(factories: widget.factories, initial: initial),
    );
    if (draft == null) return;
    try {
      await repository.saveHoliday(
        widget.organizationId,
        draft,
        id: initial?['id'] as String?,
      );
      reload();
    } catch (error) {
      if (mounted) message(_errorText(error), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<HrSnapshot>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ErrorState(message: '${snapshot.error}', onRetry: reload);
        }

        final data = snapshot.requireData;
        final sections = <_HrSection>[
          _HrSection(
            'Dashboard',
            Icons.dashboard_outlined,
            _Dashboard(snapshot: data),
          ),
          _HrSection(
            'Employees',
            Icons.badge_outlined,
            _Employees(
              snapshot: data,
              onAdd: () => editEmployee(data),
              onEdit: (row) => editEmployee(data, row),
              onToggle: toggleEmployee,
            ),
          ),
          _HrSection(
            'Attendance',
            Icons.how_to_reg_outlined,
            _Attendance(snapshot: data, onMark: markAttendance),
          ),
          _HrSection(
            'Leave',
            Icons.event_busy_outlined,
            _Leave(snapshot: data, onDecision: decideLeave),
          ),
          _HrSection(
            'Masters',
            Icons.account_tree_outlined,
            _Masters(
              snapshot: data,
              canEditOrganizationMasters:
                  widget.actorRole.canManageOrganizationSetup,
              onDepartment: editDepartment,
              onDesignation: (row) => editDesignation(data, row),
              onShift: editShift,
              onLeaveType: editLeaveType,
            ),
          ),
          _HrSection(
            'Holidays',
            Icons.celebration_outlined,
            _Holidays(
              snapshot: data,
              onAdd: () => editHoliday(),
              onEdit: editHoliday,
            ),
          ),
          _HrSection(
            'Reports',
            Icons.analytics_outlined,
            HrReports(
              organizationId: widget.organizationId,
              factories: widget.factories,
            ),
          ),
        ];

        if (section >= sections.length) section = 0;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                FactorySpacing.lg,
                FactorySpacing.lg,
                FactorySpacing.lg,
                0,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.groups_2_outlined,
                    color: FactoryColors.blue,
                  ),
                  const SizedBox(width: FactorySpacing.sm),
                  Expanded(
                    child: Text(
                      'HR & Employees',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: reload,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 56,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: FactorySpacing.lg,
                  vertical: FactorySpacing.sm,
                ),
                scrollDirection: Axis.horizontal,
                itemCount: sections.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(width: FactorySpacing.xs),
                itemBuilder: (context, index) => ChoiceChip(
                  selected: section == index,
                  avatar: Icon(sections[index].icon, size: 18),
                  label: Text(sections[index].label),
                  onSelected: (_) => setState(() => section = index),
                ),
              ),
            ),
            Expanded(child: sections[section].page),
          ],
        );
      },
    );
  }
}

class HrRepository {
  HrRepository(this.client);
  final SupabaseClient client;

  Future<HrSnapshot> load(String organizationId) async {
    final summaryRaw = await client.rpc(
      'hr_dashboard_summary',
      params: {
        'p_organization_id': organizationId,
        'p_factory_id': null,
        'p_work_date': hrDate(DateTime.now()),
      },
    );
    final departments = await client
        .from('departments')
        .select()
        .eq('organization_id', organizationId)
        .eq('is_active', true)
        .order('name');
    final designations = await client
        .from('designations')
        .select()
        .eq('organization_id', organizationId)
        .eq('is_active', true)
        .order('name');
    final shifts = await client
        .from('shifts')
        .select()
        .eq('organization_id', organizationId)
        .eq('is_active', true)
        .order('name');
    final employees = await client
        .from('employees')
        .select()
        .eq('organization_id', organizationId)
        .order('full_name');
    final leaveTypes = await client
        .from('leave_types')
        .select()
        .eq('organization_id', organizationId)
        .eq('is_active', true)
        .order('name');
    final leaveRequests = await client
        .from('leave_requests')
        .select()
        .eq('organization_id', organizationId)
        .order('created_at', ascending: false)
        .limit(80);
    final holidays = await client
        .from('holidays')
        .select()
        .eq('organization_id', organizationId)
        .eq('is_active', true)
        .order('holiday_date');
    final attendance = await client
        .from('attendance_records')
        .select()
        .eq('organization_id', organizationId)
        .order('work_date', ascending: false)
        .limit(120);

    var members = <Map<String, dynamic>>[];
    try {
      final raw = await client.rpc(
        'list_organization_members',
        params: {'p_organization_id': organizationId},
      );
      members = (raw as List<dynamic>)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
    } catch (_) {
      // Factory managers intentionally cannot list organization-wide access.
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

  Future<void> createEmployee(
    String organizationId,
    Map<String, dynamic> values,
  ) async {
    await client.from('employees').insert({
      'organization_id': organizationId,
      ...values,
    });
  }

  Future<void> updateEmployee(String id, Map<String, dynamic> values) async {
    await client.from('employees').update(values).eq('id', id);
  }

  Future<void> markAttendance(
    String organizationId,
    Map<String, dynamic> employee,
    String status,
  ) async {
    final now = DateTime.now();
    final userId = client.auth.currentUser?.id;
    final values = <String, dynamic>{
      'organization_id': organizationId,
      'factory_id': employee['primary_factory_id'],
      'employee_id': employee['id'],
      'shift_id': employee['shift_id'],
      'work_date': hrDate(now),
      'status': status,
      'source': 'admin',
      'updated_by': userId,
      if (status == 'present') 'check_in_at': now.toUtc().toIso8601String(),
      if (status == 'present') 'created_by': userId,
    };
    await client
        .from('attendance_records')
        .upsert(values, onConflict: 'employee_id,work_date');
  }

  Future<void> decideLeave(String id, String decision) async {
    await client.rpc(
      'decide_leave_request',
      params: {'p_request_id': id, 'p_decision': decision, 'p_note': null},
    );
  }

  Future<void> saveDepartment(
    String organizationId,
    Map<String, dynamic> values, {
    String? id,
  }) async {
    if (id == null) {
      await client.from('departments').insert({
        'organization_id': organizationId,
        ...values,
      });
    } else {
      await client.from('departments').update(values).eq('id', id);
    }
  }

  Future<void> saveDesignation(
    String organizationId,
    Map<String, dynamic> values, {
    String? id,
  }) async {
    if (id == null) {
      await client.from('designations').insert({
        'organization_id': organizationId,
        ...values,
      });
    } else {
      await client.from('designations').update(values).eq('id', id);
    }
  }

  Future<void> saveShift(
    String organizationId,
    Map<String, dynamic> values, {
    String? id,
  }) async {
    if (id == null) {
      await client.from('shifts').insert({
        'organization_id': organizationId,
        ...values,
      });
    } else {
      await client.from('shifts').update(values).eq('id', id);
    }
  }

  Future<void> saveLeaveType(
    String organizationId,
    Map<String, dynamic> values, {
    String? id,
  }) async {
    if (id == null) {
      await client.from('leave_types').insert({
        'organization_id': organizationId,
        ...values,
      });
    } else {
      await client.from('leave_types').update(values).eq('id', id);
    }
  }

  Future<void> saveHoliday(
    String organizationId,
    Map<String, dynamic> values, {
    String? id,
  }) async {
    if (id == null) {
      await client.from('holidays').insert({
        'organization_id': organizationId,
        ...values,
      });
    } else {
      await client.from('holidays').update(values).eq('id', id);
    }
  }
}

class HrSnapshot {
  const HrSnapshot({
    required this.summary,
    required this.departments,
    required this.designations,
    required this.shifts,
    required this.employees,
    required this.leaveTypes,
    required this.leaveRequests,
    required this.holidays,
    required this.attendance,
    required this.members,
  });

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

  String employeeName(String? id) =>
      _nameById(employees, id, 'full_name', 'Unknown employee');
  String departmentName(String? id) => _nameById(departments, id, 'name', '—');
  String designationName(String? id) =>
      _nameById(designations, id, 'name', '—');
  String shiftName(String? id) => _nameById(shifts, id, 'name', '—');
  String leaveTypeName(String? id) =>
      _nameById(leaveTypes, id, 'name', 'Leave');
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.snapshot});
  final HrSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final summary = snapshot.summary;
    return ListView(
      padding: const EdgeInsets.all(FactorySpacing.lg),
      children: [
        Wrap(
          spacing: FactorySpacing.md,
          runSpacing: FactorySpacing.md,
          children: [
            _Metric(
              'Employees',
              '${summary['employees'] ?? 0}',
              Icons.groups_outlined,
            ),
            _Metric(
              'Present today',
              '${summary['present'] ?? 0}',
              Icons.check_circle_outline,
            ),
            _Metric(
              'Absent',
              '${summary['absent'] ?? 0}',
              Icons.person_off_outlined,
            ),
            _Metric(
              'On leave',
              '${summary['on_leave'] ?? 0}',
              Icons.event_busy_outlined,
            ),
            _Metric(
              'Pending leave',
              '${summary['pending_leave'] ?? 0}',
              Icons.pending_actions_outlined,
            ),
            _Metric(
              'Late today',
              '${summary['late'] ?? 0}',
              Icons.schedule_outlined,
            ),
          ],
        ),
        const SizedBox(height: FactorySpacing.xl),
        Text(
          'Recent attendance',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: FactorySpacing.sm),
        ...snapshot.attendance
            .take(8)
            .map(
              (row) => Card(
                child: ListTile(
                  leading: Icon(
                    _attendanceIcon(row['status'] as String? ?? 'absent'),
                  ),
                  title: Text(
                    snapshot.employeeName(row['employee_id'] as String?),
                  ),
                  subtitle: Text(
                    '${row['work_date']} · ${hrTitle(row['status'] as String? ?? '')}',
                  ),
                  trailing: (row['late_minutes'] as int? ?? 0) > 0
                      ? Text('${row['late_minutes']} min late')
                      : null,
                ),
              ),
            ),
      ],
    );
  }
}

class _Employees extends StatelessWidget {
  const _Employees({
    required this.snapshot,
    required this.onAdd,
    required this.onEdit,
    required this.onToggle,
  });

  final HrSnapshot snapshot;
  final VoidCallback onAdd;
  final ValueChanged<Map<String, dynamic>> onEdit;
  final ValueChanged<Map<String, dynamic>> onToggle;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(FactorySpacing.lg),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Employees',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Add employee'),
            ),
          ],
        ),
        const SizedBox(height: FactorySpacing.md),
        ...snapshot.employees.map((employee) {
          final active = employee['status'] == 'active';
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                child: Text(_initials(employee['full_name'] as String? ?? 'E')),
              ),
              title: Text(employee['full_name'] as String),
              subtitle: Text(
                [
                  employee['employee_code'],
                  snapshot.departmentName(employee['department_id'] as String?),
                  snapshot.designationName(
                    employee['designation_id'] as String?,
                  ),
                  snapshot.shiftName(employee['shift_id'] as String?),
                  hrTitle(employee['status'] as String? ?? ''),
                ].whereType<String>().join(' · '),
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    onEdit(employee);
                  } else {
                    onToggle(employee);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit employee'),
                  ),
                  PopupMenuItem(
                    value: 'status',
                    child: Text(active ? 'Deactivate' : 'Activate'),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _Attendance extends StatelessWidget {
  const _Attendance({required this.snapshot, required this.onMark});
  final HrSnapshot snapshot;
  final void Function(Map<String, dynamic>, String) onMark;

  @override
  Widget build(BuildContext context) {
    final today = hrDate(DateTime.now());
    final todayRows = <dynamic, Map<String, dynamic>>{};
    for (final row in snapshot.attendance) {
      if (row['work_date'] == today) todayRows[row['employee_id']] = row;
    }

    return ListView(
      padding: const EdgeInsets.all(FactorySpacing.lg),
      children: [
        Text(
          'Attendance · $today',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: FactorySpacing.md),
        ...snapshot.employees.where((row) => row['status'] == 'active').map((
          employee,
        ) {
          final attendance = todayRows[employee['id']];
          final status = attendance?['status'] as String? ?? 'not_marked';
          return Card(
            child: ListTile(
              title: Text(employee['full_name'] as String),
              subtitle: Text(
                '${employee['employee_code']} · ${snapshot.shiftName(employee['shift_id'] as String?)} · ${hrTitle(status)}',
              ),
              trailing: Wrap(
                spacing: FactorySpacing.xs,
                children: [
                  IconButton(
                    tooltip: 'Present',
                    onPressed: () => onMark(employee, 'present'),
                    icon: const Icon(Icons.check_circle_outline),
                  ),
                  IconButton(
                    tooltip: 'Absent',
                    onPressed: () => onMark(employee, 'absent'),
                    icon: const Icon(Icons.person_off_outlined),
                  ),
                  IconButton(
                    tooltip: 'Half day',
                    onPressed: () => onMark(employee, 'half_day'),
                    icon: const Icon(Icons.timelapse_outlined),
                  ),
                ],
              ),
            ),
          );
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
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(FactorySpacing.lg),
      children: [
        Text(
          'Leave requests',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: FactorySpacing.md),
        if (snapshot.leaveRequests.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(FactorySpacing.lg),
              child: Text('No leave requests.'),
            ),
          ),
        ...snapshot.leaveRequests.map((request) {
          final pending = request['status'] == 'pending';
          final reason = request['reason'] as String?;
          return Card(
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.event_note_outlined),
              ),
              title: Text(
                snapshot.employeeName(request['employee_id'] as String?),
              ),
              subtitle: Text(
                '${snapshot.leaveTypeName(request['leave_type_id'] as String?)} · '
                '${request['start_date']} → ${request['end_date']} · '
                '${request['requested_days']} day(s) · '
                '${hrTitle(request['status'] as String? ?? '')}'
                '${reason == null ? '' : '\n$reason'}',
              ),
              isThreeLine: reason != null,
              trailing: pending
                  ? Wrap(
                      spacing: FactorySpacing.xs,
                      children: [
                        IconButton(
                          tooltip: 'Approve',
                          onPressed: () => onDecision(request, 'approved'),
                          icon: const Icon(Icons.check_circle_outline),
                        ),
                        IconButton(
                          tooltip: 'Reject',
                          onPressed: () => onDecision(request, 'rejected'),
                          icon: const Icon(Icons.cancel_outlined),
                        ),
                      ],
                    )
                  : null,
            ),
          );
        }),
      ],
    );
  }
}

class _Masters extends StatelessWidget {
  const _Masters({
    required this.snapshot,
    required this.canEditOrganizationMasters,
    required this.onDepartment,
    required this.onDesignation,
    required this.onShift,
    required this.onLeaveType,
  });

  final HrSnapshot snapshot;
  final bool canEditOrganizationMasters;
  final ValueChanged<Map<String, dynamic>?> onDepartment;
  final ValueChanged<Map<String, dynamic>?> onDesignation;
  final ValueChanged<Map<String, dynamic>?> onShift;
  final ValueChanged<Map<String, dynamic>?> onLeaveType;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(FactorySpacing.lg),
      children: [
        _MasterCard(
          title: 'Departments',
          rows: snapshot.departments,
          canAdd: canEditOrganizationMasters,
          onAdd: () => onDepartment(null),
          onEdit: canEditOrganizationMasters
              ? (row) => onDepartment(row)
              : null,
        ),
        _MasterCard(
          title: 'Designations',
          rows: snapshot.designations,
          canAdd: canEditOrganizationMasters,
          onAdd: () => onDesignation(null),
          onEdit: canEditOrganizationMasters
              ? (row) => onDesignation(row)
              : null,
        ),
        _MasterCard(
          title: 'Shifts',
          rows: snapshot.shifts,
          canAdd: true,
          onAdd: () => onShift(null),
          onEdit: (row) => onShift(row),
          subtitle: (row) =>
              '${row['code']} · ${row['start_time']}–${row['end_time']}',
        ),
        _MasterCard(
          title: 'Leave types',
          rows: snapshot.leaveTypes,
          canAdd: canEditOrganizationMasters,
          onAdd: () => onLeaveType(null),
          onEdit: canEditOrganizationMasters ? (row) => onLeaveType(row) : null,
          subtitle: (row) =>
              '${row['code']} · ${row['is_paid'] == true ? 'Paid' : 'Unpaid'}',
        ),
      ],
    );
  }
}

class _MasterCard extends StatelessWidget {
  const _MasterCard({
    required this.title,
    required this.rows,
    required this.canAdd,
    required this.onAdd,
    this.onEdit,
    this.subtitle,
  });

  final String title;
  final List<Map<String, dynamic>> rows;
  final bool canAdd;
  final VoidCallback onAdd;
  final ValueChanged<Map<String, dynamic>>? onEdit;
  final String Function(Map<String, dynamic>)? subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: FactorySpacing.lg),
      child: Padding(
        padding: const EdgeInsets.all(FactorySpacing.md),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (canAdd)
                  IconButton(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
              ],
            ),
            const Divider(),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.all(FactorySpacing.sm),
                child: Text('No records.'),
              ),
            ...rows.map(
              (row) => ListTile(
                dense: true,
                title: Text(row['name'] as String? ?? ''),
                subtitle: Text(
                  subtitle?.call(row) ?? (row['code'] as String? ?? ''),
                ),
                trailing: onEdit == null
                    ? null
                    : IconButton(
                        onPressed: () => onEdit!(row),
                        icon: const Icon(Icons.edit_outlined),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Holidays extends StatelessWidget {
  const _Holidays({
    required this.snapshot,
    required this.onAdd,
    required this.onEdit,
  });

  final HrSnapshot snapshot;
  final VoidCallback onAdd;
  final ValueChanged<Map<String, dynamic>> onEdit;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(FactorySpacing.lg),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Holidays',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add holiday'),
            ),
          ],
        ),
        const SizedBox(height: FactorySpacing.md),
        ...snapshot.holidays.map((row) {
          final scope = row['factory_id'] == null
              ? 'All factories'
              : 'Factory holiday';
          return Card(
            child: ListTile(
              leading: const Icon(Icons.calendar_month_outlined),
              title: Text(row['name'] as String),
              subtitle: Text(
                '${row['holiday_date']} · ${hrTitle(row['holiday_type'] as String? ?? '')} · $scope',
              ),
              trailing: IconButton(
                onPressed: () => onEdit(row),
                icon: const Icon(Icons.edit_outlined),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class HrReports extends StatefulWidget {
  const HrReports({
    required this.organizationId,
    required this.factories,
    super.key,
  });

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

  Future<void> runReport() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final raw = await Supabase.instance.client.rpc(
        'hr_attendance_report',
        params: {
          'p_organization_id': widget.organizationId,
          'p_factory_id': factoryId,
          'p_from': hrDate(from),
          'p_to': hrDate(to),
        },
      );
      rows = (raw as List<dynamic>)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
    } catch (caught) {
      error = _errorText(caught);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(FactorySpacing.lg),
      children: [
        Wrap(
          spacing: FactorySpacing.sm,
          runSpacing: FactorySpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 260,
              child: DropdownButtonFormField<String?>(
                initialValue: factoryId,
                decoration: const InputDecoration(labelText: 'Factory'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All permitted factories'),
                  ),
                  ...widget.factories.map(
                    (factory) => DropdownMenuItem<String?>(
                      value: factory['id'] as String,
                      child: Text(factory['name'] as String),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => factoryId = value),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                final value = await showDatePicker(
                  context: context,
                  initialDate: from,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (value != null) setState(() => from = value);
              },
              icon: const Icon(Icons.date_range),
              label: Text('From ${hrDate(from)}'),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                final value = await showDatePicker(
                  context: context,
                  initialDate: to,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (value != null) setState(() => to = value);
              },
              icon: const Icon(Icons.date_range),
              label: Text('To ${hrDate(to)}'),
            ),
            FilledButton.icon(
              onPressed: busy ? null : runReport,
              icon: const Icon(Icons.analytics_outlined),
              label: Text(busy ? 'Loading…' : 'Run report'),
            ),
          ],
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: FactorySpacing.md),
            child: Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: FactorySpacing.md),
        if (rows.isEmpty && !busy)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(FactorySpacing.lg),
              child: Text('Choose a date range and run the attendance report.'),
            ),
          ),
        ...rows.map(
          (row) => Card(
            child: ListTile(
              title: Text('${row['employee_name']} · ${row['employee_code']}'),
              subtitle: Text(
                '${row['work_date']} · ${hrTitle(row['attendance_status'] as String? ?? '')} · ${row['department_name']}',
              ),
              trailing: row['worked_minutes'] == null
                  ? const Text('—')
                  : Text('${row['worked_minutes']} min'),
            ),
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.icon);
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(FactorySpacing.md),
          child: Row(
            children: [
              CircleAvatar(child: Icon(icon)),
              const SizedBox(width: FactorySpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    Text(label),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HrSection {
  const _HrSection(this.label, this.icon, this.page);
  final String label;
  final IconData icon;
  final Widget page;
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(FactorySpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 44),
            const SizedBox(height: FactorySpacing.sm),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: FactorySpacing.md),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

String _nameById(
  List<Map<String, dynamic>> rows,
  String? id,
  String field,
  String fallback,
) {
  if (id == null) return fallback;
  for (final row in rows) {
    if (row['id'] == id) return row[field] as String? ?? fallback;
  }
  return fallback;
}

String _initials(String value) {
  final parts = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'E';
  return parts.take(2).map((part) => part[0].toUpperCase()).join();
}

IconData _attendanceIcon(String value) {
  return switch (value) {
    'present' => Icons.check_circle_outline,
    'on_leave' => Icons.event_busy_outlined,
    'half_day' => Icons.timelapse_outlined,
    _ => Icons.person_off_outlined,
  };
}

String _errorText(Object error) {
  if (error is PostgrestException) return error.message;
  return '$error';
}
