import 'package:factoryos_core/factoryos_core.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MaintenanceTechnicianPage extends StatefulWidget {
  const MaintenanceTechnicianPage({super.key});

  @override
  State<MaintenanceTechnicianPage> createState() =>
      _MaintenanceTechnicianPageState();
}

class _MaintenanceTechnicianPageState extends State<MaintenanceTechnicianPage> {
  late Future<TechnicianMaintenanceSnapshot> future;
  int section = 0;
  String? selectedWorkOrderId;

  TechnicianMaintenanceRepository get repository =>
      TechnicianMaintenanceRepository(Supabase.instance.client);

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

  Future<void> createRequest(TechnicianMaintenanceSnapshot data) async {
    if (data.assets.isEmpty) {
      message('No maintenance asset is available.', error: true);
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
          scrollable: true,
          content: SizedBox(
            width: 460,
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: assetId,
                  decoration: const InputDecoration(labelText: 'Equipment'),
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
                  items: const [
                    DropdownMenuItem(value: 'low', child: Text('Low')),
                    DropdownMenuItem(value: 'medium', child: Text('Medium')),
                    DropdownMenuItem(value: 'high', child: Text('High')),
                    DropdownMenuItem(value: 'critical', child: Text('Critical')),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => priority = value ?? 'medium'),
                ),
                const SizedBox(height: FactorySpacing.sm),
                TextField(
                  controller: description,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'Describe the issue *'),
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

  Future<void> addUpdate(Map<String, dynamic> workOrder) async {
    final note = TextEditingController();
    XFile? photo;
    bool picking = false;

    Future<void> pick(ImageSource source, StateSetter setDialogState) async {
      setDialogState(() => picking = true);
      try {
        final value = await ImagePicker().pickImage(
          source: source,
          imageQuality: 82,
          maxWidth: 2000,
        );
        if (value != null) setDialogState(() => photo = value);
      } finally {
        setDialogState(() => picking = false);
      }
    }

    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add work update'),
          scrollable: true,
          content: SizedBox(
            width: 460,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: note,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(labelText: 'Work done / note *'),
                ),
                const SizedBox(height: FactorySpacing.md),
                Text(
                  'Photo (optional)',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: FactorySpacing.xs),
                if (photo != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.image_outlined),
                    title: Text(
                      photo!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      onPressed: picking
                          ? null
                          : () => setDialogState(() => photo = null),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                Wrap(
                  spacing: FactorySpacing.sm,
                  runSpacing: FactorySpacing.sm,
                  children: [
                    OutlinedButton.icon(
                      onPressed: picking
                          ? null
                          : () => pick(ImageSource.camera, setDialogState),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Camera'),
                    ),
                    OutlinedButton.icon(
                      onPressed: picking
                          ? null
                          : () => pick(ImageSource.gallery, setDialogState),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Gallery'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: picking
                  ? null
                  : () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: picking
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: const Text('Save update'),
            ),
          ],
        ),
      ),
    );
    final text = note.text.trim();
    note.dispose();
    if (accepted != true || text.length < 2) return;
    await run(
      () => repository.addUpdateWithOptionalPhoto(
        workOrder: workOrder,
        note: text,
        photo: photo,
      ),
      'Work update saved.',
    );
  }

  Future<void> useSpare(
    TechnicianMaintenanceSnapshot data,
    Map<String, dynamic> workOrder,
  ) async {
    final items = data.spareItems;
    final locations = data.locationsForFactory(workOrder['factory_id']);
    if (items.isEmpty || locations.isEmpty) {
      message('No spare item or stock location is available.', error: true);
      return;
    }
    String itemId = items.first['id'] as String;
    String locationId = locations.first['id'] as String;
    final quantity = TextEditingController(text: '1');
    final unitCost = TextEditingController();
    final note = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Use spare part'),
          scrollable: true,
          content: SizedBox(
            width: 460,
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: itemId,
                  decoration: const InputDecoration(labelText: 'Spare / consumable'),
                  items: items
                      .map(
                        (row) => DropdownMenuItem(
                          value: row['id'] as String,
                          child: Text('${row['sku']} · ${row['name']}'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setDialogState(() => itemId = value);
                  },
                ),
                const SizedBox(height: FactorySpacing.sm),
                DropdownButtonFormField<String>(
                  initialValue: locationId,
                  decoration: const InputDecoration(labelText: 'Issue from location'),
                  items: locations
                      .map(
                        (row) => DropdownMenuItem(
                          value: row['id'] as String,
                          child: Text('${row['name']} · ${row['code']}'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setDialogState(() => locationId = value);
                  },
                ),
                const SizedBox(height: FactorySpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: quantity,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Quantity'),
                      ),
                    ),
                    const SizedBox(width: FactorySpacing.sm),
                    Expanded(
                      child: TextField(
                        controller: unitCost,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Unit cost (optional)'),
                      ),
                    ),
                  ],
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
              child: const Text('Use part'),
            ),
          ],
        ),
      ),
    );
    final amount = double.tryParse(quantity.text.trim());
    final cost = double.tryParse(unitCost.text.trim());
    final noteValue = note.text.trim();
    quantity.dispose();
    unitCost.dispose();
    note.dispose();
    if (accepted != true || amount == null || amount <= 0) return;
    await run(
      () => repository.useSpare(
        workOrderId: workOrder['id'] as String,
        itemId: itemId,
        locationId: locationId,
        quantity: amount,
        unitCost: cost,
        note: noteValue,
      ),
      'Spare part issued to work order.',
    );
  }

  Future<void> startDowntime(Map<String, dynamic> workOrder) async {
    final reason = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Start downtime'),
        content: TextField(
          controller: reason,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Reason *'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Start downtime'),
          ),
        ],
      ),
    );
    final text = reason.text.trim();
    reason.dispose();
    if (accepted != true || text.length < 2) return;
    await run(
      () => repository.startDowntime(workOrder['id'] as String, text),
      'Equipment downtime started.',
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
        scrollable: true,
        content: SizedBox(
          width: 460,
          child: Column(
            children: [
              TextField(
                controller: resolution,
                minLines: 3,
                maxLines: 6,
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
      note: resolution.text.trim(),
      labor: int.tryParse(labor.text.trim()) ?? 0,
      external: double.tryParse(external.text.trim()) ?? 0,
    );
    resolution.dispose();
    labor.dispose();
    external.dispose();
    if (accepted != true || values.note.length < 3) return;
    await run(
      () => repository.completeWorkOrder(
        workOrder['id'] as String,
        values.note,
        values.labor,
        values.external,
      ),
      'Work order completed.',
    );
  }

  Future<void> scanAsset(TechnicianMaintenanceSnapshot data) async {
    String? scanned;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => _AssetScanner(
          onDetected: (value) {
            scanned = value;
            Navigator.pop(context);
          },
        ),
      ),
    );
    if (!mounted || scanned == null) return;
    final asset = data.findAssetByCode(scanned!);
    if (asset == null) {
      message('No maintenance asset matches this QR/barcode.', error: true);
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(FactorySpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    child: Icon(Icons.precision_manufacturing_outlined),
                  ),
                  const SizedBox(width: FactorySpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          asset['name'] as String,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        Text('${asset['asset_code']} · ${_label(asset['status'] as String)}'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: FactorySpacing.md),
              Text('Criticality: ${_label(asset['criticality'] as String)}'),
              if (asset['model'] != null) Text('Model: ${asset['model']}'),
              if (asset['serial_no'] != null) Text('Serial: ${asset['serial_no']}'),
              const SizedBox(height: FactorySpacing.lg),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  createRequestForAsset(data, asset['id'] as String);
                },
                icon: const Icon(Icons.add_alert_outlined),
                label: const Text('Raise maintenance request'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> createRequestForAsset(
    TechnicianMaintenanceSnapshot data,
    String assetId,
  ) async {
    String issueType = 'mechanical';
    String priority = 'medium';
    final description = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Maintenance request'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                  items: const [
                    DropdownMenuItem(value: 'low', child: Text('Low')),
                    DropdownMenuItem(value: 'medium', child: Text('Medium')),
                    DropdownMenuItem(value: 'high', child: Text('High')),
                    DropdownMenuItem(value: 'critical', child: Text('Critical')),
                  ],
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
              child: const Text('Submit'),
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

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Maintenance'),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: reload,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: FutureBuilder<TechnicianMaintenanceSnapshot>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _ErrorState(message: '${snapshot.error}', onRetry: reload);
            }
            final data = snapshot.requireData;
            return switch (section) {
              0 => _Home(
                  data: data,
                  onOpenOrders: () => setState(() => section = 1),
                  onScan: () => scanAsset(data),
                  onRequest: () => createRequest(data),
                  onSchedule: () => setState(() => section = 3),
                ),
              1 => _WorkOrders(
                  data: data,
                  selectedId: selectedWorkOrderId,
                  onSelect: (id) => setState(() => selectedWorkOrderId = id),
                  onStart: (row) => run(
                    () => repository.startWorkOrder(row['id'] as String),
                    'Work order started.',
                  ),
                  onTask: (row, completed) => run(
                    () => repository.setTask(row['id'] as String, completed),
                    completed ? 'Task completed.' : 'Task reopened.',
                  ),
                  onUpdate: addUpdate,
                  onSpare: (row) => useSpare(data, row),
                  onStartDowntime: startDowntime,
                  onEndDowntime: (row) {
                    final downtime = data.openDowntime(row['id']);
                    if (downtime == null) return;
                    run(
                      () => repository.endDowntime(downtime['id'] as String),
                      'Downtime closed.',
                    );
                  },
                  onComplete: completeWorkOrder,
                ),
              2 => _Assets(
                  data: data,
                  onScan: () => scanAsset(data),
                  onRequest: (assetId) => createRequestForAsset(data, assetId),
                ),
              _ => _Schedule(data: data),
            };
          },
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: section,
          onDestinationSelected: (value) => setState(() => section = value),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.assignment_outlined),
              selectedIcon: Icon(Icons.assignment),
              label: 'Work Orders',
            ),
            NavigationDestination(
              icon: Icon(Icons.precision_manufacturing_outlined),
              label: 'Assets',
            ),
            NavigationDestination(
              icon: Icon(Icons.event_repeat_outlined),
              label: 'PM',
            ),
          ],
        ),
      );
}

