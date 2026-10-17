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

class _MaintenanceManagementPageState
    extends State<MaintenanceManagementPage> {
  String? factoryId;
  String section = 'work';
  String workFilter = 'open';
  String? selectedWorkOrderId;
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

  void chooseFactory(String? value) {
    if (value == null || value == factoryId) return;
    setState(() {
      factoryId = value;
      selectedWorkOrderId = null;
      future = repository.load(widget.organizationId, value);
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

  Future<void> generateDueWork() async {
    final id = factoryId;
    if (id == null) return;
    try {
      final count = await repository.generateDueWork(id);
      if (!mounted) return;
      message('$count due maintenance work order(s) generated.');
      reload();
    } catch (error) {
      if (mounted) message(_errorText(error), error: true);
    }
  }

  Future<void> createAsset() async {
    final id = factoryId;
    if (id == null) return;
    final code = TextEditingController();
    final name = TextEditingController();
    final maker = TextEditingController();
    final model = TextEditingController();
    final serial = TextEditingController();
    final area = TextEditingController();
    final meter = TextEditingController(text: '0');
    String category = 'machine';
    String criticality = 'medium';
    String meterType = 'none';
    final draft = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New maintenance asset'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: code,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Asset code'),
                  ),
                  const SizedBox(height: FactorySpacing.sm),
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Asset name'),
                  ),
                  const SizedBox(height: FactorySpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: category,
                          decoration: const InputDecoration(labelText: 'Category'),
                          items: const [
                            'machine',
                            'utility',
                            'electrical',
                            'safety',
                            'tool',
                            'building',
                            'vehicle_support',
                            'other',
                          ]
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(_title(value)),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setDialogState(() => category = value ?? category),
                        ),
                      ),
                      const SizedBox(width: FactorySpacing.sm),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: criticality,
                          decoration:
                              const InputDecoration(labelText: 'Criticality'),
                          items: const ['low', 'medium', 'high', 'critical']
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(_title(value)),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => setDialogState(
                            () => criticality = value ?? criticality,
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
                          controller: maker,
                          decoration:
                              const InputDecoration(labelText: 'Manufacturer'),
                        ),
                      ),
                      const SizedBox(width: FactorySpacing.sm),
                      Expanded(
                        child: TextField(
                          controller: model,
                          decoration: const InputDecoration(labelText: 'Model'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: FactorySpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: serial,
                          decoration:
                              const InputDecoration(labelText: 'Serial number'),
                        ),
                      ),
                      const SizedBox(width: FactorySpacing.sm),
                      Expanded(
                        child: TextField(
                          controller: area,
                          decoration: const InputDecoration(labelText: 'Area'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: FactorySpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: meterType,
                          decoration:
                              const InputDecoration(labelText: 'Meter type'),
                          items: const ['none', 'hours', 'cycles', 'km']
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(_title(value)),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => setDialogState(
                            () => meterType = value ?? meterType,
                          ),
                        ),
                      ),
                      const SizedBox(width: FactorySpacing.sm),
                      Expanded(
                        child: TextField(
                          controller: meter,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration:
                              const InputDecoration(labelText: 'Current meter'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final normalizedCode = code.text.trim().toUpperCase();
                if (normalizedCode.length < 2 || name.text.trim().length < 2) {
                  return;
                }
                Navigator.pop(dialogContext, {
                  'asset_code': normalizedCode,
                  'name': name.text.trim(),
                  'category': category,
                  'criticality': criticality,
                  'manufacturer': _emptyToNull(maker.text),
                  'model': _emptyToNull(model.text),
                  'serial_number': _emptyToNull(serial.text),
                  'area': _emptyToNull(area.text),
                  'meter_type': meterType,
                  'current_meter': double.tryParse(meter.text.trim()) ?? 0,
                });
              },
              child: const Text('Create asset'),
            ),
          ],
        ),
      ),
    );
    code.dispose();
    name.dispose();
    maker.dispose();
    model.dispose();
    serial.dispose();
    area.dispose();
    meter.dispose();
    if (draft == null) return;
    await run(
      () => repository.createAsset(widget.organizationId, id, draft),
      'Maintenance asset created.',
    );
  }

  Future<void> createPlan(MaintenanceSnapshot data) async {
    final id = factoryId;
    if (id == null || data.assets.isEmpty) {
      return message('Create an active asset first.', error: true);
    }
    String assetId = data.assets.first['id'] as String;
    String type = 'preventive';
    final code = TextEditingController();
    final title = TextEditingController();
    final frequency = TextEditingController(text: '30');
    final minutes = TextEditingController(text: '60');
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New preventive plan'),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: assetId,
                  decoration: const InputDecoration(labelText: 'Asset'),
                  items: data.assets
                      .where((row) => row['is_active'] == true)
                      .map(
                        (row) => DropdownMenuItem(
                          value: row['id'] as String,
                          child: Text('${row['asset_code']} · ${row['name']}'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => assetId = value ?? assetId),
                ),
                const SizedBox(height: FactorySpacing.sm),
                TextField(
                  controller: code,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Plan code'),
                ),
                const SizedBox(height: FactorySpacing.sm),
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Plan title'),
                ),
                const SizedBox(height: FactorySpacing.sm),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration:
                      const InputDecoration(labelText: 'Maintenance type'),
                  items: const [
                    'preventive',
                    'inspection',
                    'calibration',
                    'lubrication',
                    'cleaning',
                    'other',
                  ]
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(_title(value)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => type = value ?? type),
                ),
                const SizedBox(height: FactorySpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: frequency,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Every N days'),
                      ),
                    ),
                    const SizedBox(width: FactorySpacing.sm),
                    Expanded(
                      child: TextField(
                        controller: minutes,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Estimated minutes',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final days = int.tryParse(frequency.text.trim());
                if (code.text.trim().length < 2 ||
                    title.text.trim().length < 3 ||
                    days == null ||
                    days <= 0) {
                  return;
                }
                Navigator.pop(dialogContext, {
                  'asset_id': assetId,
                  'plan_code': code.text.trim().toUpperCase(),
                  'title': title.text.trim(),
                  'maintenance_type': type,
                  'frequency_days': days,
                  'estimated_minutes': int.tryParse(minutes.text.trim()),
                  'next_due_at': DateTime.now()
                      .add(Duration(days: days))
                      .toUtc()
                      .toIso8601String(),
                });
              },
              child: const Text('Create plan'),
            ),
          ],
        ),
      ),
    );
    code.dispose();
    title.dispose();
    frequency.dispose();
    minutes.dispose();
    if (result == null) return;
    await run(
      () => repository.createPlan(widget.organizationId, id, result),
      'Maintenance plan created.',
    );
  }

  Future<void> createWorkOrder(
    MaintenanceSnapshot data, {
    Map<String, dynamic>? request,
  }) async {
    if (data.assets.isEmpty) {
      return message('Create an asset first.', error: true);
    }
    String assetId = request?['asset_id'] as String? ?? data.assets.first['id'] as String;
    String type = request?['request_type'] == 'breakdown'
        ? 'breakdown'
        : 'corrective';
    String priority = request?['priority'] as String? ?? 'medium';
    String? employeeId;
    final title = TextEditingController(
      text: request?['title'] as String? ?? '',
    );
    final description = TextEditingController(
      text: request?['description'] as String? ?? '',
    );
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(request == null ? 'New work order' : 'Create from request'),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
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
                        ? (value) => setDialogState(
                            () => assetId = value ?? assetId,
                          )
                        : null,
                  ),
                  const SizedBox(height: FactorySpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: type,
                          decoration:
                              const InputDecoration(labelText: 'Work type'),
                          items: const [
                            'preventive',
                            'breakdown',
                            'corrective',
                            'inspection',
                            'calibration',
                            'lubrication',
                            'other',
                          ]
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(_title(value)),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setDialogState(() => type = value ?? type),
                        ),
                      ),
                      const SizedBox(width: FactorySpacing.sm),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: priority,
                          decoration:
                              const InputDecoration(labelText: 'Priority'),
                          items: const ['low', 'medium', 'high', 'critical']
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(_title(value)),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => setDialogState(
                            () => priority = value ?? priority,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: FactorySpacing.sm),
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  const SizedBox(height: FactorySpacing.sm),
                  TextField(
                    controller: description,
                    minLines: 2,
                    maxLines: 4,
                    decoration:
                        const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: FactorySpacing.sm),
                  DropdownButtonFormField<String?>(
                    initialValue: employeeId,
                    decoration:
                        const InputDecoration(labelText: 'Assign technician'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Unassigned'),
                      ),
                      ...data.employees.map(
                        (row) => DropdownMenuItem<String?>(
                          value: row['id'] as String,
                          child: Text('${row['employee_code']} · ${row['full_name']}'),
                        ),
                      ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => employeeId = value),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: title.text.trim().length < 3
                  ? null
                  : () => Navigator.pop(dialogContext, {
                        'asset_id': assetId,
                        'work_type': type,
                        'priority': priority,
                        'title': title.text.trim(),
                        'description': _emptyToNull(description.text),
                        'request_id': request?['id'],
                        'assigned_employee_id': employeeId,
                      }),
              child: const Text('Create work order'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    description.dispose();
    if (result == null) return;
    await run(
      () => repository.createWorkOrder(result),
      'Maintenance work order created.',
    );
  }

  Future<void> assignWorkOrder(
    MaintenanceSnapshot data,
    Map<String, dynamic> row,
  ) async {
    if (data.employees.isEmpty) {
      return message('No active factory employees found.', error: true);
    }
    String employeeId =
        row['assigned_employee_id'] as String? ?? data.employees.first['id'] as String;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Assign ${row['work_order_no']}'),
          content: DropdownButtonFormField<String>(
            initialValue: employeeId,
            decoration: const InputDecoration(labelText: 'Technician'),
            items: data.employees
                .map(
                  (employee) => DropdownMenuItem(
                    value: employee['id'] as String,
                    child: Text(
                      '${employee['employee_code']} · ${employee['full_name']}',
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) =>
                setDialogState(() => employeeId = value ?? employeeId),
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

  Future<void> holdWorkOrder(Map<String, dynamic> row) async {
    final reason = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Put ${row['work_order_no']} on hold'),
        content: TextField(
          controller: reason,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Reason'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hold'),
          ),
        ],
      ),
    );
    final value = reason.text.trim();
    reason.dispose();
    if (accepted != true || value.length < 3) return;
    await run(
      () => repository.holdWorkOrder(row['id'] as String, value),
      'Work order put on hold.',
    );
  }

  Future<void> completeWorkOrder(Map<String, dynamic> row) async {
    final resolution = TextEditingController();
    final rootCause = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Complete ${row['work_order_no']}'),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: resolution,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Resolution'),
              ),
              const SizedBox(height: FactorySpacing.sm),
              TextField(
                controller: rootCause,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Root cause'),
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
    final resolutionValue = resolution.text.trim();
    final rootCauseValue = rootCause.text.trim();
    resolution.dispose();
    rootCause.dispose();
    if (accepted != true || resolutionValue.length < 3) return;
    await run(
      () => repository.completeWorkOrder(
        row['id'] as String,
        resolutionValue,
        _emptyToNull(rootCauseValue),
      ),
      'Work order completed.',
    );
  }

  Future<void> issuePart(
    MaintenanceSnapshot data,
    Map<String, dynamic> row,
  ) async {
    final spareItems = data.items
        .where(
          (item) => const {'spare', 'consumable', 'other'}
              .contains(item['item_type']),
        )
        .toList();
    if (spareItems.isEmpty || data.locations.isEmpty) {
      return message('No spare items or stock locations are available.', error: true);
    }
    String itemId = spareItems.first['id'] as String;
    String locationId = data.locations.first['id'] as String;
    final quantity = TextEditingController(text: '1');
    final note = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Issue spare · ${row['work_order_no']}'),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: itemId,
                  decoration: const InputDecoration(labelText: 'Item'),
                  items: spareItems
                      .map(
                        (item) => DropdownMenuItem(
                          value: item['id'] as String,
                          child: Text('${item['sku']} · ${item['name']}'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => itemId = value ?? itemId),
                ),
                const SizedBox(height: FactorySpacing.sm),
                DropdownButtonFormField<String>(
                  initialValue: locationId,
                  decoration:
                      const InputDecoration(labelText: 'Source location'),
                  items: data.locations
                      .map(
                        (location) => DropdownMenuItem(
                          value: location['id'] as String,
                          child: Text(
                            '${location['code']} · ${location['name']}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => locationId = value ?? locationId),
                ),
                const SizedBox(height: FactorySpacing.sm),
                TextField(
                  controller: quantity,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Quantity'),
                ),
                const SizedBox(height: FactorySpacing.sm),
                TextField(
                  controller: note,
                  decoration: const InputDecoration(labelText: 'Note'),
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
              child: const Text('Issue'),
            ),
          ],
        ),
      ),
    );
    final amount = double.tryParse(quantity.text.trim());
    final noteValue = _emptyToNull(note.text);
    quantity.dispose();
    note.dispose();
    if (accepted != true || amount == null || amount <= 0) return;
    await run(
      () => repository.issuePart(
        row['id'] as String,
        itemId,
        locationId,
        amount,
        noteValue,
      ),
      'Spare issued through Inventory ledger.',
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
          return _MaintenanceError(message: '${snapshot.error}', onRetry: reload);
        }
        final data = snapshot.requireData;
        return ListView(
          padding: const EdgeInsets.all(FactorySpacing.lg),
          children: [
            _Header(
              factories: widget.factories,
              factoryId: factoryId!,
              onFactoryChanged: chooseFactory,
              onRefresh: reload,
              onGenerate: generateDueWork,
              onNewAsset: createAsset,
              onNewPlan: () => createPlan(data),
              onNewWork: () => createWorkOrder(data),
            ),
            const SizedBox(height: FactorySpacing.lg),
            _Metrics(summary: data.summary),
            const SizedBox(height: FactorySpacing.lg),
            Wrap(
              spacing: FactorySpacing.sm,
              runSpacing: FactorySpacing.sm,
              children: [
                _SectionChip(
                  label: 'Work orders',
                  selected: section == 'work',
                  onTap: () => setState(() => section = 'work'),
                ),
                _SectionChip(
                  label: 'Assets',
                  selected: section == 'assets',
                  onTap: () => setState(() => section = 'assets'),
                ),
                _SectionChip(
                  label: 'Preventive plans',
                  selected: section == 'plans',
                  onTap: () => setState(() => section = 'plans'),
                ),
                _SectionChip(
                  label: 'Requests',
                  selected: section == 'requests',
                  onTap: () => setState(() => section = 'requests'),
                ),
              ],
            ),
            const SizedBox(height: FactorySpacing.md),
            if (section == 'work') _buildWorkOrders(data),
            if (section == 'assets') _AssetList(data: data),
            if (section == 'plans') _PlanList(data: data),
            if (section == 'requests')
              _RequestList(
                data: data,
                onCreateWork: (row) => createWorkOrder(data, request: row),
              ),
          ],
        );
      },
    );
  }

  Widget _buildWorkOrders(MaintenanceSnapshot data) {
    final openStatuses = {'planned', 'assigned', 'in_progress', 'on_hold'};
    final rows = data.workOrders.where((row) {
      if (workFilter == 'all') return true;
      if (workFilter == 'open') return openStatuses.contains(row['status']);
      return row['status'] == workFilter;
    }).toList();
    if (selectedWorkOrderId == null && rows.isNotEmpty) {
      selectedWorkOrderId = rows.first['id'] as String;
    }
    Map<String, dynamic>? selected;
    for (final row in data.workOrders) {
      if (row['id'] == selectedWorkOrderId) selected = row;
    }
    final wide = MediaQuery.sizeOf(context).width > 1160;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: FactorySpacing.xs,
          children: ['open', 'in_progress', 'on_hold', 'completed', 'all']
              .map(
                (value) => ChoiceChip(
                  label: Text(_title(value)),
                  selected: workFilter == value,
                  onSelected: (_) => setState(() => workFilter = value),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: FactorySpacing.md),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: _WorkOrderList(
                  data: data,
                  rows: rows,
                  selectedId: selectedWorkOrderId,
                  onSelect: (id) => setState(() => selectedWorkOrderId = id),
                ),
              ),
              const SizedBox(width: FactorySpacing.md),
              Expanded(
                flex: 4,
                child: _WorkOrderDetail(
                  data: data,
                  row: selected,
                  onAssign: selected == null
                      ? null
                      : () => assignWorkOrder(data, selected!),
                  onStart: selected == null
                      ? null
                      : () => run(
                            () => repository.startWorkOrder(
                              selected!['id'] as String,
                            ),
                            'Work order started.',
                          ),
                  onHold: selected == null
                      ? null
                      : () => holdWorkOrder(selected!),
                  onResume: selected == null
                      ? null
                      : () => run(
                            () => repository.resumeWorkOrder(
                              selected!['id'] as String,
                            ),
                            'Work order resumed.',
                          ),
                  onIssuePart: selected == null
                      ? null
                      : () => issuePart(data, selected!),
                  onComplete: selected == null
                      ? null
                      : () => completeWorkOrder(selected!),
                ),
              ),
            ],
          )
        else ...[
          _WorkOrderList(
            data: data,
            rows: rows,
            selectedId: selectedWorkOrderId,
            onSelect: (id) => setState(() => selectedWorkOrderId = id),
          ),
          const SizedBox(height: FactorySpacing.md),
          _WorkOrderDetail(
            data: data,
            row: selected,
            onAssign: selected == null
                ? null
                : () => assignWorkOrder(data, selected!),
            onStart: selected == null
                ? null
                : () => run(
                      () => repository.startWorkOrder(selected!['id'] as String),
                      'Work order started.',
                    ),
            onHold: selected == null ? null : () => holdWorkOrder(selected!),
            onResume: selected == null
                ? null
                : () => run(
                      () => repository.resumeWorkOrder(selected!['id'] as String),
                      'Work order resumed.',
                    ),
            onIssuePart: selected == null
                ? null
                : () => issuePart(data, selected!),
            onComplete: selected == null
                ? null
                : () => completeWorkOrder(selected!),
          ),
        ],
      ],
    );
  }
}

