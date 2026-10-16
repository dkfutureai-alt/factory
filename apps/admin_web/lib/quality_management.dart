import 'package:factoryos_core/factoryos_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class QualityManagementPage extends StatefulWidget {
  const QualityManagementPage({required this.organizationId, required this.actorRole, required this.factories, super.key});

  final String organizationId;
  final AppRole actorRole;
  final List<Map<String, dynamic>> factories;

  @override
  State<QualityManagementPage> createState() => _QualityManagementPageState();
}

class _QualityManagementPageState extends State<QualityManagementPage> {
  int section = 0;
  late Future<QualitySnapshot> future;
  QualityRepository get repository => QualityRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    future = repository.load(widget.organizationId);
  }

  void reload() => setState(() => future = repository.load(widget.organizationId));

  void message(String text, {bool error = false}) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text), backgroundColor: error ? Theme.of(context).colorScheme.error : null),
      );

  Future<void> editPlan(QualitySnapshot data, [Map<String, dynamic>? initial]) async {
    final draft = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _PlanEditor(items: data.items, initial: initial),
    );
    if (draft == null) return;
    try {
      await repository.savePlan(widget.organizationId, draft, id: initial?['id'] as String?);
      if (!mounted) return;
      message(initial == null ? 'Inspection plan created.' : 'Inspection plan updated.');
      reload();
    } catch (e) {
      if (mounted) message(_errorText(e), error: true);
    }
  }

  Future<void> addCheck(Map<String, dynamic> plan) async {
    final draft = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => const _CheckEditor());
    if (draft == null) return;
    try {
      await repository.addCheck(widget.organizationId, plan['id'] as String, draft);
      if (!mounted) return;
      message('Checklist parameter added.');
      reload();
    } catch (e) {
      if (mounted) message(_errorText(e), error: true);
    }
  }

  Future<void> removeCheck(String id) async {
    try {
      await repository.removeCheck(id);
      if (!mounted) return;
      message('Checklist parameter removed.');
      reload();
    } catch (e) {
      if (mounted) message(_errorText(e), error: true);
    }
  }

  Future<void> startInspection(QualitySnapshot data) async {
    final activePlans = data.plans.where((row) => row['is_active'] == true).toList();
    if (activePlans.isEmpty) {
      message('Create an active inspection plan first.', error: true);
      return;
    }
    final draft = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _StartInspectionEditor(
        plans: activePlans,
        factories: widget.factories,
        batches: data.productionBatches,
        employees: data.employees,
      ),
    );
    if (draft == null) return;
    try {
      final id = await repository.startInspection(draft);
      if (!mounted) return;
      message('Inspection started · ${id.substring(0, 8)}');
      reload();
    } catch (e) {
      if (mounted) message(_errorText(e), error: true);
    }
  }

  Future<void> recordResult(QualitySnapshot data, Map<String, dynamic> inspection) async {
    final planId = inspection['plan_id'] as String;
    final checks = data.checks.where((row) => row['plan_id'] == planId).toList()..sort((a, b) => (a['sequence_no'] as int).compareTo(b['sequence_no'] as int));
    if (checks.isEmpty) {
      message('This inspection plan has no checklist parameters.', error: true);
      return;
    }
    final draft = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _ResultEditor(checks: checks, existing: data.results.where((row) => row['inspection_id'] == inspection['id']).toList()),
    );
    if (draft == null) return;
    try {
      await repository.recordResult(inspection['id'] as String, draft);
      if (!mounted) return;
      message('Inspection result saved.');
      reload();
    } catch (e) {
      if (mounted) message(_errorText(e), error: true);
    }
  }

  Future<void> completeInspection(String id, {bool hold = false}) async {
    try {
      final result = await repository.completeInspection(id, hold: hold);
      if (!mounted) return;
      message('Inspection completed · ${result.toUpperCase()}');
      reload();
    } catch (e) {
      if (mounted) message(_errorText(e), error: true);
    }
  }

  Future<void> createNcr(QualitySnapshot data) async {
    final eligible = data.inspections.where((row) => row['status'] == 'completed' && const {'fail', 'hold'}.contains(row['overall_result'])).toList();
    if (eligible.isEmpty) {
      message('No failed or held inspection requires an NCR.', error: true);
      return;
    }
    final draft = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _NcrEditor(inspections: eligible, employees: data.employees),
    );
    if (draft == null) return;
    try {
      await repository.createNcr(draft);
      if (!mounted) return;
      message('NCR created.');
      reload();
    } catch (e) {
      if (mounted) message(_errorText(e), error: true);
    }
  }

  Future<void> updateNcr(Map<String, dynamic> ncr) async {
    final draft = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => _NcrDispositionEditor(initial: ncr));
    if (draft == null) return;
    try {
      await repository.updateNcr(ncr['id'] as String, draft);
      if (!mounted) return;
      message('NCR updated.');
      reload();
    } catch (e) {
      if (mounted) message(_errorText(e), error: true);
    }
  }

  Future<void> quarantine(QualitySnapshot data) async {
    final eligible = data.inspections.where((row) => row['status'] == 'completed' && const {'fail', 'hold'}.contains(row['overall_result'])).toList();
    if (eligible.isEmpty) {
      message('No failed or held inspection is available for quarantine.', error: true);
      return;
    }
    final draft = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _QuarantineEditor(inspections: eligible, locations: data.locations),
    );
    if (draft == null) return;
    try {
      await repository.quarantineStock(draft);
      if (!mounted) return;
      message('Stock moved to quality quarantine.');
      reload();
    } catch (e) {
      if (mounted) message(_errorText(e), error: true);
    }
  }

  Future<void> release(QualitySnapshot data, Map<String, dynamic> quarantine) async {
    final locations = data.locations.where((row) => row['factory_id'] == quarantine['factory_id'] && row['id'] != quarantine['quarantine_location_id']).toList();
    final draft = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _ReleaseEditor(locations: locations),
    );
    if (draft == null) return;
    try {
      await repository.releaseQuarantine(quarantine['id'] as String, draft);
      if (!mounted) return;
      message('Quarantine released to inventory.');
      reload();
    } catch (e) {
      if (mounted) message(_errorText(e), error: true);
    }
  }

  Future<void> issueCertificate(String inspectionId) async {
    try {
      final id = await repository.issueCertificate(inspectionId);
      if (!mounted) return;
      message('Quality certificate issued · ${id.substring(0, 8)}');
      reload();
    } catch (e) {
      if (mounted) message(_errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<QualitySnapshot>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return _ErrorPanel(message: '${snapshot.error}', onRetry: reload);
          final data = snapshot.requireData;
          final canMaster = widget.actorRole.canManageOrganizationSetup;
          final canOperate = const {AppRole.platformOwner, AppRole.orgAdmin, AppRole.factoryManager, AppRole.supervisor, AppRole.employee}.contains(widget.actorRole);
          final canApprove = const {AppRole.platformOwner, AppRole.orgAdmin, AppRole.factoryManager, AppRole.supervisor}.contains(widget.actorRole);
          final sections = <_Section>[
            _Section('Dashboard', Icons.verified_user_outlined, _Dashboard(data: data, onInspection: canOperate ? () => startInspection(data) : null, onNcr: canOperate ? () => createNcr(data) : null, onQuarantine: canOperate ? () => quarantine(data) : null)),
            _Section('Plans', Icons.fact_check_outlined, _Plans(data: data, canEdit: canMaster, onAdd: () => editPlan(data), onEdit: (row) => editPlan(data, row), onAddCheck: addCheck, onRemoveCheck: removeCheck)),
            _Section('Inspections', Icons.rule_folder_outlined, _Inspections(data: data, canOperate: canOperate, canApprove: canApprove, onStart: () => startInspection(data), onResult: (row) => recordResult(data, row), onComplete: completeInspection, onCertificate: issueCertificate)),
            _Section('NCR', Icons.report_problem_outlined, _Ncrs(data: data, canCreate: canOperate, canApprove: canApprove, onCreate: () => createNcr(data), onUpdate: updateNcr)),
            _Section('Quarantine', Icons.inventory_outlined, _Quarantine(data: data, canQuarantine: canOperate, canRelease: canApprove, onQuarantine: () => quarantine(data), onRelease: (row) => release(data, row))),
            _Section('Certificates', Icons.workspace_premium_outlined, _Certificates(data: data, canIssue: canApprove, onIssue: issueCertificate)),
            _Section('Reports', Icons.analytics_outlined, _Reports(data: data)),
          ];
          if (section >= sections.length) section = 0;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(FactorySpacing.lg, FactorySpacing.lg, FactorySpacing.lg, 0),
                child: Row(children: [
                  const Icon(Icons.verified_user_outlined, color: FactoryColors.blue),
                  const SizedBox(width: FactorySpacing.sm),
                  Expanded(child: Text('Quality', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900))),
                  IconButton(tooltip: 'Refresh', onPressed: reload, icon: const Icon(Icons.refresh)),
                ]),
              ),
              SizedBox(
                height: 56,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: FactorySpacing.lg, vertical: FactorySpacing.sm),
                  scrollDirection: Axis.horizontal,
                  itemCount: sections.length,
                  separatorBuilder: (_, __) => const SizedBox(width: FactorySpacing.xs),
                  itemBuilder: (context, i) => ChoiceChip(selected: section == i, avatar: Icon(sections[i].icon, size: 18), label: Text(sections[i].label), onSelected: (_) => setState(() => section = i)),
                ),
              ),
              Expanded(child: sections[section].page),
            ],
          );
        },
      );
}

