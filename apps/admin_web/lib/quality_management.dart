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
  late Future<_QualityData> future;
  _QualityRepository get repository => _QualityRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    future = repository.load(widget.organizationId);
  }

  void reload() => setState(() => future = repository.load(widget.organizationId));

  void notify(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), backgroundColor: error ? Theme.of(context).colorScheme.error : null));
  }

  Future<void> runAction(Future<void> Function() action, String success) async {
    try {
      await action();
      if (!mounted) return;
      notify(success);
      reload();
    } catch (error) {
      if (mounted) notify(error is PostgrestException ? error.message : '$error', error: true);
    }
  }

  Future<void> editPlan(_QualityData data, [Map<String, dynamic>? initial]) async {
    final draft = await showDialog<Map<String, dynamic>>(context: context, builder: (context) => _PlanDialog(items: data.items, initial: initial));
    if (draft == null) return;
    await runAction(() => repository.savePlan(widget.organizationId, draft, id: initial?['id'] as String?), initial == null ? 'Inspection plan created.' : 'Inspection plan updated.');
  }

  Future<void> addCheck(Map<String, dynamic> plan) async {
    final draft = await showDialog<Map<String, dynamic>>(context: context, builder: (context) => const _CheckDialog());
    if (draft == null) return;
    await runAction(() => repository.addCheck(widget.organizationId, plan['id'] as String, draft), 'Checklist parameter added.');
  }

  Future<void> startInspection(_QualityData data) async {
    final plans = data.plans.where((row) => row['is_active'] == true).toList();
    if (plans.isEmpty) return notify('Create an active inspection plan first.', error: true);
    final draft = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _StartInspectionDialog(plans: plans, factories: widget.factories, batches: data.productionBatches, employees: data.employees),
    );
    if (draft == null) return;
    await runAction(() async => repository.startInspection(draft), 'Inspection started.');
  }

  Future<void> recordResult(_QualityData data, Map<String, dynamic> inspection) async {
    final checks = data.checks.where((row) => row['plan_id'] == inspection['plan_id']).toList();
    if (checks.isEmpty) return notify('This plan has no checklist parameters.', error: true);
    final draft = await showDialog<Map<String, dynamic>>(context: context, builder: (context) => _ResultDialog(checks: checks));
    if (draft == null) return;
    await runAction(() => repository.recordResult(inspection['id'] as String, draft), 'Checklist result saved.');
  }

  Future<void> completeInspection(String id, {bool hold = false}) async {
    await runAction(() async => repository.completeInspection(id, hold: hold), hold ? 'Inspection placed on hold.' : 'Inspection completed.');
  }

  Future<void> createNcr(_QualityData data, [Map<String, dynamic>? selected]) async {
    final inspections = data.inspections.where((row) => row['status'] == 'completed' && const {'fail', 'hold'}.contains(row['overall_result'])).toList();
    if (inspections.isEmpty) return notify('No failed or held inspection is available.', error: true);
    final draft = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _NcrDialog(inspections: inspections, employees: data.employees, selectedInspectionId: selected?['id'] as String?),
    );
    if (draft == null) return;
    await runAction(() => repository.createNcr(draft), 'NCR created.');
  }

  Future<void> updateNcr(Map<String, dynamic> ncr) async {
    final draft = await showDialog<Map<String, dynamic>>(context: context, builder: (context) => _NcrUpdateDialog(initial: ncr));
    if (draft == null) return;
    await runAction(() => repository.updateNcr(ncr['id'] as String, draft), 'NCR updated.');
  }

  Future<void> quarantine(_QualityData data, [Map<String, dynamic>? selected]) async {
    final inspections = data.inspections.where((row) => row['status'] == 'completed' && const {'fail', 'hold'}.contains(row['overall_result'])).toList();
    if (inspections.isEmpty) return notify('No failed or held inspection is available.', error: true);
    final draft = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _QuarantineDialog(inspections: inspections, locations: data.locations, selectedInspectionId: selected?['id'] as String?),
    );
    if (draft == null) return;
    await runAction(() => repository.quarantine(draft), 'Stock moved to quality quarantine.');
  }

  Future<void> release(_QualityData data, Map<String, dynamic> row) async {
    final locations = data.locations.where((location) => location['factory_id'] == row['factory_id'] && location['id'] != row['quarantine_location_id']).toList();
    final draft = await showDialog<Map<String, dynamic>>(context: context, builder: (context) => _ReleaseDialog(locations: locations));
    if (draft == null) return;
    await runAction(() => repository.release(row['id'] as String, draft), 'Quarantine released to inventory.');
  }

  Future<void> issueCertificate(String inspectionId) async {
    await runAction(() async => repository.issueCertificate(inspectionId), 'Quality certificate issued.');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_QualityData>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: OutlinedButton(onPressed: reload, child: Text('Retry · ${snapshot.error}')));
        final data = snapshot.requireData;
        final canMaster = widget.actorRole.canManageOrganizationSetup;
        final canOperate = const {AppRole.platformOwner, AppRole.orgAdmin, AppRole.factoryManager, AppRole.supervisor, AppRole.employee}.contains(widget.actorRole);
        final canApprove = const {AppRole.platformOwner, AppRole.orgAdmin, AppRole.factoryManager, AppRole.supervisor}.contains(widget.actorRole);
        final pages = <Widget>[
          _Dashboard(data: data, onStart: canOperate ? () => startInspection(data) : null),
          _Plans(data: data, canEdit: canMaster, onAddPlan: () => editPlan(data), onEditPlan: (row) => editPlan(data, row), onAddCheck: addCheck),
          _Inspections(data: data, canOperate: canOperate, canApprove: canApprove, onStart: () => startInspection(data), onRecord: (row) => recordResult(data, row), onComplete: completeInspection, onNcr: (row) => createNcr(data, row), onQuarantine: (row) => quarantine(data, row), onCertificate: issueCertificate),
          _Ncrs(data: data, canOperate: canOperate, canApprove: canApprove, onCreate: () => createNcr(data), onUpdate: updateNcr),
          _Quarantine(data: data, canOperate: canOperate, canApprove: canApprove, onCreate: () => quarantine(data), onRelease: (row) => release(data, row)),
          _Certificates(data: data),
          _Reports(data: data),
        ];
        const labels = ['Dashboard', 'Plans', 'Inspections', 'NCR', 'Quarantine', 'Certificates', 'Reports'];
        const icons = [Icons.dashboard_outlined, Icons.fact_check_outlined, Icons.rule_folder_outlined, Icons.report_problem_outlined, Icons.inventory_outlined, Icons.workspace_premium_outlined, Icons.analytics_outlined];
        if (section >= pages.length) section = 0;
        return Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(FactorySpacing.lg, FactorySpacing.lg, FactorySpacing.lg, 0),
            child: Row(children: [const Icon(Icons.verified_user_outlined, color: FactoryColors.blue), const SizedBox(width: FactorySpacing.sm), Expanded(child: Text('Quality', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900))), IconButton(onPressed: reload, icon: const Icon(Icons.refresh))]),
          ),
          SizedBox(
            height: 56,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: FactorySpacing.lg, vertical: FactorySpacing.sm),
              scrollDirection: Axis.horizontal,
              itemCount: labels.length,
              separatorBuilder: (context, index) => const SizedBox(width: FactorySpacing.xs),
              itemBuilder: (context, index) => ChoiceChip(selected: section == index, avatar: Icon(icons[index], size: 18), label: Text(labels[index]), onSelected: (selected) => setState(() => section = index)),
            ),
          ),
          Expanded(child: pages[section]),
        ]);
      },
    );
  }
}

