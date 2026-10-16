import 'package:factoryos_core/factoryos_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'inventory_editors.dart';

class InventoryManagementPage extends StatefulWidget {
  const InventoryManagementPage({
    required this.organizationId,
    required this.actorRole,
    required this.factories,
    super.key,
  });

  final String organizationId;
  final AppRole actorRole;
  final List<Map<String, dynamic>> factories;

  @override
  State<InventoryManagementPage> createState() =>
      _InventoryManagementPageState();
}

class _InventoryManagementPageState extends State<InventoryManagementPage> {
  int section = 0;
  late Future<InventorySnapshot> future;
  InventoryRepository get repository =>
      InventoryRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    future = repository.load(widget.organizationId);
  }

  void reload() =>
      setState(() => future = repository.load(widget.organizationId));

  void message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  Future<void> editItem(
    InventorySnapshot data, [
    Map<String, dynamic>? initial,
  ]) async {
    final draft = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => InventoryItemEditor(
        categories: data.categories,
        units: data.units,
        initial: initial,
      ),
    );
    if (draft == null) return;
    try {
      await repository.saveItem(
        widget.organizationId,
        draft,
        id: initial?['id'] as String?,
      );
      if (!mounted) return;
      message(initial == null ? 'Item added.' : 'Item updated.');
      reload();
    } catch (e) {
      if (mounted) message(_errorText(e), error: true);
    }
  }

  Future<void> toggleItem(Map<String, dynamic> item) async {
    try {
      await repository.updateItem(item['id'] as String, {
        'is_active': item['is_active'] != true,
      });
      reload();
    } catch (e) {
      if (mounted) message(_errorText(e), error: true);
    }
  }

  Future<void> editCategory([Map<String, dynamic>? initial]) async {
    final draft = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => InventoryNameCodeEditor(
        title: initial == null ? 'Add category' : 'Edit category',
        initial: initial,
      ),
    );
    if (draft == null) return;
    try {
      await repository.saveCategory(
        widget.organizationId,
        draft,
        id: initial?['id'] as String?,
      );
      reload();
    } catch (e) {
      if (mounted) message(_errorText(e), error: true);
    }
  }

  Future<void> editUnit([Map<String, dynamic>? initial]) async {
    final draft = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => InventoryNameCodeEditor(
        title: initial == null ? 'Add unit' : 'Edit unit',
        initial: initial,
        unitMode: true,
      ),
    );
    if (draft == null) return;
    try {
      await repository.saveUnit(
        widget.organizationId,
        draft,
        id: initial?['id'] as String?,
      );
      reload();
    } catch (e) {
      if (mounted) message(_errorText(e), error: true);
    }
  }

  Future<void> editLocation([Map<String, dynamic>? initial]) async {
    final draft = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) =>
          StockLocationEditor(factories: widget.factories, initial: initial),
    );
    if (draft == null) return;
    try {
      await repository.saveLocation(
        widget.organizationId,
        draft,
        id: initial?['id'] as String?,
      );
      reload();
    } catch (e) {
      if (mounted) message(_errorText(e), error: true);
    }
  }

  Future<void> editReorder(
    InventorySnapshot data, [
    Map<String, dynamic>? initial,
  ]) async {
    final draft = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => ReorderRuleEditor(
        factories: widget.factories,
        items: data.items,
        initial: initial,
      ),
    );
    if (draft == null) return;
    try {
      await repository.saveReorderRule(
        widget.organizationId,
        draft,
        id: initial?['id'] as String?,
      );
      reload();
    } catch (e) {
      if (mounted) message(_errorText(e), error: true);
    }
  }

  Future<void> movement(InventorySnapshot data, String type) async {
    final draft = await showDialog<StockMovementDraft>(
      context: context,
      builder: (_) => StockMovementEditor(
        type: type,
        factories: widget.factories,
        items: data.items,
        locations: data.locations,
      ),
    );
    if (draft == null) return;
    try {
      final transactionId = await repository.move(draft);
      if (!mounted) return;
      message('${_title(type)} completed · ${transactionId.substring(0, 8)}');
      reload();
    } catch (e) {
      if (mounted) message(_errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<InventorySnapshot>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return _InventoryError(message: '${snapshot.error}', onRetry: reload);
      }
      final data = snapshot.requireData;
      final canMaster = widget.actorRole.canManageOrganizationSetup;
      final canOperate = switch (widget.actorRole) {
        AppRole.platformOwner ||
        AppRole.orgAdmin ||
        AppRole.factoryManager => true,
        _ => false,
      };
      final sections = <_Section>[
        _Section(
          'Dashboard',
          Icons.dashboard_outlined,
          _InventoryDashboard(
            data: data,
            onMovement: canOperate ? (type) => movement(data, type) : null,
          ),
        ),
        _Section(
          'Items',
          Icons.inventory_2_outlined,
          _Items(
            data: data,
            canEdit: canMaster,
            onAdd: () => editItem(data),
            onEdit: (row) => editItem(data, row),
            onToggle: toggleItem,
          ),
        ),
        _Section(
          'Locations',
          Icons.warehouse_outlined,
          _Locations(
            data: data,
            canEdit: canOperate,
            factories: widget.factories,
            onAdd: () => editLocation(),
            onEdit: editLocation,
          ),
        ),
        _Section(
          'Movements',
          Icons.swap_horiz_outlined,
          _Movements(
            data: data,
            canOperate: canOperate,
            onMovement: (type) => movement(data, type),
          ),
        ),
        _Section(
          'Reorder',
          Icons.warning_amber_outlined,
          _Reorder(
            data: data,
            canEdit: canOperate,
            onAdd: () => editReorder(data),
            onEdit: (row) => editReorder(data, row),
          ),
        ),
        _Section(
          'Masters',
          Icons.category_outlined,
          _Masters(
            data: data,
            canEdit: canMaster,
            onCategory: editCategory,
            onUnit: editUnit,
          ),
        ),
        _Section('Reports', Icons.analytics_outlined, _Reports(data: data)),
      ];
      if (section >= sections.length) section = 0;
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
                const Icon(
                  Icons.inventory_2_outlined,
                  color: FactoryColors.blue,
                ),
                const SizedBox(width: FactorySpacing.sm),
                Expanded(
                  child: Text(
                    'Inventory',
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
            height: 56,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(
                horizontal: FactorySpacing.lg,
                vertical: FactorySpacing.sm,
              ),
              scrollDirection: Axis.horizontal,
              itemCount: sections.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(width: FactorySpacing.xs),
              itemBuilder: (_, i) => ChoiceChip(
                selected: section == i,
                avatar: Icon(sections[i].icon, size: 18),
                label: Text(sections[i].label),
                onSelected: (_) => setState(() => section = i),
              ),
            ),
          ),
          Expanded(child: sections[section].page),
        ],
      );
    },
  );
}