class MaintenanceRepository {
  MaintenanceRepository(this.client);
  final SupabaseClient client;

  Future<MaintenanceSnapshot> load(
    String organizationId,
    String factoryId,
  ) async {
    final assets = await client
        .from('maintenance_assets')
        .select()
        .eq('organization_id', organizationId)
        .eq('factory_id', factoryId)
        .order('name');
    final plans = await client
        .from('maintenance_plans')
        .select()
        .eq('organization_id', organizationId)
        .eq('factory_id', factoryId)
        .order('next_due_at');
    final requests = await client
        .from('maintenance_requests')
        .select()
        .eq('organization_id', organizationId)
        .eq('factory_id', factoryId)
        .order('reported_at', ascending: false)
        .limit(100);
    final workOrders = await client
        .from('maintenance_work_orders')
        .select()
        .eq('organization_id', organizationId)
        .eq('factory_id', factoryId)
        .order('created_at', ascending: false)
        .limit(150);
    final employees = await client
        .from('employees')
        .select('id,employee_code,full_name,primary_factory_id,status')
        .eq('organization_id', organizationId)
        .eq('primary_factory_id', factoryId)
        .eq('status', 'active')
        .order('full_name');
    final items = await client
        .from('inventory_items')
        .select('id,sku,name,item_type,is_active')
        .eq('organization_id', organizationId)
        .eq('is_active', true)
        .order('name');
    final locations = await client
        .from('stock_locations')
        .select('id,code,name,location_type,is_active')
        .eq('factory_id', factoryId)
        .eq('is_active', true)
        .order('name');
    final partUsages = await client
        .from('maintenance_part_usages')
        .select()
        .eq('factory_id', factoryId)
        .order('used_at', ascending: false)
        .limit(250);
    final logs = await client
        .from('maintenance_work_logs')
        .select()
        .eq('factory_id', factoryId)
        .order('logged_at', ascending: false)
        .limit(300);
    final rawSummary = await client.rpc(
      'maintenance_dashboard_summary',
      params: {
        'p_organization_id': organizationId,
        'p_factory_id': factoryId,
      },
    );
    return MaintenanceSnapshot(
      assets: List<Map<String, dynamic>>.from(assets),
      plans: List<Map<String, dynamic>>.from(plans),
      requests: List<Map<String, dynamic>>.from(requests),
      workOrders: List<Map<String, dynamic>>.from(workOrders),
      employees: List<Map<String, dynamic>>.from(employees),
      items: List<Map<String, dynamic>>.from(items),
      locations: List<Map<String, dynamic>>.from(locations),
      partUsages: List<Map<String, dynamic>>.from(partUsages),
      logs: List<Map<String, dynamic>>.from(logs),
      summary: Map<String, dynamic>.from(rawSummary as Map),
    );
  }