class TechnicianMaintenanceRepository {
  TechnicianMaintenanceRepository(this.client);

  final SupabaseClient client;
  static const mediaBucket = 'maintenance-media';

  Future<TechnicianMaintenanceSnapshot> load() async {
    final assets = List<Map<String, dynamic>>.from(
      await client
          .from('maintenance_assets')
          .select()
          .eq('is_active', true)
          .order('name'),
    );
    final workOrders = List<Map<String, dynamic>>.from(
      await client
          .from('maintenance_work_orders')
          .select()
          .neq('status', 'cancelled')
          .order('created_at', ascending: false),
    );
    final tasks = List<Map<String, dynamic>>.from(
      await client
          .from('maintenance_work_order_tasks')
          .select()
          .order('sequence_no'),
    );
    final updates = List<Map<String, dynamic>>.from(
      await client
          .from('maintenance_work_updates')
          .select()
          .order('created_at', ascending: false),
    );
    final downtime = List<Map<String, dynamic>>.from(
      await client
          .from('maintenance_downtime_events')
          .select()
          .order('started_at', ascending: false),
    );
    final plans = List<Map<String, dynamic>>.from(
      await client
          .from('maintenance_plans')
          .select()
          .eq('is_active', true)
          .order('next_due_date'),
    );
    final items = List<Map<String, dynamic>>.from(
      await client
          .from('inventory_items')
          .select('id,organization_id,sku,name,item_type,is_active')
          .eq('is_active', true)
          .order('name'),
    );
    final locations = List<Map<String, dynamic>>.from(
      await client
          .from('stock_locations')
          .select('id,factory_id,name,code,location_type,is_active')
          .eq('is_active', true)
          .order('name'),
    );
    final usage = List<Map<String, dynamic>>.from(
      await client
          .from('maintenance_spare_usage')
          .select()
          .order('created_at', ascending: false),
    );
    return TechnicianMaintenanceSnapshot(
      assets: assets,
      workOrders: workOrders,
      tasks: tasks,
      updates: updates,
      downtime: downtime,
      plans: plans,
      items: items,
      locations: locations,
      usage: usage,
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

  Future<void> startWorkOrder(String id) async {
    await client.rpc(
      'maintenance_start_work_order',
      params: {'p_work_order_id': id},
    );
  }

  Future<void> setTask(String taskId, bool completed) async {
    await client.rpc(
      'maintenance_set_task',
      params: {'p_task_id': taskId, 'p_completed': completed},
    );
  }

  Future<void> addUpdateWithOptionalPhoto({
    required Map<String, dynamic> workOrder,
    required String note,
    required XFile? photo,
  }) async {
    String? path;
    if (photo != null) {
      final userId = client.auth.currentUser?.id;
      if (userId == null) throw StateError('Authentication required.');
      final extension = _safeImageExtension(photo.name);
      final bytes = await photo.readAsBytes();
      if (bytes.isEmpty) throw StateError('Selected maintenance photo is empty.');
      path = '${workOrder['organization_id']}/${workOrder['factory_id']}/'
          '${workOrder['id']}/$userId/'
          '${DateTime.now().microsecondsSinceEpoch}.$extension';
      await client.storage.from(mediaBucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: _imageContentType(extension),
              upsert: false,
            ),
          );
    }
    try {
      await client.rpc(
        'maintenance_add_update',
        params: {
          'p_work_order_id': workOrder['id'],
          'p_note': note,
          'p_photo_ref': path,
        },
      );
    } catch (_) {
      if (path != null) {
        try {
          await client.storage.from(mediaBucket).remove([path]);
        } catch (_) {
          // Keep the original work-update error.
        }
      }
      rethrow;
    }
  }

  Future<void> useSpare({
    required String workOrderId,
    required String itemId,
    required String locationId,
    required double quantity,
    required double? unitCost,
    required String note,
  }) async {
    await client.rpc(
      'maintenance_use_spare',
      params: {
        'p_work_order_id': workOrderId,
        'p_item_id': itemId,
        'p_source_location_id': locationId,
        'p_quantity': quantity,
        'p_unit_cost': unitCost,
        'p_note': _nullable(note),
      },
    );
  }

  Future<void> startDowntime(String workOrderId, String reason) async {
    await client.rpc(
      'maintenance_start_downtime',
      params: {'p_work_order_id': workOrderId, 'p_reason': reason},
    );
  }

  Future<void> endDowntime(String downtimeId) async {
    await client.rpc(
      'maintenance_end_downtime',
      params: {'p_downtime_id': downtimeId},
    );
  }

  Future<void> completeWorkOrder(
    String workOrderId,
    String resolution,
    int laborMinutes,
    double externalCost,
  ) async {
    await client.rpc(
      'maintenance_complete_work_order',
      params: {
        'p_work_order_id': workOrderId,
        'p_resolution_notes': resolution,
        'p_labor_minutes': laborMinutes,
        'p_external_cost': externalCost,
      },
    );
  }
}

class TechnicianMaintenanceSnapshot {
  const TechnicianMaintenanceSnapshot({
    required this.assets,
    required this.workOrders,
    required this.tasks,
    required this.updates,
    required this.downtime,
    required this.plans,
    required this.items,
    required this.locations,
    required this.usage,
  });

