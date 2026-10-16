import 'package:factoryos_core/factoryos_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CommercialOperationsPage extends StatefulWidget {
  const CommercialOperationsPage({super.key});
  @override
  State<CommercialOperationsPage> createState() =>
      _CommercialOperationsPageState();
}

class _CommercialOperationsPageState extends State<CommercialOperationsPage> {
  late Future<_CommercialMobileData> future;
  final client = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    future = _load();
  }

  void reload() => setState(() => future = _load());
  void message(String value, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value),
          backgroundColor: error ? Theme.of(context).colorScheme.error : null,
        ),
      );

  Future<_CommercialMobileData> _load() async {
    final membershipRows = await client
        .from('organization_members')
        .select('organization_id')
        .eq('user_id', client.auth.currentUser!.id)
        .eq('is_active', true)
        .limit(1);
    if (membershipRows.isEmpty) {
      throw StateError('No active organization membership.');
    }
    final orgId = membershipRows.first['organization_id'] as String;
    final values = await Future.wait<dynamic>([
      client
          .from('purchase_orders')
          .select(
            'id,factory_id,purchase_order_no,status,business_partners(name),purchase_order_lines(id,ordered_quantity,received_quantity,inventory_items(name,sku))',
          )
          .eq('organization_id', orgId)
          .inFilter('status', ['approved', 'sent', 'partially_received'])
          .order('created_at', ascending: false)
          .limit(100),
      client
          .from('goods_receipts')
          .select(
            'id,factory_id,goods_receipt_no,status,received_location_id,purchase_orders(purchase_order_no),goods_receipt_lines(quantity_received,inventory_items(name),quality_inspections(inspection_no,overall_result,status))',
          )
          .eq('organization_id', orgId)
          .inFilter('status', [
            'received',
            'quality_pending',
            'quality_passed',
            'quality_hold',
          ])
          .order('received_at', ascending: false)
          .limit(100),
      client
          .from('sales_orders')
          .select(
            'id,factory_id,sales_order_no,status,business_partners(name),sales_order_lines(ordered_quantity,allocated_quantity,inventory_items(name,sku))',
          )
          .eq('organization_id', orgId)
          .inFilter('status', ['confirmed', 'allocated', 'dispatch_ready'])
          .order('order_date', ascending: false)
          .limit(100),
      client
          .from('stock_locations')
          .select('id,factory_id,name,code,location_type')
          .eq('organization_id', orgId)
          .eq('is_active', true)
          .order('name'),
    ]);
    return _CommercialMobileData(
      purchaseOrders: _rows(values[0]),
      receipts: _rows(values[1]),
      salesOrders: _rows(values[2]),
      locations: _rows(values[3]),
    );
  }

  Future<void> receive(
    _CommercialMobileData data,
    Map<String, dynamic> po,
  ) async {
    final lines = _nested(po, 'purchase_order_lines')
        .where(
          (l) =>
              (l['received_quantity'] as num) < (l['ordered_quantity'] as num),
        )
        .toList();
    final locations = data.locations
        .where((l) => l['factory_id'] == po['factory_id'])
        .toList();
    if (lines.isEmpty || locations.isEmpty) {
      return message(
        'No receivable line or location is available.',
        error: true,
      );
    }
    final draft = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ReceiveSheet(po: po, lines: lines, locations: locations),
    );
    if (draft == null) return;
    try {
      await client.rpc(
        'commercial_receive_goods',
        params: {
          'p_purchase_order_id': po['id'],
          'p_received_location_id': draft['location_id'],
          'p_lines': draft['lines'],
          'p_notes': draft['notes'],
        },
      );
      if (!mounted) return;
      message('Goods receipt posted. Incoming Quality started when required.');
      reload();
    } catch (e) {
      if (mounted) message(_error(e), error: true);
    }
  }

  Future<void> release(
    _CommercialMobileData data,
    Map<String, dynamic> grn,
  ) async {
    final locations = data.locations
        .where(
          (l) =>
              l['factory_id'] == grn['factory_id'] &&
              l['id'] != grn['received_location_id'],
        )
        .toList();
    final locationId = await showModalBottomSheet<String>(
      context: context,
      builder: (_) =>
          _LocationSheet(title: 'Release to Inventory', locations: locations),
    );
    if (locationId == null) return;
    try {
      await client.rpc(
        'commercial_release_goods_receipt',
        params: {
          'p_goods_receipt_id': grn['id'],
          'p_to_location_id': locationId,
        },
      );
      if (!mounted) return;
      message('Receipt released to available Inventory.');
      reload();
    } catch (e) {
      if (mounted) message(_error(e), error: true);
    }
  }

  Future<void> allocate(
    _CommercialMobileData data,
    Map<String, dynamic> order,
  ) async {
    final locations = data.locations
        .where(
          (l) =>
              l['factory_id'] == order['factory_id'] &&
              const {'warehouse', 'dispatch'}.contains(l['location_type']),
        )
        .toList();
    final locationId = await showModalBottomSheet<String>(
      context: context,
      builder: (_) =>
          _LocationSheet(title: 'Allocate stock from', locations: locations),
    );
    if (locationId == null) return;
    try {
      await client.rpc(
        'commercial_allocate_sales_order',
        params: {'p_sales_order_id': order['id'], 'p_location_id': locationId},
      );
      if (!mounted) return;
      message('Sales order allocated.');
      reload();
    } catch (e) {
      if (mounted) message(_error(e), error: true);
    }
  }

  Future<void> ready(Map<String, dynamic> order) async {
    try {
      await client.rpc(
        'commercial_mark_dispatch_ready',
        params: {'p_sales_order_id': order['id']},
      );
      if (!mounted) return;
      message('Sales order is dispatch ready.');
      reload();
    } catch (e) {
      if (mounted) message(_error(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Purchase & Sales'),
      actions: [IconButton(onPressed: reload, icon: const Icon(Icons.refresh))],
    ),
    body: FutureBuilder<_CommercialMobileData>(
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
        return RefreshIndicator(
          onRefresh: () async => reload(),
          child: ListView(
            padding: const EdgeInsets.all(FactorySpacing.md),
            children: [
              _Header(
                title: 'Goods to receive',
                count: data.purchaseOrders.length,
                icon: Icons.inventory_outlined,
              ),
              for (final po in data.purchaseOrders)
                Card(
                  child: ListTile(
                    title: Text(
                      po['purchase_order_no'] as String,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      '${_rel(po, 'business_partners', 'name')} · ${_title(po['status'] as String)}',
                    ),
                    trailing: FilledButton.tonal(
                      onPressed: () => receive(data, po),
                      child: const Text('Receive'),
                    ),
                  ),
                ),
              const SizedBox(height: FactorySpacing.lg),
              _Header(
                title: 'Incoming quality / release',
                count: data.receipts.length,
                icon: Icons.fact_check_outlined,
              ),
              for (final grn in data.receipts)
                Card(
                  child: ExpansionTile(
                    title: Text(
                      grn['goods_receipt_no'] as String,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      '${_title(grn['status'] as String)} · ${_rel(grn, 'purchase_orders', 'purchase_order_no')}',
                    ),
                    trailing:
                        const {
                          'received',
                          'quality_passed',
                        }.contains(grn['status'])
                        ? FilledButton.tonal(
                            onPressed: () => release(data, grn),
                            child: const Text('Release'),
                          )
                        : null,
                    children: [
                      for (final line in _nested(grn, 'goods_receipt_lines'))
                        ListTile(
                          dense: true,
                          title: Text(
                            '${_rel(line, 'inventory_items', 'name')} · ${_number(line['quantity_received'])}',
                          ),
                          subtitle: line['quality_inspections'] is Map
                              ? Text(
                                  'QC ${_rel(line, 'quality_inspections', 'inspection_no')} · ${_title(_rel(line, 'quality_inspections', 'overall_result'))}',
                                )
                              : const Text('No incoming inspection'),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: FactorySpacing.lg),
              _Header(
                title: 'Sales allocation',
                count: data.salesOrders.length,
                icon: Icons.local_shipping_outlined,
              ),
              for (final order in data.salesOrders)
                Card(
                  child: ExpansionTile(
                    title: Text(
                      order['sales_order_no'] as String,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      '${_rel(order, 'business_partners', 'name')} · ${_title(order['status'] as String)}',
                    ),
                    trailing: order['status'] == 'confirmed'
                        ? FilledButton.tonal(
                            onPressed: () => allocate(data, order),
                            child: const Text('Allocate'),
                          )
                        : order['status'] == 'allocated'
                        ? FilledButton.tonal(
                            onPressed: () => ready(order),
                            child: const Text('Ready'),
                          )
                        : const Icon(Icons.check_circle_outline),
                    children: [
                      for (final line in _nested(order, 'sales_order_lines'))
                        ListTile(
                          dense: true,
                          title: Text(_rel(line, 'inventory_items', 'name')),
                          subtitle: Text(
                            'Ordered ${_number(line['ordered_quantity'])} · Allocated ${_number(line['allocated_quantity'])}',
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}

class _CommercialMobileData {
  const _CommercialMobileData({
    required this.purchaseOrders,
    required this.receipts,
    required this.salesOrders,
    required this.locations,
  });
  final List<Map<String, dynamic>> purchaseOrders,
      receipts,
      salesOrders,
      locations;
}

class _ReceiveSheet extends StatefulWidget {
  const _ReceiveSheet({
    required this.po,
    required this.lines,
    required this.locations,
  });
  final Map<String, dynamic> po;
  final List<Map<String, dynamic>> lines, locations;
  @override
  State<_ReceiveSheet> createState() => _ReceiveSheetState();
}

class _ReceiveSheetState extends State<_ReceiveSheet> {
  String? lineId, locationId;
  final quantity = TextEditingController();
  final lot = TextEditingController();
  final notes = TextEditingController();
  bool quality = true;
  @override
  void initState() {
    super.initState();
    lineId = widget.lines.first['id'] as String;
    final qc = widget.locations
        .where((l) => l['location_type'] == 'quality')
        .toList();
    locationId =
        (qc.isNotEmpty ? qc.first : widget.locations.first)['id'] as String;
  }

  @override
  void dispose() {
    quantity.dispose();
    lot.dispose();
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final line = widget.lines.firstWhere((l) => l['id'] == lineId);
    final remaining =
        (line['ordered_quantity'] as num) - (line['received_quantity'] as num);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: FactorySpacing.lg,
          right: FactorySpacing.lg,
          top: FactorySpacing.lg,
          bottom: MediaQuery.viewInsetsOf(context).bottom + FactorySpacing.lg,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Receive ${widget.po['purchase_order_no']}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              DropdownButtonFormField<String>(
                initialValue: lineId,
                decoration: const InputDecoration(labelText: 'PO item'),
                items: [
                  for (final l in widget.lines)
                    DropdownMenuItem(
                      value: l['id'] as String,
                      child: Text(
                        '${_rel(l, 'inventory_items', 'name')} · rem ${_number((l['ordered_quantity'] as num) - (l['received_quantity'] as num))}',
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => lineId = v),
              ),
              const SizedBox(height: FactorySpacing.sm),
              DropdownButtonFormField<String>(
                initialValue: locationId,
                decoration: const InputDecoration(
                  labelText: 'Receiving location',
                ),
                items: [
                  for (final l in widget.locations)
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
                ),
                decoration: InputDecoration(
                  labelText: 'Quantity',
                  helperText: 'Remaining ${_number(remaining)}',
                ),
              ),
              const SizedBox(height: FactorySpacing.sm),
              TextField(
                controller: lot,
                decoration: const InputDecoration(labelText: 'Lot / batch'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Incoming quality required'),
                value: quality,
                onChanged: (v) => setState(() => quality = v),
              ),
              TextField(
                controller: notes,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
              const SizedBox(height: FactorySpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    final q = double.tryParse(quantity.text.trim());
                    if (q == null ||
                        q <= 0 ||
                        q > remaining ||
                        locationId == null) {
                      return;
                    }
                    Navigator.pop(context, {
                      'location_id': locationId,
                      'notes': notes.text.trim(),
                      'lines': [
                        {
                          'purchase_order_line_id': lineId,
                          'quantity': q,
                          'lot_batch_no': lot.text.trim().isEmpty
                              ? null
                              : lot.text.trim(),
                          'quality_required': quality,
                        },
                      ],
                    });
                  },
                  child: const Text('Post goods receipt'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationSheet extends StatelessWidget {
  const _LocationSheet({required this.title, required this.locations});
  final String title;
  final List<Map<String, dynamic>> locations;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(FactorySpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: FactorySpacing.sm),
          for (final l in locations)
            ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: Text('${l['code']} · ${l['name']}'),
              subtitle: Text(_title(l['location_type'] as String)),
              onTap: () => Navigator.pop(context, l['id'] as String),
            ),
        ],
      ),
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.count, required this.icon});
  final String title;
  final int count;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: FactorySpacing.sm),
    child: Row(
      children: [
        Icon(icon, color: FactoryColors.blue),
        const SizedBox(width: FactorySpacing.sm),
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        CircleAvatar(radius: 15, child: Text('$count')),
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

String _rel(Map<String, dynamic> row, String key, String field) {
  final value = row[key];
  return value is Map && value[field] != null ? '${value[field]}' : '—';
}

String _title(String value) => value
    .replaceAll('_', ' ')
    .split(' ')
    .where((p) => p.isNotEmpty)
    .map((p) => '${p[0].toUpperCase()}${p.substring(1)}')
    .join(' ');
String _number(dynamic value) {
  final n = value is num ? value : num.tryParse('$value') ?? 0;
  return n % 1 == 0 ? n.toInt().toString() : n.toStringAsFixed(2);
}

String _error(Object error) => error
    .toString()
    .replaceFirst('PostgrestException(message: ', '')
    .replaceFirst('AuthException(message: ', '');