class QualitySnapshot {
  const QualitySnapshot({required this.summary, required this.items, required this.plans, required this.checks, required this.inspections, required this.results, required this.ncrs, required this.quarantine, required this.certificates, required this.locations, required this.employees, required this.productionBatches, required this.inspectionReport, required this.ncrReport});

  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> items, plans, checks, inspections, results, ncrs, quarantine, certificates, locations, employees, productionBatches, inspectionReport, ncrReport;
}

class QualityRepository {
  QualityRepository(this.client);
  final SupabaseClient client;

  Future<QualitySnapshot> load(String orgId) async {
    final results = await Future.wait<dynamic>([
      client.rpc('quality_dashboard_summary', params: {'p_organization_id': orgId}),
      client.from('inventory_items').select('id,name,sku,item_type,is_active,inventory_units(code)').eq('organization_id', orgId).eq('is_active', true).order('name'),
      client.from('quality_inspection_plans').select('id,organization_id,item_id,name,code,version,inspection_type,sampling_method,default_sample_size,sample_percentage,effective_from,notes,is_active,inventory_items(name,sku)').eq('organization_id', orgId).order('name'),
      client.from('quality_plan_checks').select('id,organization_id,plan_id,sequence_no,parameter_name,check_type,target_numeric,min_numeric,max_numeric,unit_text,expected_boolean,acceptance_text,is_required').eq('organization_id', orgId).order('sequence_no'),
      client.from('quality_inspections').select('id,organization_id,factory_id,inspection_no,plan_id,inspection_type,item_id,production_order_id,production_batch_id,lot_batch_no,sample_size,status,overall_result,inspector_employee_id,started_at,completed_at,remarks,inventory_items(name,sku),quality_inspection_plans(name,code,version),employees(full_name,employee_code),production_orders(order_no),production_batches(batch_no)').eq('organization_id', orgId).order('started_at', ascending: false).limit(250),
      client.from('quality_inspection_results').select('id,inspection_id,plan_check_id,result_status,numeric_value,boolean_value,text_value,remarks,occurred_at,quality_plan_checks(parameter_name,check_type,unit_text,sequence_no)').eq('organization_id', orgId).order('occurred_at', ascending: false).limit(500),
      client.from('quality_ncrs').select('id,organization_id,factory_id,ncr_no,inspection_id,item_id,severity,category,description,status,disposition,assigned_employee_id,due_date,root_cause,corrective_action,closed_at,created_at,quality_inspections(inspection_no),inventory_items(name,sku),employees(full_name,employee_code)').eq('organization_id', orgId).order('created_at', ascending: false).limit(250),
      client.from('quality_quarantine_lots').select('id,organization_id,factory_id,inspection_id,item_id,source_location_id,quarantine_location_id,release_location_id,quantity,lot_batch_no,status,disposition,notes,quarantined_at,released_at').eq('organization_id', orgId).order('quarantined_at', ascending: false).limit(250),
      client.from('quality_certificates').select('id,organization_id,factory_id,inspection_id,item_id,certificate_no,lot_batch_no,snapshot,issued_at,quality_inspections(inspection_no),inventory_items(name,sku)').eq('organization_id', orgId).order('issued_at', ascending: false).limit(250),
      client.from('stock_locations').select('id,factory_id,name,code,location_type,is_active').eq('organization_id', orgId).eq('is_active', true).order('name'),
      client.from('employees').select('id,primary_factory_id,full_name,employee_code,status').eq('organization_id', orgId).eq('status', 'active').order('full_name'),
      client.from('production_batches').select('id,factory_id,order_id,batch_no,status,production_orders(order_no,product_item_id,inventory_items(name,sku))').eq('organization_id', orgId).order('created_at', ascending: false).limit(200),
      client.rpc('quality_inspection_report', params: {'p_organization_id': orgId, 'p_limit': 200}),
      client.rpc('quality_ncr_report', params: {'p_organization_id': orgId, 'p_limit': 200}),
    ]);
    return QualitySnapshot(
      summary: Map<String, dynamic>.from(results[0] as Map),
      items: _rows(results[1]),
      plans: _rows(results[2]),
      checks: _rows(results[3]),
      inspections: _rows(results[4]),
      results: _rows(results[5]),
      ncrs: _rows(results[6]),
      quarantine: _rows(results[7]),
      certificates: _rows(results[8]),
      locations: _rows(results[9]),
      employees: _rows(results[10]),
      productionBatches: _rows(results[11]),
      inspectionReport: _rows(results[12]),
      ncrReport: _rows(results[13]),
    );
  }