  final List<Map<String, dynamic>> assets;
  final List<Map<String, dynamic>> workOrders;
  final List<Map<String, dynamic>> tasks;
  final List<Map<String, dynamic>> updates;
  final List<Map<String, dynamic>> downtime;
  final List<Map<String, dynamic>> plans;
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> locations;
  final List<Map<String, dynamic>> usage;

  List<Map<String, dynamic>> get activeWorkOrders => workOrders
      .where((row) => !const {'completed', 'cancelled'}.contains(row['status']))
      .toList();

  List<Map<String, dynamic>> get completedWorkOrders =>
      workOrders.where((row) => row['status'] == 'completed').toList();

  List<Map<String, dynamic>> get spareItems => items
      .where(
        (row) => row['item_type'] == 'spare' || row['item_type'] == 'consumable',
      )
      .toList();

  Map<String, dynamic>? asset(Object? id) => _find(assets, id);

  List<Map<String, dynamic>> tasksFor(Object? workOrderId) =>
      tasks.where((row) => row['work_order_id'] == workOrderId).toList();

  List<Map<String, dynamic>> updatesFor(Object? workOrderId) =>
      updates.where((row) => row['work_order_id'] == workOrderId).toList();

  List<Map<String, dynamic>> usageFor(Object? workOrderId) =>
      usage.where((row) => row['work_order_id'] == workOrderId).toList();