class _QualityData {
  const _QualityData({required this.summary, required this.items, required this.plans, required this.checks, required this.inspections, required this.results, required this.ncrs, required this.quarantine, required this.certificates, required this.locations, required this.employees, required this.productionBatches, required this.inspectionReport, required this.ncrReport});
  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> items, plans, checks, inspections, results, ncrs, quarantine, certificates, locations, employees, productionBatches, inspectionReport, ncrReport;
}

class _QualityRepository {
  _QualityRepository(this.client);
  final SupabaseClient client;

  Future<_QualityData> load(String orgId) async {
    final values = await Future.wait<dynamic>([
      client.rpc('quality_dashboard_summary', params: {'p_organization_id': orgId}),
      client.from('inventory_items').select('id,name,sku,item_type').eq('organization_id', orgId).eq('is_active', true).order('name'),
      client.from('quality_inspection_plans').select('id,item_id,name,code,version,inspection_type,sampling_method,default_sample_size,notes,is_active,inventory_items(name,sku)').eq('organization_id', orgId).order('name'),
      client.from('quality_plan_checks').select('id,plan_id,sequence_no,parameter_name,check_type,target_numeric,min_numeric,max_numeric,unit_text,expected_boolean,acceptance_text,is_required').eq('organization_id', orgId).order('sequence_no'),
      client.from('quality_inspections').select('id,factory_id,inspection_no,plan_id,inspection_type,item_id,production_batch_id,lot_batch_no,sample_size,status,overall_result,started_at,completed_at,inventory_items(name,sku),quality_inspection_plans(name,code,version)').eq('organization_id', orgId).order('started_at', ascending: false).limit(250),
      client.from('quality_inspection_results').select('id,inspection_id,plan_check_id,result_status,numeric_value,boolean_value,text_value,remarks').eq('organization_id', orgId).limit(500),
      client.from('quality_ncrs').select('id,factory_id,ncr_no,inspection_id,severity,category,description,status,disposition,root_cause,corrective_action,inventory_items(name,sku)').eq('organization_id', orgId).order('created_at', ascending: false).limit(250),
      client.from('quality_quarantine_lots').select('id,factory_id,inspection_id,item_id,source_location_id,quarantine_location_id,release_location_id,quantity,lot_batch_no,status,disposition').eq('organization_id', orgId).order('quarantined_at', ascending: false).limit(250),
      client.from('quality_certificates').select('id,inspection_id,item_id,certificate_no,lot_batch_no,issued_at,inventory_items(name,sku)').eq('organization_id', orgId).order('issued_at', ascending: false).limit(250),
      client.from('stock_locations').select('id,factory_id,name,code,location_type').eq('organization_id', orgId).eq('is_active', true).order('name'),
      client.from('employees').select('id,primary_factory_id,full_name,employee_code').eq('organization_id', orgId).eq('status', 'active').order('full_name'),
      client.from('production_batches').select('id,factory_id,batch_no,status,production_orders(order_no,product_item_id)').eq('organization_id', orgId).order('created_at', ascending: false).limit(200),
      client.rpc('quality_inspection_report', params: {'p_organization_id': orgId, 'p_limit': 200}),
      client.rpc('quality_ncr_report', params: {'p_organization_id': orgId, 'p_limit': 200}),
    ]);
    return _QualityData(
      summary: Map<String, dynamic>.from(values[0] as Map),
      items: _rows(values[1]), plans: _rows(values[2]), checks: _rows(values[3]), inspections: _rows(values[4]), results: _rows(values[5]), ncrs: _rows(values[6]), quarantine: _rows(values[7]), certificates: _rows(values[8]), locations: _rows(values[9]), employees: _rows(values[10]), productionBatches: _rows(values[11]), inspectionReport: _rows(values[12]), ncrReport: _rows(values[13]),
    );
  }

  Future<void> savePlan(String orgId, Map<String, dynamic> data, {String? id}) async {
    if (id == null) {
      await client.from('quality_inspection_plans').insert({'organization_id': orgId, ...data});
    } else {
      await client.from('quality_inspection_plans').update(data).eq('id', id);
    }
  }

