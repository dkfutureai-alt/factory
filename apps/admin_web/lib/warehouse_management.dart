import 'package:factoryos_core/factoryos_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WarehouseManagementPage extends StatefulWidget {
  const WarehouseManagementPage({
    required this.organizationId,
    required this.actorRole,
    required this.factories,
    super.key,
  });

  final String organizationId;
  final AppRole actorRole;
  final List<Map<String, dynamic>> factories;

  @override
  State<WarehouseManagementPage> createState() =>
      _WarehouseManagementPageState();
}

class _WarehouseManagementPageState extends State<WarehouseManagementPage> {
  late Future<WarehouseSnapshot> future;
  int section = 0;

  WarehouseRepository get repository =>
      WarehouseRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    future = repository.load(widget.organizationId);
  }

  void reload() =>
      setState(() => future = repository.load(widget.organizationId));

  void message(String value, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value),
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

  Future<void> addLocation(WarehouseSnapshot data) async {
    final draft = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => WarehouseLocationEditor(
        factories: widget.factories,
        locations: data.locations,
      ),
    );
    if (draft == null) return;
    await run(
      () => repository.createLocation(widget.organizationId, draft),
      'Warehouse location created.',
    );
  }

  Future<void> createPutaway(WarehouseSnapshot data) async {
    final draft = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => PutawayEditor(
        factories: widget.factories,
        locations: data.locations,
        items: data.items,
        goodsReceipts: data.goodsReceipts,
      ),
    );
    if (draft == null) return;
    await run(() => repository.createPutaway(draft), 'Put-away task created.');
  }

  Future<void> createPick(WarehouseSnapshot data) async {
    final existing = data.pickLists.map((row) => row['sales_order_id']).toSet();
    final orders = data.salesOrders
        .where(
          (row) =>
              !existing.contains(row['id']) &&
              const {'allocated', 'dispatch_ready'}.contains(row['status']),
        )
        .toList();
    if (orders.isEmpty) {
      return message(
        'No allocated or dispatch-ready sales order needs a pick list.',
        error: true,
      );
    }
    final staging = data.locations
        .where(
          (row) => const {'staging', 'dispatch'}.contains(row['location_type']),
        )
        .toList();
    if (staging.isEmpty) {
      return message(
        'Create a staging or dispatch location first.',
        error: true,
      );
    }
    final draft = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => PickListEditor(orders: orders, stagingLocations: staging),
    );
    if (draft == null) return;
    await run(() => repository.createPickList(draft), 'Pick list released.');
  }

  Future<void> createCount(WarehouseSnapshot data) async {
    final locations = data.locations
        .where(
          (row) => const {
            'warehouse',
            'zone',
            'bin',
            'staging',
            'dispatch',
          }.contains(row['location_type']),
        )
        .toList();
    if (locations.isEmpty) {
      return message('No countable warehouse location exists.', error: true);
    }
    final draft = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) =>
          CycleCountEditor(factories: widget.factories, locations: locations),
    );
    if (draft == null) return;
    await run(() => repository.createCycleCount(draft), 'Cycle count opened.');
  }

  Future<void> recordCountLine(Map<String, dynamic> line) async {
    final controller = TextEditingController(
      text: '${line['counted_quantity'] ?? line['system_quantity']}',
    );
    final value = await showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Record counted quantity'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Counted quantity',
            helperText: 'System: ${_number(line['system_quantity'])}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(controller.text.trim());
              if (parsed != null && parsed >= 0) Navigator.pop(context, parsed);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    await run(
      () => repository.recordCycleLine(line['id'] as String, value),
      'Count recorded.',
    );
  }

  Future<void> adjust(WarehouseSnapshot data) async {
    final draft = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => AdjustmentEditor(
        factories: widget.factories,
        locations: data.locations,
        items: data.items,
      ),
    );
    if (draft == null) return;
    await run(
      () => repository.adjust(draft),
      'Stock adjustment posted to the Inventory ledger.',
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<WarehouseSnapshot>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return _WarehouseError(message: '${snapshot.error}', onRetry: reload);
      }
      final data = snapshot.requireData;
      final canManage = const {
        AppRole.platformOwner,
        AppRole.orgAdmin,
        AppRole.factoryManager,
      }.contains(widget.actorRole);
      final tabs = <_WarehouseSection>[
        _WarehouseSection(
          'Dashboard',
          Icons.warehouse_outlined,
          WarehouseDashboard(data: data),
        ),
        _WarehouseSection(
          'Locations',
          Icons.account_tree_outlined,
          WarehouseLocations(
            data: data,
            canManage: canManage,
            onAdd: () => addLocation(data),
          ),
        ),
        _WarehouseSection(
          'Put-away',
          Icons.move_down_outlined,
          PutawaySection(
            data: data,
            canManage: canManage,
            onCreate: () => createPutaway(data),
            onStart: (row) => run(
              () => repository.startPutaway(row['id'] as String),
              'Put-away started.',
            ),
            onComplete: (row) => run(
              () => repository.completePutaway(row['id'] as String),
              'Put-away completed.',
            ),
          ),
        ),
        _WarehouseSection(
          'Picking',
          Icons.playlist_add_check_outlined,
          PickingSection(
            data: data,
            canManage: canManage,
            onCreate: () => createPick(data),
            onStart: (row) => run(
              () => repository.startPick(row['id'] as String),
              'Picking started.',
            ),
            onPickLine: (row) => run(
              () => repository.confirmPickLine(row['id'] as String),
              'Pick line moved to staging.',
            ),
            onStage: (row) => run(
              () => repository.stagePick(row['id'] as String),
              'Pick list staged.',
            ),
            onHandoff: (row) => run(
              () => repository.handoff(row['id'] as String),
              'Warehouse handed stock to Dispatch.',
            ),
          ),
        ),
        _WarehouseSection(
          'Cycle count',
          Icons.fact_check_outlined,
          CycleCountSection(
            data: data,
            canManage: canManage,
            onCreate: () => createCount(data),
            onRecord: recordCountLine,
            onSubmit: (row) => run(
              () => repository.submitCount(row['id'] as String),
              'Cycle count submitted.',
            ),
            onApprove: (row) => run(
              () => repository.approveCount(row['id'] as String),
              'Cycle count approved.',
            ),
          ),
        ),
        _WarehouseSection(
          'Adjustments',
          Icons.tune_outlined,
          AdjustmentSection(
            data: data,
            canManage: canManage,
            onAdd: () => adjust(data),
          ),
        ),
        _WarehouseSection(
          'Reports',
          Icons.analytics_outlined,
          WarehouseReports(data: data),
        ),
      ];
      if (section >= tabs.length) section = 0;
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
                const Icon(Icons.warehouse_outlined, color: FactoryColors.blue),
                const SizedBox(width: FactorySpacing.sm),
                Expanded(
                  child: Text(
                    'Warehouse',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
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
            height: 58,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: FactorySpacing.lg,
                vertical: FactorySpacing.sm,
              ),
              itemCount: tabs.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(width: FactorySpacing.xs),
              itemBuilder: (_, i) => ChoiceChip(
                selected: section == i,
                avatar: Icon(tabs[i].icon, size: 18),
                label: Text(tabs[i].label),
                onSelected: (_) => setState(() => section = i),
              ),
            ),
          ),
          Expanded(child: tabs[section].page),
        ],
      );
    },
  );
}

