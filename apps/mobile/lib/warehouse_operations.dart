import 'package:factoryos_core/factoryos_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WarehouseOperationsPage extends StatefulWidget {
  const WarehouseOperationsPage({super.key});

  @override
  State<WarehouseOperationsPage> createState() =>
      _WarehouseOperationsPageState();
}

class _WarehouseOperationsPageState extends State<WarehouseOperationsPage> {
  late Future<_WarehouseMobileData> future;

  @override
  void initState() {
    super.initState();
    future = _load();
  }

  SupabaseClient get client => Supabase.instance.client;

  Future<_WarehouseMobileData> _load() async {
    final membership = await client
        .from('organization_members')
        .select('organization_id,role')
        .eq('user_id', client.auth.currentUser!.id)
        .eq('is_active', true)
        .limit(1)
        .maybeSingle();
    if (membership == null)
      throw Exception('No active organization membership.');
    final orgId = membership['organization_id'] as String;
    final role = AppRole.fromWireName(membership['role'] as String);
    final factories = _rows(
      await client
          .from('factory_members')
          .select('factory_id,factories(id,name,code)')
          .eq('user_id', client.auth.currentUser!.id)
          .eq('is_active', true),
    );
    final factoryIds = factories.map((e) => e['factory_id'] as String).toList();
    if (factoryIds.isEmpty &&
        role != AppRole.orgAdmin &&
        role != AppRole.platformOwner)
      throw Exception('No factory assigned.');
    final putaway = _rows(
      await client
          .from('warehouse_putaway_tasks')
          .select(
            'id,factory_id,task_no,item_id,source_location_id,target_location_id,quantity,status,inventory_items(name,sku)',
          )
          .eq('organization_id', orgId)
          .inFilter('status', ['pending', 'in_progress'])
          .order('created_at')
          .limit(100),
    );
    final picks = _rows(
      await client
          .from('warehouse_pick_lists')
          .select(
            'id,factory_id,pick_list_no,sales_order_id,staging_location_id,priority,status,sales_orders(sales_order_no,business_partners(name)),warehouse_pick_lines(id,item_id,from_location_id,quantity_required,picked_quantity,status,inventory_items(name,sku))',
          )
          .eq('organization_id', orgId)
          .inFilter('status', ['released', 'in_progress', 'picked', 'staged'])
          .order('created_at')
          .limit(100),
    );
    final counts = _rows(
      await client
          .from('warehouse_cycle_counts')
          .select(
            'id,factory_id,count_no,location_id,status,stock_locations(name,code),warehouse_cycle_count_lines(id,item_id,system_quantity,counted_quantity,variance_quantity,inventory_items(name,sku))',
          )
          .eq('organization_id', orgId)
          .inFilter('status', ['open', 'in_progress', 'submitted'])
          .order('created_at')
          .limit(50),
    );
    final locations = _rows(
      await client
          .from('stock_locations')
          .select('id,factory_id,name,code,location_type')
          .eq('organization_id', orgId)
          .eq('is_active', true)
          .order('code'),
    );
    return _WarehouseMobileData(
      role: role,
      factories: factories,
      locations: locations,
      putaway: putaway,
      picks: picks,
      counts: counts,
    );
  }

  void reload() => setState(() => future = _load());

