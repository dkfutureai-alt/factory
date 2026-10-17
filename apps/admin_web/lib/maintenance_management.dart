import 'package:factoryos_core/factoryos_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MaintenanceManagementPage extends StatefulWidget {
  const MaintenanceManagementPage({
    required this.organizationId,
    required this.actorRole,
    required this.factories,
    super.key,
  });

  final String organizationId;
  final AppRole actorRole;
  final List<Map<String, dynamic>> factories;

  @override
  State<MaintenanceManagementPage> createState() =>
      _MaintenanceManagementPageState();
}

class _MaintenanceManagementPageState extends State<MaintenanceManagementPage> {
  String? factoryId;
  String section = 'overview';
  Future<MaintenanceSnapshot>? future;

  MaintenanceRepository get repository =>
      MaintenanceRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    if (widget.factories.isNotEmpty) {
      factoryId = widget.factories.first['id'] as String;
      future = repository.load(widget.organizationId, factoryId!);
    }
  }

  void reload() {
    final id = factoryId;
    if (id == null) return;
    setState(() => future = repository.load(widget.organizationId, id));
  }

  void chooseFactory(String? id) {
    if (id == null || id == factoryId) return;
    setState(() {
      factoryId = id;
      future = repository.load(widget.organizationId, id);
    });
  }

  void message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  Future<void> run(Future<void> Function() action, String success) async {
    try {
      await action();
      if (!mounted) return;
      message(success);
      reload();
    } catch (error) {
      if (mounted) message(_errorText(error), error: true);
    }
  }

  Future<void> createAsset(MaintenanceSnapshot data) async {
    final code = TextEditingController();
    final name = TextEditingController();
    final maker = TextEditingController();
    final model = TextEditingController();
    final serial = TextEditingController();
    final qr = TextEditingController();
    final notes = TextEditingController();
    String type = 'equipment';
    String criticality = 'medium';
    String workCenterId = '';
    String locationId = '';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add asset / equipment'),
          scrollable: true,
          content: SizedBox(
            width: 560,
            child: Column(
              children: [
                TextField(
                  controller: code,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Asset code *'),
                ),
                const SizedBox(height: FactorySpacing.sm),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Asset name *'),
                ),
                const SizedBox(height: FactorySpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: type,
                        decoration: const InputDecoration(labelText: 'Type'),
                        items: const [
                          DropdownMenuItem(value: 'machine', child: Text('Machine')),
                          DropdownMenuItem(value: 'equipment', child: Text('Equipment')),
                          DropdownMenuItem(value: 'utility', child: Text('Utility')),
                          DropdownMenuItem(value: 'tool', child: Text('Tool')),
                          DropdownMenuItem(value: 'other', child: Text('Other')),
                        ],
                        onChanged: (value) => setDialogState(
                          () => type = value ?? 'equipment',
                        ),
                      ),
                    ),
                    const SizedBox(width: FactorySpacing.sm),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: criticality,
                        decoration: const InputDecoration(labelText: 'Criticality'),
                        items: _priorityItems,
                        onChanged: (value) => setDialogState(
                          () => criticality = value ?? 'medium',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: FactorySpacing.sm),
                DropdownButtonFormField<String>(
                  initialValue: workCenterId,
                  decoration: const InputDecoration(labelText: 'Work center'),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Not linked')),
                    ...data.workCenters.map(
                      (row) => DropdownMenuItem(
                        value: row['id'] as String,
                        child: Text('${row['name']} · ${row['code']}'),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => workCenterId = value ?? ''),
                ),
                const SizedBox(height: FactorySpacing.sm),
                DropdownButtonFormField<String>(
                  initialValue: locationId,
                  decoration: const InputDecoration(labelText: 'Factory location'),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Not linked')),
                    ...data.locations.map(
                      (row) => DropdownMenuItem(
                        value: row['id'] as String,
                        child: Text('${row['name']} · ${row['code']}'),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => locationId = value ?? ''),
                ),
                const SizedBox(height: FactorySpacing.sm),
                TextField(
                  controller: maker,
                  decoration: const InputDecoration(labelText: 'Manufacturer'),
                ),
                const SizedBox(height: FactorySpacing.sm),
                TextField(
                  controller: model,
                  decoration: const InputDecoration(labelText: 'Model'),
                ),
                const SizedBox(height: FactorySpacing.sm),
                TextField(
                  controller: serial,
                  decoration: const InputDecoration(labelText: 'Serial number'),
                ),
                const SizedBox(height: FactorySpacing.sm),
                TextField(
                  controller: qr,
                  decoration: const InputDecoration(labelText: 'QR code value'),
                ),
                const SizedBox(height: FactorySpacing.sm),
                TextField(
                  controller: notes,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Create asset'),
            ),
          ],
        ),
      ),
    );
    final values = (
      code: code.text.trim(),
      name: name.text.trim(),
      maker: maker.text.trim(),
      model: model.text.trim(),
      serial: serial.text.trim(),
      qr: qr.text.trim(),
      notes: notes.text.trim(),
    );
    for (final controller in [code, name, maker, model, serial, qr, notes]) {
      controller.dispose();
    }
    if (accepted != true || values.code.length < 2 || values.name.length < 2) {
      return;
    }
    await run(
      () => repository.createAsset(
        factoryId: factoryId!,
        code: values.code,
        name: values.name,
        type: type,
        criticality: criticality,
        workCenterId: _nullableId(workCenterId),
        locationId: _nullableId(locationId),
        manufacturer: values.maker,
        model: values.model,
        serialNo: values.serial,
        qrCode: values.qr,
        notes: values.notes,
      ),
      'Maintenance asset created.',
    );
  }

  Future<void> createRequest(MaintenanceSnapshot data) async {
    if (data.assets.isEmpty) {
      message('Create an asset first.', error: true);
      return;
    }
    String assetId = data.assets.first['id'] as String;
    String issueType = 'mechanical';
    String priority = 'medium';
    final description = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New maintenance request'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _AssetDropdown(
                  data: data,
                  value: assetId,
                  onChanged: (value) => setDialogState(() => assetId = value),
                ),
                const SizedBox(height: FactorySpacing.sm),
                DropdownButtonFormField<String>(
                  initialValue: issueType,
                  decoration: const InputDecoration(labelText: 'Issue type'),
                  items: const [
                    DropdownMenuItem(value: 'mechanical', child: Text('Mechanical')),
                    DropdownMenuItem(value: 'electrical', child: Text('Electrical')),
                    DropdownMenuItem(value: 'safety', child: Text('Safety')),
                    DropdownMenuItem(value: 'performance', child: Text('Performance')),
                    DropdownMenuItem(value: 'leak', child: Text('Leak')),
                    DropdownMenuItem(value: 'noise', child: Text('Noise')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (value) => setDialogState(
                    () => issueType = value ?? 'other',
                  ),
                ),
                const SizedBox(height: FactorySpacing.sm),
                DropdownButtonFormField<String>(
                  initialValue: priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: _priorityItems,
                  onChanged: (value) => setDialogState(
                    () => priority = value ?? 'medium',
                  ),
                ),
                const SizedBox(height: FactorySpacing.sm),
                TextField(
                  controller: description,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'Description *'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Submit request'),
            ),
          ],
        ),
      ),
    );
    final text = description.text.trim();
    description.dispose();
    if (accepted != true || text.length < 3) return;
    await run(
      () => repository.createRequest(
        assetId: assetId,
        issueType: issueType,
        priority: priority,
        description: text,
      ),
      'Maintenance request submitted.',
    );
  }

  Future<void> createPlan(MaintenanceSnapshot data) async {
    if (data.assets.isEmpty) {
      message('Create an asset first.', error: true);
      return;
    }
    String assetId = data.assets.first['id'] as String;
    String type = 'preventive';
    String frequencyUnit = 'months';
    String priority = 'medium';
    String technicianId = '';
    DateTime due = DateTime.now().add(const Duration(days: 7));
    final name = TextEditingController();
    final frequency = TextEditingController(text: '1');
    final estimated = TextEditingController(text: '60');
    final instructions = TextEditingController();
    final tasks = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create preventive schedule'),
          scrollable: true,
          content: SizedBox(
            width: 560,
            child: Column(
              children: [
                _AssetDropdown(
                  data: data,
                  value: assetId,
                  onChanged: (value) => setDialogState(() => assetId = value),
                ),
                const SizedBox(height: FactorySpacing.sm),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Plan name *'),
                ),
                const SizedBox(height: FactorySpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: type,
                        decoration: const InputDecoration(labelText: 'Type'),
                        items: const [
                          DropdownMenuItem(value: 'preventive', child: Text('Preventive')),
                          DropdownMenuItem(value: 'inspection', child: Text('Inspection')),
                          DropdownMenuItem(value: 'calibration', child: Text('Calibration')),
                        ],
                        onChanged: (value) => setDialogState(
                          () => type = value ?? 'preventive',
                        ),
                      ),
                    ),
                    const SizedBox(width: FactorySpacing.sm),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: priority,
                        decoration: const InputDecoration(labelText: 'Priority'),
                        items: _priorityItems,
                        onChanged: (value) => setDialogState(
                          () => priority = value ?? 'medium',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: FactorySpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: frequency,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Every'),
                      ),
                    ),
                    const SizedBox(width: FactorySpacing.sm),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: frequencyUnit,
                        decoration: const InputDecoration(labelText: 'Unit'),
                        items: const [
                          DropdownMenuItem(value: 'days', child: Text('Days')),
                          DropdownMenuItem(value: 'weeks', child: Text('Weeks')),
                          DropdownMenuItem(value: 'months', child: Text('Months')),
                        ],
                        onChanged: (value) => setDialogState(
                          () => frequencyUnit = value ?? 'months',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: FactorySpacing.sm),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_outlined),
                  title: const Text('Next due date'),
                  subtitle: Text(_date(due)),
                  trailing: const Icon(Icons.edit_calendar_outlined),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: due,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (picked != null) setDialogState(() => due = picked);
                  },
                ),
                DropdownButtonFormField<String>(
                  initialValue: technicianId,
                  decoration: const InputDecoration(labelText: 'Default technician'),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Unassigned')),
                    ...data.employees.map(
                      (row) => DropdownMenuItem(
                        value: row['id'] as String,
                        child: Text('${row['full_name']} · ${row['employee_code']}'),
                      ),
                    ),
                  ],
                  onChanged: (value) => setDialogState(
                    () => technicianId = value ?? '',
                  ),
                ),
                const SizedBox(height: FactorySpacing.sm),
                TextField(
                  controller: estimated,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Estimated minutes'),
                ),
                const SizedBox(height: FactorySpacing.sm),
                TextField(
                  controller: instructions,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Instructions'),
                ),
                const SizedBox(height: FactorySpacing.sm),
                TextField(
                  controller: tasks,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Checklist tasks (one per line)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Create schedule'),
            ),
          ],
        ),
      ),
    );
    final values = (
      name: name.text.trim(),
      frequency: int.tryParse(frequency.text.trim()) ?? 0,
      estimated: int.tryParse(estimated.text.trim()),
      instructions: instructions.text.trim(),
      tasks: tasks.text
          .split('\n')
          .map((value) => value.trim())
          .where((value) => value.length >= 2)
          .toList(),
    );
    for (final controller in [name, frequency, estimated, instructions, tasks]) {
      controller.dispose();
    }
    if (accepted != true || values.name.length < 2 || values.frequency <= 0) {
      return;
    }
    await run(() async {
      final planId = await repository.createPlan(
        assetId: assetId,
        name: values.name,
        type: type,
        frequencyUnit: frequencyUnit,
        frequencyValue: values.frequency,
        dueDate: _date(due),
        technicianId: _nullableId(technicianId),
        priority: priority,
        estimatedMinutes: values.estimated,
        instructions: values.instructions,
      );
      for (final task in values.tasks) {
        await repository.addPlanTask(planId, task);
      }
    }, 'Preventive schedule created.');
  }

  Future<void> createWorkOrder(
    MaintenanceSnapshot data, {
    Map<String, dynamic>? request,
  }) async {
    if (data.assets.isEmpty) {
      message('Create an asset first.', error: true);
      return;
    }
    String assetId = request?['asset_id'] as String? ??
        data.assets.first['id'] as String;
    String type = 'corrective';
    String priority = request?['priority'] as String? ?? 'medium';
    String technicianId = '';
    final problem = TextEditingController(
      text: request?['description'] as String? ?? '',
    );
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            request == null ? 'Create work order' : 'Convert request to work order',
          ),
          content: SizedBox(
            width: 540,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _AssetDropdown(
                  data: data,
                  value: assetId,
                  enabled: request == null,
                  onChanged: (value) => setDialogState(() => assetId = value),
                ),
                const SizedBox(height: FactorySpacing.sm),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(value: 'corrective', child: Text('Corrective')),
                    DropdownMenuItem(value: 'preventive', child: Text('Preventive')),
                    DropdownMenuItem(value: 'inspection', child: Text('Inspection')),
                    DropdownMenuItem(value: 'calibration', child: Text('Calibration')),
                  ],
                  onChanged: (value) => setDialogState(
                    () => type = value ?? 'corrective',
                  ),
                ),
                const SizedBox(height: FactorySpacing.sm),
                DropdownButtonFormField<String>(
                  initialValue: priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: _priorityItems,
                  onChanged: (value) => setDialogState(
                    () => priority = value ?? 'medium',
                  ),
                ),
                const SizedBox(height: FactorySpacing.sm),
                DropdownButtonFormField<String>(
                  initialValue: technicianId,
                  decoration: const InputDecoration(labelText: 'Assign technician'),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Unassigned')),
                    ...data.employees.map(
                      (row) => DropdownMenuItem(
                        value: row['id'] as String,
                        child: Text('${row['full_name']} · ${row['employee_code']}'),
                      ),
                    ),
                  ],
                  onChanged: (value) => setDialogState(
                    () => technicianId = value ?? '',
                  ),
                ),
                const SizedBox(height: FactorySpacing.sm),
                TextField(
                  controller: problem,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Problem / work description *',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Create work order'),
            ),
          ],
        ),
      ),
    );
    final text = problem.text.trim();
    problem.dispose();
    if (accepted != true || text.length < 3) return;
    await run(
      () => repository.createWorkOrder(
        assetId: assetId,
        type: type,
        priority: priority,
        problem: text,
        technicianId: _nullableId(technicianId),
        requestId: request?['id'] as String?,
      ),
      'Maintenance work order created.',
    );
  }

  Future<void> assignWorkOrder(
    MaintenanceSnapshot data,
    Map<String, dynamic> row,
  ) async {
    if (data.employees.isEmpty) {
      message('No active employees are available.', error: true);
      return;
    }
    String employeeId = row['assigned_employee_id'] as String? ??
        data.employees.first['id'] as String;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Assign technician'),
          content: DropdownButtonFormField<String>(
            initialValue: employeeId,
            decoration: const InputDecoration(labelText: 'Technician'),
            items: data.employees
                .map(
                  (employee) => DropdownMenuItem(
                    value: employee['id'] as String,
                    child: Text(
                      '${employee['full_name']} · ${employee['employee_code']}',
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) setDialogState(() => employeeId = value);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Assign'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true) return;
    await run(
      () => repository.assignWorkOrder(row['id'] as String, employeeId),
      'Technician assigned.',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.factories.isEmpty) {
      return const Center(child: Text('Create a factory before using Maintenance.'));
    }
    final currentFuture = future;
    if (currentFuture == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return FutureBuilder<MaintenanceSnapshot>(
      future: currentFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ErrorState(message: '${snapshot.error}', onRetry: reload);
        }
        final data = snapshot.requireData;
        return ListView(
          padding: const EdgeInsets.all(FactorySpacing.lg),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Maintenance',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      Text(
                        '${widget.actorRole.label} · Assets, PM, work orders, downtime & spares',
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 250,
                  child: DropdownButtonFormField<String>(
                    initialValue: factoryId,
                    decoration: const InputDecoration(labelText: 'Factory'),
                    items: widget.factories
                        .map(
                          (row) => DropdownMenuItem(
                            value: row['id'] as String,
                            child: Text(row['name'] as String),
                          ),
                        )
                        .toList(),
                    onChanged: chooseFactory,
                  ),
                ),
                const SizedBox(width: FactorySpacing.sm),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: reload,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: FactorySpacing.lg),
            _Metrics(summary: data.summary),
            const SizedBox(height: FactorySpacing.lg),
            Wrap(
              spacing: FactorySpacing.sm,
              runSpacing: FactorySpacing.sm,
              children: [
                for (final entry in const {
                  'overview': 'Overview',
                  'assets': 'Assets',
                  'requests': 'Requests',
                  'plans': 'Preventive',
                  'work_orders': 'Work Orders',
                  'parts': 'Parts & Downtime',
                }.entries)
                  ChoiceChip(
                    selected: section == entry.key,
                    label: Text(entry.value),
                    onSelected: (_) => setState(() => section = entry.key),
                  ),
              ],
            ),
            const SizedBox(height: FactorySpacing.md),
            if (section == 'overview') _overview(data),
            if (section == 'assets')
              _panel(
                context,
                'Assets & Equipment',
                [
                  FilledButton.icon(
                    onPressed: () => createAsset(data),
                    icon: const Icon(Icons.add),
                    label: const Text('Add asset'),
                  ),
                ],
                data.assets.isEmpty
                    ? const Text('No maintenance assets yet.')
                    : Column(
                        children: data.assets
                            .map((row) => _assetTile(data, row))
                            .toList(),
                      ),
              ),
            if (section == 'requests') _requests(data),
            if (section == 'plans') _plans(data),
            if (section == 'work_orders') _workOrders(data),
            if (section == 'parts') _parts(data),
          ],
        );
      },
    );
  }

  Widget _overview(MaintenanceSnapshot data) => LayoutBuilder(
        builder: (context, constraints) {
          final recent = _panel(
            context,
            'Recent Work Orders',
            const [],
            Column(
              children: data.workOrders.take(6).map((row) {
                final asset = data.asset(row['asset_id']);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.handyman_outlined),
                  title: Text(row['work_order_no'] as String),
                  subtitle: Text(
                    '${asset?['name'] ?? 'Asset'} · ${_label(row['maintenance_type'] as String)}',
                  ),
                  trailing: _StatusChip(row['status'] as String),
                );
              }).toList(),
            ),
          );
          final assets = _panel(
            context,
            'Asset Status',
            const [],
            Column(
              children: data.assets.take(6).map((row) => _assetTile(data, row)).toList(),
            ),
          );
          if (constraints.maxWidth <= 980) {
            return Column(
              children: [recent, const SizedBox(height: FactorySpacing.md), assets],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: recent),
              const SizedBox(width: FactorySpacing.md),
              Expanded(child: assets),
            ],
          );
        },
      );

  Widget _assetTile(MaintenanceSnapshot data, Map<String, dynamic> row) =>
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const CircleAvatar(
          child: Icon(Icons.precision_manufacturing_outlined),
        ),
        title: Text('${row['name']} (${row['asset_code']})'),
        subtitle: Text(
          '${_label(row['asset_type'] as String)} · ${_label(row['criticality'] as String)} criticality',
        ),
        trailing: _StatusChip(row['status'] as String),
      );

  Widget _requests(MaintenanceSnapshot data) => _panel(
        context,
        'Maintenance Requests',
        [
          FilledButton.icon(
            onPressed: () => createRequest(data),
            icon: const Icon(Icons.add_alert_outlined),
            label: const Text('New request'),
          ),
        ],
        data.requests.isEmpty
            ? const Text('No maintenance requests.')
            : Column(
                children: data.requests.map((row) {
                  final asset = data.asset(row['asset_id']);
                  final status = row['status'] as String;
                  return Card(
                    child: ListTile(
                      leading: _PriorityIcon(row['priority'] as String),
                      title: Text('${row['request_no']} · ${asset?['name'] ?? 'Asset'}'),
                      subtitle: Text('${_label(row['issue_type'] as String)} · ${row['description']}'),
                      trailing: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: FactorySpacing.xs,
                        children: [
                          _StatusChip(status),
                          if (status == 'open')
                            IconButton(
                              tooltip: 'Approve',
                              onPressed: () => run(
                                () => repository.decideRequest(
                                  row['id'] as String,
                                  'approved',
                                ),
                                'Request approved.',
                              ),
                              icon: const Icon(Icons.check_circle_outline),
                            ),
                          if (status == 'open')
                            IconButton(
                              tooltip: 'Reject',
                              onPressed: () => run(
                                () => repository.decideRequest(
                                  row['id'] as String,
                                  'rejected',
                                ),
                                'Request rejected.',
                              ),
                              icon: const Icon(Icons.cancel_outlined),
                            ),
                          if (status == 'open' || status == 'approved')
                            FilledButton.tonal(
                              onPressed: () => createWorkOrder(data, request: row),
                              child: const Text('Create WO'),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
      );

  Widget _plans(MaintenanceSnapshot data) => _panel(
        context,
        'Preventive Maintenance Schedule',
        [
          OutlinedButton.icon(
            onPressed: () => run(
              () => repository.generateDue(factoryId!),
              'Due preventive work orders generated.',
            ),
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('Generate due WOs'),
          ),
          FilledButton.icon(
            onPressed: () => createPlan(data),
            icon: const Icon(Icons.add),
            label: const Text('New schedule'),
          ),
        ],
        data.plans.isEmpty
            ? const Text('No preventive schedules.')
            : Column(
                children: data.plans.map((row) {
                  final asset = data.asset(row['asset_id']);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_repeat_outlined),
                    title: Text('${row['plan_no']} · ${asset?['name'] ?? 'Asset'}'),
                    subtitle: Text(
                      'Every ${row['frequency_value']} ${row['frequency_unit']} · ${_label(row['maintenance_type'] as String)}',
                    ),
                    trailing: Text('Due ${row['next_due_date']}'),
                  );
                }).toList(),
              ),
      );

  Widget _workOrders(MaintenanceSnapshot data) => _panel(
        context,
        'Work Orders',
        [
          FilledButton.icon(
            onPressed: () => createWorkOrder(data),
            icon: const Icon(Icons.add),
            label: const Text('Create work order'),
          ),
        ],
        data.workOrders.isEmpty
            ? const Text('No work orders.')
            : Column(
                children: data.workOrders.map((row) {
                  final asset = data.asset(row['asset_id']);
                  final employee = data.employee(row['assigned_employee_id']);
                  final status = row['status'] as String;
                  return Card(
                    child: ListTile(
                      leading: _PriorityIcon(row['priority'] as String),
                      title: Text('${row['work_order_no']} · ${asset?['name'] ?? 'Asset'}'),
                      subtitle: Text(
                        '${_label(row['maintenance_type'] as String)} · ${employee?['full_name'] ?? 'Unassigned'}\n${row['problem_description']}',
                      ),
                      isThreeLine: true,
                      trailing: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: FactorySpacing.xs,
                        children: [
                          _StatusChip(status),
                          if (status != 'completed' && status != 'cancelled')
                            IconButton(
                              tooltip: 'Assign technician',
                              onPressed: () => assignWorkOrder(data, row),
                              icon: const Icon(Icons.person_add_alt_1_outlined),
                            ),
                          if (status == 'open' || status == 'assigned' || status == 'on_hold')
                            FilledButton.tonal(
                              onPressed: () => run(
                                () => repository.startWorkOrder(row['id'] as String),
                                'Work order started.',
                              ),
                              child: const Text('Start'),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
      );

  Widget _parts(MaintenanceSnapshot data) => LayoutBuilder(
        builder: (context, constraints) {
          final parts = _panel(
            context,
            'Spare Parts Used',
            const [],
            data.spareUsage.isEmpty
                ? const Text('No maintenance spare usage recorded.')
                : Column(
                    children: data.spareUsage.take(12).map((row) {
                      final item = data.item(row['item_id']);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.build_circle_outlined),
                        title: Text(item?['name'] as String? ?? 'Spare item'),
                        subtitle: Text('Quantity ${row['quantity']}'),
                        trailing: Text('₹${row['line_cost']}'),
                      );
                    }).toList(),
                  ),
          );
          final downtime = _panel(
            context,
            'Downtime',
            const [],
            data.downtime.isEmpty
                ? const Text('No maintenance downtime recorded.')
                : Column(
                    children: data.downtime.take(12).map((row) {
                      final asset = data.asset(row['asset_id']);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.timer_outlined),
                        title: Text(asset?['name'] as String? ?? 'Asset'),
                        subtitle: Text(row['reason'] as String),
                        trailing: Text(
                          row['ended_at'] == null
                              ? 'Active'
                              : '${row['duration_minutes']} min',
                        ),
                      );
                    }).toList(),
                  ),
          );
          if (constraints.maxWidth <= 980) {
            return Column(
              children: [parts, const SizedBox(height: FactorySpacing.md), downtime],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: parts),
              const SizedBox(width: FactorySpacing.md),
              Expanded(child: downtime),
            ],
          );
        },
      );
}

class MaintenanceRepository {
  MaintenanceRepository(this.client);
  final SupabaseClient client;

  Future<MaintenanceSnapshot> load(String organizationId, String factoryId) async {
    final summary = Map<String, dynamic>.from(
      await client.rpc(
            'maintenance_dashboard_summary',
            params: {
              'p_organization_id': organizationId,
              'p_factory_id': factoryId,
            },
          )
          as Map,
    );
    final assets = List<Map<String, dynamic>>.from(
      await client
          .from('maintenance_assets')
          .select()
          .eq('factory_id', factoryId)
          .order('name'),
    );
    final requests = List<Map<String, dynamic>>.from(
      await client
          .from('maintenance_requests')
          .select()
          .eq('factory_id', factoryId)
          .order('created_at', ascending: false),
    );
    final plans = List<Map<String, dynamic>>.from(
      await client
          .from('maintenance_plans')
          .select()
          .eq('factory_id', factoryId)
          .order('next_due_date'),
    );
    final workOrders = List<Map<String, dynamic>>.from(
      await client
          .from('maintenance_work_orders')
          .select()
          .eq('factory_id', factoryId)
          .order('created_at', ascending: false),
    );
    final employees = List<Map<String, dynamic>>.from(
      await client
          .from('employees')
          .select('id,employee_code,full_name,status,primary_factory_id')
          .eq('primary_factory_id', factoryId)
          .eq('status', 'active')
          .order('full_name'),
    );
    final workCenters = List<Map<String, dynamic>>.from(
      await client
          .from('work_centers')
          .select('id,name,code')
          .eq('factory_id', factoryId)
          .eq('is_active', true)
          .order('name'),
    );
    final locations = List<Map<String, dynamic>>.from(
      await client
          .from('stock_locations')
          .select('id,name,code,location_type')
          .eq('factory_id', factoryId)
          .eq('is_active', true)
          .order('name'),
    );
    final items = List<Map<String, dynamic>>.from(
      await client
          .from('inventory_items')
          .select('id,sku,name,item_type,is_active')
          .eq('organization_id', organizationId)
          .eq('is_active', true)
          .order('name'),
    );
    final spareUsage = List<Map<String, dynamic>>.from(
      await client
          .from('maintenance_spare_usage')
          .select()
          .eq('factory_id', factoryId)
          .order('created_at', ascending: false),
    );
    final downtime = List<Map<String, dynamic>>.from(
      await client
          .from('maintenance_downtime_events')
          .select()
          .eq('factory_id', factoryId)
          .order('started_at', ascending: false),
    );
    return MaintenanceSnapshot(
      summary: summary,
      assets: assets,
      requests: requests,
      plans: plans,
      workOrders: workOrders,
      employees: employees,
      workCenters: workCenters,
      locations: locations,
      items: items,
      spareUsage: spareUsage,
      downtime: downtime,
    );
  }

  Future<void> createAsset({
    required String factoryId,
    required String code,
    required String name,
    required String type,
    required String criticality,
    required String? workCenterId,
    required String? locationId,
    required String manufacturer,
    required String model,
    required String serialNo,
    required String qrCode,
    required String notes,
  }) async {
    await client.rpc(
      'maintenance_create_asset',
      params: {
        'p_factory_id': factoryId,
        'p_asset_code': code,
        'p_name': name,
        'p_asset_type': type,
        'p_work_center_id': workCenterId,
        'p_location_id': locationId,
        'p_manufacturer': _nullable(manufacturer),
        'p_model': _nullable(model),
        'p_serial_no': _nullable(serialNo),
        'p_criticality': criticality,
        'p_qr_code': _nullable(qrCode),
        'p_notes': _nullable(notes),
      },
    );
  }

  Future<void> createRequest({
    required String assetId,
    required String issueType,
    required String priority,
    required String description,
  }) async {
    await client.rpc(
      'maintenance_create_request',
      params: {
        'p_asset_id': assetId,
        'p_issue_type': issueType,
        'p_priority': priority,
        'p_description': description,
      },
    );
  }

  Future<void> decideRequest(String id, String decision) async {
    await client.rpc(
      'maintenance_decide_request',
      params: {
        'p_request_id': id,
        'p_decision': decision,
        'p_note': decision == 'approved'
            ? 'Approved from Maintenance Admin'
            : 'Rejected from Maintenance Admin',
      },
    );
  }

  Future<String> createPlan({
    required String assetId,
    required String name,
    required String type,
    required String frequencyUnit,
    required int frequencyValue,
    required String dueDate,
    required String? technicianId,
    required String priority,
    required int? estimatedMinutes,
    required String instructions,
  }) async {
    final result = await client.rpc(
      'maintenance_create_plan',
      params: {
        'p_asset_id': assetId,
        'p_name': name,
        'p_maintenance_type': type,
        'p_frequency_unit': frequencyUnit,
        'p_frequency_value': frequencyValue,
        'p_next_due_date': dueDate,
        'p_default_technician_employee_id': technicianId,
        'p_default_priority': priority,
        'p_estimated_minutes': estimatedMinutes,
        'p_instructions': _nullable(instructions),
      },
    );
    return result as String;
  }

  Future<void> addPlanTask(String planId, String instruction) async {
    await client.rpc(
      'maintenance_add_plan_task',
      params: {
        'p_plan_id': planId,
        'p_instruction': instruction,
        'p_is_required': true,
      },
    );
  }

  Future<void> createWorkOrder({
    required String assetId,
    required String type,
    required String priority,
    required String problem,
    required String? technicianId,
    required String? requestId,
  }) async {
    await client.rpc(
      'maintenance_create_work_order',
      params: {
        'p_asset_id': assetId,
        'p_maintenance_type': type,
        'p_priority': priority,
        'p_problem_description': problem,
        'p_assigned_employee_id': technicianId,
        'p_request_id': requestId,
        'p_plan_id': null,
        'p_scheduled_at': null,
        'p_due_at': null,
      },
    );
  }

  Future<void> assignWorkOrder(String workOrderId, String employeeId) async {
    await client.rpc(
      'maintenance_assign_work_order',
      params: {
        'p_work_order_id': workOrderId,
        'p_employee_id': employeeId,
      },
    );
  }

  Future<void> startWorkOrder(String id) async {
    await client.rpc(
      'maintenance_start_work_order',
      params: {'p_work_order_id': id},
    );
  }

  Future<void> generateDue(String factoryId) async {
    await client.rpc(
      'maintenance_generate_due_work_orders',
      params: {'p_factory_id': factoryId, 'p_horizon_days': 7},
    );
  }
}

class MaintenanceSnapshot {
  const MaintenanceSnapshot({
    required this.summary,
    required this.assets,
    required this.requests,
    required this.plans,
    required this.workOrders,
    required this.employees,
    required this.workCenters,
    required this.locations,
    required this.items,
    required this.spareUsage,
    required this.downtime,
  });

  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> assets;
  final List<Map<String, dynamic>> requests;
  final List<Map<String, dynamic>> plans;
  final List<Map<String, dynamic>> workOrders;
  final List<Map<String, dynamic>> employees;
  final List<Map<String, dynamic>> workCenters;
  final List<Map<String, dynamic>> locations;
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> spareUsage;
  final List<Map<String, dynamic>> downtime;

  Map<String, dynamic>? asset(Object? id) => _find(assets, id);
  Map<String, dynamic>? employee(Object? id) => _find(employees, id);
  Map<String, dynamic>? item(Object? id) => _find(items, id);
}

class _Metrics extends StatelessWidget {
  const _Metrics({required this.summary});
  final Map<String, dynamic> summary;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: FactorySpacing.md,
        runSpacing: FactorySpacing.md,
        children: [
          _Metric('Open WOs', '${summary['open_work_orders'] ?? 0}', Icons.build_outlined),
          _Metric('In progress', '${summary['in_progress'] ?? 0}', Icons.settings_outlined),
          _Metric('Completed', '${summary['completed_month'] ?? 0}', Icons.check_circle_outline),
          _Metric('Overdue', '${summary['overdue'] ?? 0}', Icons.warning_amber_outlined),
          _Metric('Assets down', '${summary['assets_down'] ?? 0}', Icons.power_off_outlined),
          _Metric('PM due', '${summary['due_pm'] ?? 0}', Icons.event_repeat_outlined),
        ],
      );
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.icon);
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 180,
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
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
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

class _AssetDropdown extends StatelessWidget {
  const _AssetDropdown({
    required this.data,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final MaintenanceSnapshot data;
  final String value;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
        initialValue: value,
        decoration: const InputDecoration(labelText: 'Asset'),
        items: data.assets
            .map(
              (row) => DropdownMenuItem(
                value: row['id'] as String,
                child: Text('${row['asset_code']} · ${row['name']}'),
              ),
            )
            .toList(),
        onChanged: enabled
            ? (value) {
                if (value != null) onChanged(value);
              }
            : null,
      );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.status);
  final String status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = switch (status) {
      'completed' || 'running' || 'approved' => scheme.primaryContainer,
      'down' || 'rejected' => scheme.errorContainer,
      'in_progress' || 'maintenance' || 'converted' => scheme.tertiaryContainer,
      _ => scheme.secondaryContainer,
    };
    return Chip(
      backgroundColor: background,
      label: Text(_label(status)),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _PriorityIcon extends StatelessWidget {
  const _PriorityIcon(this.priority);
  final String priority;

  @override
  Widget build(BuildContext context) => CircleAvatar(
        child: Icon(
          priority == 'critical' || priority == 'high'
              ? Icons.priority_high
              : Icons.build_outlined,
        ),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(FactorySpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 52),
              const SizedBox(height: FactorySpacing.sm),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: FactorySpacing.md),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      );
}

Widget _panel(
  BuildContext context,
  String title,
  List<Widget> actions,
  Widget child,
) => Card(
      child: Padding(
        padding: const EdgeInsets.all(FactorySpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                Wrap(spacing: FactorySpacing.sm, children: actions),
              ],
            ),
            const SizedBox(height: FactorySpacing.md),
            child,
          ],
        ),
      ),
    );

const _priorityItems = [
  DropdownMenuItem(value: 'low', child: Text('Low')),
  DropdownMenuItem(value: 'medium', child: Text('Medium')),
  DropdownMenuItem(value: 'high', child: Text('High')),
  DropdownMenuItem(value: 'critical', child: Text('Critical')),
];

Map<String, dynamic>? _find(List<Map<String, dynamic>> rows, Object? id) {
  for (final row in rows) {
    if (row['id'] == id) return row;
  }
  return null;
}

String? _nullable(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String? _nullableId(String value) => value.isEmpty ? null : value;

String _label(String value) => value
    .split('_')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

String _errorText(Object error) {
  if (error is PostgrestException) return error.message;
  return '$error';
}