  Map<String, dynamic>? openDowntime(Object? workOrderId) {
    for (final row in downtime) {
      if (row['work_order_id'] == workOrderId && row['ended_at'] == null) {
        return row;
      }
    }
    return null;
  }

  List<Map<String, dynamic>> locationsForFactory(Object? factoryId) => locations
      .where((row) => row['factory_id'] == factoryId)
      .toList();

  Map<String, dynamic>? findAssetByCode(String raw) {
    final code = raw.trim().toLowerCase();
    for (final row in assets) {
      final qr = '${row['qr_code'] ?? ''}'.trim().toLowerCase();
      final assetCode = '${row['asset_code'] ?? ''}'.trim().toLowerCase();
      if (code == qr || code == assetCode) return row;
    }
    return null;
  }
}

class _Home extends StatelessWidget {
  const _Home({
    required this.data,
    required this.onOpenOrders,
    required this.onScan,
    required this.onRequest,
    required this.onSchedule,
  });

  final TechnicianMaintenanceSnapshot data;
  final VoidCallback onOpenOrders;
  final VoidCallback onScan;
  final VoidCallback onRequest;
  final VoidCallback onSchedule;

  @override
  Widget build(BuildContext context) {
    final open = data.workOrders
        .where((row) => row['status'] == 'open' || row['status'] == 'assigned')
        .length;
    final progress = data.workOrders
        .where((row) => row['status'] == 'in_progress' || row['status'] == 'on_hold')
        .length;
    final completed = data.completedWorkOrders.length;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(FactorySpacing.md),
        children: [
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(FactorySpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Technician workspace',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: FactorySpacing.xs),
                  const Text('Assigned work orders, asset scan and maintenance execution'),
                ],
              ),
            ),
          ),
          const SizedBox(height: FactorySpacing.md),
          Row(
            children: [
              Expanded(child: _CountCard(label: 'Open', value: open, icon: Icons.pending_actions_outlined)),
              const SizedBox(width: FactorySpacing.sm),
              Expanded(child: _CountCard(label: 'In progress', value: progress, icon: Icons.settings_outlined)),
              const SizedBox(width: FactorySpacing.sm),
              Expanded(child: _CountCard(label: 'Completed', value: completed, icon: Icons.check_circle_outline)),
            ],
          ),
          const SizedBox(height: FactorySpacing.lg),
          Text(
            'Quick actions',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: FactorySpacing.sm),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.6,
            crossAxisSpacing: FactorySpacing.sm,
            mainAxisSpacing: FactorySpacing.sm,
            children: [
              _QuickAction(icon: Icons.qr_code_scanner, label: 'Scan asset QR', onTap: onScan),
              _QuickAction(icon: Icons.add_alert_outlined, label: 'New request', onTap: onRequest),
              _QuickAction(icon: Icons.assignment_outlined, label: 'My work orders', onTap: onOpenOrders),
              _QuickAction(icon: Icons.event_repeat_outlined, label: 'PM schedule', onTap: onSchedule),
            ],
          ),
          const SizedBox(height: FactorySpacing.lg),
          Text(
            'Assigned work',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: FactorySpacing.sm),
          if (data.activeWorkOrders.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(FactorySpacing.lg),
                child: Text('No active maintenance work is assigned.'),
              ),
            )
          else
            for (final row in data.activeWorkOrders.take(4))
              _WorkOrderTile(data: data, row: row, onTap: onOpenOrders),
        ],
      ),
    );
  }
}

