import 'package:factoryos_core/factoryos_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class QualityExecutionPage extends StatefulWidget {
  const QualityExecutionPage({super.key});
  @override
  State<QualityExecutionPage> createState() => _QualityExecutionPageState();
}

class _QualityExecutionPageState extends State<QualityExecutionPage> {
  final client = Supabase.instance.client;
  late Future<_QualityMobileData> future;

  @override
  void initState() {
    super.initState();
    future = _load();
  }

  void reload() => setState(() => future = _load());

  Future<_QualityMobileData> _load() async {
    final uid = client.auth.currentUser!.id;
    final memberships = await client.from('organization_members').select('organization_id,role').eq('user_id', uid).eq('is_active', true).limit(1);
    if (memberships.isEmpty) throw StateError('No active organization membership.');
    final membership = Map<String, dynamic>.from(memberships.first);
    final orgId = membership['organization_id'] as String;
    final role = AppRole.fromWireName(membership['role'] as String);
    final results = await Future.wait<dynamic>([
      client.rpc('quality_dashboard_summary', params: {'p_organization_id': orgId}),
      client.from('quality_inspection_plans').select('id,item_id,name,code,version,inspection_type,default_sample_size,is_active,inventory_items(name,sku)').eq('organization_id', orgId).eq('is_active', true).order('name'),
      client.from('quality_plan_checks').select('id,plan_id,sequence_no,parameter_name,check_type,target_numeric,min_numeric,max_numeric,unit_text,expected_boolean,acceptance_text,is_required').eq('organization_id', orgId).order('sequence_no'),
      client.from('quality_inspections').select('id,factory_id,inspection_no,plan_id,inspection_type,item_id,production_batch_id,lot_batch_no,sample_size,status,overall_result,started_at,completed_at,inventory_items(name,sku),quality_inspection_plans(name,code,version)').eq('organization_id', orgId).order('started_at', ascending: false).limit(120),
      client.from('quality_inspection_results').select('id,inspection_id,plan_check_id,result_status,numeric_value,boolean_value,text_value,remarks,quality_plan_checks(parameter_name,sequence_no,check_type,unit_text)').eq('organization_id', orgId).order('occurred_at', ascending: false).limit(300),
      client.from('stock_locations').select('id,factory_id,name,code,location_type').eq('organization_id', orgId).eq('is_active', true).order('name'),
      client.from('employees').select('id,primary_factory_id,full_name,employee_code,status').eq('organization_id', orgId).eq('status', 'active').order('full_name'),
      client.from('production_batches').select('id,factory_id,batch_no,status,production_orders(order_no,product_item_id,inventory_items(name,sku))').eq('organization_id', orgId).order('created_at', ascending: false).limit(100),
      client.from('quality_ncrs').select('id,factory_id,ncr_no,inspection_id,severity,category,description,status,disposition,inventory_items(name,sku)').eq('organization_id', orgId).order('created_at', ascending: false).limit(100),
      client.from('quality_quarantine_lots').select('id,factory_id,inspection_id,item_id,source_location_id,quarantine_location_id,quantity,lot_batch_no,status,disposition').eq('organization_id', orgId).order('quarantined_at', ascending: false).limit(100),
      client.from('quality_certificates').select('id,inspection_id,certificate_no,item_id,lot_batch_no,issued_at').eq('organization_id', orgId).order('issued_at', ascending: false).limit(100),
    ]);
    return _QualityMobileData(
      role: role,
      summary: Map<String, dynamic>.from(results[0] as Map),
      plans: _rows(results[1]),
      checks: _rows(results[2]),
      inspections: _rows(results[3]),
      results: _rows(results[4]),
      locations: _rows(results[5]),
      employees: _rows(results[6]),
      productionBatches: _rows(results[7]),
      ncrs: _rows(results[8]),
      quarantine: _rows(results[9]),
      certificates: _rows(results[10]),
    );
  }