  Future<void> createAsset(
    String organizationId,
    String factoryId,
    Map<String, dynamic> draft,
  ) async {
    await client.from('maintenance_assets').insert({
      'organization_id': organizationId,
      'factory_id': factoryId,
      ...draft,
    });
  }

  Future<void> createPlan(
    String organizationId,
    String factoryId,
    Map<String, dynamic> draft,
  ) async {
    await client.from('maintenance_plans').insert({
      'organization_id': organizationId,
      'factory_id': factoryId,
      ...draft,
    });
  }

  Future<int> generateDueWork(String factoryId) async {
    final result = await client.rpc(
      'maintenance_generate_due_work_orders',
      params: {'p_factory_id': factoryId},
    );
    return (result as num).toInt();
  }

  Future<void> createWorkOrder(Map<String, dynamic> draft) async {
    await client.rpc(
      'maintenance_create_work_order',
      params: {
        'p_asset_id': draft['asset_id'],
        'p_work_type': draft['work_type'],
        'p_priority': draft['priority'],
        'p_title': draft['title'],
        'p_description': draft['description'],
        'p_request_id': draft['request_id'],
        'p_plan_id': null,
        'p_assigned_employee_id': draft['assigned_employee_id'],
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

  Future<void> startWorkOrder(String workOrderId) async {
    await client.rpc(
      'maintenance_start_work_order',
      params: {'p_work_order_id': workOrderId},
    );
  }

  Future<void> holdWorkOrder(String workOrderId, String reason) async {
    await client.rpc(
      'maintenance_hold_work_order',
      params: {'p_work_order_id': workOrderId, 'p_reason': reason},
    );
  }

  Future<void> resumeWorkOrder(String workOrderId) async {
    await client.rpc(
      'maintenance_resume_work_order',
      params: {'p_work_order_id': workOrderId},
    );
  }

  Future<void> completeWorkOrder(
    String workOrderId,
    String resolution,
    String? rootCause,
  ) async {
    await client.rpc(
      'maintenance_complete_work_order',
      params: {
        'p_work_order_id': workOrderId,
        'p_resolution': resolution,
        'p_root_cause': rootCause,
      },
    );
  }

  Future<void> issuePart(
    String workOrderId,
    String itemId,
    String locationId,
    double quantity,
    String? note,
  ) async {
    await client.rpc(
      'maintenance_issue_part',
      params: {
        'p_work_order_id': workOrderId,
        'p_item_id': itemId,
        'p_from_location_id': locationId,
        'p_quantity': quantity,
        'p_notes': note,
      },
    );
  }
}

class MaintenanceSnapshot {
  const MaintenanceSnapshot({
    required this.assets,
    required this.plans,
    required this.requests,
    required this.workOrders,
    required this.employees,
    required this.items,
    required this.locations,
    required this.partUsages,
    required this.logs,
    required this.summary,
  });

  final List<Map<String, dynamic>> assets;
  final List<Map<String, dynamic>> plans;
  final List<Map<String, dynamic>> requests;
  final List<Map<String, dynamic>> workOrders;
  final List<Map<String, dynamic>> employees;
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> locations;
  final List<Map<String, dynamic>> partUsages;
  final List<Map<String, dynamic>> logs;
  final Map<String, dynamic> summary;

  Map<String, dynamic>? asset(String? id) => _find(assets, id);
  Map<String, dynamic>? employee(String? id) => _find(employees, id);
  Map<String, dynamic>? item(String? id) => _find(items, id);

  List<Map<String, dynamic>> partsFor(String id) =>
      partUsages.where((row) => row['work_order_id'] == id).toList();
  List<Map<String, dynamic>> logsFor(String id) =>
      logs.where((row) => row['work_order_id'] == id).toList();
}

class _Header extends StatelessWidget {
  const _Header({
    required this.factories,
    required this.factoryId,
    required this.onFactoryChanged,
    required this.onRefresh,
    required this.onGenerate,
    required this.onNewAsset,
    required this.onNewPlan,
    required this.onNewWork,
  });

  final List<Map<String, dynamic>> factories;
  final String factoryId;
  final ValueChanged<String?> onFactoryChanged;
  final VoidCallback onRefresh;
  final VoidCallback onGenerate;
  final VoidCallback onNewAsset;
  final VoidCallback onNewPlan;
  final VoidCallback onNewWork;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: FactorySpacing.sm,
        runSpacing: FactorySpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 360,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Maintenance',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const Text(
                  'Assets, preventive schedules, breakdowns, work orders and downtime.',
                ),
              ],
            ),
          ),
          SizedBox(
            width: 250,
            child: DropdownButtonFormField<String>(
              initialValue: factoryId,
              decoration: const InputDecoration(labelText: 'Factory'),
              items: factories
                  .map(
                    (factory) => DropdownMenuItem(
                      value: factory['id'] as String,
                      child: Text(factory['name'] as String),
                    ),
                  )
                  .toList(),
              onChanged: onFactoryChanged,
            ),
          ),
          OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
          OutlinedButton.icon(
            onPressed: onGenerate,
            icon: const Icon(Icons.event_repeat_outlined),
            label: const Text('Generate due work'),
          ),
          FilledButton.tonalIcon(
            onPressed: onNewAsset,
            icon: const Icon(Icons.precision_manufacturing_outlined),
            label: const Text('Asset'),
          ),
          FilledButton.tonalIcon(
            onPressed: onNewPlan,
            icon: const Icon(Icons.event_available_outlined),
            label: const Text('Plan'),
          ),
          FilledButton.icon(
            onPressed: onNewWork,
            icon: const Icon(Icons.add_task_outlined),
            label: const Text('Work order'),
          ),
        ],
      );
}

