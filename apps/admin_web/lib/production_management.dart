import 'package:factoryos_core/factoryos_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'production_editors.dart';

class ProductionManagementPage extends StatefulWidget {
  const ProductionManagementPage({
    required this.organizationId,
    required this.actorRole,
    required this.factories,
    super.key,
  });
  final String organizationId;
  final AppRole actorRole;
  final List<Map<String, dynamic>> factories;

  @override
  State<ProductionManagementPage> createState() =>
      _ProductionManagementPageState();
}

class _ProductionManagementPageState extends State<ProductionManagementPage> {
  int section = 0;
  late Future<ProductionSnapshot> future;
  ProductionRepository get repository =>
      ProductionRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    future = repository.load(widget.organizationId);
  }

  void reload() =>
      setState(() => future = repository.load(widget.organizationId));
  void message(String text, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: error ? Theme.of(context).colorScheme.error : null,
        ),
      );

  Future<void> editRecipe(
    ProductionSnapshot data, [
    Map<String, dynamic>? initial,
  ]) async {
    final draft = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => RecipeEditor(items: data.items, initial: initial),
    );
    if (draft == null) return;
    try {
      await repository.saveRecipe(
        widget.organizationId,
        draft,
        id: initial?['id'] as String?,
      );
      if (!mounted) return;
      message(initial == null ? 'Recipe added.' : 'Recipe updated.');
      reload();
    } catch (e) {
      if (mounted) message(_errorText(e), error: true);
    }
  }

  Future<void> addComponent(
    ProductionSnapshot data,
    Map<String, dynamic> recipe,
  ) async {
    final draft = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => RecipeComponentEditor(
        items: data.items
            .where((row) => row['id'] != recipe['product_item_id'])
            .toList(),
      ),
    );
    if (draft == null) return;
    try {
      await repository.addComponent(
        widget.organizationId,
        recipe['id'] as String,
        draft,
      );
      if (!mounted) return;
      message('BOM component added.');
      reload();
    } catch (e) {
      if (mounted) message(_errorText(e), error: true);
    }
  }

  Future<void> removeComponent(String id) async {
    try {
      await repository.removeComponent(id);
      reload();
    } catch (e) {
      if (mounted) message(_errorText(e), error: true);
    }
  }

  Future<void> editWorkCenter([Map<String, dynamic>? initial]) async {
    final draft = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) =>
          WorkCenterEditor(factories: widget.factories, initial: initial),
    );
    if (draft == null) return;
    try {
      await repository.saveWorkCenter(
        widget.organizationId,
        draft,
        id: initial?['id'] as String?,
      );
      if (!mounted) return;
      message(initial == null ? 'Work center added.' : 'Work center updated.');
      reload();
    } catch (e) {
      if (mounted) message(_errorText(e), error: true);
    }
  }

  Future<void> createOrder(ProductionSnapshot data) async {
    final draft = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => ProductionOrderEditor(
        factories: widget.factories,
        recipes: data.recipes,
        workCenters: data.workCenters,
      ),
    );
    if (draft == null) return;
    try {
      final id = await repository.createOrder(draft);
      if (!mounted) return;
      message('Production order created · ${id.substring(0, 8)}');
      reload();
    } catch (e) {
      if (mounted) message(_errorText(e), error: true);
    }
  }

  Future<void> startBatch(ProductionSnapshot data) async {
    final draft = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => StartBatchEditor(
        orders: data.orders,
        shifts: data.shifts,
        employees: data.employees,
      ),
    );
    if (draft == null) return;
    try {
      final id = await repository.startBatch(draft);
      if (!mounted) return;
      message('Batch started · ${id.substring(0, 8)}');
      reload();
    } catch (e) {
      if (mounted) message(_errorText(e), error: true);
    }
  }

  Future<void> issueMaterial(ProductionSnapshot data) async {
    final active = data.batches
        .where((row) => const ['in_progress', 'paused'].contains(row['status']))
        .toList();
    if (active.isEmpty) {
      message('No active production batch.', error: true);
      return;
    }
    final draft = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => MaterialIssueEditor(
        batches: active,
        components: data.components,
        items: data.items,
        locations: data.locations,
      ),
    );
    if (draft == null) return;
    try {
      await repository.issueMaterial(draft);
      if (!mounted) return;
      message('Material issued to production.');
      reload();
    } catch (e) {
      if (mounted) message(_errorText(e), error: true);
    }
  }

  Future<void> recordOutput(ProductionSnapshot data) async {
    final active = data.batches
        .where((row) => const ['in_progress', 'paused'].contains(row['status']))
        .toList();
    if (active.isEmpty) {
      message('No active production batch.', error: true);
      return;
    }
    final draft = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => OutputEditor(batches: active, locations: data.locations),
    );
    if (draft == null) return;
    try {
      await repository.recordOutput(draft);
      if (!mounted) return;
      message('Output recorded and finished stock received.');
      reload();
    } catch (e) {
      if (mounted) message(_errorText(e), error: true);
    }
  }

  Future<void> logDowntime(ProductionSnapshot data) async {
    final active = data.batches
        .where((row) => const ['in_progress', 'paused'].contains(row['status']))
        .toList();
    if (active.isEmpty) {
      message('No active production batch.', error: true);
      return;
    }
    final draft = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => DowntimeEditor(batches: active),
    );
    if (draft == null) return;
    try {
      await repository.logDowntime(draft);
      if (!mounted) return;
      message('Downtime recorded.');
      reload();
    } catch (e) {
      if (mounted) message(_errorText(e), error: true);
    }
  }

  Future<void> setBatchStatus(String batchId, String status) async {
    try {
      await repository.setBatchStatus(batchId, status);
      if (!mounted) return;
      message('Batch ${_title(status)}.');
      reload();
    } catch (e) {
      if (mounted) message(_errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ProductionSnapshot>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return _ErrorPanel(message: '${snapshot.error}', onRetry: reload);
      }
      final data = snapshot.requireData;
      final canMaster = widget.actorRole.canManageOrganizationSetup;
      final canManage = widget.actorRole.canManagePeople;
      final sections = <_Section>[
        _Section(
          'Dashboard',
          Icons.factory_outlined,
          _Dashboard(
            data: data,
            onOrder: canManage ? () => createOrder(data) : null,
            onBatch: canManage ? () => startBatch(data) : null,
            onIssue: canManage ? () => issueMaterial(data) : null,
            onOutput: canManage ? () => recordOutput(data) : null,
          ),
        ),
        _Section(
          'Products / BOM',
          Icons.account_tree_outlined,
          _Recipes(
            data: data,
            canEdit: canMaster,
            onAdd: () => editRecipe(data),
            onEdit: (row) => editRecipe(data, row),
            onAddComponent: (row) => addComponent(data, row),
            onRemoveComponent: removeComponent,
          ),
        ),
        _Section(
          'Work centers',
          Icons.precision_manufacturing_outlined,
          _WorkCenters(
            data: data,
            canEdit: canManage,
            factories: widget.factories,
            onAdd: () => editWorkCenter(),
            onEdit: editWorkCenter,
          ),
        ),
        _Section(
          'Orders',
          Icons.assignment_outlined,
          _Orders(
            data: data,
            canManage: canManage,
            onCreate: () => createOrder(data),
            onStartBatch: () => startBatch(data),
          ),
        ),
        _Section(
          'Execution',
          Icons.play_circle_outline,
          _Execution(
            data: data,
            canOperate: canManage,
            onIssue: () => issueMaterial(data),
            onOutput: () => recordOutput(data),
            onDowntime: () => logDowntime(data),
            onStatus: setBatchStatus,
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
                const Icon(Icons.factory_outlined, color: FactoryColors.blue),
                const SizedBox(width: FactorySpacing.sm),
                Expanded(
                  child: Text(
                    'Production',
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
              separatorBuilder: (context, index) =>
                  const SizedBox(width: FactorySpacing.xs),
              itemBuilder: (context, i) => ChoiceChip(
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

class ProductionSnapshot {
  const ProductionSnapshot({
    required this.summary,
    required this.items,
    required this.recipes,
    required this.components,
    required this.workCenters,
    required this.orders,
    required this.batches,
    required this.locations,
    required this.shifts,
    required this.employees,
    required this.materialIssues,
    required this.outputs,
    required this.scrap,
    required this.downtime,
    required this.report,
  });
  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> items,
      recipes,
      components,
      workCenters,
      orders,
      batches,
      locations,
      shifts,
      employees,
      materialIssues,
      outputs,
      scrap,
      downtime,
      report;
}

class ProductionRepository {
  ProductionRepository(this.client);
  final SupabaseClient client;
  Future<ProductionSnapshot> load(String orgId) async {
    final results = await Future.wait<dynamic>([
      client.rpc(
        'production_dashboard_summary',
        params: {'p_organization_id': orgId},
      ),
      client
          .from('inventory_items')
          .select('id,name,sku,item_type,is_active,inventory_units(code)')
          .eq('organization_id', orgId)
          .order('name'),
      client
          .from('production_recipes')
          .select(
            'id,organization_id,product_item_id,name,version,output_quantity,effective_from,notes,is_active,inventory_items(name,sku)',
          )
          .eq('organization_id', orgId)
          .order('name'),
      client
          .from('production_recipe_components')
          .select(
            'id,organization_id,recipe_id,item_id,quantity_required,scrap_allowance_pct,notes,inventory_items(name,sku,inventory_units(code))',
          )
          .eq('organization_id', orgId),
      client
          .from('work_centers')
          .select(
            'id,organization_id,factory_id,name,code,center_type,capacity_per_hour,notes,is_active',
          )
          .eq('organization_id', orgId)
          .order('name'),
      client
          .from('production_orders')
          .select(
            'id,organization_id,factory_id,order_no,recipe_id,product_item_id,work_center_id,planned_quantity,status,priority,planned_start_at,planned_end_at,actual_start_at,actual_end_at,notes,inventory_items(name,sku),work_centers(name,code),production_recipes(name,version)',
          )
          .eq('organization_id', orgId)
          .order('created_at', ascending: false)
          .limit(200),
      client
          .from('production_batches')
          .select(
            'id,organization_id,factory_id,order_id,batch_no,work_center_id,shift_id,operator_employee_id,planned_quantity,status,actual_start_at,actual_end_at,production_orders(order_no,recipe_id,product_item_id),work_centers(name,code),shifts(name,code),employees(full_name,employee_code)',
          )
          .eq('organization_id', orgId)
          .order('created_at', ascending: false)
          .limit(200),
      client
          .from('stock_locations')
          .select('id,factory_id,name,code,location_type,is_active')
          .eq('organization_id', orgId)
          .eq('is_active', true)
          .order('name'),
      client
          .from('shifts')
          .select('id,factory_id,name,code,is_active')
          .eq('organization_id', orgId)
          .eq('is_active', true)
          .order('name'),
      client
          .from('employees')
          .select('id,primary_factory_id,full_name,employee_code,status')
          .eq('organization_id', orgId)
          .eq('status', 'active')
          .order('full_name'),
      client
          .from('production_material_issues')
          .select(
            'id,order_id,batch_id,item_id,quantity,occurred_at,inventory_items(name,sku),production_batches(batch_no),production_orders(order_no)',
          )
          .eq('organization_id', orgId)
          .order('occurred_at', ascending: false)
          .limit(100),
      client
          .from('production_outputs')
          .select(
            'id,order_id,batch_id,product_item_id,good_quantity,scrap_quantity,lot_batch_no,occurred_at,inventory_items(name,sku),production_batches(batch_no),production_orders(order_no)',
          )
          .eq('organization_id', orgId)
          .order('occurred_at', ascending: false)
          .limit(100),
      client
          .from('production_scrap_events')
          .select(
            'id,order_id,batch_id,quantity,reason_code,reason_text,occurred_at,production_batches(batch_no),production_orders(order_no)',
          )
          .eq('organization_id', orgId)
          .order('occurred_at', ascending: false)
          .limit(100),
      client
          .from('production_downtime_events')
          .select(
            'id,order_id,batch_id,work_center_id,reason_code,reason_text,duration_minutes,started_at,production_batches(batch_no),production_orders(order_no),work_centers(name)',
          )
          .eq('organization_id', orgId)
          .order('started_at', ascending: false)
          .limit(100),
      client.rpc(
        'production_order_report',
        params: {'p_organization_id': orgId, 'p_limit': 200},
      ),
    ]);
    return ProductionSnapshot(
      summary: Map<String, dynamic>.from(results[0] as Map),
      items: _rows(results[1]),
      recipes: _rows(results[2]),
      components: _rows(results[3]),
      workCenters: _rows(results[4]),
      orders: _rows(results[5]),
      batches: _rows(results[6]),
      locations: _rows(results[7]),
      shifts: _rows(results[8]),
      employees: _rows(results[9]),
      materialIssues: _rows(results[10]),
      outputs: _rows(results[11]),
      scrap: _rows(results[12]),
      downtime: _rows(results[13]),
      report: _rows(results[14]),
    );
  }

  Future<void> saveRecipe(
    String orgId,
    Map<String, dynamic> values, {
    String? id,
  }) async => id == null
      ? client.from('production_recipes').insert({
          'organization_id': orgId,
          ...values,
        })
      : client.from('production_recipes').update(values).eq('id', id);
  Future<void> addComponent(
    String orgId,
    String recipeId,
    Map<String, dynamic> values,
  ) async => client.from('production_recipe_components').insert({
    'organization_id': orgId,
    'recipe_id': recipeId,
    ...values,
  });
  Future<void> removeComponent(String id) async =>
      client.from('production_recipe_components').delete().eq('id', id);
  Future<void> saveWorkCenter(
    String orgId,
    Map<String, dynamic> values, {
    String? id,
  }) async => id == null
      ? client.from('work_centers').insert({
          'organization_id': orgId,
          ...values,
        })
      : client.from('work_centers').update(values).eq('id', id);
  Future<String> createOrder(Map<String, dynamic> d) async =>
      (await client.rpc(
            'production_create_order',
            params: {
              'p_factory_id': d['factory_id'],
              'p_recipe_id': d['recipe_id'],
              'p_work_center_id': d['work_center_id'],
              'p_planned_quantity': d['planned_quantity'],
              'p_priority': d['priority'],
              'p_notes': d['notes'],
            },
          ))
          as String;
  Future<String> startBatch(Map<String, dynamic> d) async =>
      (await client.rpc(
            'production_start_batch',
            params: {
              'p_order_id': d['order_id'],
              'p_batch_no': d['batch_no'],
              'p_planned_quantity': d['planned_quantity'],
              'p_shift_id': d['shift_id'],
              'p_operator_employee_id': d['operator_employee_id'],
            },
          ))
          as String;
  Future<void> issueMaterial(Map<String, dynamic> d) async => client.rpc(
    'production_issue_material',
    params: {
      'p_batch_id': d['batch_id'],
      'p_item_id': d['item_id'],
      'p_from_location_id': d['from_location_id'],
      'p_quantity': d['quantity'],
      'p_notes': d['notes'],
    },
  );
  Future<void> recordOutput(Map<String, dynamic> d) async => client.rpc(
    'production_record_output',
    params: {
      'p_batch_id': d['batch_id'],
      'p_good_quantity': d['good_quantity'],
      'p_scrap_quantity': d['scrap_quantity'],
      'p_to_location_id': d['to_location_id'],
      'p_lot_batch_no': d['lot_batch_no'],
      'p_scrap_reason': d['scrap_reason'],
      'p_notes': d['notes'],
    },
  );
  Future<void> logDowntime(Map<String, dynamic> d) async => client.rpc(
    'production_log_downtime',
    params: {
      'p_batch_id': d['batch_id'],
      'p_reason_code': d['reason_code'],
      'p_duration_minutes': d['duration_minutes'],
      'p_reason_text': d['reason_text'],
    },
  );
  Future<void> setBatchStatus(String batchId, String status) async =>
      client.rpc(
        'production_set_batch_status',
        params: {'p_batch_id': batchId, 'p_status': status},
      );
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({
    required this.data,
    this.onOrder,
    this.onBatch,
    this.onIssue,
    this.onOutput,
  });
  final ProductionSnapshot data;
  final VoidCallback? onOrder, onBatch, onIssue, onOutput;
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
              'Active orders',
              '${s['active_orders'] ?? 0}',
              Icons.assignment_outlined,
            ),
            _Metric(
              'Today output',
              _num(s['today_good_output']),
              Icons.output_outlined,
            ),
            _Metric('WIP', _num(s['wip_quantity']), Icons.timelapse_outlined),
            _Metric('Scrap', _num(s['today_scrap']), Icons.delete_outline),
            _Metric(
              'Downtime',
              '${s['today_downtime_minutes'] ?? 0} min',
              Icons.timer_off_outlined,
            ),
          ],
        ),
        const SizedBox(height: FactorySpacing.lg),
        Wrap(
          spacing: FactorySpacing.sm,
          runSpacing: FactorySpacing.sm,
          children: [
            if (onOrder != null)
              FilledButton.icon(
                onPressed: onOrder,
                icon: const Icon(Icons.add),
                label: const Text('New order'),
              ),
            if (onBatch != null)
              FilledButton.tonalIcon(
                onPressed: onBatch,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start batch'),
              ),
            if (onIssue != null)
              OutlinedButton.icon(
                onPressed: onIssue,
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('Issue material'),
              ),
            if (onOutput != null)
              OutlinedButton.icon(
                onPressed: onOutput,
                icon: const Icon(Icons.output),
                label: const Text('Record output'),
              ),
          ],
        ),
        const SizedBox(height: FactorySpacing.lg),
        Text(
          'Active production',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: FactorySpacing.sm),
        if (data.report
            .where(
              (r) => !const ['completed', 'cancelled'].contains(r['status']),
            )
            .isEmpty)
          const Card(
            child: ListTile(title: Text('No active production orders.')),
          ),
        ...data.report
            .where(
              (r) => !const ['completed', 'cancelled'].contains(r['status']),
            )
            .take(8)
            .map(_orderReportTile),
      ],
    );
  }
}

class _Recipes extends StatelessWidget {
  const _Recipes({
    required this.data,
    required this.canEdit,
    required this.onAdd,
    required this.onEdit,
    required this.onAddComponent,
    required this.onRemoveComponent,
  });
  final ProductionSnapshot data;
  final bool canEdit;
  final VoidCallback onAdd;
  final ValueChanged<Map<String, dynamic>> onEdit, onAddComponent;
  final ValueChanged<String> onRemoveComponent;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(FactorySpacing.lg),
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Products & BOM / Recipes',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          if (canEdit)
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Recipe'),
            ),
        ],
      ),
      const SizedBox(height: FactorySpacing.md),
      for (final recipe in data.recipes)
        Card(
          child: ExpansionTile(
            leading: const Icon(Icons.account_tree_outlined),
            title: Text('${recipe['name']} · ${recipe['version']}'),
            subtitle: Text(
              '${_nested(recipe, 'inventory_items', 'name') ?? 'Product'} · yield ${_num(recipe['output_quantity'])}',
            ),
            trailing: canEdit
                ? IconButton(
                    onPressed: () => onEdit(recipe),
                    icon: const Icon(Icons.edit_outlined),
                  )
                : null,
            children: [
              for (final component in data.components.where(
                (row) => row['recipe_id'] == recipe['id'],
              ))
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.subdirectory_arrow_right),
                  title: Text(
                    '${_nested(component, 'inventory_items', 'name') ?? 'Material'} · ${_nested(component, 'inventory_items', 'sku') ?? ''}',
                  ),
                  subtitle: Text(
                    'Qty ${_num(component['quantity_required'])} · scrap allowance ${_num(component['scrap_allowance_pct'])}%',
                  ),
                  trailing: canEdit
                      ? IconButton(
                          onPressed: () =>
                              onRemoveComponent(component['id'] as String),
                          icon: const Icon(Icons.delete_outline),
                        )
                      : null,
                ),
              if (canEdit)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(FactorySpacing.sm),
                    child: OutlinedButton.icon(
                      onPressed: () => onAddComponent(recipe),
                      icon: const Icon(Icons.add),
                      label: const Text('Component'),
                    ),
                  ),
                ),
            ],
          ),
        ),
    ],
  );
}