class InventorySnapshot {
  const InventorySnapshot({
    required this.summary,
    required this.categories,
    required this.units,
    required this.items,
    required this.locations,
    required this.reorderRules,
    required this.lowStock,
    required this.stock,
    required this.movements,
  });
  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> units;
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> locations;
  final List<Map<String, dynamic>> reorderRules;
  final List<Map<String, dynamic>> lowStock;
  final List<Map<String, dynamic>> stock;
  final List<Map<String, dynamic>> movements;
}

class InventoryRepository {
  InventoryRepository(this.client);
  final SupabaseClient client;

  Future<InventorySnapshot> load(String organizationId) async {
    final results = await Future.wait<dynamic>([
      client.rpc(
        'inventory_dashboard_summary',
        params: {'p_organization_id': organizationId},
      ),
      client
          .from('inventory_categories')
          .select('id,organization_id,name,code,is_active')
          .eq('organization_id', organizationId)
          .order('name'),
      client
          .from('inventory_units')
          .select('id,organization_id,name,code,decimal_places,is_active')
          .eq('organization_id', organizationId)
          .order('name'),
      client
          .from('inventory_items')
          .select(
            'id,organization_id,category_id,unit_id,sku,name,item_type,barcode,qr_code,is_batch_tracked,notes,is_active,inventory_categories(name,code),inventory_units(name,code)',
          )
          .eq('organization_id', organizationId)
          .order('name'),
      client
          .from('stock_locations')
          .select(
            'id,organization_id,factory_id,name,code,location_type,is_active',
          )
          .eq('organization_id', organizationId)
          .order('name'),
      client
          .from('inventory_reorder_rules')
          .select(
            'id,organization_id,factory_id,item_id,reorder_level,reorder_quantity,is_active,inventory_items(name,sku),factories(name,code)',
          )
          .eq('organization_id', organizationId),
      client.rpc(
        'inventory_reorder_report',
        params: {'p_organization_id': organizationId},
      ),
      client.rpc(
        'inventory_stock_report',
        params: {'p_organization_id': organizationId},
      ),
      client.rpc(
        'inventory_movement_report',
        params: {'p_organization_id': organizationId, 'p_limit': 100},
      ),
    ]);
    return InventorySnapshot(
      summary: Map<String, dynamic>.from(results[0] as Map),
      categories: _rows(results[1]),
      units: _rows(results[2]),
      items: _rows(results[3]),
      locations: _rows(results[4]),
      reorderRules: _rows(results[5]),
      lowStock: _rows(results[6]),
      stock: _rows(results[7]),
      movements: _rows(results[8]),
    );
  }