class _Metrics extends StatelessWidget {
  const _Metrics({required this.summary});
  final Map<String, dynamic> summary;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: FactorySpacing.md,
        runSpacing: FactorySpacing.md,
        children: [
          _MetricCard(
            label: 'Active assets',
            value: '${summary['assets'] ?? 0}',
            icon: Icons.precision_manufacturing_outlined,
          ),
          _MetricCard(
            label: 'Assets down',
            value: '${summary['assets_down'] ?? 0}',
            icon: Icons.warning_amber_rounded,
          ),
          _MetricCard(
            label: 'Open work orders',
            value: '${summary['open_work_orders'] ?? 0}',
            icon: Icons.engineering_outlined,
          ),
          _MetricCard(
            label: 'Due plans',
            value: '${summary['due_plans'] ?? 0}',
            icon: Icons.event_busy_outlined,
          ),
          _MetricCard(
            label: '30d downtime',
            value: '${summary['downtime_minutes_last_30_days'] ?? 0} min',
            icon: Icons.timer_off_outlined,
          ),
        ],
      );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
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
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
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

class _SectionChip extends StatelessWidget {
  const _SectionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      );
}

class _WorkOrderList extends StatelessWidget {
  const _WorkOrderList({
    required this.data,
    required this.rows,
    required this.selectedId,
    required this.onSelect,
  });
  final MaintenanceSnapshot data;
  final List<Map<String, dynamic>> rows;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(FactorySpacing.lg),
          child: Text('No work orders match this filter.'),
        ),
      );
    }
    return Card(
      child: Column(
        children: rows.map((row) {
          final asset = data.asset(row['asset_id'] as String?);
          final employee = data.employee(row['assigned_employee_id'] as String?);
          final selected = row['id'] == selectedId;
          return ListTile(
            selected: selected,
            leading: _StatusAvatar(status: row['status'] as String),
            title: Text('${row['work_order_no']} · ${row['title']}'),
            subtitle: Text(
              [
                asset?['asset_code'],
                _title(row['priority'] as String),
                _title(row['status'] as String),
                employee?['full_name'] ?? 'Unassigned',
              ].whereType<Object>().join(' · '),
            ),
            onTap: () => onSelect(row['id'] as String),
          );
        }).toList(),
      ),
    );
  }
}