class _WorkCenters extends StatelessWidget {
  const _WorkCenters({
    required this.data,
    required this.canEdit,
    required this.factories,
    required this.onAdd,
    required this.onEdit,
  });
  final ProductionSnapshot data;
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
              'Work centers & machines',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          if (canEdit)
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Work center'),
            ),
        ],
      ),
      const SizedBox(height: FactorySpacing.md),
      for (final row in data.workCenters)
        Card(
          child: ListTile(
            leading: const Icon(Icons.precision_manufacturing_outlined),
            title: Text(row['name'] as String),
            subtitle: Text(
              '${row['code']} · ${_factoryName(factories, row['factory_id'])} · ${_title(row['center_type'] as String)}${row['capacity_per_hour'] == null ? '' : ' · ${_num(row['capacity_per_hour'])}/hr'}',
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

class _Orders extends StatelessWidget {
  const _Orders({
    required this.data,
    required this.canManage,
    required this.onCreate,
    required this.onStartBatch,
  });
  final ProductionSnapshot data;
  final bool canManage;
  final VoidCallback onCreate, onStartBatch;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(FactorySpacing.lg),
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Production orders',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          if (canManage)
            Wrap(
              spacing: FactorySpacing.sm,
              children: [
                FilledButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(Icons.add),
                  label: const Text('Order'),
                ),
                OutlinedButton.icon(
                  onPressed: onStartBatch,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start batch'),
                ),
              ],
            ),
        ],
      ),
      const SizedBox(height: FactorySpacing.md),
      for (final row in data.report) _orderReportTile(row),
    ],
  );
}