class _WorkOrders extends StatelessWidget {
  const _WorkOrders({
    required this.data,
    required this.selectedId,
    required this.onSelect,
    required this.onStart,
    required this.onTask,
    required this.onUpdate,
    required this.onSpare,
    required this.onStartDowntime,
    required this.onEndDowntime,
    required this.onComplete,
  });

  final TechnicianMaintenanceSnapshot data;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final ValueChanged<Map<String, dynamic>> onStart;
  final void Function(Map<String, dynamic>, bool) onTask;
  final ValueChanged<Map<String, dynamic>> onUpdate;
  final ValueChanged<Map<String, dynamic>> onSpare;
  final ValueChanged<Map<String, dynamic>> onStartDowntime;
  final ValueChanged<Map<String, dynamic>> onEndDowntime;
  final ValueChanged<Map<String, dynamic>> onComplete;

  @override
  Widget build(BuildContext context) {
    if (data.workOrders.isEmpty) {
      return const SafeArea(
        child: Center(child: Text('No maintenance work order is assigned.')),
      );
    }
    final selected = selectedId != null &&
            data.workOrders.any((row) => row['id'] == selectedId)
        ? data.workOrders.firstWhere((row) => row['id'] == selectedId)
        : data.workOrders.first;
    final tasks = data.tasksFor(selected['id']);
    final updates = data.updatesFor(selected['id']);
    final usage = data.usageFor(selected['id']);
    final openDowntime = data.openDowntime(selected['id']);
    final status = selected['status'] as String;
    final asset = data.asset(selected['asset_id']);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(FactorySpacing.md),
        children: [
          DropdownButtonFormField<String>(
            initialValue: selected['id'] as String,
            decoration: const InputDecoration(labelText: 'My work order'),
            items: data.workOrders
                .map(
                  (row) => DropdownMenuItem(
                    value: row['id'] as String,
                    child: Text('${row['work_order_no']} · ${data.asset(row['asset_id'])?['name'] ?? 'Asset'}'),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) onSelect(value);
            },
          ),
          const SizedBox(height: FactorySpacing.md),
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(FactorySpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          selected['work_order_no'] as String,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ),
                      _StatusChip(status),
                    ],
                  ),
                  const SizedBox(height: FactorySpacing.sm),
                  Text(
                    asset?['name'] as String? ?? 'Asset',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text('${asset?['asset_code'] ?? ''} · ${_label(selected['maintenance_type'] as String)} · ${_label(selected['priority'] as String)} priority'),
                  const SizedBox(height: FactorySpacing.sm),
                  Text(selected['problem_description'] as String),
                ],
              ),
            ),
          ),
          const SizedBox(height: FactorySpacing.md),
          if (const {'open', 'assigned', 'on_hold'}.contains(status))
            FilledButton.icon(
              onPressed: () => onStart(selected),
              icon: const Icon(Icons.play_arrow),
              label: Text(status == 'on_hold' ? 'Resume work' : 'Start work'),
            ),
          if (const {'in_progress', 'on_hold'}.contains(status)) ...[
            Wrap(
              spacing: FactorySpacing.sm,
              runSpacing: FactorySpacing.sm,
              children: [
                OutlinedButton.icon(
                  onPressed: () => onUpdate(selected),
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('Add update'),
                ),
                OutlinedButton.icon(
                  onPressed: () => onSpare(selected),
                  icon: const Icon(Icons.build_circle_outlined),
                  label: const Text('Use spare'),
                ),
                if (openDowntime == null)
                  OutlinedButton.icon(
                    onPressed: () => onStartDowntime(selected),
                    icon: const Icon(Icons.timer_outlined),
                    label: const Text('Start downtime'),
                  )
                else
                  FilledButton.tonalIcon(
                    onPressed: () => onEndDowntime(selected),
                    icon: const Icon(Icons.timer_off_outlined),
                    label: const Text('End downtime'),
                  ),
              ],
            ),
          ],
          const SizedBox(height: FactorySpacing.md),
          _SectionCard(
            title: 'Tasks',
            child: tasks.isEmpty
                ? const Text('No checklist tasks for this work order.')
                : Column(
                    children: tasks.map((task) {
                      final completed = task['completed_at'] != null;
                      return CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: completed,
                        onChanged: const {'completed', 'cancelled'}.contains(status)
                            ? null
                            : (value) => onTask(task, value ?? false),
                        title: Text(task['instruction'] as String),
                        controlAffinity: ListTileControlAffinity.leading,
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: FactorySpacing.md),
          _SectionCard(
            title: 'Parts used',
            child: usage.isEmpty
                ? const Text('No spare parts recorded.')
                : Column(
                    children: usage.map((row) {
                      final item = _find(data.items, row['item_id']);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.settings_suggest_outlined),
                        title: Text(item?['name'] as String? ?? 'Spare item'),
                        subtitle: Text('Quantity ${row['quantity']}'),
                        trailing: Text('₹${row['line_cost']}'),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: FactorySpacing.md),
          _SectionCard(
            title: 'History',
            child: updates.isEmpty
                ? const Text('No work updates yet.')
                : Column(
                    children: updates.take(8).map((row) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(row['photo_ref'] == null ? Icons.notes_outlined : Icons.photo_outlined),
                          title: Text(row['note'] as String),
                          subtitle: Text('${_label(row['status_snapshot'] as String)} · ${row['created_at']}'),
                        )).toList(),
                  ),
          ),
          if (const {'in_progress', 'on_hold'}.contains(status)) ...[
            const SizedBox(height: FactorySpacing.md),
            FilledButton.icon(
              onPressed: openDowntime == null ? () => onComplete(selected) : null,
              icon: const Icon(Icons.check_circle_outline),
              label: Text(openDowntime == null ? 'Complete work order' : 'Close downtime before completion'),
            ),
          ],
        ],
      ),
    );
  }
}

