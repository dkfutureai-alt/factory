import 'package:factoryos_core/factoryos_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MaintenanceExecutionPage extends StatefulWidget {
  const MaintenanceExecutionPage({super.key});

  @override
  State<MaintenanceExecutionPage> createState() =>
      _MaintenanceExecutionPageState();
}

class _MaintenanceExecutionPageState extends State<MaintenanceExecutionPage> {
  late Future<MaintenanceMobileData> future;
  String filter = 'active';

  MaintenanceMobileRepository get repository =>
      MaintenanceMobileRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    future = repository.load();
  }

  void reload() => setState(() => future = repository.load());

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

  Future<void> reportRequest(MaintenanceMobileData data) async {
    if (data.assets.isEmpty) {
      return message('No active maintenance asset is available.', error: true);
    }
    String assetId = data.assets.first['id'] as String;
    String type = 'breakdown';
    String priority = 'high';
    bool safetyStop = false;
    final title = TextEditingController();
    final description = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Report maintenance issue'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: assetId,
                  decoration: const InputDecoration(labelText: 'Asset'),
                  items: data.assets
                      .map(
                        (asset) => DropdownMenuItem(
                          value: asset['id'] as String,
                          child: Text(
                            '${asset['asset_code']} · ${asset['name']}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => assetId = value ?? assetId),
                ),
                const SizedBox(height: FactorySpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: type,
                        decoration:
                            const InputDecoration(labelText: 'Issue type'),
                        items: const [
                          'breakdown',
                          'corrective',
                          'inspection',
                          'service',
                          'safety',
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
                  decoration: const InputDecoration(labelText: 'Problem title'),
                ),
                const SizedBox(height: FactorySpacing.sm),
                TextField(
                  controller: description,
                  minLines: 3,
                  maxLines: 5,
                  decoration:
                      const InputDecoration(labelText: 'What happened?'),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Safety stop / asset must not run'),
                  value: safetyStop,
                  onChanged: (value) =>
                      setDialogState(() => safetyStop = value),
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
              child: const Text('Report issue'),
            ),
          ],
        ),
      ),
    );
    final titleValue = title.text.trim();
    final descriptionValue = description.text.trim();
    title.dispose();
    description.dispose();
    if (accepted != true ||
        titleValue.length < 3 ||
        descriptionValue.length < 3) {
      return;
    }
    await run(
      () => repository.reportRequest(
        assetId: assetId,
        type: type,
        priority: priority,
        title: titleValue,
        description: descriptionValue,
        safetyStop: safetyStop,
      ),
      'Maintenance request reported.',
    );
  }

  Future<void> startWork(Map<String, dynamic> row) async {
    final meter = TextEditingController();
    final note = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Start ${row['work_order_no']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: meter,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Meter reading (optional)',
              ),
            ),
            const SizedBox(height: FactorySpacing.sm),
            TextField(
              controller: note,
              decoration: const InputDecoration(labelText: 'Start note'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Start work'),
          ),
        ],
      ),
    );
    final meterValue = double.tryParse(meter.text.trim());
    final noteValue = _emptyToNull(note.text);
    meter.dispose();
    note.dispose();
    if (accepted != true) return;
    await run(
      () => repository.startWork(row['id'] as String, meterValue, noteValue),
      'Work started.',
    );
  }

  Future<void> holdWork(Map<String, dynamic> row) async {
    final reason = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Put work on hold'),
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
      () => repository.holdWork(row['id'] as String, value),
      'Work put on hold.',
    );
  }

  Future<void> addNote(Map<String, dynamic> row) async {
    final controller = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add work note'),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(labelText: 'Work note'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Add note'),
          ),
        ],
      ),
    );
    final value = controller.text.trim();
    controller.dispose();
    if (accepted != true || value.length < 2) return;
    await run(
      () => repository.addNote(row['id'] as String, value),
      'Work note added.',
    );
  }

  Future<void> issuePart(
    MaintenanceMobileData data,
    Map<String, dynamic> row,
  ) async {
    if (data.items.isEmpty || data.locations.isEmpty) {
      return message('No spare stock is available to issue.', error: true);
    }
    String itemId = data.items.first['id'] as String;
    String locationId = data.locations.first['id'] as String;
    final quantity = TextEditingController(text: '1');
    final note = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Issue spare / consumable'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: itemId,
                  decoration: const InputDecoration(labelText: 'Item'),
                  items: data.items
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
                      const InputDecoration(labelText: 'Stock location'),
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
      'Spare issued from Inventory.',
    );
  }

  Future<void> completeWork(Map<String, dynamic> row) async {
    final resolution = TextEditingController();
    final rootCause = TextEditingController();
    final meter = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Complete ${row['work_order_no']}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: resolution,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Resolution'),
              ),
              const SizedBox(height: FactorySpacing.sm),
              TextField(
                controller: rootCause,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Root cause'),
              ),
              const SizedBox(height: FactorySpacing.sm),
              TextField(
                controller: meter,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Completion meter (optional)',
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
            child: const Text('Complete work'),
          ),
        ],
      ),
    );
    final resolutionValue = resolution.text.trim();
    final rootCauseValue = _emptyToNull(rootCause.text);
    final meterValue = double.tryParse(meter.text.trim());
    resolution.dispose();
    rootCause.dispose();
    meter.dispose();
    if (accepted != true || resolutionValue.length < 3) return;
    await run(
      () => repository.completeWork(
        row['id'] as String,
        resolutionValue,
        rootCauseValue,
        meterValue,
      ),
      'Work order completed.',
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Maintenance'),
          actions: [
            IconButton(
              onPressed: reload,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
          ],
        ),
        body: FutureBuilder<MaintenanceMobileData>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _MobileError(message: '${snapshot.error}', onRetry: reload);
            }
            final data = snapshot.requireData;
            final activeStatuses = {
              'planned',
              'assigned',
              'in_progress',
              'on_hold',
            };
            final visible = data.workOrders.where((row) {
              if (filter == 'all') return true;
              if (filter == 'active') {
                return activeStatuses.contains(row['status']);
              }
              return row['status'] == filter;
            }).toList();
            return RefreshIndicator(
              onRefresh: () async {
                setState(() => future = repository.load());
                await future;
              },
              child: ListView(
                padding: const EdgeInsets.all(FactorySpacing.md),
                children: [
                  _HeaderCard(data: data),
                  const SizedBox(height: FactorySpacing.md),
                  _Summary(data: data),
                  const SizedBox(height: FactorySpacing.md),
                  FilledButton.icon(
                    onPressed: () => reportRequest(data),
                    icon: const Icon(Icons.report_problem_outlined),
                    label: const Text('Report breakdown / maintenance issue'),
                  ),
                  const SizedBox(height: FactorySpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          data.role == AppRole.employee
                              ? 'My work orders'
                              : 'Factory work orders',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      PopupMenuButton<String>(
                        initialValue: filter,
                        onSelected: (value) => setState(() => filter = value),
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'active', child: Text('Active')),
                          PopupMenuItem(
                            value: 'in_progress',
                            child: Text('In progress'),
                          ),
                          PopupMenuItem(
                            value: 'on_hold',
                            child: Text('On hold'),
                          ),
                          PopupMenuItem(
                            value: 'completed',
                            child: Text('Completed'),
                          ),
                          PopupMenuItem(value: 'all', child: Text('All')),
                        ],
                        child: Chip(label: Text(_title(filter))),
                      ),
                    ],
                  ),
                  const SizedBox(height: FactorySpacing.sm),
                  if (visible.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(FactorySpacing.lg),
                        child: Text('No maintenance work matches this filter.'),
                      ),
                    ),
                  for (final row in visible)
                    _WorkCard(
                      data: data,
                      row: row,
                      onStart: () => startWork(row),
                      onHold: () => holdWork(row),
                      onResume: () => run(
                        () => repository.resumeWork(row['id'] as String),
                        'Work resumed.',
                      ),
                      onNote: () => addNote(row),
                      onPart: () => issuePart(data, row),
                      onComplete: () => completeWork(row),
                    ),
                  const SizedBox(height: FactorySpacing.lg),
                  Text(
                    'My recent requests',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: FactorySpacing.sm),
                  if (data.requests.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(FactorySpacing.lg),
                        child: Text('No maintenance requests reported yet.'),
                      ),
                    ),
                  for (final request in data.requests.take(8))
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.report_problem_outlined),
                        title: Text(request['title'] as String),
                        subtitle: Text(
                          '${request['request_no']} · ${_title(request['priority'] as String)} · ${_title(request['status'] as String)}',
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      );
}