  Future<void> saveCategory(
    String orgId,
    Map<String, dynamic> values, {
    String? id,
  }) async => id == null
      ? client.from('inventory_categories').insert({
          'organization_id': orgId,
          ...values,
        })
      : client.from('inventory_categories').update(values).eq('id', id);
  Future<void> saveUnit(
    String orgId,
    Map<String, dynamic> values, {
    String? id,
  }) async => id == null
      ? client.from('inventory_units').insert({
          'organization_id': orgId,
          ...values,
        })
      : client.from('inventory_units').update(values).eq('id', id);
  Future<void> saveItem(
    String orgId,
    Map<String, dynamic> values, {
    String? id,
  }) async => id == null
      ? client.from('inventory_items').insert({
          'organization_id': orgId,
          ...values,
        })
      : client.from('inventory_items').update(values).eq('id', id);
  Future<void> updateItem(String id, Map<String, dynamic> values) async =>
      client.from('inventory_items').update(values).eq('id', id);
  Future<void> saveLocation(
    String orgId,
    Map<String, dynamic> values, {
    String? id,
  }) async => id == null
      ? client.from('stock_locations').insert({
          'organization_id': orgId,
          ...values,
        })
      : client.from('stock_locations').update(values).eq('id', id);
  Future<void> saveReorderRule(
    String orgId,
    Map<String, dynamic> values, {
    String? id,
  }) async => id == null
      ? client.from('inventory_reorder_rules').insert({
          'organization_id': orgId,
          ...values,
        })
      : client.from('inventory_reorder_rules').update(values).eq('id', id);

  Future<String> move(StockMovementDraft draft) async {
    late final dynamic result;
    if (draft.type == 'receive') {
      result = await client.rpc(
        'inventory_receive_stock',
        params: {
          'p_factory_id': draft.factoryId,
          'p_item_id': draft.itemId,
          'p_to_location_id': draft.toLocationId,
          'p_quantity': draft.quantity,
          'p_unit_cost': draft.unitCost,
          'p_external_reference': draft.reference,
          'p_notes': draft.notes,
        },
      );
    } else if (draft.type == 'issue') {
      result = await client.rpc(
        'inventory_issue_stock',
        params: {
          'p_factory_id': draft.factoryId,
          'p_item_id': draft.itemId,
          'p_from_location_id': draft.fromLocationId,
          'p_quantity': draft.quantity,
          'p_external_reference': draft.reference,
          'p_notes': draft.notes,
        },
      );
    } else {
      result = await client.rpc(
        'inventory_transfer_stock',
        params: {
          'p_factory_id': draft.factoryId,
          'p_item_id': draft.itemId,
          'p_from_location_id': draft.fromLocationId,
          'p_to_location_id': draft.toLocationId,
          'p_quantity': draft.quantity,
          'p_external_reference': draft.reference,
          'p_notes': draft.notes,
        },
      );
    }
    return result as String;
  }
}