  Future<void> addCheck(String orgId, String planId, Map<String, dynamic> data) async => client.from('quality_plan_checks').insert({'organization_id': orgId, 'plan_id': planId, ...data});
  Future<void> startInspection(Map<String, dynamic> data) async => client.rpc('quality_start_inspection', params: {'p_factory_id': data['factory_id'], 'p_plan_id': data['plan_id'], 'p_item_id': data['item_id'], 'p_production_batch_id': data['production_batch_id'], 'p_lot_batch_no': data['lot_batch_no'], 'p_sample_size': data['sample_size'], 'p_inspector_employee_id': data['inspector_employee_id'], 'p_notes': data['notes']});
  Future<void> recordResult(String inspectionId, Map<String, dynamic> data) async => client.rpc('quality_record_result', params: {'p_inspection_id': inspectionId, 'p_plan_check_id': data['plan_check_id'], 'p_result_status': data['result_status'], 'p_numeric_value': data['numeric_value'], 'p_boolean_value': data['boolean_value'], 'p_text_value': data['text_value'], 'p_remarks': data['remarks']});
  Future<void> completeInspection(String id, {bool hold = false}) async => client.rpc('quality_complete_inspection', params: {'p_inspection_id': id, 'p_hold': hold});
  Future<void> createNcr(Map<String, dynamic> data) async => client.rpc('quality_create_ncr', params: {'p_inspection_id': data['inspection_id'], 'p_severity': data['severity'], 'p_category': data['category'], 'p_description': data['description'], 'p_assigned_employee_id': data['assigned_employee_id']});
  Future<void> updateNcr(String id, Map<String, dynamic> data) async => client.rpc('quality_update_ncr', params: {'p_ncr_id': id, 'p_status': data['status'], 'p_disposition': data['disposition'], 'p_root_cause': data['root_cause'], 'p_corrective_action': data['corrective_action']});
  Future<void> quarantine(Map<String, dynamic> data) async => client.rpc('quality_quarantine_stock', params: {'p_inspection_id': data['inspection_id'], 'p_from_location_id': data['from_location_id'], 'p_quarantine_location_id': data['quarantine_location_id'], 'p_quantity': data['quantity'], 'p_lot_batch_no': data['lot_batch_no'], 'p_notes': data['notes']});
  Future<void> release(String id, Map<String, dynamic> data) async => client.rpc('quality_release_quarantine', params: {'p_quarantine_id': id, 'p_to_location_id': data['to_location_id'], 'p_disposition': data['disposition'], 'p_notes': data['notes']});
  Future<void> issueCertificate(String inspectionId) async => client.rpc('quality_issue_certificate', params: {'p_inspection_id': inspectionId});
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.data, this.onStart});
  final _QualityData data;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final summary = data.summary;
    return ListView(padding: const EdgeInsets.all(FactorySpacing.lg), children: [
      Wrap(spacing: FactorySpacing.md, runSpacing: FactorySpacing.md, children: [
        _Metric('Inspections today', '${summary['today_inspections'] ?? 0}', Icons.fact_check_outlined),
        _Metric('Passed', '${summary['today_passed'] ?? 0}', Icons.check_circle_outline),
        _Metric('Failed', '${summary['today_failed'] ?? 0}', Icons.cancel_outlined),
        _Metric('Hold', '${summary['today_hold'] ?? 0}', Icons.pause_circle_outline),
        _Metric('Open NCR', '${summary['open_ncr'] ?? 0}', Icons.report_problem_outlined),
        _Metric('Quarantine qty', _number(summary['quarantine_quantity']), Icons.inventory_outlined),
      ]),
      if (onStart != null) ...[const SizedBox(height: FactorySpacing.lg), Align(alignment: Alignment.centerLeft, child: FilledButton.icon(onPressed: onStart, icon: const Icon(Icons.add_task), label: const Text('Start inspection')))],
      const SizedBox(height: FactorySpacing.lg),
      Text('Recent inspections', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: FactorySpacing.sm),
      for (final row in data.inspections.take(10)) _InspectionTile(row: row),
    ]);
  }
}

class _Plans extends StatelessWidget {
  const _Plans({required this.data, required this.canEdit, required this.onAddPlan, required this.onEditPlan, required this.onAddCheck});
  final _QualityData data;
  final bool canEdit;
  final VoidCallback onAddPlan;
  final ValueChanged<Map<String, dynamic>> onEditPlan, onAddCheck;

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(FactorySpacing.lg), children: [
        Row(children: [Expanded(child: Text('Inspection plans & checklists', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))), if (canEdit) FilledButton.icon(onPressed: onAddPlan, icon: const Icon(Icons.add), label: const Text('New plan'))]),
        const SizedBox(height: FactorySpacing.md),
        for (final plan in data.plans)
          Card(child: ExpansionTile(
            leading: Icon(plan['is_active'] == true ? Icons.fact_check_outlined : Icons.pause_circle_outline),
            title: Text('${plan['code']} · ${plan['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${_title('${plan['inspection_type']}')} · ${plan['version']} · ${_nested(plan, 'inventory_items', 'name') ?? 'Item'}'),
            trailing: canEdit ? IconButton(onPressed: () => onEditPlan(plan), icon: const Icon(Icons.edit_outlined)) : null,
            children: [
              for (final check in data.checks.where((row) => row['plan_id'] == plan['id'])) ListTile(leading: CircleAvatar(child: Text('${check['sequence_no']}')), title: Text(check['parameter_name'] as String), subtitle: Text(_checkDescription(check))),
              if (canEdit) Padding(padding: const EdgeInsets.all(FactorySpacing.sm), child: OutlinedButton.icon(onPressed: () => onAddCheck(plan), icon: const Icon(Icons.playlist_add), label: const Text('Add parameter'))),
            ],
          )),
      ]);
}