class MaintenanceMobileRepository {
  MaintenanceMobileRepository(this.client);
  final SupabaseClient client;

  Future<MaintenanceMobileData> load() async {
    final user = client.auth.currentUser;
    if (user == null) throw StateError('Sign in to use Maintenance.');
    final memberships = await client
        .from('organization_members')
        .select('organization_id,role')
        .eq('user_id', user.id)
        .eq('is_active', true)
        .limit(1);
    if (memberships.isEmpty) throw StateError('No active organization access.');
    final membership = Map<String, dynamic>.from(memberships.first);
    final organizationId = membership['organization_id'] as String;
    final role = AppRole.fromWireName(membership['role'] as String);
    final factories = await client
        .from('factories')
        .select('id,name,code,city,state')
        .eq('organization_id', organizationId)
        .eq('is_active', true)
        .order('name');
    if (factories.isEmpty) {
      throw StateError('No factory is assigned to this account.');
    }
    final factory = Map<String, dynamic>.from(factories.first);
    final factoryId = factory['id'] as String;

    final employeeRows = await client
        .from('employees')
        .select('id,employee_code,full_name,primary_factory_id,user_id,status')
        .eq('organization_id', organizationId)
        .eq('user_id', user.id)
        .eq('status', 'active')
        .limit(1);
    final employee = employeeRows.isEmpty
        ? null
        : Map<String, dynamic>.from(employeeRows.first);

    final assets = await client
        .from('maintenance_assets')
        .select()
        .eq('factory_id', factoryId)
        .eq('is_active', true)
        .order('name');
    var workQuery = client
        .from('maintenance_work_orders')
        .select()
        .eq('factory_id', factoryId);
    if (role == AppRole.employee && employee != null) {
      workQuery = workQuery.eq('assigned_employee_id', employee['id']);
    }
    final workOrders = await workQuery.order('created_at', ascending: false).limit(100);
    final requestQuery = client
        .from('maintenance_requests')
        .select()
        .eq('factory_id', factoryId);
    final requests = role == AppRole.employee
        ? await requestQuery
            .eq('reported_by', user.id)
            .order('reported_at', ascending: false)
            .limit(30)
        : await requestQuery.order('reported_at', ascending: false).limit(50);
    final items = await client
        .from('inventory_items')
        .select('id,sku,name,item_type,is_active')
        .eq('organization_id', organizationId)
        .eq('is_active', true)
        .inFilter('item_type', ['spare', 'consumable', 'other'])
        .order('name');
    final locations = await client
        .from('stock_locations')
        .select('id,code,name,location_type,is_active')
        .eq('factory_id', factoryId)
        .eq('is_active', true)
        .order('name');
    final rawSummary = await client.rpc(
      'maintenance_dashboard_summary',
      params: {
        'p_organization_id': organizationId,
        'p_factory_id': factoryId,
      },
    );

    return MaintenanceMobileData(
      organizationId: organizationId,
      role: role,
      factory: factory,
      employee: employee,
      assets: List<Map<String, dynamic>>.from(assets),
      workOrders: List<Map<String, dynamic>>.from(workOrders),
      requests: List<Map<String, dynamic>>.from(requests),
      items: List<Map<String, dynamic>>.from(items),
      locations: List<Map<String, dynamic>>.from(locations),
      summary: Map<String, dynamic>.from(rawSummary as Map),
    );
  }