class _InventoryDashboard extends StatelessWidget {
  const _InventoryDashboard({required this.data, this.onMovement});
  final InventorySnapshot data;
  final ValueChanged<String>? onMovement;

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
            _Metric(
              'Active items',
              '${s['active_items'] ?? 0}',
              Icons.inventory_2_outlined,
            ),
            _Metric(
              'Stock quantity',
              _num(s['total_quantity']),
              Icons.stacked_bar_chart_outlined,
            ),
            _Metric(
              'Low stock',
              '${s['low_stock_items'] ?? 0}',
              Icons.warning_amber_outlined,
            ),
            _Metric(
              'Today movements',
              '${s['today_movements'] ?? 0}',
              Icons.swap_horiz_outlined,
            ),
          ],
        ),
        const SizedBox(height: FactorySpacing.lg),
        if (onMovement != null)
          Wrap(
            spacing: FactorySpacing.sm,
            runSpacing: FactorySpacing.sm,
            children: [
              FilledButton.icon(
                onPressed: () => onMovement!('receive'),
                icon: const Icon(Icons.south_west),
                label: const Text('Receive'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => onMovement!('issue'),
                icon: const Icon(Icons.north_east),
                label: const Text('Issue'),
              ),
              OutlinedButton.icon(
                onPressed: () => onMovement!('transfer'),
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Transfer'),
              ),
            ],
          ),
        const SizedBox(height: FactorySpacing.lg),
        Text(
          'Exceptions',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: FactorySpacing.sm),
        if (data.lowStock.isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(Icons.check_circle_outline),
              title: Text('No low-stock items'),
            ),
          ),
        for (final row in data.lowStock.take(8))
          Card(
            child: ListTile(
              leading: const Icon(Icons.warning_amber_outlined),
              title: Text('${row['item_name']} · ${row['sku']}'),
              subtitle: Text(
                '${row['factory_name']} · Reorder ${_num(row['reorder_quantity'])}',
              ),
              trailing: Text(
                '${_num(row['current_quantity'])} / ${_num(row['reorder_level'])}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        const SizedBox(height: FactorySpacing.lg),
        Text(
          'Recent movements',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: FactorySpacing.sm),
        ...data.movements.take(6).map(_movementTile),
      ],
    );
  }
}

class _Items extends StatelessWidget {
  const _Items({
    required this.data,
    required this.canEdit,
    required this.onAdd,
    required this.onEdit,
    required this.onToggle,
  });
  final InventorySnapshot data;
  final bool canEdit;
  final VoidCallback onAdd;
  final ValueChanged<Map<String, dynamic>> onEdit;
  final ValueChanged<Map<String, dynamic>> onToggle;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(FactorySpacing.lg),
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Item master',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          if (canEdit)
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Item'),
            ),
        ],
      ),
      const SizedBox(height: FactorySpacing.md),
      for (final row in data.items)
        Card(
          child: ListTile(
            leading: Icon(
              row['item_type'] == 'cylinder'
                  ? Icons.local_gas_station_outlined
                  : Icons.inventory_2_outlined,
            ),
            title: Text(row['name'] as String),
            subtitle: Text(
              '${row['sku']} · ${_nested(row, 'inventory_categories', 'name') ?? 'Uncategorized'} · ${_nested(row, 'inventory_units', 'code') ?? ''}',
            ),
            trailing: canEdit
                ? PopupMenuButton<String>(
                    onSelected: (value) =>
                        value == 'edit' ? onEdit(row) : onToggle(row),
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(
                        value: 'toggle',
                        child: Text(
                          row['is_active'] == true ? 'Deactivate' : 'Activate',
                        ),
                      ),
                    ],
                  )
                : _status(row['is_active'] == true ? 'Active' : 'Inactive'),
          ),
        ),
    ],
  );
}