class WarehouseSnapshot {
  const WarehouseSnapshot({
    required this.summary,
    required this.locations,
    required this.items,
    required this.goodsReceipts,
    required this.putaway,
    required this.pickLists,
    required this.handoffs,
    required this.cycleCounts,
    required this.adjustments,
    required this.salesOrders,
    required this.stockReport,
    required this.putawayReport,
    required this.pickReport,
    required this.countReport,
  });
  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> locations,
      items,
      goodsReceipts,
      putaway,
      pickLists,
      handoffs,
      cycleCounts,
      adjustments,
      salesOrders,
      stockReport,
      putawayReport,
      pickReport,
      countReport;
}

class WarehouseRepository {
  WarehouseRepository(this.client);
  final SupabaseClient client;

  Future<WarehouseSnapshot> load(String orgId) async {
    final values = await Future.wait<dynamic>([
      client.rpc(
        'warehouse_dashboard_summary',
        params: {'p_organization_id': orgId},
      ),
      client
          .from('stock_locations')
          .select(
            'id,factory_id,name,code,location_type,parent_location_id,capacity_quantity,aisle,rack,level_no,sequence_no,is_active',
          )
          .eq('organization_id', orgId)
          .order('code'),
      client
          .from('inventory_items')
          .select('id,sku,name,item_type,inventory_units(code)')
          .eq('organization_id', orgId)
          .eq('is_active', true)
          .order('name'),
      client
          .from('goods_receipts')
          .select(
            'id,factory_id,goods_receipt_no,released_location_id,status,goods_receipt_lines(item_id,quantity_received,inventory_items(name,sku))',
          )
          .eq('organization_id', orgId)
          .eq('status', 'released')
          .order('received_at', ascending: false)
          .limit(100),
      client
          .from('warehouse_putaway_tasks')
          .select(
            'id,factory_id,task_no,goods_receipt_id,item_id,source_location_id,target_location_id,quantity,status,notes,created_at,started_at,completed_at,inventory_items(name,sku)',
          )
          .eq('organization_id', orgId)
          .order('created_at', ascending: false)
          .limit(200),
      client
          .from('warehouse_pick_lists')
          .select(
            'id,factory_id,pick_list_no,sales_order_id,staging_location_id,priority,status,created_at,started_at,staged_at,sales_orders(sales_order_no,business_partners(name)),warehouse_pick_lines(id,item_id,from_location_id,quantity_required,picked_quantity,status,inventory_items(name,sku))',
          )
          .eq('organization_id', orgId)
          .order('created_at', ascending: false)
          .limit(200),
      client
          .from('warehouse_dispatch_handoffs')
          .select(
            'id,factory_id,handoff_no,pick_list_id,sales_order_id,staging_location_id,status,created_at,handed_off_at',
          )
          .eq('organization_id', orgId)
          .order('created_at', ascending: false)
          .limit(200),
      client
          .from('warehouse_cycle_counts')
          .select(
            'id,factory_id,count_no,location_id,status,notes,created_at,started_at,submitted_at,approved_at,stock_locations(name,code),warehouse_cycle_count_lines(id,item_id,system_quantity,counted_quantity,variance_quantity,inventory_items(name,sku))',
          )
          .eq('organization_id', orgId)
          .order('created_at', ascending: false)
          .limit(200),
      client
          .from('warehouse_stock_adjustments')
          .select(
            'id,factory_id,adjustment_no,item_id,location_id,quantity_delta,reason,source,created_at,inventory_items(name,sku),stock_locations(name,code)',
          )
          .eq('organization_id', orgId)
          .order('created_at', ascending: false)
          .limit(200),
      client
          .from('sales_orders')
          .select('id,factory_id,sales_order_no,status,business_partners(name)')
          .eq('organization_id', orgId)
          .inFilter('status', ['allocated', 'dispatch_ready'])
          .order('created_at', ascending: false)
          .limit(100),
      client.rpc(
        'warehouse_bin_stock_report',
        params: {'p_organization_id': orgId},
      ),
      client.rpc(
        'warehouse_putaway_report',
        params: {'p_organization_id': orgId, 'p_limit': 200},
      ),
      client.rpc(
        'warehouse_pick_report',
        params: {'p_organization_id': orgId, 'p_limit': 200},
      ),
      client.rpc(
        'warehouse_cycle_count_report',
        params: {'p_organization_id': orgId, 'p_limit': 200},
      ),
    ]);
    return WarehouseSnapshot(
      summary: Map<String, dynamic>.from(values[0] as Map),
      locations: _rows(values[1]),
      items: _rows(values[2]),
      goodsReceipts: _rows(values[3]),
      putaway: _rows(values[4]),
      pickLists: _rows(values[5]),
      handoffs: _rows(values[6]),
      cycleCounts: _rows(values[7]),
      adjustments: _rows(values[8]),
      salesOrders: _rows(values[9]),
      stockReport: _rows(values[10]),
      putawayReport: _rows(values[11]),
      pickReport: _rows(values[12]),
      countReport: _rows(values[13]),
    );
  }