  Future<void> savePlan(String orgId, Map<String, dynamic> values, {String? id}) async => id == null ? client.from('quality_inspection_plans').insert({'organization_id': orgId, ...values}) : client.from('quality_inspection_plans').update(values).eq('id', id);
  Future<void> addCheck(String orgId, String planId, Map<String, dynamic> values) async => client.from('quality_plan_checks').insert({'organization_id': orgId, 'plan_id': planId, ...values});
  Future<void> removeCheck(String id) async => client.from('quality_plan_checks').delete().eq('id', id);
  Future<String> startInspection(Map<String, dynamic> d) async => (await client.rpc('quality_start_inspection', params: {
        'p_factory_id': d['factory_id'],
        'p_plan_id': d['plan_id'],
        'p_item_id': d['item_id'],
        'p_production_batch_id': d['production_batch_id'],
        'p_lot_batch_no': d['lot_batch_no'],
        'p_sample_size': d['sample_size'],
        'p_inspector_employee_id': d['inspector_employee_id'],
        'p_notes': d['notes'],
      })) as String;
  Future<void> recordResult(String inspectionId, Map<String, dynamic> d) async => client.rpc('quality_record_result', params: {
        'p_inspection_id': inspectionId,
        'p_plan_check_id': d['plan_check_id'],
        'p_result_status': d['result_status'],
        'p_numeric_value': d['numeric_value'],
        'p_boolean_value': d['boolean_value'],
        'p_text_value': d['text_value'],
        'p_remarks': d['remarks'],
      });
  Future<String> completeInspection(String id, {bool hold = false}) async => (await client.rpc('quality_complete_inspection', params: {'p_inspection_id': id, 'p_hold': hold})) as String;
  Future<void> createNcr(Map<String, dynamic> d) async => client.rpc('quality_create_ncr', params: {
        'p_inspection_id': d['inspection_id'],
        'p_severity': d['severity'],
        'p_category': d['category'],
        'p_description': d['description'],
        'p_assigned_employee_id': d['assigned_employee_id'],
      });
  Future<void> updateNcr(String id, Map<String, dynamic> d) async => client.rpc('quality_update_ncr', params: {
        'p_ncr_id': id,
        'p_status': d['status'],
        'p_disposition': d['disposition'],
        'p_root_cause': d['root_cause'],
        'p_corrective_action': d['corrective_action'],
      });
  Future<void> quarantineStock(Map<String, dynamic> d) async => client.rpc('quality_quarantine_stock', params: {
        'p_inspection_id': d['inspection_id'],
        'p_from_location_id': d['from_location_id'],
        'p_quarantine_location_id': d['quarantine_location_id'],
        'p_quantity': d['quantity'],
        'p_lot_batch_no': d['lot_batch_no'],
        'p_notes': d['notes'],
      });
  Future<void> releaseQuarantine(String id, Map<String, dynamic> d) async => client.rpc('quality_release_quarantine', params: {
        'p_quarantine_id': id,
        'p_to_location_id': d['to_location_id'],
        'p_disposition': d['disposition'],
        'p_notes': d['notes'],
      });
  Future<String> issueCertificate(String inspectionId) async => (await client.rpc('quality_issue_certificate', params: {'p_inspection_id': inspectionId})) as String;
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.data, this.onInspection, this.onNcr, this.onQuarantine});
  final QualitySnapshot data;
  final VoidCallback? onInspection, onNcr, onQuarantine;

  @override
  Widget build(BuildContext context) {
    final s = data.summary;
    return ListView(
      padding: const EdgeInsets.all(FactorySpacing.lg),
      children: [
        Wrap(spacing: FactorySpacing.md, runSpacing: FactorySpacing.md, children: [
          _Metric('Inspections today', '${s['today_inspections'] ?? 0}', Icons.fact_check_outlined),
          _Metric('Passed', '${s['today_passed'] ?? 0}', Icons.check_circle_outline),
          _Metric('Failed', '${s['today_failed'] ?? 0}', Icons.cancel_outlined),
          _Metric('On hold', '${s['today_hold'] ?? 0}', Icons.pause_circle_outline),
          _Metric('Open NCR', '${s['open_ncr'] ?? 0}', Icons.report_problem_outlined),
          _Metric('Quarantine qty', _number(s['quarantine_quantity']), Icons.inventory_outlined),
        ]),
        const SizedBox(height: FactorySpacing.lg),
        Text('Quick actions', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: FactorySpacing.md),
        Wrap(spacing: FactorySpacing.sm, runSpacing: FactorySpacing.sm, children: [
          if (onInspection != null) FilledButton.icon(onPressed: onInspection, icon: const Icon(Icons.add_task), label: const Text('New inspection')),
          if (onNcr != null) OutlinedButton.icon(onPressed: onNcr, icon: const Icon(Icons.report_problem_outlined), label: const Text('Create NCR')),
          if (onQuarantine != null) OutlinedButton.icon(onPressed: onQuarantine, icon: const Icon(Icons.inventory_outlined), label: const Text('Quarantine stock')),
        ]),
        const SizedBox(height: FactorySpacing.lg),
        Text('Recent inspections', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: FactorySpacing.sm),
        for (final row in data.inspections.take(8)) _InspectionCard(row: row),
      ],
    );
  }
}

class _Plans extends StatelessWidget {
  const _Plans({required this.data, required this.canEdit, required this.onAdd, required this.onEdit, required this.onAddCheck, required this.onRemoveCheck});
  final QualitySnapshot data;
  final bool canEdit;
  final VoidCallback onAdd;
  final ValueChanged<Map<String, dynamic>> onEdit, onAddCheck;
  final ValueChanged<String> onRemoveCheck;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(FactorySpacing.lg),
        children: [
          Row(children: [Expanded(child: Text('Inspection plans & checklists', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))), if (canEdit) FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('New plan'))]),
          const SizedBox(height: FactorySpacing.md),
          for (final plan in data.plans)
            Card(
              child: ExpansionTile(
                leading: Icon(plan['is_active'] == true ? Icons.fact_check_outlined : Icons.pause_circle_outline),
                title: Text('${plan['code']} · ${plan['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${_title(plan['inspection_type'] as String)} · ${plan['version']} · ${_related(plan, 'inventory_items', 'name')}'),
                trailing: canEdit ? IconButton(onPressed: () => onEdit(plan), icon: const Icon(Icons.edit_outlined)) : null,
                children: [
                  for (final check in data.checks.where((row) => row['plan_id'] == plan['id']))
                    ListTile(
                      leading: CircleAvatar(child: Text('${check['sequence_no']}')),
                      title: Text(check['parameter_name'] as String),
                      subtitle: Text(_checkSubtitle(check)),
                      trailing: canEdit ? IconButton(onPressed: () => onRemoveCheck(check['id'] as String), icon: const Icon(Icons.delete_outline)) : null,
                    ),
                  if (canEdit) Padding(padding: const EdgeInsets.all(FactorySpacing.sm), child: OutlinedButton.icon(onPressed: () => onAddCheck(plan), icon: const Icon(Icons.playlist_add), label: const Text('Add checklist parameter'))),
                ],
              ),
            ),
        ],
      );
}

