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
    } catch (e) {
      if (mounted) message(_errorText(e), error: true);
    }
  }

  Future<void> createAsset(MaintenanceSnapshot data) async {
    final code = TextEditingController();
    final name = TextEditingController();
    final manufacturer = TextEditingController();
    final model = TextEditingController();
    final serial = TextEditingController();
    final qr = TextEditingController();
    final notes = TextEditingController();
    String type = 'equipment';
    String criticality = 'medium';
    String? workCenterId;
    String? locationId;
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
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(value: 'machine', child: Text('Machine')),
                    DropdownMenuItem(value: 'equipment', child: Text('Equipment')),
                    DropdownMenuItem(value: 'utility', child: Text('Utility')),
                    DropdownMenuItem(value: 'tool', child: Text('Tool')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => type = value ?? 'equipment'),
                ),
                const SizedBox(height: FactorySpacing.sm),
                DropdownButtonFormField<String>(
                  initialValue: criticality,
                  decoration: const InputDecoration(labelText: 'Criticality'),
                  items: const [
                    DropdownMenuItem(value: 'low', child: Text('Low')),
                    DropdownMenuItem(value: 'medium', child: Text('Medium')),
                    DropdownMenuItem(value: 'high', child: Text('High')),
                    DropdownMenuItem(value: 'critical', child: Text('Critical')),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => criticality = value ?? 'medium'),
                ),
                const SizedBox(height: FactorySpacing.sm),
                DropdownButtonFormField<String?>(
                  initialValue: workCenterId,
                  decoration: const InputDecoration(labelText: 'Work center'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Not linked'),
                    ),
                    ...data.workCenters.map(
                      (row) => DropdownMenuItem<String?>(
                        value: row['id'] as String,
                        child: Text('${row['name']} · ${row['code']}'),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => workCenterId = value),
                ),
                const SizedBox(height: FactorySpacing.sm),
                DropdownButtonFormField<String?>(
                  initialValue: locationId,
                  decoration: const InputDecoration(labelText: 'Factory location'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Not linked'),
                    ),
                    ...data.locations.map(
                      (row) => DropdownMenuItem<String?>(
                        value: row['id'] as String,
                        child: Text('${row['name']} · ${row['code']}'),
                      ),
                    ),
                  ],
                  onChanged: (value) => setDialogState(() => locationId = value),
                ),
                const SizedBox(height: FactorySpacing.sm),
                TextField(
                  controller: manufacturer,
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
      manufacturer: manufacturer.text.trim(),
      model: model.text.trim(),
      serial: serial.text.trim(),
      qr: qr.text.trim(),
      notes: notes.text.trim(),
    );
    for (final controller in [code, name, manufacturer, model, serial, qr, notes]) {
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
        workCenterId: workCenterId,
        locationId: locationId,
        manufacturer: values.manufacturer,
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
      return message('Create an asset first.', error: true);
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
                DropdownButtonFormField<String>(
                  initialValue: assetId,
                  decoration: const InputDecoration(labelText: 'Asset'),
                  items: data.assets
                      .map(
                        (row) => DropdownMenuItem(
                          value: row['id'] as String,
                          child: Text('${row['asset_code']} · ${row['name']}'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setDialogState(() => assetId = value);
                  },
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
                  onChanged: (value) =>
                      setDialogState(() => issueType = value ?? 'other'),
                ),
                const SizedBox(height: FactorySpacing.sm),
                DropdownButtonFormField<String>(
                  initialValue: priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: _priorityItems,
                  onChanged: (value) =>
                      setDialogState(() => priority = value ?? 'medium'),
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
    if (data.assets.isEmpty) return message('Create an asset first.', error: true);
    String assetId = data.assets.first['id'] as String;
    String type = 'preventive';
    String frequencyUnit = 'months';
    String priority = 'medium';
    String? technicianId;
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
                DropdownButtonFormField<String>(
                  initialValue: assetId,
                  decoration: const InputDecoration(labelText: 'Asset'),
                  items: data.assets
                      .map(
                        (row) => DropdownMenuItem(
                          value: row['id'] as String,
                          child: Text('${row['asset_code']} · ${row['name']}'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setDialogState(() => assetId = value);
                  },
                ),
                const SizedBox(height: FactorySpacing.sm),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Plan name *'),
                ),
                const SizedBox(height: FactorySpacing.sm),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Maintenance type'),
                  items: const [
                    DropdownMenuItem(value: 'preventive', child: Text('Preventive')),
                    DropdownMenuItem(value: 'inspection', child: Text('Inspection')),
                    DropdownMenuItem(value: 'calibration', child: Text('Calibration')),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => type = value ?? 'preventive'),
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
                DropdownButtonFormField<String?>(
                  initialValue: technicianId,
                  decoration: const InputDecoration(labelText: 'Default technician'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Unassigned'),
                    ),
                    ...data.employees.map(
                      (row) => DropdownMenuItem<String?>(
                        value: row['id'] as String,
                        child: Text('${row['full_name']} · ${row['employee_code']}'),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => technicianId = value),
                ),
                const SizedBox(height: FactorySpacing.sm),
                DropdownButtonFormField<String>(
                  initialValue: priority,
                  decoration: const InputDecoration(labelText: 'Default priority'),
                  items: _priorityItems,
                  onChanged: (value) =>
                      setDialogState(() => priority = value ?? 'medium'),
                ),
                const SizedBox(height: FactorySpacing.sm),
                TextField(
                  controller: estimated,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Estimated minutes',
                  ),
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
        technicianId: technicianId,
        priority: priority,
        estimatedMinutes: values.estimated,
        instructions: values.instructions,
      );
      for (final task in values.tasks) {
        await repository.addPlanTask(planId, task);
      }
    }, 'Preventive maintenance schedule created.');
  }

  Future<void> createWorkOrder(
    MaintenanceSnapshot data, {
    Map<String, dynamic>? request,
  }) async {
    if (data.assets.isEmpty) return message('Create an asset first.', error: true);
    String assetId = request?['asset_id'] as String? ?? data.assets.first['id'] as String;
    String type = request == null ? 'corrective' : 'corrective';
    String priority = request?['priority'] as String? ?? 'medium';
    String? technicianId;
    final problem = TextEditingController(
      text: request?['description'] as String? ?? '',
    );
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(request == null ? 'Create work order' : 'Convert request to work order'),
          content: SizedBox(
            width: 540,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: assetId,
                  decoration: const InputDecoration(labelText: 'Asset'),
                  items: data.assets
                      .map(
                        (row) => DropdownMenuItem(
                          value: row['id'] as String,
                          child: Text('${row['asset_code']} · ${row['name']}'),
                        ),
                      )
                      .toList(),
                  onChanged: request == null
                      ? (value) {
                          if (value != null) setDialogState(() => assetId = value);
                        }
                      : null,
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
                  onChanged: (value) =>
                      setDialogState(() => type = value ?? 'corrective'),
                ),
                const SizedBox(height: FactorySpacing.sm),
                DropdownButtonFormField<String>(
                  initialValue: priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: _priorityItems,
                  onChanged: (value) =>
                      setDialogState(() => priority = value ?? 'medium'),
                ),
                const SizedBox(height: FactorySpacing.sm),
                DropdownButtonFormField<String?>(
                  initialValue: technicianId,
                  decoration: const InputDecoration(labelText: 'Assign technician'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Unassigned'),
                    ),
                    ...data.employees.map(
                      (row) => DropdownMenuItem<String?>(
                        value: row['id'] as String,
                        child: Text('${row['full_name']} · ${row['employee_code']}'),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => technicianId = value),
                ),
                const SizedBox(height: FactorySpacing.sm),
                TextField(
                  controller: problem,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'Problem / work description *'),
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
        technicianId: technicianId,
        requestId: request?['id'] as String?,
      ),
      'Maintenance work order created.',
    );
  }

  Future<void> assignWorkOrder(
    MaintenanceSnapshot data,
    Map<String, dynamic> workOrder,
  ) async {
    if (data.employees.isEmpty) {
      return message('No active employees are available.', error: true);
    }
    String employeeId = workOrder['assigned_employee_id'] as String? ??
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
                  (row) => DropdownMenuItem(
                    value: row['id'] as String,
                    child: Text('${row['full_name']} · ${row['employee_code']}'),
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
      () => repository.assignWorkOrder(
        workOrder['id'] as String,
        employeeId,
      ),
      'Technician assigned.',
    );
  }

  Future<void> completeWorkOrder(Map<String, dynamic> workOrder) async {
    final resolution = TextEditingController();
    final labor = TextEditingController(text: '0');
    final external = TextEditingController(text: '0');
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Complete work order'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: resolution,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Resolution notes *'),
              ),
              const SizedBox(height: FactorySpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: labor,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Labor minutes'),
                    ),
                  ),
                  const SizedBox(width: FactorySpacing.sm),
                  Expanded(
                    child: TextField(
                      controller: external,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'External cost'),
                    ),
                  ),
                ],
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
            child: const Text('Complete'),
          ),
        ],
      ),
    );
    final values = (
      resolution: resolution.text.trim(),
      labor: int.tryParse(labor.text.trim()) ?? 0,
      external: double.tryParse(external.text.trim()) ?? 0,
    );
    resolution.dispose();
    labor.dispose();
    external.dispose();
    if (accepted != true || values.resolution.length < 3) return;
    await run(
      () => repository.completeWorkOrder(
        workOrder['id'] as String,
        values.resolution,
        values.labor,
        values.external,
      ),
      'Work order completed.',
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
              crossAxisAlignment: CrossAxisAlignment.start,
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
            if (section == 'overview') _OverviewSection(data: data),
            if (section == 'assets')
              _AssetsSection(
                data: data,
                onCreate: () => createAsset(data),
              ),
            if (section == 'requests')
              _RequestsSection(
                data: data,
                onCreate: () => createRequest(data),
                onApprove: (row) => run(
                  () => repository.decideRequest(row['id'] as String, 'approved'),
                  'Request approved.',
                ),
                onReject: (row) => run(
                  () => repository.decideRequest(row['id'] as String, 'rejected'),
                  'Request rejected.',
                ),
                onConvert: (row) => createWorkOrder(data, request: row),
              ),
            if (section == 'plans')
              _PlansSection(
                data: data,
                onCreate: () => createPlan(data),
                onGenerate: () => run(
                  () => repository.generateDue(factoryId!),
                  'Due preventive work orders generated.',
                ),
              ),
            if (section == 'work_orders')
              _WorkOrdersSection(
                data: data,
                onCreate: () => createWorkOrder(data),
                onAssign: (row) => assignWorkOrder(data, row),
                onStart: (row) => run(
                  () => repository.startWorkOrder(row['id'] as String),
                  'Work order started.',
                ),
                onComplete: completeWorkOrder,
              ),
            if (section == 'parts') _PartsDowntimeSection(data: data),
          ],
        );
      },
    );
  }
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
    final report = List<Map<String, dynamic>>.from(
      await client.rpc(
            'maintenance_work_order_report',
            params: {
              'p_factory_id': factoryId,
              'p_from': null,
              'p_to': null,
            },
          )
          as List,
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
      report: report,
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
        'p_note': decision == 'approved' ? 'Approved from Maintenance Admin' : 'Rejected from Maintenance Admin',
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

  Future<void> completeWorkOrder(
    String id,
    String resolution,
    int laborMinutes,
    double externalCost,
  ) async {
    await client.rpc(
      'maintenance_complete_work_order',
      params: {
        'p_work_order_id': id,
        'p_resolution_notes': resolution,
        'p_labor_minutes': laborMinutes,
        'p_external_cost': externalCost,
      },
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
    required this.report,
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
  final List<Map<String, dynamic>> report;

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

class _OverviewSection extends StatelessWidget {
  const _OverviewSection({required this.data});
  final MaintenanceSnapshot data;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth > 980;
          final children = [
            _Panel(
              title: 'Recent work orders',
              child: Column(
                children: data.workOrders.take(6).map((row) {
                  final asset = data.asset(row['asset_id']);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.handyman_outlined),
                    title: Text(row['work_order_no'] as String),
                    subtitle: Text('${asset?['name'] ?? 'Asset'} · ${_label(row['maintenance_type'] as String)}'),
                    trailing: _StatusChip(row['status'] as String),
                  );
                }).toList(),
              ),
            ),
            _Panel(
              title: 'Asset status',
              child: Column(
                children: data.assets.take(6).map((row) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.precision_manufacturing_outlined),
                      title: Text(row['name'] as String),
                      subtitle: Text('${row['asset_code']} · ${_label(row['criticality'] as String)} criticality'),
                      trailing: _StatusChip(row['status'] as String),
                    )).toList(),
              ),
            ),
          ];
          return wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [Expanded(child: children[0]), const SizedBox(width: FactorySpacing.md), Expanded(child: children[1])],
                )
              : Column(children: [children[0], const SizedBox(height: FactorySpacing.md), children[1]]);
        },
      );
}