  Future<void> createLocation(String orgId, Map<String, dynamic> draft) async =>
      client.from('stock_locations').insert({
        'organization_id': orgId,
        ...draft,
      });
  Future<void> createPutaway(Map<String, dynamic> d) async => client.rpc(
    'warehouse_create_putaway_task',
    params: {
      'p_factory_id': d['factory_id'],
      'p_item_id': d['item_id'],
      'p_source_location_id': d['source_location_id'],
      'p_target_location_id': d['target_location_id'],
      'p_quantity': d['quantity'],
      'p_goods_receipt_id': d['goods_receipt_id'],
      'p_notes': d['notes'],
    },
  );
  Future<void> startPutaway(String id) async =>
      client.rpc('warehouse_start_putaway', params: {'p_task_id': id});
  Future<void> completePutaway(String id) async =>
      client.rpc('warehouse_complete_putaway', params: {'p_task_id': id});
  Future<void> createPickList(Map<String, dynamic> d) async => client.rpc(
    'warehouse_create_pick_list',
    params: {
      'p_sales_order_id': d['sales_order_id'],
      'p_staging_location_id': d['staging_location_id'],
      'p_priority': d['priority'],
      'p_notes': d['notes'],
    },
  );
  Future<void> startPick(String id) async =>
      client.rpc('warehouse_start_pick_list', params: {'p_pick_list_id': id});
  Future<void> confirmPickLine(String id) async =>
      client.rpc('warehouse_confirm_pick_line', params: {'p_pick_line_id': id});
  Future<void> stagePick(String id) async =>
      client.rpc('warehouse_stage_pick_list', params: {'p_pick_list_id': id});
  Future<void> handoff(String id) async => client.rpc(
    'warehouse_handoff_pick_list',
    params: {
      'p_pick_list_id': id,
      'p_notes': 'Handed off from Warehouse workspace',
    },
  );
  Future<void> createCycleCount(Map<String, dynamic> d) async => client.rpc(
    'warehouse_create_cycle_count',
    params: {
      'p_factory_id': d['factory_id'],
      'p_location_id': d['location_id'],
      'p_notes': d['notes'],
    },
  );
  Future<void> recordCycleLine(String id, num value) async => client.rpc(
    'warehouse_record_cycle_count_line',
    params: {'p_line_id': id, 'p_counted_quantity': value},
  );
  Future<void> submitCount(String id) async => client.rpc(
    'warehouse_submit_cycle_count',
    params: {'p_cycle_count_id': id},
  );
  Future<void> approveCount(String id) async => client.rpc(
    'warehouse_approve_cycle_count',
    params: {'p_cycle_count_id': id},
  );
  Future<void> adjust(Map<String, dynamic> d) async => client.rpc(
    'warehouse_adjust_stock',
    params: {
      'p_factory_id': d['factory_id'],
      'p_item_id': d['item_id'],
      'p_location_id': d['location_id'],
      'p_quantity_delta': d['quantity_delta'],
      'p_reason': d['reason'],
    },
  );
}

class WarehouseDashboard extends StatelessWidget {
  const WarehouseDashboard({required this.data, super.key});
  final WarehouseSnapshot data;
  @override
  Widget build(BuildContext context) {
    final s = data.summary;
    return ListView(
      padding: const EdgeInsets.all(FactorySpacing.lg),
      children: [
        Wrap(
          spacing: FactorySpacing.md,
          runSpacing: FactorySpacing.md,
          children: [
            _WarehouseMetric(
              'Warehouses',
              '${s['warehouses'] ?? 0}',
              Icons.warehouse_outlined,
            ),
            _WarehouseMetric(
              'Zones / Bins',
              '${s['zones'] ?? 0} / ${s['bins'] ?? 0}',
              Icons.account_tree_outlined,
            ),
            _WarehouseMetric(
              'Pending put-away',
              '${s['pending_putaway'] ?? 0}',
              Icons.move_down_outlined,
            ),
            _WarehouseMetric(
              'Active picks',
              '${s['active_picks'] ?? 0}',
              Icons.playlist_add_check_outlined,
            ),
            _WarehouseMetric(
              'Open counts',
              '${s['open_cycle_counts'] ?? 0}',
              Icons.fact_check_outlined,
            ),
            _WarehouseMetric(
              'Ready handoffs',
              '${s['ready_handoffs'] ?? 0}',
              Icons.local_shipping_outlined,
            ),
          ],
        ),
        const SizedBox(height: FactorySpacing.lg),
        Text(
          'Current warehouse activity',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: FactorySpacing.sm),
        for (final row in data.putaway.take(4))
          Card(
            child: ListTile(
              leading: const Icon(Icons.move_down_outlined),
              title: Text(row['task_no'] as String),
              subtitle: Text(
                '${_rel(row, 'inventory_items', 'name')} · ${_number(row['quantity'])} · ${_title(row['status'] as String)}',
              ),
            ),
          ),
        for (final row in data.pickLists.take(4))
          Card(
            child: ListTile(
              leading: const Icon(Icons.playlist_add_check_outlined),
              title: Text(row['pick_list_no'] as String),
              subtitle: Text(
                '${_rel(_map(row['sales_orders']), 'business_partners', 'name')} · ${_title(row['status'] as String)}',
              ),
            ),
          ),
      ],
    );
  }
}