class _Inspections extends StatelessWidget {
  const _Inspections({required this.data, required this.canOperate, required this.canApprove, required this.onStart, required this.onResult, required this.onComplete, required this.onCertificate});
  final QualitySnapshot data;
  final bool canOperate, canApprove;
  final VoidCallback onStart;
  final ValueChanged<Map<String, dynamic>> onResult;
  final void Function(String id, {bool hold}) onComplete;
  final ValueChanged<String> onCertificate;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(FactorySpacing.lg),
        children: [
          Row(children: [Expanded(child: Text('Inspection execution', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))), if (canOperate) FilledButton.icon(onPressed: onStart, icon: const Icon(Icons.add_task), label: const Text('Start inspection'))]),
          const SizedBox(height: FactorySpacing.md),
          for (final row in data.inspections)
            Card(
              child: ListTile(
                leading: _ResultIcon(result: row['overall_result'] as String),
                title: Text('${row['inspection_no']} · ${_related(row, 'inventory_items', 'name')}', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${_title(row['inspection_type'] as String)} · ${_related(row, 'quality_inspection_plans', 'name')} · sample ${row['sample_size']}'),
                trailing: Wrap(mainAxisSize: MainAxisSize.min, spacing: FactorySpacing.xs, children: [
                  if (row['status'] == 'in_progress' && canOperate) IconButton(tooltip: 'Record result', onPressed: () => onResult(row), icon: const Icon(Icons.playlist_add_check_circle_outlined)),
                  if (row['status'] == 'in_progress' && canOperate) IconButton(tooltip: 'Complete', onPressed: () => onComplete(row['id'] as String), icon: const Icon(Icons.check_circle_outline)),
                  if (row['status'] == 'in_progress' && canOperate) IconButton(tooltip: 'Hold', onPressed: () => onComplete(row['id'] as String, hold: true), icon: const Icon(Icons.pause_circle_outline)),
                  if (row['status'] == 'completed' && row['overall_result'] == 'pass' && canApprove && !data.certificates.any((c) => c['inspection_id'] == row['id'])) IconButton(tooltip: 'Issue certificate', onPressed: () => onCertificate(row['id'] as String), icon: const Icon(Icons.workspace_premium_outlined)),
                ]),
              ),
            ),
        ],
      );
}

class _Ncrs extends StatelessWidget {
  const _Ncrs({required this.data, required this.canCreate, required this.canApprove, required this.onCreate, required this.onUpdate});
  final QualitySnapshot data;
  final bool canCreate, canApprove;
  final VoidCallback onCreate;
  final ValueChanged<Map<String, dynamic>> onUpdate;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(FactorySpacing.lg),
        children: [
          Row(children: [Expanded(child: Text('NCR / deviation', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))), if (canCreate) FilledButton.icon(onPressed: onCreate, icon: const Icon(Icons.add), label: const Text('Create NCR'))]),
          const SizedBox(height: FactorySpacing.md),
          for (final row in data.ncrs)
            Card(
              child: ListTile(
                leading: Icon(row['status'] == 'closed' ? Icons.task_alt : Icons.report_problem_outlined, color: row['severity'] == 'critical' || row['severity'] == 'high' ? Theme.of(context).colorScheme.error : null),
                title: Text('${row['ncr_no']} · ${row['category']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${_title(row['severity'] as String)} · ${_title(row['status'] as String)} · ${_related(row, 'inventory_items', 'name')}\n${row['description']}'),
                isThreeLine: true,
                trailing: canApprove ? IconButton(onPressed: () => onUpdate(row), icon: const Icon(Icons.edit_note_outlined)) : null,
              ),
            ),
        ],
      );
}

class _Quarantine extends StatelessWidget {
  const _Quarantine({required this.data, required this.canQuarantine, required this.canRelease, required this.onQuarantine, required this.onRelease});
  final QualitySnapshot data;
  final bool canQuarantine, canRelease;
  final VoidCallback onQuarantine;
  final ValueChanged<Map<String, dynamic>> onRelease;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(FactorySpacing.lg),
        children: [
          Row(children: [Expanded(child: Text('Quarantine & release', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))), if (canQuarantine) FilledButton.icon(onPressed: onQuarantine, icon: const Icon(Icons.inventory_outlined), label: const Text('Quarantine'))]),
          const SizedBox(height: FactorySpacing.md),
          for (final row in data.quarantine)
            Card(
              child: ListTile(
                leading: Icon(row['status'] == 'quarantined' ? Icons.lock_outline : Icons.lock_open_outlined),
                title: Text('${_itemName(data, row['item_id'])} · ${_number(row['quantity'])}', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${_title(row['status'] as String)} · ${row['lot_batch_no'] ?? 'No lot'} · ${_locationName(data, row['quarantine_location_id'])}'),
                trailing: row['status'] == 'quarantined' && canRelease ? FilledButton.tonal(onPressed: () => onRelease(row), child: const Text('Release')) : null,
              ),
            ),
        ],
      );
}

class _Certificates extends StatelessWidget {
  const _Certificates({required this.data, required this.canIssue, required this.onIssue});
  final QualitySnapshot data;
  final bool canIssue;
  final ValueChanged<String> onIssue;

  @override
  Widget build(BuildContext context) {
    final eligible = data.inspections.where((row) => row['status'] == 'completed' && row['overall_result'] == 'pass' && !data.certificates.any((c) => c['inspection_id'] == row['id'])).toList();
    return ListView(
      padding: const EdgeInsets.all(FactorySpacing.lg),
      children: [
        Text('Quality certificates', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        if (canIssue && eligible.isNotEmpty) ...[
          const SizedBox(height: FactorySpacing.md),
          Wrap(spacing: FactorySpacing.sm, runSpacing: FactorySpacing.sm, children: [for (final row in eligible) OutlinedButton.icon(onPressed: () => onIssue(row['id'] as String), icon: const Icon(Icons.workspace_premium_outlined), label: Text('Issue ${row['inspection_no']}'))]),
        ],
        const SizedBox(height: FactorySpacing.md),
        for (final row in data.certificates)
          Card(child: ListTile(leading: const Icon(Icons.workspace_premium_outlined), title: Text(row['certificate_no'] as String, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text('${_related(row, 'inventory_items', 'name')} · ${row['lot_batch_no'] ?? 'No lot'} · ${_related(row, 'quality_inspections', 'inspection_no')}'))),
      ],
    );
  }
}

class _Reports extends StatelessWidget {
  const _Reports({required this.data});
  final QualitySnapshot data;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(FactorySpacing.lg),
        children: [
          Text('Quality reports', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: FactorySpacing.md),
          Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(columns: const [DataColumn(label: Text('Inspection')), DataColumn(label: Text('Item')), DataColumn(label: Text('Type')), DataColumn(label: Text('Result')), DataColumn(label: Text('Sample'))], rows: [for (final row in data.inspectionReport.take(100)) DataRow(cells: [DataCell(Text('${row['inspection_no']}')), DataCell(Text('${row['item_name']}')), DataCell(Text(_title('${row['inspection_type']}'))), DataCell(Text(_title('${row['overall_result']}'))), DataCell(Text('${row['sample_size']}'))])]),
            ),
          ),
          const SizedBox(height: FactorySpacing.lg),
          Text('NCR report', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: FactorySpacing.sm),
          for (final row in data.ncrReport.take(50)) Card(child: ListTile(title: Text('${row['ncr_no']} · ${row['item_name']}'), subtitle: Text('${_title('${row['severity']}')} · ${_title('${row['status']}')} · ${_title('${row['disposition']}')}'))),
        ],
      );
}