class _Assets extends StatelessWidget {
  const _Assets({required this.data, required this.onScan, required this.onRequest});

  final TechnicianMaintenanceSnapshot data;
  final VoidCallback onScan;
  final ValueChanged<String> onRequest;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(FactorySpacing.md),
          children: [
            FilledButton.icon(
              onPressed: onScan,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan asset QR'),
            ),
            const SizedBox(height: FactorySpacing.md),
            for (final asset in data.assets)
              Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.precision_manufacturing_outlined),
                  ),
                  title: Text(asset['name'] as String),
                  subtitle: Text('${asset['asset_code']} · ${_label(asset['criticality'] as String)} criticality'),
                  trailing: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _StatusChip(asset['status'] as String),
                      TextButton(
                        onPressed: () => onRequest(asset['id'] as String),
                        child: const Text('Request'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
}

class _Schedule extends StatelessWidget {
  const _Schedule({required this.data});
  final TechnicianMaintenanceSnapshot data;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(FactorySpacing.md),
          children: [
            Text(
              'Preventive Maintenance',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: FactorySpacing.md),
            if (data.plans.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(FactorySpacing.lg),
                  child: Text('No preventive maintenance schedule is available.'),
                ),
              )
            else
              for (final plan in data.plans)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.event_repeat_outlined),
                    title: Text(data.asset(plan['asset_id'])?['name'] as String? ?? 'Asset'),
                    subtitle: Text('${_label(plan['maintenance_type'] as String)} · Every ${plan['frequency_value']} ${plan['frequency_unit']}'),
                    trailing: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${plan['next_due_date']}'),
                        Text(_label(plan['default_priority'] as String)),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      );
}