class WarehouseLocations extends StatelessWidget {
  const WarehouseLocations({
    required this.data,
    required this.canManage,
    required this.onAdd,
    super.key,
  });
  final WarehouseSnapshot data;
  final bool canManage;
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(FactorySpacing.lg),
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Warehouse, zones & bins',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          if (canManage)
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add location'),
            ),
        ],
      ),
      const SizedBox(height: FactorySpacing.md),
      for (final row in data.locations.where(
        (row) => const {
          'warehouse',
          'zone',
          'bin',
          'receiving',
          'staging',
          'dispatch',
        }.contains(row['location_type']),
      ))
        Card(
          child: ListTile(
            leading: Icon(_locationIcon(row['location_type'] as String)),
            title: Text(
              '${row['code']} · ${row['name']}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${_title(row['location_type'] as String)}${row['aisle'] == null ? '' : ' · Aisle ${row['aisle']}'}${row['rack'] == null ? '' : ' · Rack ${row['rack']}'}',
            ),
            trailing: row['capacity_quantity'] == null
                ? null
                : Chip(label: Text('Cap ${_number(row['capacity_quantity'])}')),
          ),
        ),
    ],
  );
}

class PutawaySection extends StatelessWidget {
  const PutawaySection({
    required this.data,
    required this.canManage,
    required this.onCreate,
    required this.onStart,
    required this.onComplete,
    super.key,
  });
  final WarehouseSnapshot data;
  final bool canManage;
  final VoidCallback onCreate;
  final ValueChanged<Map<String, dynamic>> onStart, onComplete;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(FactorySpacing.lg),
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Put-away',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          if (canManage)
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_task),
              label: const Text('New task'),
            ),
        ],
      ),
      const SizedBox(height: FactorySpacing.md),
      for (final row in data.putaway)
        Card(
          child: ListTile(
            leading: const Icon(Icons.move_down_outlined),
            title: Text(
              '${row['task_no']} · ${_rel(row, 'inventory_items', 'name')}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${_locationName(data.locations, row['source_location_id'])} → ${_locationName(data.locations, row['target_location_id'])} · Qty ${_number(row['quantity'])} · ${_title(row['status'] as String)}',
            ),
            trailing: switch (row['status']) {
              'pending' => TextButton(
                onPressed: () => onStart(row),
                child: const Text('Start'),
              ),
              'in_progress' => FilledButton.tonal(
                onPressed: () => onComplete(row),
                child: const Text('Complete'),
              ),
              _ => null,
            },
          ),
        ),
    ],
  );
}

class PickingSection extends StatelessWidget {
  const PickingSection({
    required this.data,
    required this.canManage,
    required this.onCreate,
    required this.onStart,
    required this.onPickLine,
    required this.onStage,
    required this.onHandoff,
    super.key,
  });
  final WarehouseSnapshot data;
  final bool canManage;
  final VoidCallback onCreate;
  final ValueChanged<Map<String, dynamic>> onStart,
      onPickLine,
      onStage,
      onHandoff;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(FactorySpacing.lg),
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Pick → Stage → Dispatch handoff',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          if (canManage)
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Create pick list'),
            ),
        ],
      ),
      const SizedBox(height: FactorySpacing.md),
      for (final row in data.pickLists)
        Card(
          child: ExpansionTile(
            leading: const Icon(Icons.playlist_add_check_outlined),
            title: Text(
              '${row['pick_list_no']} · ${_rel(_map(row['sales_orders']), 'business_partners', 'name')}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${_title(row['priority'] as String)} priority · ${_title(row['status'] as String)}',
            ),
            trailing: switch (row['status']) {
              'released' => TextButton(
                onPressed: () => onStart(row),
                child: const Text('Start'),
              ),
              'picked' => FilledButton.tonal(
                onPressed: () => onStage(row),
                child: const Text('Stage'),
              ),
              'staged' => FilledButton.tonal(
                onPressed: () => onHandoff(row),
                child: const Text('Handoff'),
              ),
              _ => null,
            },
            children: [
              for (final line in _nested(row, 'warehouse_pick_lines'))
                ListTile(
                  title: Text(_rel(line, 'inventory_items', 'name')),
                  subtitle: Text(
                    'Required ${_number(line['quantity_required'])} · Picked ${_number(line['picked_quantity'])} · ${_title(line['status'] as String)}',
                  ),
                  trailing:
                      line['status'] == 'pending' &&
                          const {
                            'released',
                            'in_progress',
                          }.contains(row['status'])
                      ? FilledButton.tonal(
                          onPressed: () => onPickLine(line),
                          child: const Text('Confirm pick'),
                        )
                      : null,
                ),
            ],
          ),
        ),
    ],
  );
}