class _InspectionCard extends StatelessWidget {
  const _InspectionCard({required this.row});
  final Map<String, dynamic> row;
  @override
  Widget build(BuildContext context) => Card(child: ListTile(leading: _ResultIcon(result: row['overall_result'] as String), title: Text('${row['inspection_no']} · ${_related(row, 'inventory_items', 'name')}'), subtitle: Text('${_title(row['inspection_type'] as String)} · ${_title(row['overall_result'] as String)}')));
}

class _ResultIcon extends StatelessWidget {
  const _ResultIcon({required this.result});
  final String result;
  @override
  Widget build(BuildContext context) {
    final icon = switch (result) {'pass' => Icons.check_circle, 'fail' => Icons.cancel, 'hold' => Icons.pause_circle, _ => Icons.hourglass_empty};
    final color = switch (result) {'pass' => Colors.green, 'fail' => Theme.of(context).colorScheme.error, 'hold' => Colors.orange, _ => Colors.grey};
    return Icon(icon, color: color);
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.icon);
  final String label, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => SizedBox(width: 220, child: Card(child: Padding(padding: const EdgeInsets.all(FactorySpacing.lg), child: Row(children: [CircleAvatar(child: Icon(icon)), const SizedBox(width: FactorySpacing.md), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)), Text(label)]))]))));
}

class _PlanEditor extends StatefulWidget {
  const _PlanEditor({required this.items, this.initial});
  final List<Map<String, dynamic>> items;
  final Map<String, dynamic>? initial;
  @override
  State<_PlanEditor> createState() => _PlanEditorState();
}

class _PlanEditorState extends State<_PlanEditor> {
  late final name = TextEditingController(text: widget.initial?['name'] as String? ?? '');
  late final code = TextEditingController(text: widget.initial?['code'] as String? ?? '');
  late final version = TextEditingController(text: widget.initial?['version'] as String? ?? 'V1');
  late final sampleSize = TextEditingController(text: '${widget.initial?['default_sample_size'] ?? 5}');
  late final notes = TextEditingController(text: widget.initial?['notes'] as String? ?? '');
  String? itemId;
  String inspectionType = 'final';
  String samplingMethod = 'fixed';
  bool active = true;

  @override
  void initState() {
    super.initState();
    itemId = widget.initial?['item_id'] as String? ?? (widget.items.isEmpty ? null : widget.items.first['id'] as String);
    inspectionType = widget.initial?['inspection_type'] as String? ?? 'final';
    samplingMethod = widget.initial?['sampling_method'] as String? ?? 'fixed';
    active = widget.initial?['is_active'] as bool? ?? true;
  }

  @override
  void dispose() {
    name.dispose(); code.dispose(); version.dispose(); sampleSize.dispose(); notes.dispose(); super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.initial == null ? 'New inspection plan' : 'Edit inspection plan'),
        content: SizedBox(width: 560, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Plan name')),
          const SizedBox(height: FactorySpacing.sm),
          Row(children: [Expanded(child: TextField(controller: code, decoration: const InputDecoration(labelText: 'Code'))), const SizedBox(width: FactorySpacing.sm), Expanded(child: TextField(controller: version, decoration: const InputDecoration(labelText: 'Version')))]),
          const SizedBox(height: FactorySpacing.sm),
          DropdownButtonFormField<String>(value: itemId, decoration: const InputDecoration(labelText: 'Product / item'), items: [for (final item in widget.items) DropdownMenuItem(value: item['id'] as String, child: Text('${item['sku']} · ${item['name']}'))], onChanged: (value) => setState(() => itemId = value)),
          const SizedBox(height: FactorySpacing.sm),
          Row(children: [Expanded(child: DropdownButtonFormField<String>(value: inspectionType, decoration: const InputDecoration(labelText: 'Inspection type'), items: const [DropdownMenuItem(value: 'incoming', child: Text('Incoming')), DropdownMenuItem(value: 'in_process', child: Text('In-process')), DropdownMenuItem(value: 'final', child: Text('Final'))], onChanged: (value) => setState(() => inspectionType = value ?? inspectionType))), const SizedBox(width: FactorySpacing.sm), Expanded(child: DropdownButtonFormField<String>(value: samplingMethod, decoration: const InputDecoration(labelText: 'Sampling'), items: const [DropdownMenuItem(value: 'full', child: Text('100% / Full')), DropdownMenuItem(value: 'fixed', child: Text('Fixed sample')), DropdownMenuItem(value: 'aql', child: Text('AQL')), DropdownMenuItem(value: 'percentage', child: Text('Percentage'))], onChanged: (value) => setState(() => samplingMethod = value ?? samplingMethod)))]),
          const SizedBox(height: FactorySpacing.sm),
          TextField(controller: sampleSize, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Default sample size')),
          const SizedBox(height: FactorySpacing.sm),
          TextField(controller: notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes')),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Active'), value: active, onChanged: (value) => setState(() => active = value)),
        ]))),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: itemId == null ? null : () {
          final parsed = int.tryParse(sampleSize.text.trim());
          if (name.text.trim().length < 2 || code.text.trim().length < 2 || parsed == null || parsed <= 0) return;
          Navigator.pop(context, {'item_id': itemId, 'name': name.text.trim(), 'code': code.text.trim().toUpperCase(), 'version': version.text.trim(), 'inspection_type': inspectionType, 'sampling_method': samplingMethod, 'default_sample_size': parsed, 'notes': _nullIfBlank(notes.text), 'is_active': active});
        }, child: const Text('Save'))],
      );
}

class _CheckEditor extends StatefulWidget {
  const _CheckEditor();
  @override
  State<_CheckEditor> createState() => _CheckEditorState();
}