  Future<void> _run(Future<void> Function() action, String success) async {
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(success)));
      reload();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
    }
  }

  Future<void> _countLine(Map<String, dynamic> line) async {
    final controller = TextEditingController(
      text: '${line['counted_quantity'] ?? line['system_quantity']}',
    );
    final value = await showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(_rel(line, 'inventory_items', 'name')),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Counted quantity',
            helperText: 'System ${_number(line['system_quantity'])}',
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
    await _run(() async {
      await client.rpc(
        'warehouse_record_cycle_count_line',
        params: {'p_line_id': line['id'], 'p_counted_quantity': value},
      );
    }, 'Count saved.');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Warehouse'),
      actions: [IconButton(onPressed: reload, icon: const Icon(Icons.refresh))],
    ),
    body: FutureBuilder<_WarehouseMobileData>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(FactorySpacing.lg),
              child: Text('${snapshot.error}', textAlign: TextAlign.center),
            ),
          );
        final data = snapshot.requireData;
        return DefaultTabController(
          length: 3,
          child: Column(
            children: [
              const TabBar(
                tabs: [
                  Tab(text: 'Put-away'),
                  Tab(text: 'Picking'),
                  Tab(text: 'Counts'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [_putaway(data), _picking(data), _counts(data)],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );

  Widget _putaway(_WarehouseMobileData data) => ListView(
    padding: const EdgeInsets.all(FactorySpacing.md),
    children: [
      for (final row in data.putaway)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(FactorySpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.move_down_outlined,
                      color: FactoryColors.blue,
                    ),
                    const SizedBox(width: FactorySpacing.sm),
                    Expanded(
                      child: Text(
                        row['task_no'] as String,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Chip(label: Text(_title(row['status'] as String))),
                  ],
                ),
                const SizedBox(height: FactorySpacing.sm),
                Text(
                  _rel(row, 'inventory_items', 'name'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${_location(data.locations, row['source_location_id'])} → ${_location(data.locations, row['target_location_id'])}',
                ),
                Text('Quantity ${_number(row['quantity'])}'),
                const SizedBox(height: FactorySpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: row['status'] == 'pending'
                      ? FilledButton.tonalIcon(
                          onPressed: () => _run(() async {
                            await client.rpc(
                              'warehouse_start_putaway',
                              params: {'p_task_id': row['id']},
                            );
                          }, 'Put-away started.'),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Start task'),
                        )
                      : FilledButton.icon(
                          onPressed: () => _run(() async {
                            await client.rpc(
                              'warehouse_complete_putaway',
                              params: {'p_task_id': row['id']},
                            );
                          }, 'Put-away completed.'),
                          icon: const Icon(Icons.check),
                          label: const Text('Confirm put-away'),
                        ),
                ),
              ],
            ),
          ),
        ),
      if (data.putaway.isEmpty)
        const _Empty(
          icon: Icons.move_down_outlined,
          text: 'No active put-away tasks.',
        ),
    ],
  );

  Widget _picking(_WarehouseMobileData data) => ListView(
    padding: const EdgeInsets.all(FactorySpacing.md),
    children: [
      for (final pick in data.picks)
        Card(
          child: ExpansionTile(
            leading: const Icon(
              Icons.playlist_add_check_outlined,
              color: FactoryColors.blue,
            ),
            title: Text(
              pick['pick_list_no'] as String,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              '${_rel(_map(pick['sales_orders']), 'business_partners', 'name')} · ${_title(pick['status'] as String)}',
            ),
            children: [
              if (pick['status'] == 'released')
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    FactorySpacing.md,
                    0,
                    FactorySpacing.md,
                    FactorySpacing.sm,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonal(
                      onPressed: () => _run(() async {
                        await client.rpc(
                          'warehouse_start_pick_list',
                          params: {'p_pick_list_id': pick['id']},
                        );
                      }, 'Picking started.'),
                      child: const Text('Start picking'),
                    ),
                  ),
                ),
              for (final line in _nested(pick, 'warehouse_pick_lines'))
                ListTile(
                  leading: Icon(
                    line['status'] == 'picked'
                        ? Icons.check_circle
                        : Icons.qr_code_scanner,
                  ),
                  title: Text(_rel(line, 'inventory_items', 'name')),
                  subtitle: Text(
                    '${_location(data.locations, line['from_location_id'])} · Qty ${_number(line['quantity_required'])}',
                  ),
                  trailing:
                      line['status'] == 'pending' &&
                          const {
                            'released',
                            'in_progress',
                          }.contains(pick['status'])
                      ? FilledButton.tonal(
                          onPressed: () => _run(() async {
                            await client.rpc(
                              'warehouse_confirm_pick_line',
                              params: {'p_pick_line_id': line['id']},
                            );
                          }, 'Item moved to staging.'),
                          child: const Text('Pick'),
                        )
                      : null,
                ),
              if (pick['status'] == 'picked')
                Padding(
                  padding: const EdgeInsets.all(FactorySpacing.md),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _run(() async {
                        await client.rpc(
                          'warehouse_stage_pick_list',
                          params: {'p_pick_list_id': pick['id']},
                        );
                      }, 'Pick list staged.'),
                      icon: const Icon(Icons.view_in_ar_outlined),
                      label: const Text('Stage order'),
                    ),
                  ),
                ),
              if (pick['status'] == 'staged' && data.role != AppRole.employee)
                Padding(
                  padding: const EdgeInsets.all(FactorySpacing.md),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _run(() async {
                        await client.rpc(
                          'warehouse_handoff_pick_list',
                          params: {
                            'p_pick_list_id': pick['id'],
                            'p_notes': 'Mobile warehouse handoff',
                          },
                        );
                      }, 'Handed to Dispatch.'),
                      icon: const Icon(Icons.local_shipping_outlined),
                      label: const Text('Handoff to Dispatch'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      if (data.picks.isEmpty)
        const _Empty(
          icon: Icons.playlist_add_check_outlined,
          text: 'No active pick lists.',
        ),
    ],
  );

  Widget _counts(_WarehouseMobileData data) => ListView(
    padding: const EdgeInsets.all(FactorySpacing.md),
    children: [
      for (final count in data.counts)
        Card(
          child: ExpansionTile(
            leading: const Icon(
              Icons.fact_check_outlined,
              color: FactoryColors.blue,
            ),
            title: Text(
              count['count_no'] as String,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              '${_rel(count, 'stock_locations', 'name')} · ${_title(count['status'] as String)}',
            ),
            children: [
              for (final line in _nested(count, 'warehouse_cycle_count_lines'))
                ListTile(
                  title: Text(_rel(line, 'inventory_items', 'name')),
                  subtitle: Text(
                    'System ${_number(line['system_quantity'])} · Counted ${line['counted_quantity'] == null ? '—' : _number(line['counted_quantity'])}',
                  ),
                  trailing:
                      const {'open', 'in_progress'}.contains(count['status'])
                      ? TextButton(
                          onPressed: () => _countLine(line),
                          child: const Text('Count'),
                        )
                      : null,
                ),
              if (const {'open', 'in_progress'}.contains(count['status']))
                Padding(
                  padding: const EdgeInsets.all(FactorySpacing.md),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonal(
                      onPressed: () => _run(() async {
                        await client.rpc(
                          'warehouse_submit_cycle_count',
                          params: {'p_cycle_count_id': count['id']},
                        );
                      }, 'Cycle count submitted.'),
                      child: const Text('Submit count'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      if (data.counts.isEmpty)
        const _Empty(
          icon: Icons.fact_check_outlined,
          text: 'No open cycle counts.',
        ),
    ],
  );
}

class _WarehouseMobileData {
  const _WarehouseMobileData({
    required this.role,
    required this.factories,
    required this.locations,
    required this.putaway,
    required this.picks,
    required this.counts,
  });
  final AppRole role;
  final List<Map<String, dynamic>> factories, locations, putaway, picks, counts;
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(FactorySpacing.xl),
    child: Column(
      children: [
        Icon(icon, size: 54, color: Theme.of(context).colorScheme.outline),
        const SizedBox(height: FactorySpacing.md),
        Text(text, textAlign: TextAlign.center),
      ],
    ),
  );
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

String _location(List<Map<String, dynamic>> rows, dynamic id) {
  for (final row in rows) {
    if (row['id'] == id) return '${row['code']} · ${row['name']}';
  }
  return 'Unknown';
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