  void message(String text, {bool error = false}) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), backgroundColor: error ? Theme.of(context).colorScheme.error : null));

  Future<void> _run(Future<void> Function() action, String success) async {
    try {
      await action();
      if (!mounted) return;
      message(success);
      reload();
    } catch (e) {
      if (mounted) message(e is PostgrestException ? e.message : '$e', error: true);
    }
  }

  Future<void> startInspection(_QualityMobileData data) async {
    if (data.plans.isEmpty) {
      message('No active inspection plan.', error: true);
      return;
    }
    final draft = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => _StartInspectionDialog(plans: data.plans, batches: data.productionBatches, employees: data.employees));
    if (draft == null) return;
    await _run(() async {
      await client.rpc('quality_start_inspection', params: {
        'p_factory_id': draft['factory_id'],
        'p_plan_id': draft['plan_id'],
        'p_item_id': draft['item_id'],
        'p_production_batch_id': draft['production_batch_id'],
        'p_lot_batch_no': draft['lot_batch_no'],
        'p_sample_size': draft['sample_size'],
        'p_inspector_employee_id': draft['inspector_employee_id'],
        'p_notes': 'Mobile quality inspection',
      });
    }, 'Inspection started.');
  }

  Future<void> recordResult(_QualityMobileData data, Map<String, dynamic> inspection) async {
    final checks = data.checks.where((row) => row['plan_id'] == inspection['plan_id']).toList();
    if (checks.isEmpty) {
      message('Inspection plan has no checklist parameters.', error: true);
      return;
    }
    final draft = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => _ResultDialog(checks: checks));
    if (draft == null) return;
    await _run(() async {
      await client.rpc('quality_record_result', params: {
        'p_inspection_id': inspection['id'],
        'p_plan_check_id': draft['plan_check_id'],
        'p_result_status': draft['result_status'],
        'p_numeric_value': draft['numeric_value'],
        'p_boolean_value': draft['boolean_value'],
        'p_text_value': draft['text_value'],
        'p_remarks': draft['remarks'],
      });
    }, 'Checklist result saved.');
  }

  Future<void> complete(String id, {bool hold = false}) => _run(() async {
        await client.rpc('quality_complete_inspection', params: {'p_inspection_id': id, 'p_hold': hold});
      }, hold ? 'Inspection placed on hold.' : 'Inspection completed.');

  Future<void> createNcr(_QualityMobileData data, Map<String, dynamic> inspection) async {
    final draft = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => _NcrDialog(employees: data.employees.where((row) => row['primary_factory_id'] == inspection['factory_id']).toList()));
    if (draft == null) return;
    await _run(() async {
      await client.rpc('quality_create_ncr', params: {
        'p_inspection_id': inspection['id'],
        'p_severity': draft['severity'],
        'p_category': draft['category'],
        'p_description': draft['description'],
        'p_assigned_employee_id': draft['assigned_employee_id'],
      });
    }, 'NCR created.');
  }

  Future<void> quarantine(_QualityMobileData data, Map<String, dynamic> inspection) async {
    final locations = data.locations.where((row) => row['factory_id'] == inspection['factory_id']).toList();
    final draft = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => _QuarantineDialog(locations: locations, defaultLot: inspection['lot_batch_no'] as String?));
    if (draft == null) return;
    await _run(() async {
      await client.rpc('quality_quarantine_stock', params: {
        'p_inspection_id': inspection['id'],
        'p_from_location_id': draft['from_location_id'],
        'p_quarantine_location_id': draft['quarantine_location_id'],
        'p_quantity': draft['quantity'],
        'p_lot_batch_no': draft['lot_batch_no'],
        'p_notes': 'Mobile quality quarantine',
      });
    }, 'Stock moved to quarantine.');
  }

  Future<void> release(_QualityMobileData data, Map<String, dynamic> row) async {
    final locations = data.locations.where((location) => location['factory_id'] == row['factory_id'] && location['id'] != row['quarantine_location_id']).toList();
    final draft = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => _ReleaseDialog(locations: locations));
    if (draft == null) return;
    await _run(() async {
      await client.rpc('quality_release_quarantine', params: {'p_quarantine_id': row['id'], 'p_to_location_id': draft['to_location_id'], 'p_disposition': draft['disposition'], 'p_notes': 'Mobile quality release'});
    }, 'Quarantine released.');
  }

  Future<void> issueCertificate(String inspectionId) => _run(() async {
        await client.rpc('quality_issue_certificate', params: {'p_inspection_id': inspectionId});
      }, 'Quality certificate issued.');

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Quality')),
        body: FutureBuilder<_QualityMobileData>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(FactorySpacing.lg), child: Column(mainAxisSize: MainAxisSize.min, children: [Text('${snapshot.error}', textAlign: TextAlign.center), const SizedBox(height: FactorySpacing.md), OutlinedButton(onPressed: reload, child: const Text('Retry'))])));
            final data = snapshot.requireData;
            final s = data.summary;
            final active = data.inspections.where((row) => row['status'] == 'in_progress').toList();
            final failures = data.inspections.where((row) => row['status'] == 'completed' && const {'fail', 'hold'}.contains(row['overall_result'])).toList();
            final canApprove = const {AppRole.platformOwner, AppRole.orgAdmin, AppRole.factoryManager, AppRole.supervisor}.contains(data.role);
            return RefreshIndicator(
              onRefresh: () async => reload(),
              child: ListView(
                padding: const EdgeInsets.all(FactorySpacing.md),
                children: [
                  Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Quality control', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)), Text(data.role.label)])), IconButton(onPressed: reload, icon: const Icon(Icons.refresh))]),
                  const SizedBox(height: FactorySpacing.md),
                  Wrap(spacing: FactorySpacing.sm, runSpacing: FactorySpacing.sm, children: [
                    _Metric('Inspections', '${s['today_inspections'] ?? 0}', Icons.fact_check_outlined),
                    _Metric('Pass', '${s['today_passed'] ?? 0}', Icons.check_circle_outline),
                    _Metric('Fail', '${s['today_failed'] ?? 0}', Icons.cancel_outlined),
                    _Metric('Hold', '${s['today_hold'] ?? 0}', Icons.pause_circle_outline),
                    _Metric('NCR', '${s['open_ncr'] ?? 0}', Icons.report_problem_outlined),
                    _Metric('Quarantine', _num(s['quarantine_quantity']), Icons.inventory_outlined),
                  ]),
                  const SizedBox(height: FactorySpacing.md),
                  FilledButton.icon(onPressed: () => startInspection(data), icon: const Icon(Icons.add_task), label: const Text('Start inspection')),
                  const SizedBox(height: FactorySpacing.lg),
                  Text('Active inspections', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: FactorySpacing.sm),
                  if (active.isEmpty) const Card(child: ListTile(title: Text('No inspection is currently in progress.'))),
                  for (final row in active)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.rule_folder_outlined),
                        title: Text('${row['inspection_no']} · ${_nested(row, 'inventory_items', 'name') ?? 'Item'}'),
                        subtitle: Text('${_title(row['inspection_type'] as String)} · sample ${row['sample_size']}'),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'result') recordResult(data, row);
                            if (value == 'complete') complete(row['id'] as String);
                            if (value == 'hold') complete(row['id'] as String, hold: true);
                          },
                          itemBuilder: (_) => const [PopupMenuItem(value: 'result', child: Text('Record result')), PopupMenuItem(value: 'complete', child: Text('Complete')), PopupMenuItem(value: 'hold', child: Text('Put on hold'))],
                        ),
                      ),
                    ),
                  const SizedBox(height: FactorySpacing.lg),
                  Text('Failed / held inspections', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: FactorySpacing.sm),
                  if (failures.isEmpty) const Card(child: ListTile(title: Text('No failed or held inspections.'))),
                  for (final row in failures.take(12))
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(FactorySpacing.sm),
                        child: Column(children: [
                          ListTile(leading: Icon(row['overall_result'] == 'fail' ? Icons.cancel : Icons.pause_circle, color: row['overall_result'] == 'fail' ? Theme.of(context).colorScheme.error : Colors.orange), title: Text('${row['inspection_no']} · ${_nested(row, 'inventory_items', 'name') ?? 'Item'}'), subtitle: Text(_title(row['overall_result'] as String))),
                          Wrap(spacing: FactorySpacing.xs, runSpacing: FactorySpacing.xs, children: [OutlinedButton.icon(onPressed: () => createNcr(data, row), icon: const Icon(Icons.report_problem_outlined), label: const Text('NCR')), OutlinedButton.icon(onPressed: () => quarantine(data, row), icon: const Icon(Icons.inventory_outlined), label: const Text('Quarantine'))]),
                        ]),
                      ),
                    ),
                  const SizedBox(height: FactorySpacing.lg),
                  Text('Open NCR', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: FactorySpacing.sm),
                  for (final row in data.ncrs.where((row) => row['status'] != 'closed').take(8)) Card(child: ListTile(leading: const Icon(Icons.report_problem_outlined), title: Text('${row['ncr_no']} · ${row['category']}'), subtitle: Text('${_title(row['severity'] as String)} · ${_title(row['status'] as String)}'))),
                  const SizedBox(height: FactorySpacing.lg),
                  Text('Quarantine', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: FactorySpacing.sm),
                  for (final row in data.quarantine.where((row) => row['status'] == 'quarantined').take(8)) Card(child: ListTile(leading: const Icon(Icons.lock_outline), title: Text('${row['lot_batch_no'] ?? 'Lot'} · ${_num(row['quantity'])}'), subtitle: const Text('Quality hold'), trailing: canApprove ? FilledButton.tonal(onPressed: () => release(data, row), child: const Text('Release')) : null)),
                  if (canApprove) ...[
                    const SizedBox(height: FactorySpacing.lg),
                    Text('Certificate-ready inspections', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: FactorySpacing.sm),
                    for (final row in data.inspections.where((row) => row['status'] == 'completed' && row['overall_result'] == 'pass' && !data.certificates.any((c) => c['inspection_id'] == row['id'])).take(8)) Card(child: ListTile(leading: const Icon(Icons.workspace_premium_outlined), title: Text(row['inspection_no'] as String), subtitle: Text(_nested(row, 'inventory_items', 'name') ?? 'Passed inspection'), trailing: IconButton(onPressed: () => issueCertificate(row['id'] as String), icon: const Icon(Icons.add_circle_outline))))
                  ],
                ],
              ),
            );
          },
        ),
      );
}