  Future<void> reportRequest({
    required String assetId,
    required String type,
    required String priority,
    required String title,
    required String description,
    required bool safetyStop,
  }) async {
    await client.rpc(
      'maintenance_report_request',
      params: {
        'p_asset_id': assetId,
        'p_request_type': type,
        'p_priority': priority,
        'p_title': title,
        'p_description': description,
        'p_safety_stop': safetyStop,
      },
    );
  }

  Future<void> startWork(
    String workOrderId,
    double? meter,
    String? note,
  ) async {
    await client.rpc(
      'maintenance_start_work_order',
      params: {
        'p_work_order_id': workOrderId,
        'p_meter_reading': meter,
        'p_notes': note,
      },
    );
  }

  Future<void> holdWork(String workOrderId, String reason) async {
    await client.rpc(
      'maintenance_hold_work_order',
      params: {'p_work_order_id': workOrderId, 'p_reason': reason},
    );
  }

  Future<void> resumeWork(String workOrderId) async {
    await client.rpc(
      'maintenance_resume_work_order',
      params: {'p_work_order_id': workOrderId},
    );
  }

  Future<void> addNote(String workOrderId, String note) async {
    await client.rpc(
      'maintenance_add_work_log',
      params: {'p_work_order_id': workOrderId, 'p_message': note},
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

  Future<void> completeWork(
    String workOrderId,
    String resolution,
    String? rootCause,
    double? meter,
  ) async {
    await client.rpc(
      'maintenance_complete_work_order',
      params: {
        'p_work_order_id': workOrderId,
        'p_resolution': resolution,
        'p_root_cause': rootCause,
        'p_meter_reading': meter,
      },
    );
  }
}

class MaintenanceMobileData {
  const MaintenanceMobileData({
    required this.organizationId,
    required this.role,
    required this.factory,
    required this.employee,
    required this.assets,
    required this.workOrders,
    required this.requests,
    required this.items,
    required this.locations,
    required this.summary,
  });

  final String organizationId;
  final AppRole role;
  final Map<String, dynamic> factory;
  final Map<String, dynamic>? employee;
  final List<Map<String, dynamic>> assets;
  final List<Map<String, dynamic>> workOrders;
  final List<Map<String, dynamic>> requests;
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> locations;
  final Map<String, dynamic> summary;

  Map<String, dynamic>? asset(String? id) {
    if (id == null) return null;
    for (final row in assets) {
      if (row['id'] == id) return row;
    }
    return null;
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.data});
  final MaintenanceMobileData data;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.build_outlined)),
          title: Text(data.factory['name'] as String),
          subtitle: Text(
            [
              data.factory['code'],
              data.employee?['full_name'] ?? data.role.label,
            ].whereType<Object>().join(' · '),
          ),
        ),
      );
}

