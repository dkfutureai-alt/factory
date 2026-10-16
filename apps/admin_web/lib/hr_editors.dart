import 'package:factoryos_core/factoryos_core.dart';
import 'package:flutter/material.dart';

class EmployeeEditor extends StatefulWidget {
  const EmployeeEditor({
    required this.departments,
    required this.designations,
    required this.shifts,
    required this.factories,
    required this.members,
    this.initial,
    super.key,
  });

  final List<Map<String, dynamic>> departments;
  final List<Map<String, dynamic>> designations;
  final List<Map<String, dynamic>> shifts;
  final List<Map<String, dynamic>> factories;
  final List<Map<String, dynamic>> members;
  final Map<String, dynamic>? initial;

  @override
  State<EmployeeEditor> createState() => _EmployeeEditorState();
}

class _EmployeeEditorState extends State<EmployeeEditor> {
  late final TextEditingController name;
  late final TextEditingController code;
  late final TextEditingController phone;
  late final TextEditingController email;
  String? factoryId;
  String? departmentId;
  String? designationId;
  String? shiftId;
  String? userId;
  String employmentType = 'full_time';

  @override
  void initState() {
    super.initState();
    name = TextEditingController(
      text: widget.initial?['full_name'] as String? ?? '',
    );
    code = TextEditingController(
      text: widget.initial?['employee_code'] as String? ?? '',
    );
    phone = TextEditingController(
      text: widget.initial?['phone'] as String? ?? '',
    );
    email = TextEditingController(
      text: widget.initial?['email'] as String? ?? '',
    );
    factoryId =
        widget.initial?['primary_factory_id'] as String? ??
        (widget.factories.isEmpty
            ? null
            : widget.factories.first['id'] as String);
    departmentId = widget.initial?['department_id'] as String?;
    designationId = widget.initial?['designation_id'] as String?;
    shiftId = widget.initial?['shift_id'] as String?;
    userId = widget.initial?['user_id'] as String?;
    employmentType =
        widget.initial?['employment_type'] as String? ?? 'full_time';
  }