class _QualityMobileData {
  const _QualityMobileData({required this.role, required this.summary, required this.plans, required this.checks, required this.inspections, required this.results, required this.locations, required this.employees, required this.productionBatches, required this.ncrs, required this.quarantine, required this.certificates});
  final AppRole role;
  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> plans, checks, inspections, results, locations, employees, productionBatches, ncrs, quarantine, certificates;
}

class _StartInspectionDialog extends StatefulWidget {
  const _StartInspectionDialog({required this.plans, required this.batches, required this.employees});
  final List<Map<String, dynamic>> plans, batches, employees;
  @override
  State<_StartInspectionDialog> createState() => _StartInspectionDialogState();
}

class _StartInspectionDialogState extends State<_StartInspectionDialog> {
  String? planId, batchId, employeeId;
  final lot = TextEditingController();
  final sample = TextEditingController(text: '5');
  @override
  void initState() { super.initState(); planId = widget.plans.first['id'] as String; _sync(); }
  Map<String, dynamic> get plan => widget.plans.firstWhere((row) => row['id'] == planId);
  void _sync() { sample.text = '${plan['default_sample_size'] ?? 5}'; }
  String? get factoryId {
    if (batchId != null) return widget.batches.firstWhere((row) => row['id'] == batchId)['factory_id'] as String;
    final itemId = plan['item_id'];
    final factoryIds = widget.employees.map((row) => row['primary_factory_id']).whereType<String>().toSet();
    if (factoryIds.length == 1) return factoryIds.first;
    final matchingBatch = widget.batches.where((row) => _nested(row, 'production_orders', 'product_item_id') == itemId).toList();
    return matchingBatch.isEmpty ? (factoryIds.isEmpty ? null : factoryIds.first) : matchingBatch.first['factory_id'] as String;
  }
  @override
  void dispose() { lot.dispose(); sample.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final type = plan['inspection_type'] as String;
    final batches = widget.batches.where((row) => type != 'incoming' && _nested(row, 'production_orders', 'product_item_id') == plan['item_id']).toList();
    final employees = widget.employees.where((row) => factoryId == null || row['primary_factory_id'] == factoryId).toList();
    return AlertDialog(
      title: const Text('Start inspection'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(initialValue: planId, decoration: const InputDecoration(labelText: 'Inspection plan'), items: widget.plans.map((row) => DropdownMenuItem(value: row['id'] as String, child: Text('${row['code']} · ${row['name']}'))).toList(), onChanged: (value) => setState(() { planId = value; batchId = null; employeeId = null; _sync(); })),
        if (type != 'incoming') ...[const SizedBox(height: FactorySpacing.sm), DropdownButtonFormField<String>(initialValue: batchId, decoration: const InputDecoration(labelText: 'Production batch'), items: batches.map((row) => DropdownMenuItem(value: row['id'] as String, child: Text('${row['batch_no']} · ${_nested(row, 'production_orders', 'order_no') ?? ''}'))).toList(), onChanged: (value) => setState(() { batchId = value; employeeId = null; }))],
        const SizedBox(height: FactorySpacing.sm),
        DropdownButtonFormField<String>(initialValue: employeeId, decoration: const InputDecoration(labelText: 'Inspector (optional)'), items: employees.map((row) => DropdownMenuItem(value: row['id'] as String, child: Text('${row['employee_code']} · ${row['full_name']}'))).toList(), onChanged: (value) => setState(() => employeeId = value)),
        const SizedBox(height: FactorySpacing.sm),
        TextField(controller: lot, decoration: const InputDecoration(labelText: 'Lot / batch no.')),
        const SizedBox(height: FactorySpacing.sm),
        TextField(controller: sample, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Sample size')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: factoryId == null ? null : () { final size = int.tryParse(sample.text.trim()); if (size == null || size <= 0) return; Navigator.pop(context, {'factory_id': factoryId, 'plan_id': planId, 'item_id': plan['item_id'], 'production_batch_id': type == 'incoming' ? null : batchId, 'lot_batch_no': lot.text.trim().isEmpty ? null : lot.text.trim(), 'sample_size': size, 'inspector_employee_id': employeeId}); }, child: const Text('Start'))],
    );
  }
}

class _ResultDialog extends StatefulWidget {
  const _ResultDialog({required this.checks});
  final List<Map<String, dynamic>> checks;
  @override
  State<_ResultDialog> createState() => _ResultDialogState();
}

class _ResultDialogState extends State<_ResultDialog> {
  String? checkId;
  String result = 'pass';
  bool booleanValue = true;
  final numeric = TextEditingController();
  final text = TextEditingController();
  final remarks = TextEditingController();
  @override
  void initState() { super.initState(); checkId = widget.checks.first['id'] as String; }
  Map<String, dynamic> get check => widget.checks.firstWhere((row) => row['id'] == checkId);
  @override
  void dispose() { numeric.dispose(); text.dispose(); remarks.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final type = check['check_type'] as String;
    return AlertDialog(
      title: const Text('Checklist result'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(initialValue: checkId, decoration: const InputDecoration(labelText: 'Parameter'), items: widget.checks.map((row) => DropdownMenuItem(value: row['id'] as String, child: Text('${row['sequence_no']}. ${row['parameter_name']}'))).toList(), onChanged: (value) => setState(() => checkId = value)),
        const SizedBox(height: FactorySpacing.sm),
        if (type == 'numeric') TextField(controller: numeric, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Measured value${check['unit_text'] == null ? '' : ' (${check['unit_text']})'}'))
        else if (type == 'boolean') SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Observed result is Yes'), value: booleanValue, onChanged: (value) => setState(() => booleanValue = value))
        else DropdownButtonFormField<String>(initialValue: result, decoration: const InputDecoration(labelText: 'Result'), items: const [DropdownMenuItem(value: 'pass', child: Text('Pass')), DropdownMenuItem(value: 'fail', child: Text('Fail')), DropdownMenuItem(value: 'not_applicable', child: Text('Not applicable'))], onChanged: (value) => setState(() => result = value ?? result)),
        if (type == 'visual' || type == 'text') ...[const SizedBox(height: FactorySpacing.sm), TextField(controller: text, decoration: const InputDecoration(labelText: 'Observed value / note'))],
        const SizedBox(height: FactorySpacing.sm),
        TextField(controller: remarks, decoration: const InputDecoration(labelText: 'Remarks')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () { final value = double.tryParse(numeric.text.trim()); if (type == 'numeric' && value == null) return; Navigator.pop(context, {'plan_check_id': checkId, 'result_status': type == 'numeric' || type == 'boolean' ? null : result, 'numeric_value': type == 'numeric' ? value : null, 'boolean_value': type == 'boolean' ? booleanValue : null, 'text_value': type == 'visual' || type == 'text' ? (text.text.trim().isEmpty ? null : text.text.trim()) : null, 'remarks': remarks.text.trim().isEmpty ? null : remarks.text.trim()}); }, child: const Text('Save'))],
    );
  }
}

class _NcrDialog extends StatefulWidget {
  const _NcrDialog({required this.employees});
  final List<Map<String, dynamic>> employees;
  @override
  State<_NcrDialog> createState() => _NcrDialogState();
}

class _NcrDialogState extends State<_NcrDialog> {
  String severity = 'medium';
  String? employeeId;
  final category = TextEditingController();
  final description = TextEditingController();
  @override
  void dispose() { category.dispose(); description.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Create NCR'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(initialValue: severity, decoration: const InputDecoration(labelText: 'Severity'), items: const [DropdownMenuItem(value: 'low', child: Text('Low')), DropdownMenuItem(value: 'medium', child: Text('Medium')), DropdownMenuItem(value: 'high', child: Text('High')), DropdownMenuItem(value: 'critical', child: Text('Critical'))], onChanged: (value) => setState(() => severity = value ?? severity)),
          const SizedBox(height: FactorySpacing.sm),
          TextField(controller: category, decoration: const InputDecoration(labelText: 'Category')),
          const SizedBox(height: FactorySpacing.sm),
          TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
          const SizedBox(height: FactorySpacing.sm),
          DropdownButtonFormField<String>(initialValue: employeeId, decoration: const InputDecoration(labelText: 'Assign employee (optional)'), items: widget.employees.map((row) => DropdownMenuItem(value: row['id'] as String, child: Text('${row['employee_code']} · ${row['full_name']}'))).toList(), onChanged: (value) => setState(() => employeeId = value)),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () { if (category.text.trim().length < 2 || description.text.trim().length < 4) return; Navigator.pop(context, {'severity': severity, 'category': category.text.trim(), 'description': description.text.trim(), 'assigned_employee_id': employeeId}); }, child: const Text('Create'))],
      );
}

class _QuarantineDialog extends StatefulWidget {
  const _QuarantineDialog({required this.locations, this.defaultLot});
  final List<Map<String, dynamic>> locations;
  final String? defaultLot;
  @override
  State<_QuarantineDialog> createState() => _QuarantineDialogState();
}

class _QuarantineDialogState extends State<_QuarantineDialog> {
  String? fromId, quarantineId;
  final quantity = TextEditingController(text: '1');
  late final lot = TextEditingController(text: widget.defaultLot ?? '');
  @override
  void dispose() { quantity.dispose(); lot.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final quarantineLocations = widget.locations.where((row) => row['location_type'] == 'quarantine').toList();
    return AlertDialog(
      title: const Text('Quarantine stock'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(initialValue: fromId, decoration: const InputDecoration(labelText: 'Source location'), items: widget.locations.map((row) => DropdownMenuItem(value: row['id'] as String, child: Text('${row['code']} · ${row['name']}'))).toList(), onChanged: (value) => setState(() => fromId = value)),
        const SizedBox(height: FactorySpacing.sm),
        DropdownButtonFormField<String>(initialValue: quarantineId, decoration: const InputDecoration(labelText: 'Quarantine location'), items: quarantineLocations.map((row) => DropdownMenuItem(value: row['id'] as String, child: Text('${row['code']} · ${row['name']}'))).toList(), onChanged: (value) => setState(() => quarantineId = value)),
        const SizedBox(height: FactorySpacing.sm),
        TextField(controller: quantity, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Quantity')),
        const SizedBox(height: FactorySpacing.sm),
        TextField(controller: lot, decoration: const InputDecoration(labelText: 'Lot / batch')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: fromId == null || quarantineId == null ? null : () { final q = num.tryParse(quantity.text.trim()); if (q == null || q <= 0) return; Navigator.pop(context, {'from_location_id': fromId, 'quarantine_location_id': quarantineId, 'quantity': q, 'lot_batch_no': lot.text.trim().isEmpty ? null : lot.text.trim()}); }, child: const Text('Quarantine'))],
    );
  }
}

class _ReleaseDialog extends StatefulWidget {
  const _ReleaseDialog({required this.locations});
  final List<Map<String, dynamic>> locations;
  @override
  State<_ReleaseDialog> createState() => _ReleaseDialogState();
}

class _ReleaseDialogState extends State<_ReleaseDialog> {
  String? locationId;
  String disposition = 'release';
  @override
  void initState() { super.initState(); locationId = widget.locations.isEmpty ? null : widget.locations.first['id'] as String; }
  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Release quarantine'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(initialValue: locationId, decoration: const InputDecoration(labelText: 'Destination'), items: widget.locations.map((row) => DropdownMenuItem(value: row['id'] as String, child: Text('${row['code']} · ${row['name']}'))).toList(), onChanged: (value) => setState(() => locationId = value)),
          const SizedBox(height: FactorySpacing.sm),
          DropdownButtonFormField<String>(initialValue: disposition, decoration: const InputDecoration(labelText: 'Disposition'), items: const [DropdownMenuItem(value: 'release', child: Text('Release')), DropdownMenuItem(value: 'rework', child: Text('Rework')), DropdownMenuItem(value: 'use_as_is', child: Text('Use as-is'))], onChanged: (value) => setState(() => disposition = value ?? disposition)),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: locationId == null ? null : () => Navigator.pop(context, {'to_location_id': locationId, 'disposition': disposition}), child: const Text('Release'))],
      );
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.icon);
  final String label, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => SizedBox(width: 154, child: Card(child: Padding(padding: const EdgeInsets.all(FactorySpacing.md), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: FactoryColors.blue), const SizedBox(height: FactorySpacing.xs), Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)), Text(label)]))));
}

List<Map<String, dynamic>> _rows(dynamic value) => (value as List<dynamic>).map((row) => Map<String, dynamic>.from(row as Map)).toList();
String? _nested(Map<String, dynamic> row, String key, String field) { final value = row[key]; return value is Map && value[field] != null ? '${value[field]}' : null; }
String _title(String value) => value.replaceAll('_', ' ').split(' ').where((part) => part.isNotEmpty).map((part) => '${part[0].toUpperCase()}${part.substring(1)}').join(' ');
String _num(dynamic value) { final n = value is num ? value : num.tryParse('$value') ?? 0; return n % 1 == 0 ? n.toInt().toString() : n.toStringAsFixed(2); }