class _AssetsSection extends StatelessWidget {
  const _AssetsSection({required this.data, required this.onCreate});
  final MaintenanceSnapshot data;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => _Panel(
        title: 'Assets & Equipment',
        action: FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add),
          label: const Text('Add asset'),
        ),
        child: data.assets.isEmpty
            ? const Text('No maintenance assets yet.')
            : Column(
                children: data.assets.map((row) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(child: Icon(Icons.precision_manufacturing_outlined)),
                      title: Text('${row['name']} (${row['asset_code']})'),
                      subtitle: Text('${_label(row['asset_type'] as String)} · ${_label(row['criticality'] as String)} criticality${row['model'] == null ? '' : ' · ${row['model']}'}'),
                      trailing: _StatusChip(row['status'] as String),
                    )).toList(),
              ),
      );
}

class _RequestsSection extends StatelessWidget {
  const _RequestsSection({
    required this.data,
    required this.onCreate,
    required this.onApprove,
    required this.onReject,
    required this.onConvert,
  });
  final MaintenanceSnapshot data;
  final VoidCallback onCreate;
  final ValueChanged<Map<String, dynamic>> onApprove;
  final ValueChanged<Map<String, dynamic>> onReject;
  final ValueChanged<Map<String, dynamic>> onConvert;