class _Locations extends StatelessWidget {
  const _Locations({
    required this.data,
    required this.canEdit,
    required this.factories,
    required this.onAdd,
    required this.onEdit,
  });
  final InventorySnapshot data;
  final bool canEdit;
  final List<Map<String, dynamic>> factories;
  final VoidCallback onAdd;
  final ValueChanged<Map<String, dynamic>> onEdit;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(FactorySpacing.lg),
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Stock locations',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          if (canEdit)
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Location'),
            ),
        ],
      ),
      const SizedBox(height: FactorySpacing.md),
      for (final row in data.locations)
        Card(
          child: ListTile(
            leading: const Icon(Icons.warehouse_outlined),
            title: Text(row['name'] as String),
            subtitle: Text(
              '${row['code']} · ${_factoryName(factories, row['factory_id'])} · ${_title(row['location_type'] as String)}',
            ),
            trailing: canEdit
                ? IconButton(
                    onPressed: () => onEdit(row),
                    icon: const Icon(Icons.edit_outlined),
                  )
                : null,
          ),
        ),
    ],
  );
}

class _Movements extends StatelessWidget {
  const _Movements({
    required this.data,
    required this.canOperate,
    required this.onMovement,
  });
  final InventorySnapshot data;
  final bool canOperate;
  final ValueChanged<String> onMovement;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(FactorySpacing.lg),
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Stock movements',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          if (canOperate)
            Wrap(
              spacing: FactorySpacing.sm,
              children: [
                FilledButton.icon(
                  onPressed: () => onMovement('receive'),
                  icon: const Icon(Icons.south_west),
                  label: const Text('Receive'),
                ),
                OutlinedButton.icon(
                  onPressed: () => onMovement('issue'),
                  icon: const Icon(Icons.north_east),
                  label: const Text('Issue'),
                ),
                OutlinedButton.icon(
                  onPressed: () => onMovement('transfer'),
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Transfer'),
                ),
              ],
            ),
        ],
      ),
      const SizedBox(height: FactorySpacing.md),
      ...data.movements.map(_movementTile),
    ],
  );
}

class _Reorder extends StatelessWidget {
  const _Reorder({
    required this.data,
    required this.canEdit,
    required this.onAdd,
    required this.onEdit,
  });
  final InventorySnapshot data;
  final bool canEdit;
  final VoidCallback onAdd;
  final ValueChanged<Map<String, dynamic>> onEdit;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(FactorySpacing.lg),
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Reorder rules',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          if (canEdit)
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_alert_outlined),
              label: const Text('Rule'),
            ),
        ],
      ),
      const SizedBox(height: FactorySpacing.md),
      for (final row in data.reorderRules)
        Card(
          child: ListTile(
            leading: const Icon(Icons.low_priority),
            title: Text(
              '${_nested(row, 'inventory_items', 'name') ?? 'Item'} · ${_nested(row, 'inventory_items', 'sku') ?? ''}',
            ),
            subtitle: Text(
              '${_nested(row, 'factories', 'name') ?? ''} · Level ${_num(row['reorder_level'])} · Reorder ${_num(row['reorder_quantity'])}',
            ),
            trailing: canEdit
                ? IconButton(
                    onPressed: () => onEdit(row),
                    icon: const Icon(Icons.edit_outlined),
                  )
                : null,
          ),
        ),
    ],
  );
}

class _Masters extends StatelessWidget {
  const _Masters({
    required this.data,
    required this.canEdit,
    required this.onCategory,
    required this.onUnit,
  });
  final InventorySnapshot data;
  final bool canEdit;
  final ValueChanged<Map<String, dynamic>?> onCategory;
  final ValueChanged<Map<String, dynamic>?> onUnit;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(FactorySpacing.lg),
    children: [
      _masterHeader(
        context,
        'Categories',
        canEdit ? () => onCategory(null) : null,
      ),
      ...data.categories.map(
        (row) => Card(
          child: ListTile(
            title: Text(row['name'] as String),
            subtitle: Text(row['code'] as String),
            trailing: canEdit
                ? IconButton(
                    onPressed: () => onCategory(row),
                    icon: const Icon(Icons.edit_outlined),
                  )
                : null,
          ),
        ),
      ),
      const SizedBox(height: FactorySpacing.lg),
      _masterHeader(context, 'Units', canEdit ? () => onUnit(null) : null),
      ...data.units.map(
        (row) => Card(
          child: ListTile(
            title: Text(row['name'] as String),
            subtitle: Text(
              '${row['code']} · ${row['decimal_places']} decimal places',
            ),
            trailing: canEdit
                ? IconButton(
                    onPressed: () => onUnit(row),
                    icon: const Icon(Icons.edit_outlined),
                  )
                : null,
          ),
        ),
      ),
    ],
  );
}