class _Execution extends StatelessWidget {
  const _Execution({
    required this.data,
    required this.canOperate,
    required this.onIssue,
    required this.onOutput,
    required this.onDowntime,
    required this.onStatus,
  });
  final ProductionSnapshot data;
  final bool canOperate;
  final VoidCallback onIssue, onOutput, onDowntime;
  final void Function(String, String) onStatus;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(FactorySpacing.lg),
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Batch & shift execution',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          if (canOperate)
            Wrap(
              spacing: FactorySpacing.sm,
              children: [
                OutlinedButton.icon(
                  onPressed: onIssue,
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text('Issue'),
                ),
                FilledButton.icon(
                  onPressed: onOutput,
                  icon: const Icon(Icons.output),
                  label: const Text('Output'),
                ),
                OutlinedButton.icon(
                  onPressed: onDowntime,
                  icon: const Icon(Icons.timer_off_outlined),
                  label: const Text('Downtime'),
                ),
              ],
            ),
        ],
      ),
      const SizedBox(height: FactorySpacing.md),
      if (data.batches.isEmpty)
        const Card(child: ListTile(title: Text('No production batches.'))),
      for (final row in data.batches)
        Card(
          child: ListTile(
            leading: Icon(
              row['status'] == 'in_progress'
                  ? Icons.play_circle
                  : Icons.precision_manufacturing_outlined,
            ),
            title: Text(
              '${row['batch_no']} · ${_nested(row, 'production_orders', 'order_no') ?? ''}',
            ),
            subtitle: Text(
              '${_nested(row, 'work_centers', 'name') ?? 'Work center'} · planned ${_num(row['planned_quantity'])} · ${_title(row['status'] as String)}',
            ),
            trailing:
                canOperate &&
                    const ['in_progress', 'paused'].contains(row['status'])
                ? PopupMenuButton<String>(
                    onSelected: (value) => onStatus(row['id'] as String, value),
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
                  )
                : _status(_title(row['status'] as String)),
          ),
        ),
      const SizedBox(height: FactorySpacing.lg),
      Text(
        'Recent material consumption',
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: FactorySpacing.sm),
      for (final row in data.materialIssues.take(6))
        Card(
          child: ListTile(
            leading: const Icon(Icons.inventory_2_outlined),
            title: Text(
              '${_nested(row, 'inventory_items', 'name') ?? 'Material'} · ${_num(row['quantity'])}',
            ),
            subtitle: Text(
              '${_nested(row, 'production_orders', 'order_no') ?? ''} · ${_nested(row, 'production_batches', 'batch_no') ?? ''}',
            ),
            trailing: Text(_shortDate(row['occurred_at'])),
          ),
        ),
      const SizedBox(height: FactorySpacing.lg),
      Text(
        'Recent output / losses',
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: FactorySpacing.sm),
      for (final row in data.outputs.take(6))
        Card(
          child: ListTile(
            leading: const Icon(Icons.output_outlined),
            title: Text(
              '${_nested(row, 'inventory_items', 'name') ?? 'Output'} · good ${_num(row['good_quantity'])} · scrap ${_num(row['scrap_quantity'])}',
            ),
            subtitle: Text(
              '${_nested(row, 'production_orders', 'order_no') ?? ''} · ${row['lot_batch_no'] ?? 'No lot'}',
            ),
            trailing: Text(_shortDate(row['occurred_at'])),
          ),
        ),
    ],
  );
}

