import 'dart:math';

import 'package:factoryos_core/factoryos_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Identity and inspection evidence only. Stock and customer custody remain
/// controlled by the existing quantity-based workflows.
class GasContainerRegistryPage extends StatefulWidget {
  const GasContainerRegistryPage({
    required this.organizationId,
    required this.actorRole,
    required this.factories,
    super.key,
  });

  final String organizationId;
  final AppRole actorRole;
  final List<Map<String, dynamic>> factories;

  @override
  State<GasContainerRegistryPage> createState() => _GasContainerRegistryPageState();
}

class _GasContainerRegistryPageState extends State<GasContainerRegistryPage> {
  String? factoryId;
  String filter = '';
  Future<_RegistryData>? future;
  final search = TextEditingController();
  final client = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    if (widget.factories.isNotEmpty) {
      factoryId = widget.factories.first['id'] as String;
      future = load();
    }
    search.addListener(() => setState(() => filter = search.text.trim().toUpperCase()));
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<_RegistryData> load() async {
    final assets = List<Map<String, dynamic>>.from(await client
        .from('gas_container_assets')
        .select('id,serial_number,qr_code,item_id,container_type,ownership,state,condition,test_due_on,last_inspection_at,created_at')
        .eq('factory_id', factoryId!)
        .order('created_at', ascending: false)
        .limit(200));
    final items = List<Map<String, dynamic>>.from(await client
        .from('inventory_items')
        .select('id,sku,name,item_type,is_returnable')
        .eq('organization_id', widget.organizationId)
        .eq('is_active', true)
        .order('name'));
    final transactions = List<Map<String, dynamic>>.from(await client
        .from('inventory_transactions')
        .select('id,transaction_no,item_id,transaction_type,quantity,occurred_at')
        .eq('factory_id', factoryId!)
        .order('occurred_at', ascending: false)
        .limit(200));
    final coverage = List<Map<String, dynamic>>.from(
      await client.rpc('gas_serial_attestation_coverage', params: {
        'p_organization_id': widget.organizationId,
        'p_factory_id': factoryId,
        'p_limit': 200,
      }) as List<dynamic>,
    );
    return _RegistryData(
      assets: assets,
      coverage: coverage,
      transactions: transactions,
      items: items.where((item) =>
        item['item_type'] == 'cylinder' || item['is_returnable'] == true).toList(),
    );
  }

  void reload() {
    if (factoryId != null) setState(() => future = load());
  }