class CycleCountSection extends StatelessWidget {
  const CycleCountSection({
    required this.data,
    required this.canManage,
    required this.onCreate,
    required this.onRecord,
    required this.onSubmit,
    required this.onApprove,
    super.key,
  });
  final WarehouseSnapshot data;
  final bool canManage;
  final VoidCallback onCreate;
  final ValueChanged<Map<String, dynamic>> onRecord, onSubmit, onApprove;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(FactorySpacing.lg),
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Cycle counts',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          if (canManage)
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Start count'),
            ),
        ],
      ),
      const SizedBox(height: FactorySpacing.md),
      for (final row in data.cycleCounts)
        Card(
          child: ExpansionTile(
            leading: const Icon(Icons.fact_check_outlined),
            title: Text(
              '${row['count_no']} · ${_rel(row, 'stock_locations', 'name')}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(_title(row['status'] as String)),
            trailing: row['status'] == 'submitted' && canManage
                ? FilledButton.tonal(
                    onPressed: () => onApprove(row),
                    child: const Text('Approve'),
                  )
                : null,
            children: [
              for (final line in _nested(row, 'warehouse_cycle_count_lines'))
                ListTile(
                  title: Text(_rel(line, 'inventory_items', 'name')),
                  subtitle: Text(
                    'System ${_number(line['system_quantity'])} · Counted ${line['counted_quantity'] == null ? '—' : _number(line['counted_quantity'])} · Variance ${line['variance_quantity'] == null ? '—' : _number(line['variance_quantity'])}',
                  ),
                  trailing:
                      const {'open', 'in_progress'}.contains(row['status'])
                      ? TextButton(
                          onPressed: () => onRecord(line),
                          child: const Text('Count'),
                        )
                      : null,
                ),
              if (const {'open', 'in_progress'}.contains(row['status']))
                Padding(
                  padding: const EdgeInsets.all(FactorySpacing.sm),
                  child: FilledButton.tonal(
                    onPressed: () => onSubmit(row),
                    child: const Text('Submit count'),
                  ),
                ),
            ],
          ),
        ),
    ],
  );
}

class AdjustmentSection extends StatelessWidget {
  const AdjustmentSection({
    required this.data,
    required this.canManage,
    required this.onAdd,
    super.key,
  });
  final WarehouseSnapshot data;
  final bool canManage;
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(FactorySpacing.lg),
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Stock adjustments',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          if (canManage)
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Adjust stock'),
            ),
        ],
      ),
      const SizedBox(height: FactorySpacing.md),
      for (final row in data.adjustments)
        Card(
          child: ListTile(
            leading: Icon(
              (row['quantity_delta'] as num) >= 0
                  ? Icons.add_circle_outline
                  : Icons.remove_circle_outline,
            ),
            title: Text(
              '${row['adjustment_no']} · ${_rel(row, 'inventory_items', 'name')}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${_rel(row, 'stock_locations', 'name')} · ${_number(row['quantity_delta'])} · ${row['reason']} · ${_title(row['source'] as String)}',
            ),
          ),
        ),
    ],
  );
}

class WarehouseReports extends StatelessWidget {
  const WarehouseReports({required this.data, super.key});
  final WarehouseSnapshot data;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(FactorySpacing.lg),
    children: [
      Text(
        'Stock availability by warehouse location',
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: FactorySpacing.md),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Location')),
            DataColumn(label: Text('SKU')),
            DataColumn(label: Text('Item')),
            DataColumn(label: Text('On hand')),
            DataColumn(label: Text('Reserved')),
            DataColumn(label: Text('Available')),
          ],
          rows: [
            for (final row in data.stockReport)
              DataRow(
                cells: [
                  DataCell(
                    Text('${row['location_code']} · ${row['location_name']}'),
                  ),
                  DataCell(Text(row['sku'] as String)),
                  DataCell(Text(row['item_name'] as String)),
                  DataCell(Text(_number(row['on_hand']))),
                  DataCell(Text(_number(row['reserved']))),
                  DataCell(Text(_number(row['available']))),
                ],
              ),
          ],
        ),
      ),
      const SizedBox(height: FactorySpacing.xl),
      Text(
        'Operational report counts',
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
      Wrap(
        spacing: FactorySpacing.md,
        runSpacing: FactorySpacing.md,
        children: [
          _WarehouseMetric(
            'Put-away rows',
            '${data.putawayReport.length}',
            Icons.move_down_outlined,
          ),
          _WarehouseMetric(
            'Pick lists',
            '${data.pickReport.length}',
            Icons.playlist_add_check_outlined,
          ),
          _WarehouseMetric(
            'Cycle counts',
            '${data.countReport.length}',
            Icons.fact_check_outlined,
          ),
        ],
      ),
    ],
  );
}

class WarehouseLocationEditor extends StatefulWidget {
  const WarehouseLocationEditor({
    required this.factories,
    required this.locations,
    super.key,
  });
  final List<Map<String, dynamic>> factories, locations;
  @override
  State<WarehouseLocationEditor> createState() =>
      _WarehouseLocationEditorState();
}

class _WarehouseLocationEditorState extends State<WarehouseLocationEditor> {
  String? factoryId, parentId;
  String type = 'zone';
  final code = TextEditingController(),
      name = TextEditingController(),
      capacity = TextEditingController(),
      aisle = TextEditingController(),
      rack = TextEditingController(),
      level = TextEditingController();
  @override
  void initState() {
    super.initState();
    factoryId = widget.factories.isEmpty
        ? null
        : widget.factories.first['id'] as String;
  }