class _CountCard extends StatelessWidget {
  const _CountCard({required this.label, required this.value, required this.icon});
  final String label;
  final int value;
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
                '$value',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              Text(label, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(FactoryRadius.lg),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(FactorySpacing.md),
            child: Row(
              children: [
                Icon(icon, color: FactoryColors.blue),
                const SizedBox(width: FactorySpacing.sm),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _WorkOrderTile extends StatelessWidget {
  const _WorkOrderTile({required this.data, required this.row, required this.onTap});
  final TechnicianMaintenanceSnapshot data;
  final Map<String, dynamic> row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          onTap: onTap,
          leading: const Icon(Icons.handyman_outlined),
          title: Text(row['work_order_no'] as String),
          subtitle: Text('${data.asset(row['asset_id'])?['name'] ?? 'Asset'} · ${_label(row['priority'] as String)} priority'),
          trailing: _StatusChip(row['status'] as String),
        ),
      );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(FactorySpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: FactorySpacing.sm),
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
      'down' || 'rejected' => scheme.errorContainer,
      'in_progress' || 'maintenance' => scheme.tertiaryContainer,
      _ => scheme.secondaryContainer,
    };
    return Chip(
      label: Text(_label(status)),
      backgroundColor: background,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _AssetScanner extends StatefulWidget {
  const _AssetScanner({required this.onDetected});
  final ValueChanged<String> onDetected;

  @override
  State<_AssetScanner> createState() => _AssetScannerState();
}

class _AssetScannerState extends State<_AssetScanner> {
  bool consumed = false;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Scan Asset QR')),
        body: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              onDetect: (capture) {
                if (consumed) return;
                for (final barcode in capture.barcodes) {
                  final value = barcode.rawValue?.trim();
                  if (value != null && value.isNotEmpty) {
                    consumed = true;
                    widget.onDetected(value);
                    return;
                  }
                }
              },
            ),
            IgnorePointer(
              child: Center(
                child: Container(
                  width: 230,
                  height: 230,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 3,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
            const Positioned(
              left: 24,
              right: 24,
              bottom: 48,
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(FactorySpacing.md),
                  child: Text(
                    'Position the equipment QR code inside the frame.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
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

String _safeImageExtension(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.png')) return 'png';
  if (lower.endsWith('.webp')) return 'webp';
  return 'jpg';
}

String _imageContentType(String extension) => switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };

String _errorText(Object error) {
  if (error is PostgrestException) return error.message;
  if (error is StorageException) return error.message;
  return '$error';
}