  @override
  void dispose() {
    name.dispose();
    code.dispose();
    phone.dispose();
    email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Add employee' : 'Edit employee'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Full name *'),
              ),
              const SizedBox(height: FactorySpacing.sm),
              TextField(
                controller: code,
                decoration: const InputDecoration(labelText: 'Employee ID *'),
              ),
              const SizedBox(height: FactorySpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: phone,
                      decoration: const InputDecoration(labelText: 'Phone'),
                    ),
                  ),
                  const SizedBox(width: FactorySpacing.sm),
                  Expanded(
                    child: TextField(
                      controller: email,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: FactorySpacing.sm),
              DropdownButtonFormField<String>(
                initialValue: factoryId,
                decoration: const InputDecoration(
                  labelText: 'Primary factory *',
                ),
                items: widget.factories
                    .map(
                      (factory) => DropdownMenuItem<String>(
                        value: factory['id'] as String,
                        child: Text(factory['name'] as String),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => factoryId = value),
              ),
              const SizedBox(height: FactorySpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      initialValue: departmentId,
                      decoration: const InputDecoration(
                        labelText: 'Department',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('None'),
                        ),
                        ...widget.departments.map(
                          (row) => DropdownMenuItem<String?>(
                            value: row['id'] as String,
                            child: Text(row['name'] as String),
                          ),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => departmentId = value),
                    ),
                  ),
                  const SizedBox(width: FactorySpacing.sm),
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      initialValue: designationId,
                      decoration: const InputDecoration(
                        labelText: 'Designation',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('None'),
                        ),
                        ...widget.designations.map(
                          (row) => DropdownMenuItem<String?>(
                            value: row['id'] as String,
                            child: Text(row['name'] as String),
                          ),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => designationId = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: FactorySpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      initialValue: shiftId,
                      decoration: const InputDecoration(labelText: 'Shift'),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('None'),
                        ),
                        ...widget.shifts.map(
                          (row) => DropdownMenuItem<String?>(
                            value: row['id'] as String,
                            child: Text(row['name'] as String),
                          ),
                        ),
                      ],
                      onChanged: (value) => setState(() => shiftId = value),
                    ),
                  ),
                  const SizedBox(width: FactorySpacing.sm),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: employmentType,
                      decoration: const InputDecoration(
                        labelText: 'Employment type',
                      ),
                      items:
                          const [
                                'full_time',
                                'part_time',
                                'contract',
                                'temporary',
                                'intern',
                              ]
                              .map(
                                (value) => DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(hrTitle(value)),
                                ),
                              )
                              .toList(),
                      onChanged: (value) =>
                          setState(() => employmentType = value ?? 'full_time'),
                    ),
                  ),
                ],
              ),
              if (widget.members.isNotEmpty) ...[
                const SizedBox(height: FactorySpacing.sm),
                DropdownButtonFormField<String?>(
                  initialValue: userId,
                  decoration: const InputDecoration(
                    labelText: 'Linked FactoryOS user (optional)',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Not linked'),
                    ),
                    ...widget.members.map((member) {
                      final fullName = member['full_name'] as String? ?? '';
                      final mail = member['email'] as String? ?? '';
                      return DropdownMenuItem<String?>(
                        value: member['user_id'] as String,
                        child: Text(
                          fullName.trim().isEmpty ? mail : '$fullName · $mail',
                        ),
                      );
                    }),
                  ],
                  onChanged: (value) => setState(() => userId = value),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (name.text.trim().length < 2 ||
                code.text.trim().length < 2 ||
                factoryId == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Name, employee ID and factory are required.'),
                ),
              );
              return;
            }
            Navigator.pop(context, <String, dynamic>{
              'employee_code': code.text.trim().toUpperCase(),
              'full_name': name.text.trim(),
              'email': hrNullable(email.text),
              'phone': hrNullable(phone.text),
              'primary_factory_id': factoryId,
              'department_id': departmentId,
              'designation_id': designationId,
              'shift_id': shiftId,
              'user_id': userId,
              'employment_type': employmentType,
              'join_date':
                  widget.initial?['join_date'] ?? hrDate(DateTime.now()),
              'status': widget.initial?['status'] ?? 'active',
            });
          },
          child: const Text('Save employee'),
        ),
      ],
    );
  }
}

class NameCodeEditor extends StatefulWidget {
  const NameCodeEditor({required this.title, this.initial, super.key});
  final String title;
  final Map<String, dynamic>? initial;

  @override
  State<NameCodeEditor> createState() => _NameCodeEditorState();
}

class _NameCodeEditorState extends State<NameCodeEditor> {
  late final TextEditingController name;
  late final TextEditingController code;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(
      text: widget.initial?['name'] as String? ?? '',
    );
    code = TextEditingController(
      text: widget.initial?['code'] as String? ?? '',
    );
  }

  @override
  void dispose() {
    name.dispose();
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 460,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: FactorySpacing.sm),
          TextField(
            controller: code,
            decoration: const InputDecoration(labelText: 'Code'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, <String, dynamic>{
          'name': name.text.trim(),
          'code': code.text.trim().toUpperCase(),
          'is_active': true,
        }),
        child: const Text('Save'),
      ),
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
  late final TextEditingController name;
  late final TextEditingController code;
  String? departmentId;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(
      text: widget.initial?['name'] as String? ?? '',
    );
    code = TextEditingController(
      text: widget.initial?['code'] as String? ?? '',
    );
    departmentId = widget.initial?['department_id'] as String?;
  }

  @override
  void dispose() {
    name.dispose();
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.initial == null ? 'Add designation' : 'Edit designation',
    ),
    content: SizedBox(
      width: 480,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: FactorySpacing.sm),
          TextField(
            controller: code,
            decoration: const InputDecoration(labelText: 'Code'),
          ),
          const SizedBox(height: FactorySpacing.sm),
          DropdownButtonFormField<String?>(
            initialValue: departmentId,
            decoration: const InputDecoration(labelText: 'Department'),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Any department'),
              ),
              ...widget.departments.map(
                (row) => DropdownMenuItem<String?>(
                  value: row['id'] as String,
                  child: Text(row['name'] as String),
                ),
              ),
            ],
            onChanged: (value) => setState(() => departmentId = value),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, <String, dynamic>{
          'name': name.text.trim(),
          'code': code.text.trim().toUpperCase(),
          'department_id': departmentId,
          'is_active': true,
        }),
        child: const Text('Save'),
      ),
    ],
  );
}