  @override
  void dispose() {
    code.dispose();
    name.dispose();
    capacity.dispose();
    aisle.dispose();
    rack.dispose();
    level.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parents = widget.locations
        .where(
          (row) =>
              row['factory_id'] == factoryId &&
              const {
                'warehouse',
                'zone',
                'dispatch',
              }.contains(row['location_type']),
        )
        .toList();
    return AlertDialog(
      title: const Text('Add warehouse location'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: factoryId,
                decoration: const InputDecoration(labelText: 'Factory'),
                items: [
                  for (final f in widget.factories)
                    DropdownMenuItem(
                      value: f['id'] as String,
                      child: Text('${f['code']} · ${f['name']}'),
                    ),
                ],
                onChanged: (v) => setState(() {
                  factoryId = v;
                  parentId = null;
                }),
              ),
              const SizedBox(height: FactorySpacing.sm),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(
                    value: 'warehouse',
                    child: Text('Warehouse'),
                  ),
                  DropdownMenuItem(value: 'zone', child: Text('Zone')),
                  DropdownMenuItem(value: 'bin', child: Text('Bin')),
                  DropdownMenuItem(
                    value: 'receiving',
                    child: Text('Receiving'),
                  ),
                  DropdownMenuItem(value: 'staging', child: Text('Staging')),
                ],
                onChanged: (v) => setState(() => type = v ?? type),
              ),
              const SizedBox(height: FactorySpacing.sm),
              if (type != 'warehouse')
                DropdownButtonFormField<String>(
                  initialValue: parentId,
                  decoration: const InputDecoration(
                    labelText: 'Parent location',
                  ),
                  items: [
                    for (final p in parents)
                      DropdownMenuItem(
                        value: p['id'] as String,
                        child: Text('${p['code']} · ${p['name']}'),
                      ),
                  ],
                  onChanged: (v) => setState(() => parentId = v),
                ),
              if (type != 'warehouse')
                const SizedBox(height: FactorySpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: code,
                      decoration: const InputDecoration(labelText: 'Code'),
                    ),
                  ),
                  const SizedBox(width: FactorySpacing.sm),
                  Expanded(
                    child: TextField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: FactorySpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: capacity,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Capacity'),
                    ),
                  ),
                  const SizedBox(width: FactorySpacing.sm),
                  Expanded(
                    child: TextField(
                      controller: aisle,
                      decoration: const InputDecoration(labelText: 'Aisle'),
                    ),
                  ),
                  const SizedBox(width: FactorySpacing.sm),
                  Expanded(
                    child: TextField(
                      controller: rack,
                      decoration: const InputDecoration(labelText: 'Rack'),
                    ),
                  ),
                  const SizedBox(width: FactorySpacing.sm),
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: level,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Level'),
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
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: factoryId == null
              ? null
              : () {
                  final cap = double.tryParse(capacity.text.trim());
                  final lvl = int.tryParse(level.text.trim());
                  if (code.text.trim().length < 2 ||
                      name.text.trim().length < 2 ||
                      (type != 'warehouse' && parentId == null)) {
                    return;
                  }
                  Navigator.pop(context, {
                    'factory_id': factoryId,
                    'name': name.text.trim(),
                    'code': code.text.trim().toUpperCase(),
                    'location_type': type,
                    'parent_location_id': type == 'warehouse' ? null : parentId,
                    'capacity_quantity': cap,
                    'aisle': _nullIfBlank(aisle.text),
                    'rack': _nullIfBlank(rack.text),
                    'level_no': lvl,
                    'is_active': true,
                  });
                },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class PutawayEditor extends StatefulWidget {
  const PutawayEditor({
    required this.factories,
    required this.locations,
    required this.items,
    required this.goodsReceipts,
    super.key,
  });
  final List<Map<String, dynamic>> factories, locations, items, goodsReceipts;
  @override
  State<PutawayEditor> createState() => _PutawayEditorState();
}

class _PutawayEditorState extends State<PutawayEditor> {
  String? factoryId, itemId, sourceId, targetId, grnId;
  final quantity = TextEditingController(), notes = TextEditingController();
  @override
  void initState() {
    super.initState();
    factoryId = widget.factories.isEmpty
        ? null
        : widget.factories.first['id'] as String;
    itemId = widget.items.isEmpty ? null : widget.items.first['id'] as String;
  }