  void showMessage(String value, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(value),
      backgroundColor: error ? Theme.of(context).colorScheme.error : null,
    ));
  }

  Future<void> register(_RegistryData data) async {
    if (data.items.isEmpty) {
      showMessage('Create an active cylinder/returnable Inventory item first.', error: true);
      return;
    }
    final draft = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _RegisterDialog(items: data.items),
    );
    if (draft == null || !mounted) return;
    try {
      await client.rpc('gas_register_container', params: {
        'p_factory_id': factoryId,
        'p_item_id': draft['item_id'],
        'p_serial_number': draft['serial_number'],
        'p_container_type': draft['container_type'],
        'p_ownership': draft['ownership'],
        'p_test_due_on': draft['test_due_on'],
        'p_notes': draft['notes'],
      });
      showMessage('Container registered on hold; inspection and certification still required.');
      reload();
    } catch (e) {
      showMessage(_error(e), error: true);
    }
  }

  Future<void> inspect(Map<String, dynamic> asset) async {
    final notes = TextEditingController();
    String condition = 'good';
    try {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, update) => AlertDialog(
            title: Text('Record inspection · ${asset['serial_number']}'),
            content: SizedBox(
              width: 480,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('This records a visual condition only. It does not certify pressure testing, approve refilling, or change Inventory stock.'),
                const SizedBox(height: FactorySpacing.md),
                DropdownButtonFormField<String>(
                  initialValue: condition,
                  decoration: const InputDecoration(labelText: 'Observed condition'),
                  items: const [
                    DropdownMenuItem(value: 'good', child: Text('Good · inspection recorded')),
                    DropdownMenuItem(value: 'damaged', child: Text('Damaged · quarantine')),
                    DropdownMenuItem(value: 'rejected', child: Text('Rejected · quarantine')),
                  ],
                  onChanged: (value) { if (value != null) update(() => condition = value); },
                ),
                const SizedBox(height: FactorySpacing.md),
                TextField(
                  controller: notes,
                  onChanged: (_) => update(() {}),
                  maxLength: 500,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Inspection observations (required)'),
                ),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
              FilledButton(
                onPressed: notes.text.trim().length < 3
                    ? null
                    : () => Navigator.pop(dialogContext, true),
                child: const Text('Save inspection'),
              ),
            ],
          ),
        ),
      );
      if (accepted != true || !mounted) return;
      await client.rpc('gas_record_container_inspection', params: {
        'p_asset_id': asset['id'],
        'p_condition': condition,
        'p_notes': notes.text.trim(),
      });
      showMessage('Inspection recorded without releasing the cylinder for dispatch.');
      reload();
    } catch (e) {
      showMessage(_error(e), error: true);
    } finally {
      notes.dispose();
    }
  }

  Future<void> retire(Map<String, dynamic> asset) async {
    final reason = TextEditingController();
    try {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Retire ${asset['serial_number']}?'),
          content: SizedBox(width: 430, child: TextField(
            controller: reason,
            maxLength: 500,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Reason (at least 5 characters)'),
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Retire asset')),
          ],
        ),
      );
      if (accepted != true || reason.text.trim().length < 5 || !mounted) return;
      await client.rpc('gas_retire_container', params: {
        'p_asset_id': asset['id'],
        'p_reason': reason.text.trim(),
      });
      showMessage('Asset retired and event history preserved.');
      reload();
    } catch (e) {
      showMessage(_error(e), error: true);
    } finally {
      reason.dispose();
    }
  }

  Future<void> linkTransaction(
    Map<String, dynamic> asset,
    _RegistryData data,
  ) async {
    final candidates = data.transactions
        .where((row) => row['item_id'] == asset['item_id'])
        .toList();
    if (candidates.isEmpty) {
      showMessage(
        'No recent Inventory transaction matches this container item.',
        error: true,
      );
      return;
    }
    final scannedCode = TextEditingController();
    var transactionId = candidates.first['id'] as String;
    try {
      final approved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, update) => AlertDialog(
            title: const Text('Attach serial to Inventory transaction'),
            content: SizedBox(
              width: 490,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text(
                  'This creates an auditable serial attestation for a posted '
                  'Inventory movement. It does not move stock, prove unscanned '
                  'custody or certify the container.',
                ),
                const SizedBox(height: FactorySpacing.md),
                DropdownButtonFormField<String>(
                  initialValue: transactionId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Recorded movement'),
                  items: candidates.map((row) => DropdownMenuItem(
                    value: row['id'] as String,
                    child: Text(
                      '${row['transaction_no']} · ${row['transaction_type']} · ${row['quantity']}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  )).toList(),
                  onChanged: (value) {
                    if (value != null) update(() => transactionId = value);
                  },
                ),
                const SizedBox(height: FactorySpacing.md),
                TextField(
                  controller: scannedCode,
                  maxLength: 80,
                  onChanged: (_) => update(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Scan or enter the physical serial / QR',
                    prefixIcon: Icon(Icons.qr_code_scanner),
                  ),
                ),
              ]),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: scannedCode.text.trim().length < 3
                    ? null
                    : () => Navigator.pop(dialogContext, true),
                child: const Text('Record serial attestation'),
              ),
            ],
          ),
        ),
      );
      if (approved != true || !mounted) return;
      await client.rpc('gas_link_container_transaction', params: {
        'p_asset_id': asset['id'],
        'p_transaction_id': transactionId,
        'p_scanned_code': scannedCode.text.trim(),
        'p_request_key': _randomRequestId(),
      });
      showMessage('Serial attestation saved. Inventory quantity was unchanged.');
      reload();
    } catch (e) {
      showMessage(_error(e), error: true);
    } finally {
      scannedCode.dispose();
    }
  }

  Future<void> showHistory(Map<String, dynamic> asset) async {
    try {
      final events = List<Map<String, dynamic>>.from(await client
          .from('gas_container_asset_events')
          .select('event_type,condition_after,state_after,notes,created_at')
          .eq('asset_id', asset['id'] as String)
          .order('created_at', ascending: false)
          .limit(100));
      final links = List<Map<String, dynamic>>.from(await client
          .from('gas_container_transaction_links')
          .select('transaction_type,transaction_id,from_location_id,to_location_id,customer_id,recorded_at')
          .eq('asset_id', asset['id'] as String)
          .order('recorded_at', ascending: false)
          .limit(100));
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('History · ${asset['serial_number']}'),
          content: SizedBox(width: 520, height: 360, child: ListView(
            children: [
              const Text('Transaction-linked serial attestations (not a complete custody trail)'),
              for (final link in links)
                ListTile(
                  leading: const Icon(Icons.sync_alt_outlined),
                  title: Text('${_display(link['transaction_type'])} · ${link['recorded_at']}'),
                  subtitle: Text('Inventory transaction: ${link['transaction_id']}'),
                ),
              const Divider(),
              const Text('Physical asset inspection events'),
              for (final event in events)
                ListTile(
                  leading: const Icon(Icons.history),
                  title: Text('${_display(event['event_type'])} · ${_display(event['state_after'])}'),
                  subtitle: Text('${event['notes'] ?? ''}\n${event['created_at']}'),
                ),
              if (events.isEmpty) const Text('No recorded events.'),
            ],
          )),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
        ),
      );
    } catch (e) {
      showMessage(_error(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.factories.isEmpty) {
      return const Center(child: Text('Create and assign a factory before registering gas assets.'));
    }
    return FutureBuilder<_RegistryData>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Registry could not be loaded: ${snapshot.error}'));
        }
        final data = snapshot.requireData;
        final visible = data.assets.where((row) =>
          filter.isEmpty ||
          '${row['serial_number']} ${row['qr_code']}'.toUpperCase().contains(filter)).toList();
        final withoutEvidence = data.coverage
            .where((row) => row['coverage_status'] != 'fully_attested')
            .toList();
        return ListView(padding: const EdgeInsets.all(FactorySpacing.lg), children: [
          Text('Cylinder & Dura registry', style: Theme.of(context).textTheme.headlineMedium),
          const Text('Serial/QR identity, inspection observations and immutable history. Stock movement and safety approval are separate.'),
          const SizedBox(height: FactorySpacing.md),
          Wrap(spacing: FactorySpacing.md, runSpacing: FactorySpacing.sm, children: [
            SizedBox(width: 260, child: DropdownButtonFormField<String>(
              initialValue: factoryId,
              decoration: const InputDecoration(labelText: 'Factory'),
              items: widget.factories.map((factory) => DropdownMenuItem(
                value: factory['id'] as String,
                child: Text(factory['name'] as String),
              )).toList(),
              onChanged: (id) {
                if (id == null || id == factoryId) return;
                setState(() { factoryId = id; future = load(); });
              },
            )),
            SizedBox(width: 260, child: TextField(
              controller: search,
              decoration: const InputDecoration(
                labelText: 'Search serial or QR',
                prefixIcon: Icon(Icons.search),
              ),
            )),
            IconButton(tooltip: 'Refresh', onPressed: reload, icon: const Icon(Icons.refresh)),
            if (widget.actorRole.canUseAdminPortal)
              FilledButton.icon(
                onPressed: () => register(data),
                icon: const Icon(Icons.add),
                label: const Text('Register container'),
              ),
          ]),
          const SizedBox(height: FactorySpacing.sm),
          Card(
            child: ExpansionTile(
              leading: const Icon(Icons.fact_check_outlined),
              title: Text(
                'Serial evidence reconciliation · ${withoutEvidence.length} unattested/partial movements',
              ),
              subtitle: const Text(
                'Last 200 cylinder/returnable Inventory transactions only. '
                'Unattested means no serial evidence—not missing physical stock.',
              ),
              children: [
                if (withoutEvidence.isEmpty)
                  const ListTile(
                    title: Text('No unattested transactions in this limited view.'),
                    subtitle: Text('This does not prove every historical movement was scanned.'),
                  ),
                for (final row in withoutEvidence.take(30))
                  ListTile(
                    leading: const Icon(Icons.warning_amber_outlined),
                    title: Text(
                      '${row['transaction_no']} · ${row['sku']} · '
                      '${_display(row['coverage_status'])}',
                    ),
                    subtitle: Text(
                      'Evidence: ${row['linked_serial_count']} of ${row['quantity']} units · '
                      '${row['occurred_at']}',
                    ),
                    trailing: Text(
                      'Unattested: ${row['unattested_quantity']}',
                    ),
                  ),
                if (withoutEvidence.length > 30)
                  const ListTile(
                    title: Text('Showing first 30 exceptions. Expand report limits in a separate audited export.'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: FactorySpacing.sm),
          Text('Showing ${visible.length} of the latest ${data.assets.length} records (200 record cap).'),
          const SizedBox(height: FactorySpacing.md),
          if (visible.isEmpty) const Center(child: Padding(
            padding: EdgeInsets.all(FactorySpacing.xl),
            child: Text('No registered containers found in this factory.'),
          )),
          for (final asset in visible)
            Card(child: ListTile(
              leading: Icon(asset['container_type'] == 'dura'
                  ? Icons.propane_tank_outlined : Icons.inventory_2_outlined),
              title: Text('${asset['serial_number']} · ${_display(asset['container_type'])}'),
              subtitle: Text(
                'QR: ${asset['qr_code']}\n'
                'State: ${_display(asset['state'])} · Condition: ${_display(asset['condition'])}\n'
                'Test due: ${asset['test_due_on'] ?? 'Not recorded'} · Inspection is not certification',
              ),
              isThreeLine: true,
              onTap: () => showHistory(asset),
              trailing: widget.actorRole.canUseAdminPortal && asset['state'] != 'retired'
                  ? PopupMenuButton<String>(
                      tooltip: 'Container actions',
                      onSelected: (action) {
                        if (action == 'inspect') inspect(asset);
                        if (action == 'link') linkTransaction(asset, data);
                        if (action == 'retire') retire(asset);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'inspect', child: Text('Record inspection')),
                        PopupMenuItem(value: 'link', child: Text('Attach serial to movement')),
                        PopupMenuItem(value: 'retire', child: Text('Retire')),
                      ],
                    )
                  : const Icon(Icons.history),
            )),
        ]);
      },
    );
  }
}