class _Reports extends StatelessWidget {
  const _Reports({required this.data});
  final ProductionSnapshot data;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(FactorySpacing.lg),
    children: [
      Text(
        'Production performance',
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: FactorySpacing.sm),
      ...data.report.map(_orderReportTile),
      const SizedBox(height: FactorySpacing.lg),
      Text(
        'Downtime',
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: FactorySpacing.sm),
      if (data.downtime.isEmpty)
        const Card(child: ListTile(title: Text('No downtime recorded.'))),
      for (final row in data.downtime)
        Card(
          child: ListTile(
            leading: const Icon(Icons.timer_off_outlined),
            title: Text(
              '${row['reason_code']} · ${row['duration_minutes']} min',
            ),
            subtitle: Text(
              '${_nested(row, 'work_centers', 'name') ?? ''} · ${row['reason_text'] ?? ''}',
            ),
            trailing: Text(_shortDate(row['started_at'])),
          ),
        ),
      const SizedBox(height: FactorySpacing.lg),
      Text(
        'Scrap',
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: FactorySpacing.sm),
      if (data.scrap.isEmpty)
        const Card(child: ListTile(title: Text('No scrap recorded.'))),
      for (final row in data.scrap)
        Card(
          child: ListTile(
            leading: const Icon(Icons.delete_outline),
            title: Text('${row['reason_code']} · ${_num(row['quantity'])}'),
            subtitle: Text(
              '${_nested(row, 'production_orders', 'order_no') ?? ''} · ${row['reason_text'] ?? ''}',
            ),
            trailing: Text(_shortDate(row['occurred_at'])),
          ),
        ),
    ],
  );
}

Widget _orderReportTile(Map<String, dynamic> row) => Card(
  child: ListTile(
    leading: const Icon(Icons.assignment_outlined),
    title: Text('${row['order_no']} · ${row['product_name']}'),
    subtitle: Text(
      '${row['work_center_name']} · planned ${_num(row['planned_quantity'])} · good ${_num(row['good_quantity'])} · scrap ${_num(row['scrap_quantity'])}',
    ),
    trailing: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _status(_title(row['status'] as String)),
        Text(
          'WIP ${_num(row['wip_quantity'])}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  ),
);

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.icon);
  final String label, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 205,
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

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});
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

Widget _status(String text) => Chip(label: Text(text));
String _factoryName(List<Map<String, dynamic>> factories, dynamic id) =>
    factories
        .where((row) => row['id'] == id)
        .map((row) => row['name'] as String)
        .firstOrNull ??
    'Factory';
String? _nested(Map<String, dynamic> row, String object, String key) =>
    row[object] is Map ? (row[object] as Map)[key]?.toString() : null;
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

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