  @override
  Widget build(BuildContext context) => _Panel(
        title: 'Maintenance Requests',
        action: FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add_alert_outlined),
          label: const Text('New request'),
        ),
        child: data.requests.isEmpty
            ? const Text('No maintenance requests.')
            : Column(
                children: data.requests.map((row) {
                  final asset = data.asset(row['asset_id']);
                  final open = row['status'] == 'open';
                  final approved = row['status'] == 'approved';
                  return Card(
                    child: ListTile(
                      title: Text('${row['request_no']} · ${asset?['name'] ?? 'Asset'}'),
                      subtitle: Text('${_label(row['issue_type'] as String)} · ${row['description']}'),
                      leading: _PriorityIcon(row['priority'] as String),
                      trailing: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: FactorySpacing.xs,
                        children: [
                          _StatusChip(row['status'] as String),
                          if (open)
                            IconButton(
                              tooltip: 'Approve',
                              onPressed: () => onApprove(row),
                              icon: const Icon(Icons.check_circle_outline),
                            ),
                          if (open)
                            IconButton(
                              tooltip: 'Reject',
                              onPressed: () => onReject(row),
                              icon: const Icon(Icons.cancel_outlined),
                            ),
                          if (open || approved)
                            FilledButton.tonal(
                              onPressed: () => onConvert(row),
                              child: const Text('Create WO'),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
      );
}

class _PlansSection extends StatelessWidget {
  const _PlansSection({required this.data, required this.onCreate, required this.onGenerate});
  final MaintenanceSnapshot data;
  final VoidCallback onCreate;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) => _Panel(
        title: 'Preventive Maintenance Schedule',
        action: Wrap(
          spacing: FactorySpacing.sm,
          children: [
            OutlinedButton.icon(
              onPressed: onGenerate,
              icon: const Icon(Icons.auto_awesome_outlined),
              label: const Text('Generate due WOs'),
            ),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('New schedule'),
            ),
          ],
        ),
        child: data.plans.isEmpty
            ? const Text('No preventive schedules.')
            : Column(
                children: data.plans.map((row) {
                  final asset = data.asset(row['asset_id']);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_repeat_outlined),
                    title: Text('${row['plan_no']} · ${asset?['name'] ?? 'Asset'}'),
                    subtitle: Text('Every ${row['frequency_value']} ${row['frequency_unit']} · ${_label(row['maintenance_type'] as String)}'),
                    trailing: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Due ${row['next_due_date']}'),
                        Text(row['is_active'] == true ? 'Active' : 'Inactive'),
                      ],
                    ),
                  );
                }).toList(),
              ),
      );
}

