import 'package:factoryos_core/factoryos_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'workspace_guard.dart';

class ProductionExecutionPage extends StatefulWidget {
  const ProductionExecutionPage({super.key});
  @override
  State<ProductionExecutionPage> createState() =>
      _ProductionExecutionPageState();
}

class _ProductionExecutionPageState extends State<ProductionExecutionPage> {
  late Future<_ProductionMobileData> future;
  final client = Supabase.instance.client;
  @override
  void initState() {
    super.initState();
    future = _load();
  }

  void reload() => setState(() => future = _load());

  Future<_ProductionMobileData> _load() async {
    final uid = client.auth.currentUser!.id;
    final memberships = await client
        .from('organization_members')
        .select('organization_id,role')
        .eq('user_id', uid)
        .eq('is_active', true)
        .limit(2);
    if (memberships.isEmpty) {
      throw StateError('No active organization membership.');
    }
    final membership = requireSingleActiveMembership(memberships);
    final orgId = membership['organization_id'] as String;
    final role = AppRole.fromWireName(membership['role'] as String);
    final results = await Future.wait<dynamic>([
      client.rpc(
        'production_dashboard_summary',
        params: {'p_organization_id': orgId},
      ),
      client
          .from('production_orders')
          .select(
            'id,factory_id,order_no,recipe_id,planned_quantity,status,priority,inventory_items(name,sku),work_centers(name)',
          )
          .eq('organization_id', orgId)
          .order('created_at', ascending: false)
          .limit(100),
      client
          .from('production_batches')
          .select(
            'id,factory_id,order_id,batch_no,planned_quantity,status,actual_start_at,production_orders(order_no,recipe_id,product_item_id),work_centers(name),shifts(name)',
          )
          .eq('organization_id', orgId)
          .order('created_at', ascending: false)
          .limit(100),
      client
          .from('production_recipe_components')
          .select(
            'id,recipe_id,item_id,quantity_required,inventory_items(name,sku)',
          )
          .eq('organization_id', orgId),
      client
          .from('stock_locations')
          .select('id,factory_id,name,code,location_type')
          .eq('organization_id', orgId)
          .eq('is_active', true)
          .order('name'),
      client
          .from('shifts')
          .select('id,factory_id,name,code')
          .eq('organization_id', orgId)
          .eq('is_active', true)
          .order('name'),
      client.rpc(
        'production_order_report',
        params: {'p_organization_id': orgId, 'p_limit': 100},
      ),
    ]);
    return _ProductionMobileData(
      orgId: orgId,
      role: role,
      summary: Map<String, dynamic>.from(results[0] as Map),
      orders: _rows(results[1]),
      batches: _rows(results[2]),
      components: _rows(results[3]),
      locations: _rows(results[4]),
      shifts: _rows(results[5]),
      report: _rows(results[6]),
    );
  }