class _Inspections extends StatelessWidget {
  const _Inspections({required this.data, required this.canOperate, required this.canApprove, required this.onStart, required this.onRecord, required this.onComplete, required this.onNcr, required this.onQuarantine, required this.onCertificate});
  final _QualityData data;
  final bool canOperate, canApprove;
  final VoidCallback onStart;
  final ValueChanged<Map<String, dynamic>> onRecord, onNcr, onQuarantine;
  final void Function(String id, {bool hold}) onComplete;
  final ValueChanged<String> onCertificate;

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(FactorySpacing.lg), children: [
        Row(children: [Expanded(child: Text('Inspection execution', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))), if (canOperate) FilledButton.icon(onPressed: onStart, icon: const Icon(Icons.add_task), label: const Text('Start inspection'))]),
        const SizedBox(height: FactorySpacing.md),
        for (final row in data.inspections)
          Card(child: ListTile(
            leading: _ResultIcon(result: '${row['overall_result']}'),
            title: Text('${row['inspection_no']} · ${_nested(row, 'inventory_items', 'name') ?? 'Item'}', style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${_title('${row['inspection_type']}')} · ${_title('${row['status']}')} · sample ${row['sample_size']}'),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'record') onRecord(row);
                if (value == 'complete') onComplete(row['id'] as String);
                if (value == 'hold') onComplete(row['id'] as String, hold: true);
                if (value == 'ncr') onNcr(row);
                if (value == 'quarantine') onQuarantine(row);
                if (value == 'certificate') onCertificate(row['id'] as String);
              },
              itemBuilder: (context) => [
                if (canOperate && row['status'] == 'in_progress') const PopupMenuItem(value: 'record', child: Text('Record result')),
                if (canOperate && row['status'] == 'in_progress') const PopupMenuItem(value: 'complete', child: Text('Complete')),
                if (canOperate && row['status'] == 'in_progress') const PopupMenuItem(value: 'hold', child: Text('Put on hold')),
                if (canOperate && row['status'] == 'completed' && const {'fail', 'hold'}.contains(row['overall_result'])) const PopupMenuItem(value: 'ncr', child: Text('Create NCR')),
                if (canOperate && row['status'] == 'completed' && const {'fail', 'hold'}.contains(row['overall_result'])) const PopupMenuItem(value: 'quarantine', child: Text('Quarantine stock')),
                if (canApprove && row['status'] == 'completed' && row['overall_result'] == 'pass' && !data.certificates.any((certificate) => certificate['inspection_id'] == row['id'])) const PopupMenuItem(value: 'certificate', child: Text('Issue certificate')),
              ],
            ),
          )),
      ]);
}

class _Ncrs extends StatelessWidget {
  const _Ncrs({required this.data, required this.canOperate, required this.canApprove, required this.onCreate, required this.onUpdate});
  final _QualityData data;
  final bool canOperate, canApprove;
  final VoidCallback onCreate;
  final ValueChanged<Map<String, dynamic>> onUpdate;

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(FactorySpacing.lg), children: [
        Row(children: [Expanded(child: Text('NCR / deviation', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))), if (canOperate) FilledButton.icon(onPressed: onCreate, icon: const Icon(Icons.add), label: const Text('Create NCR'))]),
        const SizedBox(height: FactorySpacing.md),
        for (final row in data.ncrs) Card(child: ListTile(leading: Icon(row['status'] == 'closed' ? Icons.task_alt : Icons.report_problem_outlined), title: Text('${row['ncr_no']} · ${row['category']}'), subtitle: Text('${_title('${row['severity']}')} · ${_title('${row['status']}')} · ${row['description']}'), trailing: canApprove ? IconButton(onPressed: () => onUpdate(row), icon: const Icon(Icons.edit_note_outlined)) : null)),
      ]);
}

class _Quarantine extends StatelessWidget {
  const _Quarantine({required this.data, required this.canOperate, required this.canApprove, required this.onCreate, required this.onRelease});
  final _QualityData data;
  final bool canOperate, canApprove;
  final VoidCallback onCreate;
  final ValueChanged<Map<String, dynamic>> onRelease;

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(FactorySpacing.lg), children: [
        Row(children: [Expanded(child: Text('Quarantine & release', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))), if (canOperate) FilledButton.icon(onPressed: onCreate, icon: const Icon(Icons.inventory_outlined), label: const Text('Quarantine'))]),
        const SizedBox(height: FactorySpacing.md),
        for (final row in data.quarantine) Card(child: ListTile(leading: Icon(row['status'] == 'quarantined' ? Icons.lock_outline : Icons.lock_open_outlined), title: Text('${_itemName(data, row['item_id'])} · ${_number(row['quantity'])}'), subtitle: Text('${_title('${row['status']}')} · ${row['lot_batch_no'] ?? 'No lot'} · ${_locationName(data, row['quarantine_location_id'])}'), trailing: canApprove && row['status'] == 'quarantined' ? FilledButton.tonal(onPressed: () => onRelease(row), child: const Text('Release')) : null)),
      ]);
}

class _Certificates extends StatelessWidget {
  const _Certificates({required this.data});
  final _QualityData data;
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(FactorySpacing.lg), children: [
        Text('Quality certificates', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: FactorySpacing.md),
        for (final row in data.certificates) Card(child: ListTile(leading: const Icon(Icons.workspace_premium_outlined), title: Text(row['certificate_no'] as String), subtitle: Text('${_nested(row, 'inventory_items', 'name') ?? _itemName(data, row['item_id'])} · ${row['lot_batch_no'] ?? 'No lot'}'))),
      ]);
}

class _Reports extends StatelessWidget {
  const _Reports({required this.data});
  final _QualityData data;
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(FactorySpacing.lg), children: [
        Text('Quality reports', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: FactorySpacing.md),
        Card(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
          columns: const [DataColumn(label: Text('Inspection')), DataColumn(label: Text('Item')), DataColumn(label: Text('Type')), DataColumn(label: Text('Result')), DataColumn(label: Text('Sample'))],
          rows: [for (final row in data.inspectionReport.take(100)) DataRow(cells: [DataCell(Text('${row['inspection_no']}')), DataCell(Text('${row['item_name']}')), DataCell(Text(_title('${row['inspection_type']}'))), DataCell(Text(_title('${row['overall_result']}'))), DataCell(Text('${row['sample_size']}'))])],
        ))),
        const SizedBox(height: FactorySpacing.lg),
        Text('NCR report', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        for (final row in data.ncrReport.take(50)) Card(child: ListTile(title: Text('${row['ncr_no']} · ${row['item_name']}'), subtitle: Text('${_title('${row['severity']}')} · ${_title('${row['status']}')} · ${_title('${row['disposition']}')}'))),
      ]);
}

class _PlanDialog extends StatefulWidget {
  const _PlanDialog({required this.items, this.initial});
  final List<Map<String, dynamic>> items;
  final Map<String, dynamic>? initial;
  @override
  State<_PlanDialog> createState() => _PlanDialogState();
}