class _CheckEditorState extends State<_CheckEditor> {
  final sequence = TextEditingController(text: '1');
  final parameter = TextEditingController();
  final min = TextEditingController();
  final max = TextEditingController();
  final target = TextEditingController();
  final unit = TextEditingController();
  final acceptance = TextEditingController();
  String checkType = 'visual';
  bool expectedBoolean = true;
  bool required = true;
  @override
  void dispose() { sequence.dispose(); parameter.dispose(); min.dispose(); max.dispose(); target.dispose(); unit.dispose(); acceptance.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Add checklist parameter'),
        content: SizedBox(width: 520, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [Expanded(child: TextField(controller: sequence, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Sequence'))), const SizedBox(width: FactorySpacing.sm), Expanded(child: DropdownButtonFormField<String>(value: checkType, decoration: const InputDecoration(labelText: 'Check type'), items: const [DropdownMenuItem(value: 'visual', child: Text('Visual')), DropdownMenuItem(value: 'numeric', child: Text('Numeric')), DropdownMenuItem(value: 'boolean', child: Text('Yes / No')), DropdownMenuItem(value: 'text', child: Text('Text'))], onChanged: (value) => setState(() => checkType = value ?? checkType)))]),
          const SizedBox(height: FactorySpacing.sm),
          TextField(controller: parameter, decoration: const InputDecoration(labelText: 'Parameter name')),
          if (checkType == 'numeric') ...[
            const SizedBox(height: FactorySpacing.sm),
            Row(children: [Expanded(child: TextField(controller: min, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Min'))), const SizedBox(width: FactorySpacing.xs), Expanded(child: TextField(controller: target, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Target'))), const SizedBox(width: FactorySpacing.xs), Expanded(child: TextField(controller: max, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Max'))), const SizedBox(width: FactorySpacing.xs), Expanded(child: TextField(controller: unit, decoration: const InputDecoration(labelText: 'Unit')))]),
          ],
          if (checkType == 'boolean') SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Expected result is Yes'), value: expectedBoolean, onChanged: (value) => setState(() => expectedBoolean = value)),
          const SizedBox(height: FactorySpacing.sm),
          TextField(controller: acceptance, maxLines: 2, decoration: const InputDecoration(labelText: 'Acceptance criteria')),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Required parameter'), value: required, onChanged: (value) => setState(() => required = value)),
        ]))),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () {
          final seq = int.tryParse(sequence.text.trim());
          if (seq == null || seq <= 0 || parameter.text.trim().length < 2) return;
          Navigator.pop(context, {'sequence_no': seq, 'parameter_name': parameter.text.trim(), 'check_type': checkType, 'target_numeric': double.tryParse(target.text.trim()), 'min_numeric': double.tryParse(min.text.trim()), 'max_numeric': double.tryParse(max.text.trim()), 'unit_text': _nullIfBlank(unit.text), 'expected_boolean': checkType == 'boolean' ? expectedBoolean : null, 'acceptance_text': _nullIfBlank(acceptance.text), 'is_required': required});
        }, child: const Text('Add'))],
      );
}

class _StartInspectionEditor extends StatefulWidget {
  const _StartInspectionEditor({required this.plans, required this.factories, required this.batches, required this.employees});
  final List<Map<String, dynamic>> plans, factories, batches, employees;
  @override
  State<_StartInspectionEditor> createState() => _StartInspectionEditorState();
}

class _StartInspectionEditorState extends State<_StartInspectionEditor> {
  String? planId, factoryId, batchId, employeeId;
  final lot = TextEditingController();
  final sample = TextEditingController(text: '5');
  final notes = TextEditingController();
  @override
  void initState() {
    super.initState();
    planId = widget.plans.isEmpty ? null : widget.plans.first['id'] as String;
    factoryId = widget.factories.isEmpty ? null : widget.factories.first['id'] as String;
    _syncSample();
  }
  Map<String, dynamic>? get plan => widget.plans.cast<Map<String, dynamic>?>().firstWhere((row) => row?['id'] == planId, orElse: () => null);
  void _syncSample() { final value = plan?['default_sample_size']; if (value != null) sample.text = '$value'; }
  @override
  void dispose() { lot.dispose(); sample.dispose(); notes.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final selectedPlan = plan;
    final type = selectedPlan?['inspection_type'] as String?;
    final batches = widget.batches.where((row) => row['factory_id'] == factoryId && row['status'] != 'cancelled').toList();
    final employees = widget.employees.where((row) => row['primary_factory_id'] == factoryId).toList();
    return AlertDialog(
      title: const Text('Start quality inspection'),
      content: SizedBox(width: 560, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(value: factoryId, decoration: const InputDecoration(labelText: 'Factory'), items: [for (final row in widget.factories) DropdownMenuItem(value: row['id'] as String, child: Text(row['name'] as String))], onChanged: (value) => setState(() { factoryId = value; batchId = null; employeeId = null; })),
        const SizedBox(height: FactorySpacing.sm),
        DropdownButtonFormField<String>(value: planId, decoration: const InputDecoration(labelText: 'Inspection plan'), items: [for (final row in widget.plans) DropdownMenuItem(value: row['id'] as String, child: Text('${row['code']} · ${row['name']}'))], onChanged: (value) => setState(() { planId = value; batchId = null; _syncSample(); })),
        if (type != 'incoming') ...[
          const SizedBox(height: FactorySpacing.sm),
          DropdownButtonFormField<String>(value: batchId, decoration: const InputDecoration(labelText: 'Production batch (optional)'), items: [for (final row in batches) DropdownMenuItem(value: row['id'] as String, child: Text('${row['batch_no']} · ${_related(row, 'production_orders', 'order_no')}'))], onChanged: (value) => setState(() => batchId = value)),
        ],
        const SizedBox(height: FactorySpacing.sm),
        DropdownButtonFormField<String>(value: employeeId, decoration: const InputDecoration(labelText: 'Inspector (optional)'), items: [for (final row in employees) DropdownMenuItem(value: row['id'] as String, child: Text('${row['employee_code']} · ${row['full_name']}'))], onChanged: (value) => setState(() => employeeId = value)),
        const SizedBox(height: FactorySpacing.sm),
        Row(children: [Expanded(child: TextField(controller: lot, decoration: const InputDecoration(labelText: 'Lot / batch no.'))), const SizedBox(width: FactorySpacing.sm), Expanded(child: TextField(controller: sample, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Sample size')))]),
        const SizedBox(height: FactorySpacing.sm),
        TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes')),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: selectedPlan == null || factoryId == null ? null : () {
        final sampleSize = int.tryParse(sample.text.trim());
        if (sampleSize == null || sampleSize <= 0) return;
        Navigator.pop(context, {'factory_id': factoryId, 'plan_id': planId, 'item_id': selectedPlan['item_id'], 'production_batch_id': type == 'incoming' ? null : batchId, 'lot_batch_no': _nullIfBlank(lot.text), 'sample_size': sampleSize, 'inspector_employee_id': employeeId, 'notes': _nullIfBlank(notes.text)});
      }, child: const Text('Start'))],
    );
  }
}

class _ResultEditor extends StatefulWidget {
  const _ResultEditor({required this.checks, required this.existing});
  final List<Map<String, dynamic>> checks, existing;
  @override
  State<_ResultEditor> createState() => _ResultEditorState();
}

class _ResultEditorState extends State<_ResultEditor> {
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
    final c = check;
    final type = c['check_type'] as String;
    final done = widget.existing.any((row) => row['plan_check_id'] == checkId);
    return AlertDialog(
      title: const Text('Record checklist result'),
      content: SizedBox(width: 520, child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(value: checkId, decoration: const InputDecoration(labelText: 'Checklist parameter'), items: [for (final row in widget.checks) DropdownMenuItem(value: row['id'] as String, child: Text('${row['sequence_no']}. ${row['parameter_name']}'))], onChanged: (value) => setState(() => checkId = value)),
        if (done) const Padding(padding: EdgeInsets.only(top: FactorySpacing.sm), child: Text('A result already exists for this parameter; saving will replace it.')),
        const SizedBox(height: FactorySpacing.sm),
        if (type == 'numeric') TextField(controller: numeric, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Measured value${c['unit_text'] == null ? '' : ' (${c['unit_text']})'}', helperText: _checkSubtitle(c)))
        else if (type == 'boolean') SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Observed result is Yes'), value: booleanValue, onChanged: (value) => setState(() => booleanValue = value))
        else ...[
          DropdownButtonFormField<String>(value: result, decoration: const InputDecoration(labelText: 'Result'), items: const [DropdownMenuItem(value: 'pass', child: Text('Pass')), DropdownMenuItem(value: 'fail', child: Text('Fail')), DropdownMenuItem(value: 'not_applicable', child: Text('Not applicable'))], onChanged: (value) => setState(() => result = value ?? result)),
          const SizedBox(height: FactorySpacing.sm),
          TextField(controller: text, decoration: const InputDecoration(labelText: 'Observed value / note')),
        ],
        const SizedBox(height: FactorySpacing.sm),
        TextField(controller: remarks, maxLines: 2, decoration: const InputDecoration(labelText: 'Remarks')),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () {
        final numericValue = double.tryParse(numeric.text.trim());
        if (type == 'numeric' && numericValue == null) return;
        Navigator.pop(context, {'plan_check_id': checkId, 'result_status': type == 'numeric' || type == 'boolean' ? null : result, 'numeric_value': type == 'numeric' ? numericValue : null, 'boolean_value': type == 'boolean' ? booleanValue : null, 'text_value': type == 'visual' || type == 'text' ? _nullIfBlank(text.text) : null, 'remarks': _nullIfBlank(remarks.text)});
      }, child: const Text('Save'))],
    );
  }
}

class _NcrEditor extends StatefulWidget {
  const _NcrEditor({required this.inspections, required this.employees});
  final List<Map<String, dynamic>> inspections, employees;
  @override
  State<_NcrEditor> createState() => _NcrEditorState();
}

class _NcrEditorState extends State<_NcrEditor> {
  String? inspectionId, employeeId;
  String severity = 'medium';
  final category = TextEditingController();
  final description = TextEditingController();
  @override
  void initState() { super.initState(); inspectionId = widget.inspections.first['id'] as String; }
  @override
  void dispose() { category.dispose(); description.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final inspection = widget.inspections.firstWhere((row) => row['id'] == inspectionId);
    final employees = widget.employees.where((row) => row['primary_factory_id'] == inspection['factory_id']).toList();
    return AlertDialog(
      title: const Text('Create NCR / deviation'),
      content: SizedBox(width: 540, child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(value: inspectionId, decoration: const InputDecoration(labelText: 'Inspection'), items: [for (final row in widget.inspections) DropdownMenuItem(value: row['id'] as String, child: Text('${row['inspection_no']} · ${_related(row, 'inventory_items', 'name')}'))], onChanged: (value) => setState(() { inspectionId = value; employeeId = null; })),
        const SizedBox(height: FactorySpacing.sm),
        DropdownButtonFormField<String>(value: severity, decoration: const InputDecoration(labelText: 'Severity'), items: const [DropdownMenuItem(value: 'low', child: Text('Low')), DropdownMenuItem(value: 'medium', child: Text('Medium')), DropdownMenuItem(value: 'high', child: Text('High')), DropdownMenuItem(value: 'critical', child: Text('Critical'))], onChanged: (value) => setState(() => severity = value ?? severity)),
        const SizedBox(height: FactorySpacing.sm),
        TextField(controller: category, decoration: const InputDecoration(labelText: 'Category')),
        const SizedBox(height: FactorySpacing.sm),
        TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
        const SizedBox(height: FactorySpacing.sm),
        DropdownButtonFormField<String>(value: employeeId, decoration: const InputDecoration(labelText: 'Assign employee (optional)'), items: [for (final row in employees) DropdownMenuItem(value: row['id'] as String, child: Text('${row['employee_code']} · ${row['full_name']}'))], onChanged: (value) => setState(() => employeeId = value)),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () { if (category.text.trim().length < 2 || description.text.trim().length < 4) return; Navigator.pop(context, {'inspection_id': inspectionId, 'severity': severity, 'category': category.text.trim(), 'description': description.text.trim(), 'assigned_employee_id': employeeId}); }, child: const Text('Create'))],
    );
  }
}

class _NcrDispositionEditor extends StatefulWidget {
  const _NcrDispositionEditor({required this.initial});
  final Map<String, dynamic> initial;
  @override
  State<_NcrDispositionEditor> createState() => _NcrDispositionEditorState();
}

class _NcrDispositionEditorState extends State<_NcrDispositionEditor> {
  late String status = widget.initial['status'] as String;
  late String disposition = widget.initial['disposition'] as String;
  late final rootCause = TextEditingController(text: widget.initial['root_cause'] as String? ?? '');
  late final corrective = TextEditingController(text: widget.initial['corrective_action'] as String? ?? '');
  @override
  void dispose() { rootCause.dispose(); corrective.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Update ${widget.initial['ncr_no']}'),
        content: SizedBox(width: 520, child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(value: status, decoration: const InputDecoration(labelText: 'Status'), items: const [DropdownMenuItem(value: 'open', child: Text('Open')), DropdownMenuItem(value: 'investigating', child: Text('Investigating')), DropdownMenuItem(value: 'action_pending', child: Text('Action pending')), DropdownMenuItem(value: 'closed', child: Text('Closed'))], onChanged: (value) => setState(() => status = value ?? status)),
          const SizedBox(height: FactorySpacing.sm),
          DropdownButtonFormField<String>(value: disposition, decoration: const InputDecoration(labelText: 'Disposition'), items: const [DropdownMenuItem(value: 'pending', child: Text('Pending')), DropdownMenuItem(value: 'rework', child: Text('Rework')), DropdownMenuItem(value: 'scrap', child: Text('Scrap')), DropdownMenuItem(value: 'use_as_is', child: Text('Use as-is')), DropdownMenuItem(value: 'return', child: Text('Return')), DropdownMenuItem(value: 'sort', child: Text('Sort')), DropdownMenuItem(value: 'other', child: Text('Other'))], onChanged: (value) => setState(() => disposition = value ?? disposition)),
          const SizedBox(height: FactorySpacing.sm),
          TextField(controller: rootCause, maxLines: 2, decoration: const InputDecoration(labelText: 'Root cause')),
          const SizedBox(height: FactorySpacing.sm),
          TextField(controller: corrective, maxLines: 2, decoration: const InputDecoration(labelText: 'Corrective action')),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, {'status': status, 'disposition': disposition, 'root_cause': _nullIfBlank(rootCause.text), 'corrective_action': _nullIfBlank(corrective.text)}), child: const Text('Save'))],
      );
}