  void message(String text, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: error ? Theme.of(context).colorScheme.error : null,
        ),
      );
  Future<void> _run(Future<void> Function() action, String success) async {
    try {
      await action();
      if (!mounted) return;
      message(success);
      reload();
    } catch (e) {
      if (mounted) {
        message(e is PostgrestException ? e.message : '$e', error: true);
      }
    }
  }

  Future<void> startBatch(_ProductionMobileData data) async {
    final activeOrders = data.orders
        .where(
          (row) => !const [
            'completed',
            'cancelled',
            'on_hold',
          ].contains(row['status']),
        )
        .toList();
    if (activeOrders.isEmpty) {
      message('No production order is ready.', error: true);
      return;
    }
    final draft = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) =>
          _StartBatchDialog(orders: activeOrders, shifts: data.shifts),
    );
    if (draft == null) return;
    await _run(() async {
      await client.rpc(
        'production_start_batch',
        params: {
          'p_order_id': draft['order_id'],
          'p_batch_no': draft['batch_no'],
          'p_planned_quantity': draft['planned_quantity'],
          'p_shift_id': draft['shift_id'],
        },
      );
    }, 'Batch started.');
  }

  Future<void> issueMaterial(_ProductionMobileData data) async {
    final active = data.batches
        .where((row) => const ['in_progress', 'paused'].contains(row['status']))
        .toList();
    if (active.isEmpty) {
      message('No active batch.', error: true);
      return;
    }
    final draft = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _IssueDialog(
        batches: active,
        components: data.components,
        locations: data.locations,
      ),
    );
    if (draft == null) return;
    await _run(() async {
      await client.rpc(
        'production_issue_material',
        params: {
          'p_batch_id': draft['batch_id'],
          'p_item_id': draft['item_id'],
          'p_from_location_id': draft['from_location_id'],
          'p_quantity': draft['quantity'],
          'p_notes': 'Mobile production issue',
        },
      );
    }, 'Material issued.');
  }

  Future<void> recordOutput(_ProductionMobileData data) async {
    final active = data.batches
        .where((row) => const ['in_progress', 'paused'].contains(row['status']))
        .toList();
    if (active.isEmpty) {
      message('No active batch.', error: true);
      return;
    }
    final draft = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _OutputDialog(batches: active, locations: data.locations),
    );
    if (draft == null) return;
    await _run(() async {
      await client.rpc(
        'production_record_output',
        params: {
          'p_batch_id': draft['batch_id'],
          'p_good_quantity': draft['good_quantity'],
          'p_scrap_quantity': draft['scrap_quantity'],
          'p_to_location_id': draft['to_location_id'],
          'p_lot_batch_no': draft['lot_batch_no'],
          'p_scrap_reason': draft['scrap_reason'],
          'p_notes': 'Mobile production output',
        },
      );
    }, 'Output saved and stock updated.');
  }

  Future<void> downtime(_ProductionMobileData data) async {
    final active = data.batches
        .where((row) => const ['in_progress', 'paused'].contains(row['status']))
        .toList();
    if (active.isEmpty) {
      message('No active batch.', error: true);
      return;
    }
    final draft = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _DowntimeDialog(batches: active),
    );
    if (draft == null) return;
    await _run(() async {
      await client.rpc(
        'production_log_downtime',
        params: {
          'p_batch_id': draft['batch_id'],
          'p_reason_code': draft['reason_code'],
          'p_duration_minutes': draft['duration_minutes'],
          'p_reason_text': draft['reason_text'],
        },
      );
    }, 'Downtime saved.');
  }

  Future<void> status(String batchId, String value) => _run(() async {
    await client.rpc(
      'production_set_batch_status',
      params: {'p_batch_id': batchId, 'p_status': value},
    );
  }, 'Batch ${_title(value)}.');

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Production')),
    body: FutureBuilder<_ProductionMobileData>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(FactorySpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${snapshot.error}', textAlign: TextAlign.center),
                  const SizedBox(height: FactorySpacing.md),
                  OutlinedButton(onPressed: reload, child: const Text('Retry')),
                ],
              ),
            ),
          );
        }
        final data = snapshot.requireData;
        final s = data.summary;
        return RefreshIndicator(
          onRefresh: () async => reload(),
          child: ListView(
            padding: const EdgeInsets.all(FactorySpacing.md),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Production floor',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        Text(data.role.label),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: reload,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: FactorySpacing.md),
              Wrap(
                spacing: FactorySpacing.sm,
                runSpacing: FactorySpacing.sm,
                children: [
                  _Metric(
                    'Orders',
                    '${s['active_orders'] ?? 0}',
                    Icons.assignment_outlined,
                  ),
                  _Metric(
                    'Output',
                    _num(s['today_good_output']),
                    Icons.output_outlined,
                  ),
                  _Metric('WIP', _num(s['wip_quantity']), Icons.timelapse),
                  _Metric(
                    'Scrap',
                    _num(s['today_scrap']),
                    Icons.delete_outline,
                  ),
                ],
              ),
              const SizedBox(height: FactorySpacing.md),
              Wrap(
                spacing: FactorySpacing.sm,
                runSpacing: FactorySpacing.sm,
                children: [
                  FilledButton.icon(
                    onPressed: () => startBatch(data),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start batch'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => issueMaterial(data),
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: const Text('Issue'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => recordOutput(data),
                    icon: const Icon(Icons.output),
                    label: const Text('Output'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => downtime(data),
                    icon: const Icon(Icons.timer_off_outlined),
                    label: const Text('Downtime'),
                  ),
                ],
              ),
              const SizedBox(height: FactorySpacing.lg),
              Text(
                'Active batches',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: FactorySpacing.sm),
              if (data.batches
                  .where(
                    (row) =>
                        const ['in_progress', 'paused'].contains(row['status']),
                  )
                  .isEmpty)
                const Card(child: ListTile(title: Text('No active batches.'))),
              for (final row in data.batches.where(
                (row) =>
                    const ['in_progress', 'paused'].contains(row['status']),
              ))
                Card(
                  child: ListTile(
                    leading: Icon(
                      row['status'] == 'in_progress'
                          ? Icons.play_circle_fill
                          : Icons.pause_circle,
                    ),
                    title: Text(
                      '${row['batch_no']} · ${_nested(row, 'production_orders', 'order_no') ?? ''}',
                    ),
                    subtitle: Text(
                      '${_nested(row, 'work_centers', 'name') ?? 'Work center'} · planned ${_num(row['planned_quantity'])}',
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) => status(row['id'] as String, value),
                      itemBuilder: (context) => [
                        if (row['status'] == 'in_progress')
                          const PopupMenuItem(
                            value: 'paused',
                            child: Text('Pause'),
                          ),
                        if (row['status'] == 'paused')
                          const PopupMenuItem(
                            value: 'in_progress',
                            child: Text('Resume'),
                          ),
                        const PopupMenuItem(
                          value: 'completed',
                          child: Text('Complete'),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: FactorySpacing.lg),
              Text(
                'Orders / WIP',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: FactorySpacing.sm),
              for (final row in data.report.take(12))
                Card(
                  child: ListTile(
                    title: Text('${row['order_no']} · ${row['product_name']}'),
                    subtitle: Text(
                      '${_title(row['status'] as String)} · good ${_num(row['good_quantity'])} · scrap ${_num(row['scrap_quantity'])}',
                    ),
                    trailing: Text(
                      'WIP ${_num(row['wip_quantity'])}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
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

class _ProductionMobileData {
  const _ProductionMobileData({
    required this.orgId,
    required this.role,
    required this.summary,
    required this.orders,
    required this.batches,
    required this.components,
    required this.locations,
    required this.shifts,
    required this.report,
  });
  final String orgId;
  final AppRole role;
  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> orders,
      batches,
      components,
      locations,
      shifts,
      report;
}

class _StartBatchDialog extends StatefulWidget {
  const _StartBatchDialog({required this.orders, required this.shifts});
  final List<Map<String, dynamic>> orders, shifts;
  @override
  State<_StartBatchDialog> createState() => _StartBatchDialogState();
}

class _StartBatchDialogState extends State<_StartBatchDialog> {
  String? orderId, shiftId;
  final batch = TextEditingController(text: 'BATCH-');
  final qty = TextEditingController(text: '10');
  @override
  void initState() {
    super.initState();
    orderId = widget.orders.first['id'] as String;
  }

  Map<String, dynamic>? get order => widget.orders
      .where((row) => row['id'] == orderId)
      .cast<Map<String, dynamic>?>()
      .firstOrNull;
  @override
  void dispose() {
    batch.dispose();
    qty.dispose();
    super.dispose();
  }

  void submit() {
    final q = num.tryParse(qty.text.trim());
    if (orderId == null || batch.text.trim().isEmpty || q == null || q <= 0) {
      return;
    }
    Navigator.pop(context, {
      'order_id': orderId,
      'batch_no': batch.text.trim(),
      'planned_quantity': q,
      'shift_id': shiftId,
    });
  }

  @override
  Widget build(BuildContext context) {
    final factory = order?['factory_id'];
    final shifts = widget.shifts
        .where(
          (row) => row['factory_id'] == null || row['factory_id'] == factory,
        )
        .toList();
    return AlertDialog(
      title: const Text('Start batch'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: orderId,
            decoration: const InputDecoration(labelText: 'Order'),
            items: widget.orders
                .map(
                  (row) => DropdownMenuItem(
                    value: row['id'] as String,
                    child: Text(
                      '${row['order_no']} · ${_nested(row, 'inventory_items', 'name') ?? ''}',
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() {
              orderId = value;
              shiftId = null;
            }),
          ),
          const SizedBox(height: FactorySpacing.sm),
          TextField(
            controller: batch,
            decoration: const InputDecoration(labelText: 'Batch number'),
          ),
          const SizedBox(height: FactorySpacing.sm),
          TextField(
            controller: qty,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Planned quantity'),
          ),
          const SizedBox(height: FactorySpacing.sm),
          DropdownButtonFormField<String>(
            initialValue: shiftId,
            decoration: const InputDecoration(labelText: 'Shift (optional)'),
            items: shifts
                .map(
                  (row) => DropdownMenuItem(
                    value: row['id'] as String,
                    child: Text(row['name'] as String),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => shiftId = value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: submit, child: const Text('Start')),
      ],
    );
  }
}

class _IssueDialog extends StatefulWidget {
  const _IssueDialog({
    required this.batches,
    required this.components,
    required this.locations,
  });
  final List<Map<String, dynamic>> batches, components, locations;
  @override
  State<_IssueDialog> createState() => _IssueDialogState();
}

class _IssueDialogState extends State<_IssueDialog> {
  String? batchId, itemId, locationId;
  final qty = TextEditingController(text: '1');
  @override
  void initState() {
    super.initState();
    batchId = widget.batches.first['id'] as String;
  }

  Map<String, dynamic>? get batch => widget.batches
      .where((row) => row['id'] == batchId)
      .cast<Map<String, dynamic>?>()
      .firstOrNull;
  String? get recipeId =>
      _nested(batch ?? const {}, 'production_orders', 'recipe_id');
  @override
  void dispose() {
    qty.dispose();
    super.dispose();
  }

  void submit() {
    final q = num.tryParse(qty.text.trim());
    if (batchId == null ||
        itemId == null ||
        locationId == null ||
        q == null ||
        q <= 0) {
      return;
    }
    Navigator.pop(context, {
      'batch_id': batchId,
      'item_id': itemId,
      'from_location_id': locationId,
      'quantity': q,
    });
  }

  @override
  Widget build(BuildContext context) {
    final components = widget.components
        .where((row) => row['recipe_id'] == recipeId)
        .toList();
    final locations = widget.locations
        .where((row) => row['factory_id'] == batch?['factory_id'])
        .toList();
    return AlertDialog(
      title: const Text('Issue material'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: batchId,
            decoration: const InputDecoration(labelText: 'Batch'),
            items: widget.batches
                .map(
                  (row) => DropdownMenuItem(
                    value: row['id'] as String,
                    child: Text(row['batch_no'] as String),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() {
              batchId = value;
              itemId = null;
              locationId = null;
            }),
          ),
          const SizedBox(height: FactorySpacing.sm),
          DropdownButtonFormField<String>(
            initialValue: itemId,
            decoration: const InputDecoration(labelText: 'BOM material'),
            items: components
                .map(
                  (row) => DropdownMenuItem(
                    value: row['item_id'] as String,
                    child: Text(
                      '${_nested(row, 'inventory_items', 'name') ?? 'Material'} · ${_nested(row, 'inventory_items', 'sku') ?? ''}',
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => itemId = value),
          ),
          const SizedBox(height: FactorySpacing.sm),
          DropdownButtonFormField<String>(
            initialValue: locationId,
            decoration: const InputDecoration(labelText: 'Source'),
            items: locations
                .map(
                  (row) => DropdownMenuItem(
                    value: row['id'] as String,
                    child: Text(row['name'] as String),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => locationId = value),
          ),
          const SizedBox(height: FactorySpacing.sm),
          TextField(
            controller: qty,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Quantity'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: submit, child: const Text('Issue')),
      ],
    );
  }
}

class _OutputDialog extends StatefulWidget {
  const _OutputDialog({required this.batches, required this.locations});
  final List<Map<String, dynamic>> batches, locations;
  @override
  State<_OutputDialog> createState() => _OutputDialogState();
}

class _OutputDialogState extends State<_OutputDialog> {
  String? batchId, locationId;
  final good = TextEditingController(text: '1'),
      scrap = TextEditingController(text: '0'),
      lot = TextEditingController(),
      reason = TextEditingController();
  @override
  void initState() {
    super.initState();
    batchId = widget.batches.first['id'] as String;
  }

  Map<String, dynamic>? get batch => widget.batches
      .where((row) => row['id'] == batchId)
      .cast<Map<String, dynamic>?>()
      .firstOrNull;
  @override
  void dispose() {
    good.dispose();
    scrap.dispose();
    lot.dispose();
    reason.dispose();
    super.dispose();
  }

  void submit() {
    final g = num.tryParse(good.text.trim()),
        s = num.tryParse(scrap.text.trim());
    if (batchId == null ||
        g == null ||
        s == null ||
        g < 0 ||
        s < 0 ||
        g + s <= 0 ||
        (g > 0 && locationId == null)) {
      return;
    }
    Navigator.pop(context, {
      'batch_id': batchId,
      'good_quantity': g,
      'scrap_quantity': s,
      'to_location_id': g > 0 ? locationId : null,
      'lot_batch_no': lot.text.trim().isEmpty ? null : lot.text.trim(),
      'scrap_reason': reason.text.trim().isEmpty ? null : reason.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final locations = widget.locations
        .where((row) => row['factory_id'] == batch?['factory_id'])
        .toList();
    return AlertDialog(
      title: const Text('Record output'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: batchId,
              decoration: const InputDecoration(labelText: 'Batch'),
              items: widget.batches
                  .map(
                    (row) => DropdownMenuItem(
                      value: row['id'] as String,
                      child: Text(row['batch_no'] as String),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() {
                batchId = value;
                locationId = null;
              }),
            ),
            const SizedBox(height: FactorySpacing.sm),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: good,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Good'),
                  ),
                ),
                const SizedBox(width: FactorySpacing.sm),
                Expanded(
                  child: TextField(
                    controller: scrap,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Scrap'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: FactorySpacing.sm),
            DropdownButtonFormField<String>(
              initialValue: locationId,
              decoration: const InputDecoration(
                labelText: 'Finished stock location',
              ),
              items: locations
                  .map(
                    (row) => DropdownMenuItem(
                      value: row['id'] as String,
                      child: Text(row['name'] as String),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => locationId = value),
            ),
            const SizedBox(height: FactorySpacing.sm),
            TextField(
              controller: lot,
              decoration: const InputDecoration(labelText: 'Lot / batch'),
            ),
            const SizedBox(height: FactorySpacing.sm),
            TextField(
              controller: reason,
              decoration: const InputDecoration(labelText: 'Scrap reason'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: submit, child: const Text('Save')),
      ],
    );
  }
}

class _DowntimeDialog extends StatefulWidget {
  const _DowntimeDialog({required this.batches});
  final List<Map<String, dynamic>> batches;
  @override
  State<_DowntimeDialog> createState() => _DowntimeDialogState();
}

class _DowntimeDialogState extends State<_DowntimeDialog> {
  String? batchId;
  final code = TextEditingController(text: 'BREAKDOWN'),
      minutes = TextEditingController(text: '15'),
      reason = TextEditingController();
  @override
  void initState() {
    super.initState();
    batchId = widget.batches.first['id'] as String;
  }

  @override
  void dispose() {
    code.dispose();
    minutes.dispose();
    reason.dispose();
    super.dispose();
  }

  void submit() {
    final m = int.tryParse(minutes.text.trim());
    if (batchId == null || code.text.trim().length < 2 || m == null || m <= 0) {
      return;
    }
    Navigator.pop(context, {
      'batch_id': batchId,
      'reason_code': code.text.trim().toUpperCase().replaceAll(' ', '_'),
      'duration_minutes': m,
      'reason_text': reason.text.trim().isEmpty ? null : reason.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Downtime'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButtonFormField<String>(
          initialValue: batchId,
          decoration: const InputDecoration(labelText: 'Batch'),
          items: widget.batches
              .map(
                (row) => DropdownMenuItem(
                  value: row['id'] as String,
                  child: Text(row['batch_no'] as String),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => batchId = value),
        ),
        const SizedBox(height: FactorySpacing.sm),
        TextField(
          controller: code,
          decoration: const InputDecoration(labelText: 'Reason code'),
        ),
        const SizedBox(height: FactorySpacing.sm),
        TextField(
          controller: minutes,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Minutes'),
        ),
        const SizedBox(height: FactorySpacing.sm),
        TextField(
          controller: reason,
          decoration: const InputDecoration(labelText: 'Remarks'),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: submit, child: const Text('Save')),
    ],
  );
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.icon);
  final String label, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 150,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(FactorySpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: FactoryColors.blue),
            const SizedBox(height: FactorySpacing.sm),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            Text(label),
          ],
        ),
      ),
    ),
  );
}

String? _nested(Map<String, dynamic> row, String object, String key) =>
    row[object] is Map ? (row[object] as Map)[key]?.toString() : null;
String _num(dynamic value) => value == null
    ? '0'
    : (value is num
          ? value.toStringAsFixed(value % 1 == 0 ? 0 : 2)
          : value.toString());
String _title(String value) => value
    .split('_')
    .map(
      (part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}',
    )
    .join(' ');
List<Map<String, dynamic>> _rows(dynamic value) => (value as List<dynamic>)
    .map((row) => Map<String, dynamic>.from(row as Map))
    .toList();

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