class _PlanDialogState extends State<_PlanDialog> {
  late final name = TextEditingController(text: widget.initial?['name'] as String? ?? '');
  late final code = TextEditingController(text: widget.initial?['code'] as String? ?? '');
  late final version = TextEditingController(text: widget.initial?['version'] as String? ?? 'V1');
  late final sample = TextEditingController(text: '${widget.initial?['default_sample_size'] ?? 5}');
  late final notes = TextEditingController(text: widget.initial?['notes'] as String? ?? '');
  String? itemId;
  String type = 'final';
  String sampling = 'fixed';
  bool active = true;

  @override
  void initState() {
    super.initState();
    itemId = widget.initial?['item_id'] as String? ?? (widget.items.isEmpty ? null : widget.items.first['id'] as String);
    type = widget.initial?['inspection_type'] as String? ?? 'final';
    sampling = widget.initial?['sampling_method'] as String? ?? 'fixed';
    active = widget.initial?['is_active'] as bool? ?? true;
  }

  @override
  void dispose() { name.dispose(); code.dispose(); version.dispose(); sample.dispose(); notes.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.initial == null ? 'New inspection plan' : 'Edit inspection plan'),
        content: SizedBox(width: 560, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Plan name')),
          const SizedBox(height: FactorySpacing.sm),
          Row(children: [Expanded(child: TextField(controller: code, decoration: const InputDecoration(labelText: 'Code'))), const SizedBox(width: FactorySpacing.sm), Expanded(child: TextField(controller: version, decoration: const InputDecoration(labelText: 'Version')))]),
          const SizedBox(height: FactorySpacing.sm),
          DropdownButtonFormField<String>(initialValue: itemId, decoration: const InputDecoration(labelText: 'Product / item'), items: widget.items.map((item) => DropdownMenuItem(value: item['id'] as String, child: Text('${item['sku']} · ${item['name']}'))).toList(), onChanged: (value) => setState(() => itemId = value)),
          const SizedBox(height: FactorySpacing.sm),
          Row(children: [Expanded(child: DropdownButtonFormField<String>(initialValue: type, decoration: const InputDecoration(labelText: 'Inspection type'), items: const [DropdownMenuItem(value: 'incoming', child: Text('Incoming')), DropdownMenuItem(value: 'in_process', child: Text('In-process')), DropdownMenuItem(value: 'final', child: Text('Final'))], onChanged: (value) => setState(() => type = value ?? type))), const SizedBox(width: FactorySpacing.sm), Expanded(child: DropdownButtonFormField<String>(initialValue: sampling, decoration: const InputDecoration(labelText: 'Sampling'), items: const [DropdownMenuItem(value: 'full', child: Text('Full')), DropdownMenuItem(value: 'fixed', child: Text('Fixed')), DropdownMenuItem(value: 'percentage', child: Text('Percentage')), DropdownMenuItem(value: 'aql', child: Text('AQL'))], onChanged: (value) => setState(() => sampling = value ?? sampling)))]),
          const SizedBox(height: FactorySpacing.sm),
          TextField(controller: sample, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Default sample size')),
          const SizedBox(height: FactorySpacing.sm),
          TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes')),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Active'), value: active, onChanged: (value) => setState(() => active = value)),
        ]))),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: itemId == null ? null : () { final size = int.tryParse(sample.text.trim()); if (size == null || size <= 0 || name.text.trim().length < 2 || code.text.trim().length < 2) return; Navigator.pop(context, {'item_id': itemId, 'name': name.text.trim(), 'code': code.text.trim().toUpperCase(), 'version': version.text.trim(), 'inspection_type': type, 'sampling_method': sampling, 'default_sample_size': size, 'notes': _blank(notes.text), 'is_active': active}); }, child: const Text('Save'))],
      );
}

class _CheckDialog extends StatefulWidget {
  const _CheckDialog();
  @override
  State<_CheckDialog> createState() => _CheckDialogState();
}