  @override
  void dispose() {
    quantity.dispose();
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locations = widget.locations
        .where(
          (row) => row['factory_id'] == factoryId && row['is_active'] == true,
        )
        .toList();
    final bins = locations
        .where((row) => row['location_type'] == 'bin')
        .toList();
    return AlertDialog(
      title: const Text('Create put-away task'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: factoryId,
              decoration: const InputDecoration(labelText: 'Factory'),
              items: [
                for (final f in widget.factories)
                  DropdownMenuItem(
                    value: f['id'] as String,
                    child: Text('${f['code']} · ${f['name']}'),
                  ),
              ],
              onChanged: (v) => setState(() {
                factoryId = v;
                sourceId = null;
                targetId = null;
                grnId = null;
              }),
            ),
            const SizedBox(height: FactorySpacing.sm),
            DropdownButtonFormField<String>(
              initialValue: itemId,
              decoration: const InputDecoration(labelText: 'Item'),
              items: [
                for (final i in widget.items)
                  DropdownMenuItem(
                    value: i['id'] as String,
                    child: Text('${i['sku']} · ${i['name']}'),
                  ),
              ],
              onChanged: (v) => setState(() => itemId = v),
            ),
            const SizedBox(height: FactorySpacing.sm),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: sourceId,
                    decoration: const InputDecoration(labelText: 'Source'),
                    items: [
                      for (final l in locations)
                        DropdownMenuItem(
                          value: l['id'] as String,
                          child: Text('${l['code']} · ${l['name']}'),
                        ),
                    ],
                    onChanged: (v) => setState(() => sourceId = v),
                  ),
                ),
                const SizedBox(width: FactorySpacing.sm),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: targetId,
                    decoration: const InputDecoration(labelText: 'Target bin'),
                    items: [
                      for (final l in bins)
                        DropdownMenuItem(
                          value: l['id'] as String,
                          child: Text('${l['code']} · ${l['name']}'),
                        ),
                    ],
                    onChanged: (v) => setState(() => targetId = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: FactorySpacing.sm),
            TextField(
              controller: quantity,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Quantity'),
            ),
            const SizedBox(height: FactorySpacing.sm),
            DropdownButtonFormField<String>(
              initialValue: grnId,
              decoration: const InputDecoration(
                labelText: 'Released GRN (optional)',
              ),
              items: [
                for (final g in widget.goodsReceipts.where(
                  (g) => g['factory_id'] == factoryId,
                ))
                  DropdownMenuItem(
                    value: g['id'] as String,
                    child: Text(g['goods_receipt_no'] as String),
                  ),
              ],
              onChanged: (v) => setState(() => grnId = v),
            ),
            const SizedBox(height: FactorySpacing.sm),
            TextField(
              controller: notes,
              decoration: const InputDecoration(labelText: 'Notes'),
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
          onPressed: () {
            final q = double.tryParse(quantity.text.trim());
            if (factoryId == null ||
                itemId == null ||
                sourceId == null ||
                targetId == null ||
                q == null ||
                q <= 0) {
              return;
            }
            Navigator.pop(context, {
              'factory_id': factoryId,
              'item_id': itemId,
              'source_location_id': sourceId,
              'target_location_id': targetId,
              'quantity': q,
              'goods_receipt_id': grnId,
              'notes': notes.text.trim(),
            });
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class PickListEditor extends StatefulWidget {
  const PickListEditor({
    required this.orders,
    required this.stagingLocations,
    super.key,
  });
  final List<Map<String, dynamic>> orders, stagingLocations;
  @override
  State<PickListEditor> createState() => _PickListEditorState();
}

class _PickListEditorState extends State<PickListEditor> {
  String? orderId, stagingId;
  String priority = 'normal';
  final notes = TextEditingController();
  @override
  void initState() {
    super.initState();
    orderId = widget.orders.first['id'] as String;
    stagingId = widget.stagingLocations.first['id'] as String;
  }

  @override
  void dispose() {
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Create pick list'),
    content: SizedBox(
      width: 520,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: orderId,
            decoration: const InputDecoration(labelText: 'Sales order'),
            items: [
              for (final o in widget.orders)
                DropdownMenuItem(
                  value: o['id'] as String,
                  child: Text(
                    '${o['sales_order_no']} · ${_rel(o, 'business_partners', 'name')}',
                  ),
                ),
            ],
            onChanged: (v) => setState(() => orderId = v),
          ),
          const SizedBox(height: FactorySpacing.sm),
          DropdownButtonFormField<String>(
            initialValue: stagingId,
            decoration: const InputDecoration(labelText: 'Staging location'),
            items: [
              for (final l in widget.stagingLocations)
                DropdownMenuItem(
                  value: l['id'] as String,
                  child: Text('${l['code']} · ${l['name']}'),
                ),
            ],
            onChanged: (v) => setState(() => stagingId = v),
          ),
          const SizedBox(height: FactorySpacing.sm),
          DropdownButtonFormField<String>(
            initialValue: priority,
            decoration: const InputDecoration(labelText: 'Priority'),
            items: const [
              DropdownMenuItem(value: 'low', child: Text('Low')),
              DropdownMenuItem(value: 'normal', child: Text('Normal')),
              DropdownMenuItem(value: 'high', child: Text('High')),
              DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
            ],
            onChanged: (v) => setState(() => priority = v ?? priority),
          ),
          const SizedBox(height: FactorySpacing.sm),
          TextField(
            controller: notes,
            decoration: const InputDecoration(labelText: 'Notes'),
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
        onPressed: orderId == null || stagingId == null
            ? null
            : () => Navigator.pop(context, {
                'sales_order_id': orderId,
                'staging_location_id': stagingId,
                'priority': priority,
                'notes': notes.text.trim(),
              }),
        child: const Text('Release'),
      ),
    ],
  );
}

class CycleCountEditor extends StatefulWidget {
  const CycleCountEditor({
    required this.factories,
    required this.locations,
    super.key,
  });
  final List<Map<String, dynamic>> factories, locations;
  @override
  State<CycleCountEditor> createState() => _CycleCountEditorState();
}

class _CycleCountEditorState extends State<CycleCountEditor> {
  String? factoryId, locationId;
  final notes = TextEditingController();
  @override
  void initState() {
    super.initState();
    factoryId = widget.factories.isEmpty
        ? null
        : widget.factories.first['id'] as String;
  }

  @override
  void dispose() {
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locations = widget.locations
        .where((row) => row['factory_id'] == factoryId)
        .toList();
    return AlertDialog(
      title: const Text('Start cycle count'),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: factoryId,
              decoration: const InputDecoration(labelText: 'Factory'),
              items: [
                for (final f in widget.factories)
                  DropdownMenuItem(
                    value: f['id'] as String,
                    child: Text('${f['code']} · ${f['name']}'),
                  ),
              ],
              onChanged: (v) => setState(() {
                factoryId = v;
                locationId = null;
              }),
            ),
            const SizedBox(height: FactorySpacing.sm),
            DropdownButtonFormField<String>(
              initialValue: locationId,
              decoration: const InputDecoration(labelText: 'Location'),
              items: [
                for (final l in locations)
                  DropdownMenuItem(
                    value: l['id'] as String,
                    child: Text('${l['code']} · ${l['name']}'),
                  ),
              ],
              onChanged: (v) => setState(() => locationId = v),
            ),
            const SizedBox(height: FactorySpacing.sm),
            TextField(
              controller: notes,
              decoration: const InputDecoration(labelText: 'Notes'),
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
          onPressed: factoryId == null || locationId == null
              ? null
              : () => Navigator.pop(context, {
                  'factory_id': factoryId,
                  'location_id': locationId,
                  'notes': notes.text.trim(),
                }),
          child: const Text('Start'),
        ),
      ],
    );
  }
}