class _WorkOrderDetail extends StatelessWidget {
  const _WorkOrderDetail({
    required this.data,
    required this.row,
    required this.onAssign,
    required this.onStart,
    required this.onHold,
    required this.onResume,
    required this.onIssuePart,
    required this.onComplete,
  });
  final MaintenanceSnapshot data;
  final Map<String, dynamic>? row;
  final VoidCallback? onAssign;
  final VoidCallback? onStart;
  final VoidCallback? onHold;
  final VoidCallback? onResume;
  final VoidCallback? onIssuePart;
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) {
    final value = row;
    if (value == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(FactorySpacing.lg),
          child: Text('Select a work order to see execution details.'),
        ),
      );
    }
    final id = value['id'] as String;
    final asset = data.asset(value['asset_id'] as String?);
    final employee = data.employee(value['assigned_employee_id'] as String?);
    final parts = data.partsFor(id);
    final logs = data.logsFor(id);
    final status = value['status'] as String;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(FactorySpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    value['work_order_no'] as String,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
                _StatusChip(status: status),
              ],
            ),
            const SizedBox(height: FactorySpacing.xs),
            Text(value['title'] as String),
            const Divider(height: FactorySpacing.lg),
            _Detail('Asset', '${asset?['asset_code'] ?? ''} · ${asset?['name'] ?? ''}'),
            _Detail('Type', _title(value['work_type'] as String)),
            _Detail('Priority', _title(value['priority'] as String)),
            _Detail('Technician', employee?['full_name'] as String? ?? 'Unassigned'),
            _Detail('Started', _dateTime(value['started_at'])),
            _Detail('Completed', _dateTime(value['completed_at'])),
            _Detail('Downtime', '${value['actual_downtime_minutes'] ?? 0} min'),
            if ((value['root_cause'] as String?)?.isNotEmpty == true)
              _Detail('Root cause', value['root_cause'] as String),
            if ((value['resolution'] as String?)?.isNotEmpty == true)
              _Detail('Resolution', value['resolution'] as String),
            const SizedBox(height: FactorySpacing.md),
            Wrap(
              spacing: FactorySpacing.sm,
              runSpacing: FactorySpacing.sm,
              children: [
                if (!const {'completed', 'cancelled'}.contains(status))
                  OutlinedButton.icon(
                    onPressed: onAssign,
                    icon: const Icon(Icons.person_add_alt_outlined),
                    label: const Text('Assign'),
                  ),
                if (status == 'planned' || status == 'assigned')
                  FilledButton.icon(
                    onPressed: onStart,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start'),
                  ),
                if (status == 'in_progress')
                  OutlinedButton.icon(
                    onPressed: onHold,
                    icon: const Icon(Icons.pause),
                    label: const Text('Hold'),
                  ),
                if (status == 'on_hold')
                  FilledButton.tonalIcon(
                    onPressed: onResume,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Resume'),
                  ),
                if (status == 'in_progress')
                  OutlinedButton.icon(
                    onPressed: onIssuePart,
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: const Text('Issue spare'),
                  ),
                if (status == 'in_progress' || status == 'on_hold')
                  FilledButton.icon(
                    onPressed: onComplete,
                    icon: const Icon(Icons.task_alt),
                    label: const Text('Complete'),
                  ),
              ],
            ),
            if (parts.isNotEmpty) ...[
              const Divider(height: FactorySpacing.xl),
              Text(
                'Spare usage',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              for (final part in parts.take(6))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: Text(
                    '${data.item(part['item_id'] as String?)?['name'] ?? part['item_id']}',
                  ),
                  trailing: Text('${part['quantity']}'),
                ),
            ],
            if (logs.isNotEmpty) ...[
              const Divider(height: FactorySpacing.xl),
              Text(
                'Recent work log',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              for (final log in logs.take(5))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.notes_outlined),
                  title: Text(log['message'] as String),
                  subtitle: Text(
                    '${_title(log['log_type'] as String)} · ${_dateTime(log['logged_at'])}',
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AssetList extends StatelessWidget {
  const _AssetList({required this.data});
  final MaintenanceSnapshot data;

  @override
  Widget build(BuildContext context) {
    if (data.assets.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(FactorySpacing.lg),
          child: Text('No maintenance assets yet.'),
        ),
      );
    }
    return Wrap(
      spacing: FactorySpacing.md,
      runSpacing: FactorySpacing.md,
      children: data.assets.map((asset) {
        return SizedBox(
          width: 340,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(FactorySpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          asset['asset_code'] as String,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      _StatusChip(status: asset['status'] as String),
                    ],
                  ),
                  const SizedBox(height: FactorySpacing.xs),
                  Text(
                    asset['name'] as String,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: FactorySpacing.sm),
                  Text(
                    '${_title(asset['category'] as String)} · ${_title(asset['criticality'] as String)} criticality',
                  ),
                  if ((asset['area'] as String?)?.isNotEmpty == true)
                    Text('Area: ${asset['area']}'),
                  if (asset['meter_type'] != 'none')
                    Text(
                      'Meter: ${asset['current_meter']} ${asset['meter_type']}',
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _PlanList extends StatelessWidget {
  const _PlanList({required this.data});
  final MaintenanceSnapshot data;

  @override
  Widget build(BuildContext context) {
    if (data.plans.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(FactorySpacing.lg),
          child: Text('No preventive plans yet.'),
        ),
      );
    }
    return Card(
      child: Column(
        children: data.plans.map((plan) {
          final asset = data.asset(plan['asset_id'] as String?);
          final dueAt = DateTime.tryParse('${plan['next_due_at'] ?? ''}');
          final meterDue = plan['next_due_meter'] as num?;
          final currentMeter = asset?['current_meter'] as num?;
          final overdue = (dueAt != null && dueAt.isBefore(DateTime.now())) ||
              (meterDue != null &&
                  currentMeter != null &&
                  currentMeter.toDouble() >= meterDue.toDouble());
          return ListTile(
            leading: Icon(
              overdue ? Icons.event_busy_outlined : Icons.event_available_outlined,
            ),
            title: Text('${plan['plan_code']} · ${plan['title']}'),
            subtitle: Text(
              [
                asset?['asset_code'],
                _title(plan['maintenance_type'] as String),
                if (plan['frequency_days'] != null)
                  'Every ${plan['frequency_days']} days',
                if (plan['next_due_at'] != null)
                  'Due ${_dateTime(plan['next_due_at'])}',
                if (plan['next_due_meter'] != null)
                  'Meter due ${plan['next_due_meter']}',
              ].whereType<Object>().join(' · '),
            ),
            trailing: overdue
                ? const Chip(label: Text('Due'))
                : const Chip(label: Text('Scheduled')),
          );
        }).toList(),
      ),
    );
  }
}

class _RequestList extends StatelessWidget {
  const _RequestList({required this.data, required this.onCreateWork});
  final MaintenanceSnapshot data;
  final ValueChanged<Map<String, dynamic>> onCreateWork;

  @override
  Widget build(BuildContext context) {
    if (data.requests.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(FactorySpacing.lg),
          child: Text('No maintenance requests yet.'),
        ),
      );
    }
    return Card(
      child: Column(
        children: data.requests.map((row) {
          final asset = data.asset(row['asset_id'] as String?);
          final open = const {'open', 'triaged'}.contains(row['status']);
          return ListTile(
            leading: _StatusAvatar(status: row['status'] as String),
            title: Text('${row['request_no']} · ${row['title']}'),
            subtitle: Text(
              [
                asset?['asset_code'],
                _title(row['priority'] as String),
                _title(row['request_type'] as String),
                _dateTime(row['reported_at']),
              ].whereType<Object>().join(' · '),
            ),
            trailing: open
                ? FilledButton.tonal(
                    onPressed: () => onCreateWork(row),
                    child: const Text('Create work'),
                  )
                : _StatusChip(status: row['status'] as String),
          );
        }).toList(),
      ),
    );
  }
}

class _StatusAvatar extends StatelessWidget {
  const _StatusAvatar({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) => CircleAvatar(
        child: Icon(
          switch (status) {
            'completed' || 'resolved' || 'active' => Icons.check,
            'in_progress' || 'maintenance' => Icons.build_outlined,
            'on_hold' => Icons.pause,
            'down' => Icons.warning_amber_rounded,
            _ => Icons.schedule,
          },
        ),
      );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) => Chip(label: Text(_title(status)));
}

class _Detail extends StatelessWidget {
  const _Detail(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: FactorySpacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 100,
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Expanded(child: Text(value)),
          ],
        ),
      );
}

class _MaintenanceError extends StatelessWidget {
  const _MaintenanceError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(FactorySpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: FactorySpacing.sm),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: FactorySpacing.md),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      );
}

Map<String, dynamic>? _find(List<Map<String, dynamic>> rows, String? id) {
  if (id == null) return null;
  for (final row in rows) {
    if (row['id'] == id) return row;
  }
  return null;
}

String _title(String value) => value
    .split('_')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

String _dateTime(dynamic value) {
  if (value == null) return '—';
  final parsed = DateTime.tryParse('$value');
  if (parsed == null) return '$value';
  final local = parsed.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
}

String? _emptyToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _errorText(Object error) {
  if (error is PostgrestException) return error.message;
  return '$error';
}