class _CheckDialogState extends State<_CheckDialog> {
  final sequence = TextEditingController(text: '1');
  final parameter = TextEditingController();
  final min = TextEditingController();
  final max = TextEditingController();
  final unit = TextEditingController();
  final acceptance = TextEditingController();
  String type = 'visual';
  bool expected = true;
  bool required = true;
  @override
  void dispose() { sequence.dispose(); parameter.dispose(); min.dispose(); max.dispose(); unit.dispose(); acceptance.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Add checklist parameter'),
        content: SizedBox(width: 520, child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [Expanded(child: TextField(controller: sequence, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Sequence'))), const SizedBox(width: FactorySpacing.sm), Expanded(child: DropdownButtonFormField<String>(initialValue: type, decoration: const InputDecoration(labelText: 'Type'), items: const [DropdownMenuItem(value: 'visual', child: Text('Visual')), DropdownMenuItem(value: 'numeric', child: Text('Numeric')), DropdownMenuItem(value: 'boolean', child: Text('Yes / No')), DropdownMenuItem(value: 'text', child: Text('Text'))], onChanged: (value) => setState(() => type = value ?? type)))]),
          const SizedBox(height: FactorySpacing.sm),
          TextField(controller: parameter, decoration: const InputDecoration(labelText: 'Parameter')),
          if (type == 'numeric') ...[const SizedBox(height: FactorySpacing.sm), Row(children: [Expanded(child: TextField(controller: min, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Min'))), const SizedBox(width: FactorySpacing.sm), Expanded(child: TextField(controller: max, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Max'))), const SizedBox(width: FactorySpacing.sm), Expanded(child: TextField(controller: unit, decoration: const InputDecoration(labelText: 'Unit')))])],
          if (type == 'boolean') SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Expected result is Yes'), value: expected, onChanged: (value) => setState(() => expected = value)),
          const SizedBox(height: FactorySpacing.sm),
          TextField(controller: acceptance, decoration: const InputDecoration(labelText: 'Acceptance criteria')),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Required'), value: required, onChanged: (value) => setState(() => required = value)),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () { final seq = int.tryParse(sequence.text.trim()); if (seq == null || seq <= 0 || parameter.text.trim().length < 2) return; Navigator.pop(context, {'sequence_no': seq, 'parameter_name': parameter.text.trim(), 'check_type': type, 'min_numeric': double.tryParse(min.text.trim()), 'max_numeric': double.tryParse(max.text.trim()), 'unit_text': _blank(unit.text), 'expected_boolean': type == 'boolean' ? expected : null, 'acceptance_text': _blank(acceptance.text), 'is_required': required}); }, child: const Text('Add'))],
      );
}

class _StartInspectionDialog extends StatefulWidget {
  const _StartInspectionDialog({required this.plans, required this.factories, required this.batches, required this.employees});
  final List<Map<String, dynamic>> plans, factories, batches, employees;
  @override
  State<_StartInspectionDialog> createState() => _StartInspectionDialogState();
}

class _StartInspectionDialogState extends State<_StartInspectionDialog> {
  String? planId, factoryId, batchId, employeeId;
  final lot = TextEditingController();
  final sample = TextEditingController(text: '5');
  final notes = TextEditingController();
  @override
  void initState() { super.initState(); planId = widget.plans.first['id'] as String; factoryId = widget.factories.isEmpty ? null : widget.factories.first['id'] as String; sample.text = '${widget.plans.first['default_sample_size'] ?? 5}'; }
  Map<String, dynamic> get plan => widget.plans.firstWhere((row) => row['id'] == planId);
  @override
  void dispose() { lot.dispose(); sample.dispose(); notes.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final type = plan['inspection_type'] as String;
    final batches = widget.batches.where((row) => row['factory_id'] == factoryId && row['status'] != 'cancelled').toList();
    final employees = widget.employees.where((row) => row['primary_factory_id'] == factoryId).toList();
    return AlertDialog(
      title: const Text('Start inspection'),
      content: SizedBox(width: 560, child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(key: ValueKey('factory-$factoryId'), initialValue: factoryId, decoration: const InputDecoration(labelText: 'Factory'), items: widget.factories.map((row) => DropdownMenuItem(value: row['id'] as String, child: Text(row['name'] as String))).toList(), onChanged: (value) => setState(() { factoryId = value; batchId = null; employeeId = null; })),
        const SizedBox(height: FactorySpacing.sm),
        DropdownButtonFormField<String>(key: ValueKey('plan-$planId'), initialValue: planId, decoration: const InputDecoration(labelText: 'Plan'), items: widget.plans.map((row) => DropdownMenuItem(value: row['id'] as String, child: Text('${row['code']} · ${row['name']}'))).toList(), onChanged: (value) => setState(() { planId = value; batchId = null; sample.text = '${plan['default_sample_size'] ?? 5}'; })),
        if (type != 'incoming') ...[const SizedBox(height: FactorySpacing.sm), DropdownButtonFormField<String>(key: ValueKey('batch-$factoryId-$batchId'), initialValue: batchId, decoration: const InputDecoration(labelText: 'Production batch (optional)'), items: batches.map((row) => DropdownMenuItem(value: row['id'] as String, child: Text('${row['batch_no']} · ${_nested(row, 'production_orders', 'order_no') ?? ''}'))).toList(), onChanged: (value) => setState(() => batchId = value))],
        const SizedBox(height: FactorySpacing.sm),
        DropdownButtonFormField<String>(key: ValueKey('employee-$factoryId-$employeeId'), initialValue: employeeId, decoration: const InputDecoration(labelText: 'Inspector (optional)'), items: employees.map((row) => DropdownMenuItem(value: row['id'] as String, child: Text('${row['employee_code']} · ${row['full_name']}'))).toList(), onChanged: (value) => setState(() => employeeId = value)),
        const SizedBox(height: FactorySpacing.sm),
        Row(children: [Expanded(child: TextField(controller: lot, decoration: const InputDecoration(labelText: 'Lot / batch'))), const SizedBox(width: FactorySpacing.sm), Expanded(child: TextField(controller: sample, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Sample size')))]),
        const SizedBox(height: FactorySpacing.sm),
        TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notes')),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: factoryId == null ? null : () { final size = int.tryParse(sample.text.trim()); if (size == null || size <= 0) return; Navigator.pop(context, {'factory_id': factoryId, 'plan_id': planId, 'item_id': plan['item_id'], 'production_batch_id': type == 'incoming' ? null : batchId, 'lot_batch_no': _blank(lot.text), 'sample_size': size, 'inspector_employee_id': employeeId, 'notes': _blank(notes.text)}); }, child: const Text('Start'))],
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
  bool observed = true;
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
      title: const Text('Record checklist result'),
      content: SizedBox(width: 520, child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(key: ValueKey('check-$checkId'), initialValue: checkId, decoration: const InputDecoration(labelText: 'Parameter'), items: widget.checks.map((row) => DropdownMenuItem(value: row['id'] as String, child: Text('${row['sequence_no']}. ${row['parameter_name']}'))).toList(), onChanged: (value) => setState(() => checkId = value)),
        const SizedBox(height: FactorySpacing.sm),
        if (type == 'numeric') TextField(controller: numeric, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Measured value${check['unit_text'] == null ? '' : ' (${check['unit_text']})'}', helperText: _checkDescription(check)))
        else if (type == 'boolean') SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Observed result is Yes'), value: observed, onChanged: (value) => setState(() => observed = value))
        else ...[DropdownButtonFormField<String>(initialValue: result, decoration: const InputDecoration(labelText: 'Result'), items: const [DropdownMenuItem(value: 'pass', child: Text('Pass')), DropdownMenuItem(value: 'fail', child: Text('Fail')), DropdownMenuItem(value: 'not_applicable', child: Text('Not applicable'))], onChanged: (value) => setState(() => result = value ?? result)), const SizedBox(height: FactorySpacing.sm), TextField(controller: text, decoration: const InputDecoration(labelText: 'Observed value / note'))],
        const SizedBox(height: FactorySpacing.sm),
        TextField(controller: remarks, decoration: const InputDecoration(labelText: 'Remarks')),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () { final measured = double.tryParse(numeric.text.trim()); if (type == 'numeric' && measured == null) return; Navigator.pop(context, {'plan_check_id': checkId, 'result_status': type == 'numeric' || type == 'boolean' ? null : result, 'numeric_value': type == 'numeric' ? measured : null, 'boolean_value': type == 'boolean' ? observed : null, 'text_value': type == 'visual' || type == 'text' ? _blank(text.text) : null, 'remarks': _blank(remarks.text)}); }, child: const Text('Save'))],
    );
  }
}

class _NcrDialog extends StatefulWidget {
  const _NcrDialog({required this.inspections, required this.employees, this.selectedInspectionId});
  final List<Map<String, dynamic>> inspections, employees;
  final String? selectedInspectionId;
  @override
  State<_NcrDialog> createState() => _NcrDialogState();
}

class _NcrDialogState extends State<_NcrDialog> {
  String? inspectionId, employeeId;
  String severity = 'medium';
  final category = TextEditingController();
  final description = TextEditingController();
  @override
  void initState() { super.initState(); inspectionId = widget.selectedInspectionId ?? widget.inspections.first['id'] as String; }
  @override
  void dispose() { category.dispose(); description.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final inspection = widget.inspections.firstWhere((row) => row['id'] == inspectionId);
    final employees = widget.employees.where((row) => row['primary_factory_id'] == inspection['factory_id']).toList();
    return AlertDialog(
      title: const Text('Create NCR / deviation'),
      content: SizedBox(width: 540, child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(key: ValueKey('ncr-inspection-$inspectionId'), initialValue: inspectionId, decoration: const InputDecoration(labelText: 'Inspection'), items: widget.inspections.map((row) => DropdownMenuItem(value: row['id'] as String, child: Text('${row['inspection_no']} · ${_nested(row, 'inventory_items', 'name') ?? 'Item'}'))).toList(), onChanged: (value) => setState(() { inspectionId = value; employeeId = null; })),
        const SizedBox(height: FactorySpacing.sm),
        DropdownButtonFormField<String>(initialValue: severity, decoration: const InputDecoration(labelText: 'Severity'), items: const [DropdownMenuItem(value: 'low', child: Text('Low')), DropdownMenuItem(value: 'medium', child: Text('Medium')), DropdownMenuItem(value: 'high', child: Text('High')), DropdownMenuItem(value: 'critical', child: Text('Critical'))], onChanged: (value) => setState(() => severity = value ?? severity)),
        const SizedBox(height: FactorySpacing.sm),
        TextField(controller: category, decoration: const InputDecoration(labelText: 'Category')),
        const SizedBox(height: FactorySpacing.sm),
        TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
        const SizedBox(height: FactorySpacing.sm),
        DropdownButtonFormField<String>(key: ValueKey('ncr-employee-$inspectionId-$employeeId'), initialValue: employeeId, decoration: const InputDecoration(labelText: 'Assign employee (optional)'), items: employees.map((row) => DropdownMenuItem(value: row['id'] as String, child: Text('${row['employee_code']} · ${row['full_name']}'))).toList(), onChanged: (value) => setState(() => employeeId = value)),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () { if (category.text.trim().length < 2 || description.text.trim().length < 4) return; Navigator.pop(context, {'inspection_id': inspectionId, 'severity': severity, 'category': category.text.trim(), 'description': description.text.trim(), 'assigned_employee_id': employeeId}); }, child: const Text('Create'))],
    );
  }
}

class _NcrUpdateDialog extends StatefulWidget {
  const _NcrUpdateDialog({required this.initial});
  final Map<String, dynamic> initial;
  @override
  State<_NcrUpdateDialog> createState() => _NcrUpdateDialogState();
}

class _NcrUpdateDialogState extends State<_NcrUpdateDialog> {
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
          DropdownButtonFormField<String>(initialValue: status, decoration: const InputDecoration(labelText: 'Status'), items: const [DropdownMenuItem(value: 'open', child: Text('Open')), DropdownMenuItem(value: 'investigating', child: Text('Investigating')), DropdownMenuItem(value: 'action_pending', child: Text('Action pending')), DropdownMenuItem(value: 'closed', child: Text('Closed'))], onChanged: (value) => setState(() => status = value ?? status)),
          const SizedBox(height: FactorySpacing.sm),
          DropdownButtonFormField<String>(initialValue: disposition, decoration: const InputDecoration(labelText: 'Disposition'), items: const [DropdownMenuItem(value: 'pending', child: Text('Pending')), DropdownMenuItem(value: 'rework', child: Text('Rework')), DropdownMenuItem(value: 'scrap', child: Text('Scrap')), DropdownMenuItem(value: 'use_as_is', child: Text('Use as-is')), DropdownMenuItem(value: 'return', child: Text('Return')), DropdownMenuItem(value: 'sort', child: Text('Sort')), DropdownMenuItem(value: 'other', child: Text('Other'))], onChanged: (value) => setState(() => disposition = value ?? disposition)),
          const SizedBox(height: FactorySpacing.sm),
          TextField(controller: rootCause, decoration: const InputDecoration(labelText: 'Root cause')),
          const SizedBox(height: FactorySpacing.sm),
          TextField(controller: corrective, decoration: const InputDecoration(labelText: 'Corrective action')),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, {'status': status, 'disposition': disposition, 'root_cause': _blank(rootCause.text), 'corrective_action': _blank(corrective.text)}), child: const Text('Save'))],
      );
}

class _QuarantineDialog extends StatefulWidget {
  const _QuarantineDialog({required this.inspections, required this.locations, this.selectedInspectionId});
  final List<Map<String, dynamic>> inspections, locations;
  final String? selectedInspectionId;
  @override
  State<_QuarantineDialog> createState() => _QuarantineDialogState();
}

class _QuarantineDialogState extends State<_QuarantineDialog> {
  String? inspectionId, sourceId, quarantineId;
  final quantity = TextEditingController(text: '1');
  final lot = TextEditingController();
  final notes = TextEditingController();
  @override
  void initState() { super.initState(); inspectionId = widget.selectedInspectionId ?? widget.inspections.first['id'] as String; }
  @override
  void dispose() { quantity.dispose(); lot.dispose(); notes.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final inspection = widget.inspections.firstWhere((row) => row['id'] == inspectionId);
    final locations = widget.locations.where((row) => row['factory_id'] == inspection['factory_id']).toList();
    final quarantineLocations = locations.where((row) => row['location_type'] == 'quarantine').toList();
    return AlertDialog(
      title: const Text('Quarantine stock'),
      content: SizedBox(width: 560, child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(key: ValueKey('q-inspection-$inspectionId'), initialValue: inspectionId, decoration: const InputDecoration(labelText: 'Inspection'), items: widget.inspections.map((row) => DropdownMenuItem(value: row['id'] as String, child: Text('${row['inspection_no']} · ${_nested(row, 'inventory_items', 'name') ?? 'Item'}'))).toList(), onChanged: (value) => setState(() { inspectionId = value; sourceId = null; quarantineId = null; })),
        const SizedBox(height: FactorySpacing.sm),
        Row(children: [Expanded(child: DropdownButtonFormField<String>(key: ValueKey('source-$inspectionId-$sourceId'), initialValue: sourceId, decoration: const InputDecoration(labelText: 'Source'), items: locations.map((row) => DropdownMenuItem(value: row['id'] as String, child: Text('${row['code']} · ${row['name']}'))).toList(), onChanged: (value) => setState(() => sourceId = value))), const SizedBox(width: FactorySpacing.sm), Expanded(child: DropdownButtonFormField<String>(key: ValueKey('hold-$inspectionId-$quarantineId'), initialValue: quarantineId, decoration: const InputDecoration(labelText: 'Quarantine'), items: quarantineLocations.map((row) => DropdownMenuItem(value: row['id'] as String, child: Text('${row['code']} · ${row['name']}'))).toList(), onChanged: (value) => setState(() => quarantineId = value)))]),
        const SizedBox(height: FactorySpacing.sm),
        Row(children: [Expanded(child: TextField(controller: quantity, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Quantity'))), const SizedBox(width: FactorySpacing.sm), Expanded(child: TextField(controller: lot, decoration: InputDecoration(labelText: 'Lot / batch', hintText: inspection['lot_batch_no'] as String?)))]),
        const SizedBox(height: FactorySpacing.sm),
        TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notes')),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: sourceId == null || quarantineId == null ? null : () { final amount = double.tryParse(quantity.text.trim()); if (amount == null || amount <= 0) return; Navigator.pop(context, {'inspection_id': inspectionId, 'from_location_id': sourceId, 'quarantine_location_id': quarantineId, 'quantity': amount, 'lot_batch_no': _blank(lot.text) ?? inspection['lot_batch_no'], 'notes': _blank(notes.text)}); }, child: const Text('Quarantine'))],
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
  final notes = TextEditingController();
  @override
  void initState() { super.initState(); locationId = widget.locations.isEmpty ? null : widget.locations.first['id'] as String; }
  @override
  void dispose() { notes.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Release quarantine'),
        content: SizedBox(width: 500, child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(initialValue: locationId, decoration: const InputDecoration(labelText: 'Destination'), items: widget.locations.map((row) => DropdownMenuItem(value: row['id'] as String, child: Text('${row['code']} · ${row['name']}'))).toList(), onChanged: (value) => setState(() => locationId = value)),
          const SizedBox(height: FactorySpacing.sm),
          DropdownButtonFormField<String>(initialValue: disposition, decoration: const InputDecoration(labelText: 'Disposition'), items: const [DropdownMenuItem(value: 'release', child: Text('Release')), DropdownMenuItem(value: 'rework', child: Text('Rework')), DropdownMenuItem(value: 'use_as_is', child: Text('Use as-is'))], onChanged: (value) => setState(() => disposition = value ?? disposition)),
          const SizedBox(height: FactorySpacing.sm),
          TextField(controller: notes, decoration: const InputDecoration(labelText: 'Release notes')),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: locationId == null ? null : () => Navigator.pop(context, {'to_location_id': locationId, 'disposition': disposition, 'notes': _blank(notes.text)}), child: const Text('Release'))],
      );
}

class _InspectionTile extends StatelessWidget {
  const _InspectionTile({required this.row});
  final Map<String, dynamic> row;
  @override
  Widget build(BuildContext context) => Card(child: ListTile(leading: _ResultIcon(result: '${row['overall_result']}'), title: Text('${row['inspection_no']} · ${_nested(row, 'inventory_items', 'name') ?? 'Item'}'), subtitle: Text('${_title('${row['inspection_type']}')} · ${_title('${row['overall_result']}')}')));
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

List<Map<String, dynamic>> _rows(dynamic value) => (value as List<dynamic>).map((row) => Map<String, dynamic>.from(row as Map)).toList();
String? _nested(Map<String, dynamic> row, String key, String field) { final value = row[key]; return value is Map && value[field] != null ? '${value[field]}' : null; }
String _title(String value) => value.replaceAll('_', ' ').split(' ').where((part) => part.isNotEmpty).map((part) => '${part[0].toUpperCase()}${part.substring(1)}').join(' ');
String _number(dynamic value) { final number = value is num ? value : num.tryParse('$value') ?? 0; return number % 1 == 0 ? number.toInt().toString() : number.toStringAsFixed(2); }
String? _blank(String value) => value.trim().isEmpty ? null : value.trim();
String _checkDescription(Map<String, dynamic> check) {
  if (check['check_type'] == 'numeric') return '${check['min_numeric'] ?? '—'} to ${check['max_numeric'] ?? '—'} ${check['unit_text'] ?? ''}'.trim();
  if (check['check_type'] == 'boolean') return 'Expected: ${check['expected_boolean'] == true ? 'Yes' : 'No'}';
  return '${check['acceptance_text'] ?? _title('${check['check_type']}')}';
}
String _itemName(_QualityData data, dynamic id) { for (final row in data.items) { if (row['id'] == id) return row['name'] as String; } return 'Item'; }
String _locationName(_QualityData data, dynamic id) { for (final row in data.locations) { if (row['id'] == id) return row['name'] as String; } return 'Location'; }