class AdjustmentEditor extends StatefulWidget {
  const AdjustmentEditor({
    required this.factories,
    required this.locations,
    required this.items,
    super.key,
  });
  final List<Map<String, dynamic>> factories, locations, items;
  @override
  State<AdjustmentEditor> createState() => _AdjustmentEditorState();
}

class _AdjustmentEditorState extends State<AdjustmentEditor> {
  String? factoryId, locationId, itemId;
  final quantity = TextEditingController(), reason = TextEditingController();
  @override
  void initState() {
    super.initState();
    factoryId = widget.factories.isEmpty
        ? null
        : widget.factories.first['id'] as String;
    itemId = widget.items.isEmpty ? null : widget.items.first['id'] as String;
  }

  @override
  void dispose() {
    quantity.dispose();
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locations = widget.locations
        .where(
          (row) => row['factory_id'] == factoryId && row['is_active'] == true,
        )
        .toList();
    return AlertDialog(
      title: const Text('Adjust warehouse stock'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: factoryId,
              decoration: const InputDecoration(labelText: 'Factory'),
              items: [
                for (final f in widget.factories)
                  DropdownMenuItem(
                    value: f['id'] as String,
                    child: Text('${f['code']} · ${f['name']}'),
                  ),
              ],
              onChanged: (v) => setState(() {
                factoryId = v;
                locationId = null;
              }),
            ),
            const SizedBox(height: FactorySpacing.sm),
            DropdownButtonFormField<String>(
              initialValue: itemId,
              decoration: const InputDecoration(labelText: 'Item'),
              items: [
                for (final i in widget.items)
                  DropdownMenuItem(
                    value: i['id'] as String,
                    child: Text('${i['sku']} · ${i['name']}'),
                  ),
              ],
              onChanged: (v) => setState(() => itemId = v),
            ),
            const SizedBox(height: FactorySpacing.sm),
            DropdownButtonFormField<String>(
              initialValue: locationId,
              decoration: const InputDecoration(labelText: 'Location'),
              items: [
                for (final l in locations)
                  DropdownMenuItem(
                    value: l['id'] as String,
                    child: Text('${l['code']} · ${l['name']}'),
                  ),
              ],
              onChanged: (v) => setState(() => locationId = v),
            ),
            const SizedBox(height: FactorySpacing.sm),
            TextField(
              controller: quantity,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Quantity delta',
                helperText: 'Positive adds stock; negative removes stock',
              ),
            ),
            const SizedBox(height: FactorySpacing.sm),
            TextField(
              controller: reason,
              decoration: const InputDecoration(labelText: 'Reason'),
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
          onPressed: () {
            final q = double.tryParse(quantity.text.trim());
            if (factoryId == null ||
                locationId == null ||
                itemId == null ||
                q == null ||
                q == 0 ||
                reason.text.trim().length < 3) {
              return;
            }
            Navigator.pop(context, {
              'factory_id': factoryId,
              'item_id': itemId,
              'location_id': locationId,
              'quantity_delta': q,
              'reason': reason.text.trim(),
            });
          },
          child: const Text('Post adjustment'),
        ),
      ],
    );
  }
}

class _WarehouseMetric extends StatelessWidget {
  const _WarehouseMetric(this.label, this.value, this.icon);
  final String label, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 210,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(FactorySpacing.lg),
        child: Row(
          children: [
            CircleAvatar(child: Icon(icon)),
            const SizedBox(width: FactorySpacing.md),
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

class _WarehouseError extends StatelessWidget {
  const _WarehouseError({required this.message, required this.onRetry});
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
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}

class _WarehouseSection {
  const _WarehouseSection(this.label, this.icon, this.page);
  final String label;
  final IconData icon;
  final Widget page;
}

List<Map<String, dynamic>> _rows(dynamic value) => (value as List<dynamic>)
    .map((e) => Map<String, dynamic>.from(e as Map))
    .toList();
List<Map<String, dynamic>> _nested(Map<String, dynamic> row, String key) {
  final value = row[key];
  if (value is! List) return const [];
  return value.map((e) => Map<String, dynamic>.from(e as Map)).toList();
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
String _rel(Map<String, dynamic> row, String key, String field) {
  final value = row[key];
  return value is Map ? '${value[field] ?? '—'}' : '—';
}

String _number(dynamic value) {
  final n = value is num ? value : num.tryParse('$value') ?? 0;
  return n == n.roundToDouble() ? n.toInt().toString() : n.toStringAsFixed(2);
}

String _title(String value) => value
    .replaceAll('_', ' ')
    .split(' ')
    .map(
      (word) =>
          word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}',
    )
    .join(' ');
String _locationName(List<Map<String, dynamic>> locations, dynamic id) {
  for (final row in locations) {
    if (row['id'] == id) return '${row['code']} · ${row['name']}';
  }
  return 'Unknown';
}

IconData _locationIcon(String type) => switch (type) {
  'warehouse' => Icons.warehouse_outlined,
  'zone' => Icons.grid_view_outlined,
  'bin' => Icons.inventory_2_outlined,
  'receiving' => Icons.move_to_inbox_outlined,
  'staging' => Icons.view_in_ar_outlined,
  'dispatch' => Icons.local_shipping_outlined,
  _ => Icons.location_on_outlined,
};
String? _nullIfBlank(String value) =>
    value.trim().isEmpty ? null : value.trim();
String _errorText(Object error) => error
    .toString()
    .replaceFirst('PostgrestException(message: ', '')
    .replaceFirst('AuthException(message: ', '');