class ShiftEditor extends StatefulWidget {
  const ShiftEditor({required this.factories, this.initial, super.key});
  final List<Map<String, dynamic>> factories;
  final Map<String, dynamic>? initial;

  @override
  State<ShiftEditor> createState() => _ShiftEditorState();
}

class _ShiftEditorState extends State<ShiftEditor> {
  late final TextEditingController name;
  late final TextEditingController code;
  late final TextEditingController start;
  late final TextEditingController end;
  String? factoryId;
  bool crossesMidnight = false;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(
      text: widget.initial?['name'] as String? ?? '',
    );
    code = TextEditingController(
      text: widget.initial?['code'] as String? ?? '',
    );
    start = TextEditingController(
      text: _timeShort(widget.initial?['start_time']) ?? '06:00',
    );
    end = TextEditingController(
      text: _timeShort(widget.initial?['end_time']) ?? '14:00',
    );
    factoryId =
        widget.initial?['factory_id'] as String? ??
        (widget.factories.isEmpty
            ? null
            : widget.factories.first['id'] as String);
    crossesMidnight = widget.initial?['crosses_midnight'] as bool? ?? false;
  }

  @override
  void dispose() {
    name.dispose();
    code.dispose();
    start.dispose();
    end.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.initial == null ? 'Add shift' : 'Edit shift'),
    content: SizedBox(
      width: 500,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Shift name'),
          ),
          const SizedBox(height: FactorySpacing.sm),
          TextField(
            controller: code,
            decoration: const InputDecoration(labelText: 'Code'),
          ),
          const SizedBox(height: FactorySpacing.sm),
          DropdownButtonFormField<String?>(
            initialValue: factoryId,
            decoration: const InputDecoration(labelText: 'Factory'),
            items: widget.factories
                .map(
                  (factory) => DropdownMenuItem<String?>(
                    value: factory['id'] as String,
                    child: Text(factory['name'] as String),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => factoryId = value),
          ),
          const SizedBox(height: FactorySpacing.sm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: start,
                  decoration: const InputDecoration(labelText: 'Start HH:mm'),
                ),
              ),
              const SizedBox(width: FactorySpacing.sm),
              Expanded(
                child: TextField(
                  controller: end,
                  decoration: const InputDecoration(labelText: 'End HH:mm'),
                ),
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: crossesMidnight,
            title: const Text('Crosses midnight'),
            onChanged: (value) => setState(() => crossesMidnight = value),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, <String, dynamic>{
          'name': name.text.trim(),
          'code': code.text.trim().toUpperCase(),
          'factory_id': factoryId,
          'start_time': start.text.trim(),
          'end_time': end.text.trim(),
          'crosses_midnight': crossesMidnight,
          'grace_minutes': 10,
          'half_day_after_minutes': 240,
          'is_active': true,
        }),
        child: const Text('Save'),
      ),
    ],
  );
}

class LeaveTypeEditor extends StatefulWidget {
  const LeaveTypeEditor({this.initial, super.key});
  final Map<String, dynamic>? initial;

  @override
  State<LeaveTypeEditor> createState() => _LeaveTypeEditorState();
}