class _Reports extends StatelessWidget {
  const _Reports({required this.data});
  final InventorySnapshot data;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(FactorySpacing.lg),
    children: [
      Text(
        'Current stock',
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: FactorySpacing.sm),
      if (data.stock.isEmpty)
        const Card(child: ListTile(title: Text('No non-zero stock balances.'))),
      for (final row in data.stock)
        Card(
          child: ListTile(
            leading: const Icon(Icons.inventory_outlined),
            title: Text('${row['item_name']} · ${row['sku']}'),
            subtitle: Text('${row['factory_name']} · ${row['location_name']}'),
            trailing: Text(
              '${_num(row['quantity'])} ${row['unit_code']}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      const SizedBox(height: FactorySpacing.lg),
      Text(
        'Low stock report',
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: FactorySpacing.sm),
      if (data.lowStock.isEmpty)
        const Card(child: ListTile(title: Text('Nothing requires reorder.'))),
      for (final row in data.lowStock)
        Card(
          child: ListTile(
            leading: const Icon(Icons.warning_amber_outlined),
            title: Text('${row['item_name']} · ${row['sku']}'),
            subtitle: Text(
              '${row['factory_name']} · threshold ${_num(row['reorder_level'])}',
            ),
            trailing: Text(
              _num(row['current_quantity']),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
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
    width: 220,
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
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
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

class _Section {
  const _Section(this.label, this.icon, this.page);
  final String label;
  final IconData icon;
  final Widget page;
}

class _InventoryError extends StatelessWidget {
  const _InventoryError({required this.message, required this.onRetry});
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
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}

Widget _movementTile(Map<String, dynamic> row) => Card(
  child: ListTile(
    leading: Icon(_movementIcon(row['transaction_type'] as String? ?? '')),
    title: Text(
      '${row['item_name']} · ${_title(row['transaction_type'] as String? ?? '')} ${_num(row['quantity'])}',
    ),
    subtitle: Text(
      [
        row['transaction_no'],
        row['from_location'],
        row['to_location'],
        row['external_reference'],
      ].whereType<String>().where((v) => v.isNotEmpty).join(' · '),
    ),
    trailing: Text(_shortDate(row['occurred_at'])),
  ),
);

Widget _masterHeader(BuildContext context, String title, VoidCallback? onAdd) =>
    Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        if (onAdd != null)
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
      ],
    );

Widget _status(String text) => Chip(label: Text(text));
IconData _movementIcon(String type) => switch (type) {
  'receive' || 'opening' => Icons.south_west,
  'issue' => Icons.north_east,
  'transfer' => Icons.swap_horiz,
  _ => Icons.receipt_long_outlined,
};
String _factoryName(List<Map<String, dynamic>> factories, dynamic id) =>
    factories
        .where((row) => row['id'] == id)
        .map((row) => row['name'] as String)
        .firstOrNull ??
    'Factory';
String? _nested(Map<String, dynamic> row, String object, String key) =>
    row[object] is Map ? (row[object] as Map)[key] as String? : null;
String _num(dynamic value) => value == null
    ? '0'
    : (value is num
          ? value.toStringAsFixed(value % 1 == 0 ? 0 : 2)
          : value.toString());
String _shortDate(dynamic value) {
  final dt = DateTime.tryParse('$value')?.toLocal();
  return dt == null
      ? ''
      : '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

String _title(String value) => value
    .split('_')
    .map(
      (part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}',
    )
    .join(' ');
String _errorText(Object error) =>
    error is PostgrestException ? error.message : '$error';
List<Map<String, dynamic>> _rows(dynamic value) => (value as List<dynamic>)
    .map((row) => Map<String, dynamic>.from(row as Map))
    .toList();