class _RegistryData {
  const _RegistryData({
    required this.assets,
    required this.items,
    required this.transactions,
    required this.coverage,
  });
  final List<Map<String, dynamic>> assets;
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> transactions;
  final List<Map<String, dynamic>> coverage;
}

class _RegisterDialog extends StatefulWidget {
  const _RegisterDialog({required this.items});
  final List<Map<String, dynamic>> items;

  @override
  State<_RegisterDialog> createState() => _RegisterDialogState();
}

class _RegisterDialogState extends State<_RegisterDialog> {
  final serial = TextEditingController();
  final notes = TextEditingController();
  late String itemId = widget.items.first['id'] as String;
  String type = 'cylinder';
  String ownership = 'owned';
  DateTime? testDue;

  @override
  void dispose() {
    serial.dispose();
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Register physical container'),
    content: SizedBox(width: 510, child: SingleChildScrollView(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Registration does not create stock, customer custody, or a pressure-test certificate.'),
        const SizedBox(height: FactorySpacing.md),
        DropdownButtonFormField<String>(
          initialValue: itemId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Existing Inventory item'),
          items: widget.items.map((item) => DropdownMenuItem(
            value: item['id'] as String,
            child: Text('${item['sku']} · ${item['name']}', overflow: TextOverflow.ellipsis),
          )).toList(),
          onChanged: (value) { if (value != null) setState(() => itemId = value); },
        ),
        const SizedBox(height: FactorySpacing.md),
        TextField(controller: serial, maxLength: 80,
          decoration: const InputDecoration(labelText: 'Unique manufacturer/asset serial')),
        const SizedBox(height: FactorySpacing.sm),
        DropdownButtonFormField<String>(
          initialValue: type,
          decoration: const InputDecoration(labelText: 'Container type'),
          items: const [
            DropdownMenuItem(value: 'cylinder', child: Text('Cylinder')),
            DropdownMenuItem(value: 'dura', child: Text('Dura')),
          ],
          onChanged: (value) { if (value != null) setState(() => type = value); },
        ),
        const SizedBox(height: FactorySpacing.sm),
        DropdownButtonFormField<String>(
          initialValue: ownership,
          decoration: const InputDecoration(labelText: 'Ownership'),
          items: const [
            DropdownMenuItem(value: 'owned', child: Text('Company owned')),
            DropdownMenuItem(value: 'customer', child: Text('Customer owned')),
            DropdownMenuItem(value: 'leased', child: Text('Leased')),
          ],
          onChanged: (value) { if (value != null) setState(() => ownership = value); },
        ),
        const SizedBox(height: FactorySpacing.sm),
        OutlinedButton.icon(
          icon: const Icon(Icons.event),
          onPressed: () async {
            final value = await showDatePicker(
              context: context,
              initialDate: testDue ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (value != null) setState(() => testDue = value);
          },
          label: Text(testDue == null
            ? 'Record next test due date (optional)'
            : 'Test due ${testDue!.year}-${testDue!.month.toString().padLeft(2, '0')}-${testDue!.day.toString().padLeft(2, '0')}'),
        ),
        const SizedBox(height: FactorySpacing.sm),
        TextField(
          controller: notes, maxLines: 2, maxLength: 500,
          decoration: const InputDecoration(labelText: 'Notes (optional)'),
        ),
      ]),
    )),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(
        onPressed: () {
          if (serial.text.trim().length < 3) return;
          Navigator.pop(context, {
            'item_id': itemId,
            'serial_number': serial.text.trim(),
            'container_type': type,
            'ownership': ownership,
            'test_due_on': testDue == null ? null
              : '${testDue!.year}-${testDue!.month.toString().padLeft(2, '0')}-${testDue!.day.toString().padLeft(2, '0')}',
            'notes': notes.text.trim().isEmpty ? null : notes.text.trim(),
          });
        },
        child: const Text('Register on hold'),
      ),
    ],
  );
}

String _display(Object? text) => '${text ?? '—'}'.split('_')
    .map((part) => part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

String _randomRequestId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

String _error(Object error) =>
    error is PostgrestException ? error.message : '$error';