class _Summary extends StatelessWidget {
  const _Summary({required this.data});
  final MaintenanceMobileData data;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: _SummaryCard(
              label: 'Open work',
              value: '${data.summary['open_work_orders'] ?? 0}',
              icon: Icons.engineering_outlined,
            ),
          ),
          const SizedBox(width: FactorySpacing.sm),
          Expanded(
            child: _SummaryCard(
              label: 'Assets down',
              value: '${data.summary['assets_down'] ?? 0}',
              icon: Icons.warning_amber_rounded,
            ),
          ),
          const SizedBox(width: FactorySpacing.sm),
          Expanded(
            child: _SummaryCard(
              label: 'Due plans',
              value: '${data.summary['due_plans'] ?? 0}',
              icon: Icons.event_busy_outlined,
            ),
          ),
        ],
      );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(FactorySpacing.sm),
          child: Column(
            children: [
              Icon(icon, color: FactoryColors.blue),
              const SizedBox(height: FactorySpacing.xs),
              Text(
                value,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
}

class _WorkCard extends StatelessWidget {
  const _WorkCard({
    required this.data,
    required this.row,
    required this.onStart,
    required this.onHold,
    required this.onResume,
    required this.onNote,
    required this.onPart,
    required this.onComplete,
  });

  final MaintenanceMobileData data;
  final Map<String, dynamic> row;
  final VoidCallback onStart;
  final VoidCallback onHold;
  final VoidCallback onResume;
  final VoidCallback onNote;
  final VoidCallback onPart;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final asset = data.asset(row['asset_id'] as String?);
    final status = row['status'] as String;
    return Card(
      margin: const EdgeInsets.only(bottom: FactorySpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(FactorySpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    row['work_order_no'] as String,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                Chip(label: Text(_title(status))),
              ],
            ),
            Text(
              row['title'] as String,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: FactorySpacing.xs),
            Text(
              '${asset?['asset_code'] ?? ''} · ${asset?['name'] ?? ''}',
            ),
            Text(
              '${_title(row['work_type'] as String)} · ${_title(row['priority'] as String)} priority',
            ),
            if ((row['description'] as String?)?.isNotEmpty == true) ...[
              const SizedBox(height: FactorySpacing.xs),
              Text(row['description'] as String),
            ],
            const SizedBox(height: FactorySpacing.md),
            Wrap(
              spacing: FactorySpacing.sm,
              runSpacing: FactorySpacing.sm,
              children: [
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
                if (status == 'in_progress' || status == 'on_hold')
                  OutlinedButton.icon(
                    onPressed: onNote,
                    icon: const Icon(Icons.notes_outlined),
                    label: const Text('Note'),
                  ),
                if (status == 'in_progress')
                  OutlinedButton.icon(
                    onPressed: onPart,
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: const Text('Spare'),
                  ),
                if (status == 'in_progress' || status == 'on_hold')
                  FilledButton.icon(
                    onPressed: onComplete,
                    icon: const Icon(Icons.task_alt),
                    label: const Text('Complete'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileError extends StatelessWidget {
  const _MobileError({required this.message, required this.onRetry});
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
              const SizedBox(height: FactorySpacing.md),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: FactorySpacing.md),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      );
}

String _title(String value) => value
    .split('_')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

String? _emptyToNull(String value) {
  final result = value.trim();
  return result.isEmpty ? null : result;
}

String _errorText(Object error) {
  if (error is PostgrestException) return error.message;
  return '$error';
}