class _WorkOrdersSection extends StatelessWidget {
  const _WorkOrdersSection({
    required this.data,
    required this.onCreate,
    required this.onAssign,
    required this.onStart,
    required this.onComplete,
  });
  final MaintenanceSnapshot data;
  final VoidCallback onCreate;
  final ValueChanged<Map<String, dynamic>> onAssign;
  final ValueChanged<Map<String, dynamic>> onStart;
  final ValueChanged<Map<String, dynamic>> onComplete;

  @override
  Widget build(BuildContext context) => _Panel(
        title: 'Work Orders',
        action: FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add),
          label: const Text('Create work order'),
        ),
        child: data.workOrders.isEmpty
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
                      subtitle: Text('${_label(row['maintenance_type'] as String)} · ${employee?['full_name'] ?? 'Unassigned'}\n${row['problem_description']}'),
                      isThreeLine: true,
                      trailing: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: FactorySpacing.xs,
                        children: [
                          _StatusChip(status),
                          if (!const {'completed', 'cancelled'}.contains(status))
                            IconButton(
                              tooltip: 'Assign technician',
                              onPressed: () => onAssign(row),
                              icon: const Icon(Icons.person_add_alt_1_outlined),
                            ),
                          if (const {'open', 'assigned', 'on_hold'}.contains(status))
                            FilledButton.tonal(
                              onPressed: () => onStart(row),
                              child: const Text('Start'),
                            ),
                          if (const {'in_progress', 'on_hold'}.contains(status))
                            FilledButton(
                              onPressed: () => onComplete(row),
                              child: const Text('Complete'),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
      );
}