class _LeaveTypeEditorState extends State<LeaveTypeEditor> {
  late final TextEditingController name;
  late final TextEditingController code;
  late final TextEditingController maxDays;
  bool paid = true;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(
      text: widget.initial?['name'] as String? ?? '',
    );
    code = TextEditingController(
      text: widget.initial?['code'] as String? ?? '',
    );
    maxDays = TextEditingController(
      text: '${widget.initial?['max_days_per_year'] ?? ''}',
    );
    paid = widget.initial?['is_paid'] as bool? ?? true;
  }

  @override
  void dispose() {
    name.dispose();
    code.dispose();
    maxDays.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.initial == null ? 'Add leave type' : 'Edit leave type'),
    content: SizedBox(
      width: 460,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: FactorySpacing.sm),
          TextField(
            controller: code,
            decoration: const InputDecoration(labelText: 'Code'),
          ),
          const SizedBox(height: FactorySpacing.sm),
          TextField(
            controller: maxDays,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Max days/year (optional)',
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: paid,
            title: const Text('Paid leave'),
            onChanged: (value) => setState(() => paid = value),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, <String, dynamic>{
          'name': name.text.trim(),
          'code': code.text.trim().toUpperCase(),
          'is_paid': paid,
          'max_days_per_year': double.tryParse(maxDays.text.trim()),
          'requires_approval': true,
          'is_active': true,
        }),
        child: const Text('Save'),
      ),
    ],
  );
}

class HolidayEditor extends StatefulWidget {
  const HolidayEditor({required this.factories, this.initial, super.key});
  final List<Map<String, dynamic>> factories;
  final Map<String, dynamic>? initial;

  @override
  State<HolidayEditor> createState() => _HolidayEditorState();
}

class _HolidayEditorState extends State<HolidayEditor> {
  late final TextEditingController name;
  DateTime date = DateTime.now();
  String? factoryId;
  String type = 'company';

  @override
  void initState() {
    super.initState();
    name = TextEditingController(
      text: widget.initial?['name'] as String? ?? '',
    );
    final initialDate = widget.initial?['holiday_date'] as String?;
    if (initialDate != null) date = DateTime.parse(initialDate);
    factoryId = widget.initial?['factory_id'] as String?;
    type = widget.initial?['holiday_type'] as String? ?? 'company';
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.initial == null ? 'Add holiday' : 'Edit holiday'),
    content: SizedBox(
      width: 500,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Holiday name'),
          ),
          const SizedBox(height: FactorySpacing.sm),
          DropdownButtonFormField<String?>(
            initialValue: factoryId,
            decoration: const InputDecoration(labelText: 'Scope'),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('All factories'),
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
          const SizedBox(height: FactorySpacing.sm),
          DropdownButtonFormField<String>(
            initialValue: type,
            decoration: const InputDecoration(labelText: 'Type'),
            items:
                const ['national', 'state', 'festival', 'company', 'optional']
                    .map(
                      (value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(hrTitle(value)),
                      ),
                    )
                    .toList(),
            onChanged: (value) => setState(() => type = value ?? 'company'),
          ),
          const SizedBox(height: FactorySpacing.sm),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Date'),
            subtitle: Text(hrDate(date)),
            trailing: const Icon(Icons.calendar_month),
            onTap: () async {
              final value = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (value != null) setState(() => date = value);
            },
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, <String, dynamic>{
          'name': name.text.trim(),
          'holiday_date': hrDate(date),
          'factory_id': factoryId,
          'holiday_type': type,
          'is_active': true,
        }),
        child: const Text('Save'),
      ),
    ],
  );
}

String hrDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String hrTitle(String value) => value
    .replaceAll('_', ' ')
    .split(' ')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

String? hrNullable(String value) => value.trim().isEmpty ? null : value.trim();

String? _timeShort(dynamic value) {
  if (value == null) return null;
  final text = '$value';
  return text.length >= 5 ? text.substring(0, 5) : text;
}