class _QuarantineEditor extends StatefulWidget {
  const _QuarantineEditor({required this.inspections, required this.locations});
  final List<Map<String, dynamic>> inspections, locations;
  @override
  State<_QuarantineEditor> createState() => _QuarantineEditorState();
}

class _QuarantineEditorState extends State<_QuarantineEditor> {
  String? inspectionId, fromLocationId, quarantineLocationId;
  final quantity = TextEditingController(text: '1');
  final lot = TextEditingController();
  final notes = TextEditingController();
  @override
  void initState() { super.initState(); inspectionId = widget.inspections.first['id'] as String; }
  @override
  void dispose() { quantity.dispose(); lot.dispose(); notes.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final inspection = widget.inspections.firstWhere((row) => row['id'] == inspectionId);
    final locations = widget.locations.where((row) => row['factory_id'] == inspection['factory_id']).toList();
    final quarantineLocations = locations.where((row) => row['location_type'] == 'quarantine').toList();
    return AlertDialog(
      title: const Text('Move stock to quality quarantine'),
      content: SizedBox(width: 560, child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(value: inspectionId, decoration: const InputDecoration(labelText: 'Failed / held inspection'), items: [for (final row in widget.inspections) DropdownMenuItem(value: row['id'] as String, child: Text('${row['inspection_no']} · ${_related(row, 'inventory_items', 'name')}'))], onChanged: (value) => setState(() { inspectionId = value; fromLocationId = null; quarantineLocationId = null; })),
        const SizedBox(height: FactorySpacing.sm),
        Row(children: [Expanded(child: DropdownButtonFormField<String>(value: fromLocationId, decoration: const InputDecoration(labelText: 'Source location'), items: [for (final row in locations) DropdownMenuItem(value: row['id'] as String, child: Text('${row['code']} · ${row['name']}'))], onChanged: (value) => setState(() => fromLocationId = value))), const SizedBox(width: FactorySpacing.sm), Expanded(child: DropdownButtonFormField<String>(value: quarantineLocationId, decoration: const InputDecoration(labelText: 'Quarantine location'), items: [for (final row in quarantineLocations) DropdownMenuItem(value: row['id'] as String, child: Text('${row['code']} · ${row['name']}'))], onChanged: (value) => setState(() => quarantineLocationId = value)))]),
        const SizedBox(height: FactorySpacing.sm),
        Row(children: [Expanded(child: TextField(controller: quantity, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Quantity'))), const SizedBox(width: FactorySpacing.sm), Expanded(child: TextField(controller: lot, decoration: InputDecoration(labelText: 'Lot / batch', hintText: inspection['lot_batch_no'] as String?)))]),
        const SizedBox(height: FactorySpacing.sm),
        TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes')),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: fromLocationId == null || quarantineLocationId == null ? null : () { final q = double.tryParse(quantity.text.trim()); if (q == null || q <= 0) return; Navigator.pop(context, {'inspection_id': inspectionId, 'from_location_id': fromLocationId, 'quarantine_location_id': quarantineLocationId, 'quantity': q, 'lot_batch_no': _nullIfBlank(lot.text) ?? inspection['lot_batch_no'], 'notes': _nullIfBlank(notes.text)}); }, child: const Text('Quarantine'))],
    );
  }
}

class _ReleaseEditor extends StatefulWidget {
  const _ReleaseEditor({required this.locations});
  final List<Map<String, dynamic>> locations;
  @override
  State<_ReleaseEditor> createState() => _ReleaseEditorState();
}

class _ReleaseEditorState extends State<_ReleaseEditor> {
  String? locationId;
  String disposition = 'release';
  final notes = TextEditingController();
  @override
  void initState() { super.initState(); locationId = widget.locations.isEmpty ? null : widget.locations.first['id'] as String; }
  @override
  void dispose() { notes.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Release quarantine stock'),
        content: SizedBox(width: 500, child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(value: locationId, decoration: const InputDecoration(labelText: 'Release destination'), items: [for (final row in widget.locations) DropdownMenuItem(value: row['id'] as String, child: Text('${row['code']} · ${row['name']}'))], onChanged: (value) => setState(() => locationId = value)),
          const SizedBox(height: FactorySpacing.sm),
          DropdownButtonFormField<String>(value: disposition, decoration: const InputDecoration(labelText: 'Disposition'), items: const [DropdownMenuItem(value: 'release', child: Text('Release')), DropdownMenuItem(value: 'rework', child: Text('Rework')), DropdownMenuItem(value: 'use_as_is', child: Text('Use as-is'))], onChanged: (value) => setState(() => disposition = value ?? disposition)),
          const SizedBox(height: FactorySpacing.sm),
          TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Release notes')),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: locationId == null ? null : () => Navigator.pop(context, {'to_location_id': locationId, 'disposition': disposition, 'notes': _nullIfBlank(notes.text)}), child: const Text('Release'))],
      );
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(FactorySpacing.lg), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.error_outline, size: 48), const SizedBox(height: FactorySpacing.md), Text(message, textAlign: TextAlign.center), const SizedBox(height: FactorySpacing.md), OutlinedButton(onPressed: onRetry, child: const Text('Retry'))])));
}

class _Section {
  const _Section(this.label, this.icon, this.page);
  final String label;
  final IconData icon;
  final Widget page;
}

List<Map<String, dynamic>> _rows(dynamic value) => (value as List<dynamic>).map((row) => Map<String, dynamic>.from(row as Map)).toList();
String _related(Map<String, dynamic> row, String key, String field) { final value = row[key]; return value is Map && value[field] != null ? '${value[field]}' : '—'; }
String _title(String value) => value.replaceAll('_', ' ').split(' ').where((part) => part.isNotEmpty).map((part) => '${part[0].toUpperCase()}${part.substring(1)}').join(' ');
String _number(dynamic value) { final n = value is num ? value : num.tryParse('$value') ?? 0; return n % 1 == 0 ? n.toInt().toString() : n.toStringAsFixed(2); }
String? _nullIfBlank(String value) => value.trim().isEmpty ? null : value.trim();
String _errorText(Object error) => error.toString().replaceFirst('PostgrestException(message: ', '').replaceFirst('AuthException(message: ', '');
String _checkSubtitle(Map<String, dynamic> check) {
  if (check['check_type'] == 'numeric') return '${check['min_numeric'] ?? '—'} ≤ ${check['parameter_name']} ≤ ${check['max_numeric'] ?? '—'} ${check['unit_text'] ?? ''}'.trim();
  if (check['check_type'] == 'boolean') return 'Expected: ${check['expected_boolean'] == true ? 'Yes' : 'No'}';
  return '${check['acceptance_text'] ?? _title('${check['check_type']}')}';
}
String _itemName(QualitySnapshot data, dynamic id) { for (final row in data.items) { if (row['id'] == id) return row['name'] as String; } return 'Item'; }
String _locationName(QualitySnapshot data, dynamic id) { for (final row in data.locations) { if (row['id'] == id) return row['name'] as String; } return 'Location'; }