class _PartsDowntimeSection extends StatelessWidget {
  const _PartsDowntimeSection({required this.data});
  final MaintenanceSnapshot data;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final usage = _Panel(
            title: 'Spare Parts Used',
            child: data.spareUsage.isEmpty
                ? const Text('No maintenance spare usage recorded.')
                : Column(
                    children: data.spareUsage.take(12).map((row) {
                      final item = data.item(row['item_id']);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.build_circle_outlined),
                        title: Text(item?['name'] as String? ?? 'Spare item'),
                        subtitle: Text('${row['quantity']} used · ${row['created_at']}'),
                        trailing: Text('₹${row['line_cost']}'),
                      );
                    }).toList(),
                  ),
          );
          final downtime = _Panel(
            title: 'Downtime',
            child: data.downtime.isEmpty
                ? const Text('No maintenance downtime recorded.')
                : Column(
                    children: data.downtime.take(12).map((row) {
                      final asset = data.asset(row['asset_id']);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.timer_outlined),
                        title: Text(asset?['name'] as String? ?? 'Asset'),
                        subtitle: Text(row['reason'] as String),
                        trailing: Text(row['ended_at'] == null ? 'Active' : '${row['duration_minutes']} min'),
                      );
                    }).toList(),
                  ),
          );
          return constraints.maxWidth > 980
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [Expanded(child: usage), const SizedBox(width: FactorySpacing.md), Expanded(child: downtime)],
                )
              : Column(children: [usage, const SizedBox(height: FactorySpacing.md), downtime]);
        },
      );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child, this.action});
  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Card(
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
                  if (action != null) action!,
                ],
              ),
              const SizedBox(height: FactorySpacing.md),
              child,
            ],
          ),
        ),
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
      'down' || 'overdue' || 'rejected' => scheme.errorContainer,
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
