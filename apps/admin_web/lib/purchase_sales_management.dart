import 'package:factoryos_core/factoryos_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PurchaseSalesManagementPage extends StatefulWidget {
  const PurchaseSalesManagementPage({required this.organizationId, required this.actorRole, required this.factories, super.key});
  final String organizationId;
  final AppRole actorRole;
  final List<Map<String, dynamic>> factories;

  @override
  State<PurchaseSalesManagementPage> createState() => _PurchaseSalesManagementPageState();
}

class _PurchaseSalesManagementPageState extends State<PurchaseSalesManagementPage> {
  int section = 0;
  late Future<CommercialSnapshot> future;
  CommercialRepository get repository => CommercialRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    future = repository.load(widget.organizationId);
  }

  void reload() => setState(() => future = repository.load(widget.organizationId));
  void message(String value, {bool error = false}) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value), backgroundColor: error ? Theme.of(context).colorScheme.error : null));

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

  Future<void> editPartner(CommercialSnapshot data, [Map<String, dynamic>? initial]) async {
    final draft = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => PartnerEditor(initial: initial));
    if (draft == null) return;
    await run(() => repository.savePartner(widget.organizationId, draft, id: initial?['id'] as String?), initial == null ? 'Business partner created.' : 'Business partner updated.');
  }

  Future<void> createRequisition(CommercialSnapshot data) async {
    final draft = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => RequisitionEditor(factories: widget.factories, items: data.items));
    if (draft == null) return;
    await run(() async { await repository.createRequisition(draft); }, 'Purchase requisition submitted.');
  }

  Future<void> decideRequisition(Map<String, dynamic> row, String status) async {
    await run(() => repository.decideRequisition(row['id'] as String, status), 'Requisition ${_title(status)}.');
  }

  Future<void> createPurchaseOrder(CommercialSnapshot data) async {
    final suppliers = data.partners.where((p) => p['is_active'] == true && const {'supplier', 'both'}.contains(p['partner_type'])).toList();
    if (suppliers.isEmpty) return message('Create an active supplier first.', error: true);
    final draft = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => PurchaseOrderEditor(factories: widget.factories, suppliers: suppliers, requisitions: data.requisitions.where((r) => r['status'] == 'approved').toList(), items: data.items));
    if (draft == null) return;
    await run(() async { await repository.createPurchaseOrder(draft); }, 'Purchase order approved.');
  }

  Future<void> receiveGoods(CommercialSnapshot data, Map<String, dynamic> po) async {
    final lines = _nestedRows(po, 'purchase_order_lines').where((l) => (l['received_quantity'] as num) < (l['ordered_quantity'] as num)).toList();
    if (lines.isEmpty) return message('This purchase order has no quantity left to receive.', error: true);
    final locations = data.locations.where((l) => l['factory_id'] == po['factory_id']).toList();
    final draft = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => GoodsReceiptEditor(po: po, lines: lines, locations: locations));
    if (draft == null) return;
    await run(() async { await repository.receiveGoods(po['id'] as String, draft); }, 'Goods receipt posted and Inventory updated.');
  }

  Future<void> releaseReceipt(CommercialSnapshot data, Map<String, dynamic> grn) async {
    final locations = data.locations.where((l) => l['factory_id'] == grn['factory_id'] && l['id'] != grn['received_location_id']).toList();
    final destination = await showDialog<String>(context: context, builder: (_) => LocationPickerDialog(title: 'Release goods receipt', locations: locations));
    if (destination == null) return;
    await run(() => repository.releaseReceipt(grn['id'] as String, destination), 'Goods released to available Inventory.');
  }

  Future<void> createSupplierInvoice(Map<String, dynamic> po) async {
    final draft = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => InvoiceEditor(title: 'Supplier invoice', numberLabel: 'Supplier invoice no.'));
    if (draft == null) return;
    await run(() async { await repository.createSupplierInvoice(po['id'] as String, draft); }, 'Supplier invoice posted.');
  }

  Future<void> supplierPayment(Map<String, dynamic> invoice) async {
    final draft = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => PaymentEditor(maxAmount: _due(invoice, 'supplier_payments')));
    if (draft == null) return;
    await run(() async { await repository.supplierPayment(invoice['id'] as String, draft); }, 'Supplier payment recorded.');
  }

  Future<void> createQuotation(CommercialSnapshot data) async {
    final customers = data.partners.where((p) => p['is_active'] == true && const {'customer', 'both'}.contains(p['partner_type'])).toList();
    if (customers.isEmpty) return message('Create an active customer first.', error: true);
    final draft = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => QuotationEditor(factories: widget.factories, customers: customers, items: data.items));
    if (draft == null) return;
    await run(() async { await repository.createQuotation(draft); }, 'Quotation created.');
  }

  Future<void> quotationAction(Map<String, dynamic> quote, String status) async {
    await run(() => repository.setQuotationStatus(quote['id'] as String, status), 'Quotation ${_title(status)}.');
  }

  Future<void> convertQuote(Map<String, dynamic> quote) async {
    final date = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)), initialDate: DateTime.now().add(const Duration(days: 2)));
    if (date == null) return;
    await run(() async { await repository.convertQuote(quote['id'] as String, _date(date)); }, 'Sales order created.');
  }

  Future<void> allocate(CommercialSnapshot data, Map<String, dynamic> order) async {
    final locations = data.locations.where((l) => l['factory_id'] == order['factory_id'] && const {'warehouse', 'dispatch'}.contains(l['location_type'])).toList();
    final location = await showDialog<String>(context: context, builder: (_) => LocationPickerDialog(title: 'Allocate stock', locations: locations));
    if (location == null) return;
    await run(() => repository.allocate(order['id'] as String, location), 'Sales order stock allocated.');
  }

  Future<void> markReady(Map<String, dynamic> order) async {
    await run(() => repository.markDispatchReady(order['id'] as String), 'Sales order marked dispatch ready.');
  }

  Future<void> createCustomerInvoice(Map<String, dynamic> order) async {
    final draft = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => const InvoiceEditor(title: 'Customer invoice', numberLabel: 'Invoice number generated automatically', autoNumber: true));
    if (draft == null) return;
    await run(() async { await repository.createCustomerInvoice(order['id'] as String, draft); }, 'Customer invoice posted.');
  }

  Future<void> customerPayment(Map<String, dynamic> invoice) async {
    final draft = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => PaymentEditor(maxAmount: _due(invoice, 'customer_payments')));
    if (draft == null) return;
    await run(() async { await repository.customerPayment(invoice['id'] as String, draft); }, 'Customer payment recorded.');
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<CommercialSnapshot>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return _ErrorPanel(message: '${snapshot.error}', onRetry: reload);
          final data = snapshot.requireData;
          final canManage = const {AppRole.platformOwner, AppRole.orgAdmin, AppRole.factoryManager}.contains(widget.actorRole);
          final tabs = <_CommercialSection>[
            _CommercialSection('Dashboard', Icons.insights_outlined, CommercialDashboard(data: data)),
            _CommercialSection('Partners', Icons.handshake_outlined, PartnersSection(data: data, canManage: canManage, onAdd: () => editPartner(data), onEdit: (row) => editPartner(data, row))),
            _CommercialSection('Purchase', Icons.shopping_cart_checkout_outlined, PurchaseSection(data: data, canManage: canManage, onRequisition: () => createRequisition(data), onDecision: decideRequisition, onPurchaseOrder: () => createPurchaseOrder(data), onReceive: (row) => receiveGoods(data, row))),
            _CommercialSection('Goods receipt', Icons.inventory_outlined, GoodsReceiptSection(data: data, onRelease: (row) => releaseReceipt(data, row))),
            _CommercialSection('Supplier billing', Icons.receipt_long_outlined, SupplierBillingSection(data: data, canManage: canManage, onInvoice: createSupplierInvoice, onPayment: supplierPayment)),
            _CommercialSection('Sales', Icons.request_quote_outlined, SalesSection(data: data, canManage: canManage, onQuotation: () => createQuotation(data), onQuoteAction: quotationAction, onConvert: convertQuote)),
            _CommercialSection('Allocation', Icons.fact_check_outlined, AllocationSection(data: data, onAllocate: (row) => allocate(data, row), onReady: markReady)),
            _CommercialSection('Customer billing', Icons.payments_outlined, CustomerBillingSection(data: data, canManage: canManage, onInvoice: createCustomerInvoice, onPayment: customerPayment)),
            _CommercialSection('Reports', Icons.analytics_outlined, CommercialReports(data: data)),
          ];
          if (section >= tabs.length) section = 0;
          return Column(children: [
            Padding(padding: const EdgeInsets.fromLTRB(FactorySpacing.lg, FactorySpacing.lg, FactorySpacing.lg, 0), child: Row(children: [
              const Icon(Icons.sync_alt, color: FactoryColors.blue),
              const SizedBox(width: FactorySpacing.sm),
              Expanded(child: Text('Purchase & Sales', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900))),
              IconButton(tooltip: 'Refresh', onPressed: reload, icon: const Icon(Icons.refresh)),
            ])),
            SizedBox(height: 58, child: ListView.separated(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: FactorySpacing.lg, vertical: FactorySpacing.sm), itemCount: tabs.length, separatorBuilder: (_, _) => const SizedBox(width: FactorySpacing.xs), itemBuilder: (_, i) => ChoiceChip(selected: section == i, avatar: Icon(tabs[i].icon, size: 18), label: Text(tabs[i].label), onSelected: (_) => setState(() => section = i)))),
            Expanded(child: tabs[section].page),
          ]);
        },
      );
}

class CommercialSnapshot {
  const CommercialSnapshot({required this.summary, required this.partners, required this.items, required this.requisitions, required this.purchaseOrders, required this.goodsReceipts, required this.supplierInvoices, required this.quotations, required this.salesOrders, required this.customerInvoices, required this.locations, required this.purchaseReport, required this.salesReport});
  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> partners, items, requisitions, purchaseOrders, goodsReceipts, supplierInvoices, quotations, salesOrders, customerInvoices, locations, purchaseReport, salesReport;
}

class CommercialRepository {
  CommercialRepository(this.client);
  final SupabaseClient client;

  Future<CommercialSnapshot> load(String orgId) async {
    final values = await Future.wait<dynamic>([
      client.rpc('commercial_dashboard_summary', params: {'p_organization_id': orgId}),
      client.from('business_partners').select('id,partner_code,name,partner_type,tax_id,contact_person,email,phone,city,state,country_code,credit_days,is_active').eq('organization_id', orgId).order('name'),
      client.from('inventory_items').select('id,name,sku,item_type,inventory_units(code)').eq('organization_id', orgId).eq('is_active', true).order('name'),
      client.from('purchase_requisitions').select('id,factory_id,requisition_no,request_date,required_date,purpose,status,decision_note,purchase_requisition_lines(id,item_id,quantity,estimated_unit_cost,inventory_items(name,sku))').eq('organization_id', orgId).order('created_at', ascending: false).limit(200),
      client.from('purchase_orders').select('id,factory_id,purchase_order_no,supplier_id,requisition_id,order_date,expected_date,currency_code,status,notes,business_partners(name,partner_code),purchase_order_lines(id,item_id,ordered_quantity,received_quantity,unit_price,tax_rate,inventory_items(name,sku))').eq('organization_id', orgId).order('created_at', ascending: false).limit(200),
      client.from('goods_receipts').select('id,factory_id,goods_receipt_no,purchase_order_id,received_location_id,released_location_id,received_at,released_at,status,notes,purchase_orders(purchase_order_no,business_partners(name)),goods_receipt_lines(id,item_id,quantity_received,lot_batch_no,quality_required,inventory_items(name,sku),quality_inspections(inspection_no,status,overall_result))').eq('organization_id', orgId).order('received_at', ascending: false).limit(200),
      client.from('supplier_invoices').select('id,factory_id,invoice_no,supplier_id,purchase_order_id,invoice_date,due_date,subtotal,tax_amount,total_amount,status,business_partners(name),purchase_orders(purchase_order_no),supplier_payments(id,amount,payment_no,paid_at)').eq('organization_id', orgId).order('invoice_date', ascending: false).limit(200),
      client.from('quotations').select('id,factory_id,quotation_no,customer_id,quotation_date,valid_until,currency_code,status,notes,business_partners(name,partner_code),quotation_lines(id,item_id,quantity,unit_price,tax_rate,inventory_items(name,sku))').eq('organization_id', orgId).order('quotation_date', ascending: false).limit(200),
      client.from('sales_orders').select('id,factory_id,sales_order_no,customer_id,quotation_id,order_date,requested_delivery_date,currency_code,status,dispatch_ready_at,notes,business_partners(name,partner_code),sales_order_lines(id,item_id,ordered_quantity,allocated_quantity,unit_price,tax_rate,inventory_items(name,sku)),sales_allocations(id,item_id,location_id,quantity,status)').eq('organization_id', orgId).order('order_date', ascending: false).limit(200),
      client.from('customer_invoices').select('id,factory_id,invoice_no,customer_id,sales_order_id,invoice_date,due_date,subtotal,tax_amount,total_amount,status,business_partners(name),sales_orders(sales_order_no),customer_payments(id,amount,payment_no,paid_at)').eq('organization_id', orgId).order('invoice_date', ascending: false).limit(200),
      client.from('stock_locations').select('id,factory_id,name,code,location_type,is_active').eq('organization_id', orgId).eq('is_active', true).order('name'),
      client.rpc('purchase_order_report', params: {'p_organization_id': orgId, 'p_limit': 200}),
      client.rpc('sales_order_report', params: {'p_organization_id': orgId, 'p_limit': 200}),
    ]);
    return CommercialSnapshot(
      summary: Map<String, dynamic>.from(values[0] as Map),
      partners: _rows(values[1]), items: _rows(values[2]), requisitions: _rows(values[3]), purchaseOrders: _rows(values[4]), goodsReceipts: _rows(values[5]), supplierInvoices: _rows(values[6]), quotations: _rows(values[7]), salesOrders: _rows(values[8]), customerInvoices: _rows(values[9]), locations: _rows(values[10]), purchaseReport: _rows(values[11]), salesReport: _rows(values[12]),
    );
  }

  Future<void> savePartner(String orgId, Map<String, dynamic> draft, {String? id}) async => id == null ? client.from('business_partners').insert({'organization_id': orgId, ...draft}) : client.from('business_partners').update(draft).eq('id', id);
  Future<String> createRequisition(Map<String, dynamic> d) async => (await client.rpc('commercial_create_requisition', params: {'p_factory_id': d['factory_id'], 'p_required_date': d['required_date'], 'p_purpose': d['purpose'], 'p_lines': d['lines']})) as String;
  Future<void> decideRequisition(String id, String status) async => client.rpc('commercial_decide_requisition', params: {'p_requisition_id': id, 'p_status': status});
  Future<String> createPurchaseOrder(Map<String, dynamic> d) async => (await client.rpc('commercial_create_purchase_order', params: {'p_factory_id': d['factory_id'], 'p_supplier_id': d['supplier_id'], 'p_requisition_id': d['requisition_id'], 'p_expected_date': d['expected_date'], 'p_currency_code': 'INR', 'p_notes': d['notes'], 'p_lines': d['lines']})) as String;
  Future<String> receiveGoods(String poId, Map<String, dynamic> d) async => (await client.rpc('commercial_receive_goods', params: {'p_purchase_order_id': poId, 'p_received_location_id': d['location_id'], 'p_lines': d['lines'], 'p_notes': d['notes']})) as String;
  Future<void> releaseReceipt(String id, String locationId) async => client.rpc('commercial_release_goods_receipt', params: {'p_goods_receipt_id': id, 'p_to_location_id': locationId});
  Future<String> createSupplierInvoice(String poId, Map<String, dynamic> d) async => (await client.rpc('commercial_create_supplier_invoice', params: {'p_purchase_order_id': poId, 'p_invoice_no': d['invoice_no'], 'p_invoice_date': d['invoice_date'], 'p_due_date': d['due_date']})) as String;
  Future<String> supplierPayment(String invoiceId, Map<String, dynamic> d) async => (await client.rpc('commercial_record_supplier_payment', params: {'p_supplier_invoice_id': invoiceId, 'p_amount': d['amount'], 'p_payment_method': d['method'], 'p_reference_no': d['reference']})) as String;
  Future<String> createQuotation(Map<String, dynamic> d) async => (await client.rpc('commercial_create_quotation', params: {'p_factory_id': d['factory_id'], 'p_customer_id': d['customer_id'], 'p_valid_until': d['valid_until'], 'p_currency_code': 'INR', 'p_notes': d['notes'], 'p_lines': d['lines']})) as String;
  Future<void> setQuotationStatus(String id, String status) async => client.rpc('commercial_set_quotation_status', params: {'p_quotation_id': id, 'p_status': status});
  Future<String> convertQuote(String id, String date) async => (await client.rpc('commercial_convert_quotation', params: {'p_quotation_id': id, 'p_requested_delivery_date': date})) as String;
  Future<void> allocate(String id, String locationId) async => client.rpc('commercial_allocate_sales_order', params: {'p_sales_order_id': id, 'p_location_id': locationId});
  Future<void> markDispatchReady(String id) async => client.rpc('commercial_mark_dispatch_ready', params: {'p_sales_order_id': id});
  Future<String> createCustomerInvoice(String id, Map<String, dynamic> d) async => (await client.rpc('commercial_create_customer_invoice', params: {'p_sales_order_id': id, 'p_invoice_date': d['invoice_date'], 'p_due_date': d['due_date']})) as String;
  Future<String> customerPayment(String invoiceId, Map<String, dynamic> d) async => (await client.rpc('commercial_record_customer_payment', params: {'p_customer_invoice_id': invoiceId, 'p_amount': d['amount'], 'p_payment_method': d['method'], 'p_reference_no': d['reference']})) as String;
}

class CommercialDashboard extends StatelessWidget {
  const CommercialDashboard({required this.data, super.key});
  final CommercialSnapshot data;
  @override
  Widget build(BuildContext context) {
    final s = data.summary;
    return ListView(padding: const EdgeInsets.all(FactorySpacing.lg), children: [
      Wrap(spacing: FactorySpacing.md, runSpacing: FactorySpacing.md, children: [
        _Metric('Suppliers', '${s['suppliers'] ?? 0}', Icons.local_shipping_outlined),
        _Metric('Customers', '${s['customers'] ?? 0}', Icons.apartment_outlined),
        _Metric('Open PR', '${s['open_requisitions'] ?? 0}', Icons.playlist_add_check_outlined),
        _Metric('Open PO', '${s['open_purchase_orders'] ?? 0}', Icons.shopping_cart_outlined),
        _Metric('QC receipt', '${s['quality_pending_grn'] ?? 0}', Icons.fact_check_outlined),
        _Metric('Supplier due', _money(s['supplier_due']), Icons.payments_outlined),
        _Metric('Open quotes', '${s['open_quotations'] ?? 0}', Icons.request_quote_outlined),
        _Metric('Sales orders', '${s['open_sales_orders'] ?? 0}', Icons.receipt_long_outlined),
        _Metric('Dispatch ready', '${s['dispatch_ready'] ?? 0}', Icons.local_shipping_outlined),
        _Metric('Customer due', _money(s['customer_due']), Icons.account_balance_wallet_outlined),
      ]),
      const SizedBox(height: FactorySpacing.lg),
      Text('Purchase → Quality → Inventory → Sales', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: FactorySpacing.sm),
      const Card(child: Padding(padding: EdgeInsets.all(FactorySpacing.lg), child: Text('Goods receipts post into the Inventory ledger. Lines marked for incoming inspection automatically create a Quality inspection. Passed receipts can be released to available stock. Sales allocation reserves ledger-derived stock before dispatch readiness.'))),
    ]);
  }
}

class PartnersSection extends StatelessWidget {
  const PartnersSection({required this.data, required this.canManage, required this.onAdd, required this.onEdit, super.key});
  final CommercialSnapshot data; final bool canManage; final VoidCallback onAdd; final ValueChanged<Map<String, dynamic>> onEdit;
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(FactorySpacing.lg), children: [
    Row(children: [Expanded(child: Text('Suppliers & customers', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))), if (canManage) FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Add partner'))]),
    const SizedBox(height: FactorySpacing.md),
    for (final row in data.partners) Card(child: ListTile(leading: CircleAvatar(child: Icon(row['partner_type'] == 'supplier' ? Icons.local_shipping_outlined : row['partner_type'] == 'customer' ? Icons.apartment_outlined : Icons.handshake_outlined)), title: Text('${row['partner_code']} · ${row['name']}', style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text('${_title(row['partner_type'] as String)} · ${row['city'] ?? '—'} · ${row['credit_days']} credit days'), trailing: canManage ? IconButton(onPressed: () => onEdit(row), icon: const Icon(Icons.edit_outlined)) : null)),
  ]);
}

class PurchaseSection extends StatelessWidget {
  const PurchaseSection({required this.data, required this.canManage, required this.onRequisition, required this.onDecision, required this.onPurchaseOrder, required this.onReceive, super.key});
  final CommercialSnapshot data; final bool canManage; final VoidCallback onRequisition, onPurchaseOrder; final void Function(Map<String, dynamic>, String) onDecision; final ValueChanged<Map<String, dynamic>> onReceive;
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(FactorySpacing.lg), children: [
    Wrap(spacing: FactorySpacing.sm, runSpacing: FactorySpacing.sm, children: [FilledButton.icon(onPressed: onRequisition, icon: const Icon(Icons.add_task), label: const Text('New requisition')), if (canManage) FilledButton.tonalIcon(onPressed: onPurchaseOrder, icon: const Icon(Icons.shopping_cart_checkout), label: const Text('New purchase order'))]),
    const SizedBox(height: FactorySpacing.lg),
    Text('Purchase requisitions', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
    for (final row in data.requisitions) Card(child: ListTile(title: Text('${row['requisition_no']} · ${_title(row['status'] as String)}', style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text('${row['purpose'] ?? 'No purpose'} · ${_nestedRows(row, 'purchase_requisition_lines').length} line(s)'), trailing: row['status'] == 'submitted' && canManage ? Row(mainAxisSize: MainAxisSize.min, children: [IconButton(tooltip: 'Approve', onPressed: () => onDecision(row, 'approved'), icon: const Icon(Icons.check_circle_outline)), IconButton(tooltip: 'Reject', onPressed: () => onDecision(row, 'rejected'), icon: const Icon(Icons.cancel_outlined))]) : null)),
    const SizedBox(height: FactorySpacing.lg),
    Text('Purchase orders', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
    for (final row in data.purchaseOrders) Card(child: ListTile(title: Text('${row['purchase_order_no']} · ${_rel(row, 'business_partners', 'name')}', style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text('${_title(row['status'] as String)} · ${_nestedRows(row, 'purchase_order_lines').length} line(s) · ${row['expected_date'] ?? 'No ETA'}'), trailing: const {'approved','sent','partially_received'}.contains(row['status']) ? FilledButton.tonal(onPressed: () => onReceive(row), child: const Text('Receive')) : null)),
  ]);
}

class GoodsReceiptSection extends StatelessWidget {
  const GoodsReceiptSection({required this.data, required this.onRelease, super.key});
  final CommercialSnapshot data; final ValueChanged<Map<String, dynamic>> onRelease;
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(FactorySpacing.lg), children: [
    Text('Goods receipt & incoming quality', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
    const SizedBox(height: FactorySpacing.md),
    for (final row in data.goodsReceipts) Card(child: ExpansionTile(leading: Icon(row['status'] == 'released' ? Icons.inventory_2_outlined : row['status'] == 'quality_hold' ? Icons.warning_amber : Icons.fact_check_outlined), title: Text('${row['goods_receipt_no']} · ${_rel(_map(row['purchase_orders']), 'business_partners', 'name')}', style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text('${_title(row['status'] as String)} · ${_rel(row, 'purchase_orders', 'purchase_order_no')}'), trailing: const {'received','quality_passed'}.contains(row['status']) ? FilledButton.tonal(onPressed: () => onRelease(row), child: const Text('Release')) : null, children: [for (final line in _nestedRows(row, 'goods_receipt_lines')) ListTile(title: Text('${_rel(line, 'inventory_items', 'name')} · ${_number(line['quantity_received'])}'), subtitle: Text(line['quality_required'] == true ? 'Incoming QC: ${_rel(line, 'quality_inspections', 'inspection_no')} · ${_title(_rel(line, 'quality_inspections', 'overall_result'))}' : 'Quality inspection not required'))])),
  ]);
}

class SupplierBillingSection extends StatelessWidget {
  const SupplierBillingSection({required this.data, required this.canManage, required this.onInvoice, required this.onPayment, super.key});
  final CommercialSnapshot data; final bool canManage; final ValueChanged<Map<String, dynamic>> onInvoice, onPayment;
  @override
  Widget build(BuildContext context) {
    final invoicedPo = data.supplierInvoices.map((e) => e['purchase_order_id']).toSet();
    final eligible = data.purchaseOrders.where((p) => const {'partially_received','received'}.contains(p['status']) && !invoicedPo.contains(p['id']));
    return ListView(padding: const EdgeInsets.all(FactorySpacing.lg), children: [
      Text('Supplier invoices & payments', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      if (canManage && eligible.isNotEmpty) ...[const SizedBox(height: FactorySpacing.sm), Wrap(spacing: FactorySpacing.sm, children: [for (final po in eligible) OutlinedButton.icon(onPressed: () => onInvoice(po), icon: const Icon(Icons.add_card), label: Text('Invoice ${po['purchase_order_no']}'))])],
      const SizedBox(height: FactorySpacing.md),
      for (final row in data.supplierInvoices) Card(child: ListTile(title: Text('${row['invoice_no']} · ${_rel(row, 'business_partners', 'name')}', style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text('${_title(row['status'] as String)} · Total ${_money(row['total_amount'])} · Due ${_money(_due(row, 'supplier_payments'))}'), trailing: canManage && _due(row, 'supplier_payments') > 0 ? FilledButton.tonal(onPressed: () => onPayment(row), child: const Text('Pay')) : null)),
    ]);
  }
}

class SalesSection extends StatelessWidget {
  const SalesSection({required this.data, required this.canManage, required this.onQuotation, required this.onQuoteAction, required this.onConvert, super.key});
  final CommercialSnapshot data; final bool canManage; final VoidCallback onQuotation; final void Function(Map<String, dynamic>, String) onQuoteAction; final ValueChanged<Map<String, dynamic>> onConvert;
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(FactorySpacing.lg), children: [
    Row(children: [Expanded(child: Text('Quotation → Sales order', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))), if (canManage) FilledButton.icon(onPressed: onQuotation, icon: const Icon(Icons.add), label: const Text('New quotation'))]),
    const SizedBox(height: FactorySpacing.md),
    for (final row in data.quotations) Card(child: ListTile(title: Text('${row['quotation_no']} · ${_rel(row, 'business_partners', 'name')}', style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text('${_title(row['status'] as String)} · valid until ${row['valid_until']} · ${_nestedRows(row, 'quotation_lines').length} line(s)'), trailing: canManage ? Row(mainAxisSize: MainAxisSize.min, children: [if (row['status'] == 'draft') TextButton(onPressed: () => onQuoteAction(row, 'sent'), child: const Text('Send')), if (row['status'] == 'sent') TextButton(onPressed: () => onQuoteAction(row, 'accepted'), child: const Text('Accept')), if (const {'sent','accepted'}.contains(row['status'])) FilledButton.tonal(onPressed: () => onConvert(row), child: const Text('Create SO'))]) : null)),
    const SizedBox(height: FactorySpacing.lg),
    Text('Sales orders', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
    for (final row in data.salesOrders) Card(child: ListTile(title: Text('${row['sales_order_no']} · ${_rel(row, 'business_partners', 'name')}', style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text('${_title(row['status'] as String)} · ${_nestedRows(row, 'sales_order_lines').length} line(s) · Delivery ${row['requested_delivery_date'] ?? 'TBD'}'))),
  ]);
}

class AllocationSection extends StatelessWidget {
  const AllocationSection({required this.data, required this.onAllocate, required this.onReady, super.key});
  final CommercialSnapshot data; final ValueChanged<Map<String, dynamic>> onAllocate, onReady;
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(FactorySpacing.lg), children: [
    Text('Stock allocation & dispatch readiness', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
    const SizedBox(height: FactorySpacing.md),
    for (final row in data.salesOrders.where((r) => const {'confirmed','allocated','dispatch_ready'}.contains(r['status']))) Card(child: ExpansionTile(title: Text('${row['sales_order_no']} · ${_rel(row, 'business_partners', 'name')}', style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text(_title(row['status'] as String)), trailing: Row(mainAxisSize: MainAxisSize.min, children: [if (row['status'] == 'confirmed') FilledButton.tonal(onPressed: () => onAllocate(row), child: const Text('Allocate')), if (row['status'] == 'allocated') FilledButton.tonal(onPressed: () => onReady(row), child: const Text('Dispatch ready')), if (row['status'] == 'dispatch_ready') const Chip(label: Text('Ready'))]), children: [for (final line in _nestedRows(row, 'sales_order_lines')) ListTile(title: Text(_rel(line, 'inventory_items', 'name')), subtitle: Text('Ordered ${_number(line['ordered_quantity'])} · Allocated ${_number(line['allocated_quantity'])}'))])),
  ]);
}

class CustomerBillingSection extends StatelessWidget {
  const CustomerBillingSection({required this.data, required this.canManage, required this.onInvoice, required this.onPayment, super.key});
  final CommercialSnapshot data; final bool canManage; final ValueChanged<Map<String, dynamic>> onInvoice, onPayment;
  @override
  Widget build(BuildContext context) {
    final invoiced = data.customerInvoices.map((e) => e['sales_order_id']).toSet();
    final eligible = data.salesOrders.where((s) => const {'dispatch_ready','dispatched','completed'}.contains(s['status']) && !invoiced.contains(s['id']));
    return ListView(padding: const EdgeInsets.all(FactorySpacing.lg), children: [
      Text('Customer invoices & payments', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      if (canManage && eligible.isNotEmpty) ...[const SizedBox(height: FactorySpacing.sm), Wrap(spacing: FactorySpacing.sm, children: [for (final order in eligible) OutlinedButton.icon(onPressed: () => onInvoice(order), icon: const Icon(Icons.add_card), label: Text('Invoice ${order['sales_order_no']}'))])],
      const SizedBox(height: FactorySpacing.md),
      for (final row in data.customerInvoices) Card(child: ListTile(title: Text('${row['invoice_no']} · ${_rel(row, 'business_partners', 'name')}', style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text('${_title(row['status'] as String)} · Total ${_money(row['total_amount'])} · Due ${_money(_due(row, 'customer_payments'))}'), trailing: canManage && _due(row, 'customer_payments') > 0 ? FilledButton.tonal(onPressed: () => onPayment(row), child: const Text('Receive')) : null)),
    ]);
  }
}

class CommercialReports extends StatelessWidget {
  const CommercialReports({required this.data, super.key}); final CommercialSnapshot data;
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(FactorySpacing.lg), children: [
    Text('Purchase report', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
    const SizedBox(height: FactorySpacing.sm),
    Card(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(columns: const [DataColumn(label: Text('PO')), DataColumn(label: Text('Supplier')), DataColumn(label: Text('Status')), DataColumn(label: Text('Total')), DataColumn(label: Text('Received'))], rows: [for (final r in data.purchaseReport) DataRow(cells: [DataCell(Text('${r['purchase_order_no']}')), DataCell(Text('${r['supplier_name']}')), DataCell(Text(_title('${r['status']}'))), DataCell(Text(_money(r['total_amount']))), DataCell(Text('${_number(r['received_percent'])}%'))])]))),
    const SizedBox(height: FactorySpacing.lg),
    Text('Sales report', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
    const SizedBox(height: FactorySpacing.sm),
    Card(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(columns: const [DataColumn(label: Text('SO')), DataColumn(label: Text('Customer')), DataColumn(label: Text('Status')), DataColumn(label: Text('Total')), DataColumn(label: Text('Allocated'))], rows: [for (final r in data.salesReport) DataRow(cells: [DataCell(Text('${r['sales_order_no']}')), DataCell(Text('${r['customer_name']}')), DataCell(Text(_title('${r['status']}'))), DataCell(Text(_money(r['total_amount']))), DataCell(Text('${_number(r['allocated_percent'])}%'))])]))),
  ]);
}

class PartnerEditor extends StatefulWidget {
  const PartnerEditor({this.initial, super.key}); final Map<String, dynamic>? initial;
  @override State<PartnerEditor> createState() => _PartnerEditorState();
}
class _PartnerEditorState extends State<PartnerEditor> {
  late final code=TextEditingController(text:'${widget.initial?['partner_code'] ?? ''}'); late final name=TextEditingController(text:'${widget.initial?['name'] ?? ''}'); late final contact=TextEditingController(text:'${widget.initial?['contact_person'] ?? ''}'); late final phone=TextEditingController(text:'${widget.initial?['phone'] ?? ''}'); late final email=TextEditingController(text:'${widget.initial?['email'] ?? ''}'); late final city=TextEditingController(text:'${widget.initial?['city'] ?? ''}'); late final state=TextEditingController(text:'${widget.initial?['state'] ?? ''}'); late final credit=TextEditingController(text:'${widget.initial?['credit_days'] ?? 0}'); String type='supplier'; bool active=true;
  @override void initState(){super.initState(); type=widget.initial?['partner_type'] as String? ?? 'supplier'; active=widget.initial?['is_active'] as bool? ?? true;}
  @override void dispose(){code.dispose();name.dispose();contact.dispose();phone.dispose();email.dispose();city.dispose();state.dispose();credit.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>AlertDialog(title:Text(widget.initial==null?'Add business partner':'Edit business partner'),content:SizedBox(width:560,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[Row(children:[Expanded(child:TextField(controller:code,decoration:const InputDecoration(labelText:'Partner code'))),const SizedBox(width:FactorySpacing.sm),Expanded(child:DropdownButtonFormField<String>(initialValue:type,decoration:const InputDecoration(labelText:'Type'),items:const [DropdownMenuItem(value:'supplier',child:Text('Supplier')),DropdownMenuItem(value:'customer',child:Text('Customer')),DropdownMenuItem(value:'both',child:Text('Both'))],onChanged:(v)=>setState(()=>type=v??type)))]),const SizedBox(height:FactorySpacing.sm),TextField(controller:name,decoration:const InputDecoration(labelText:'Name')),const SizedBox(height:FactorySpacing.sm),Row(children:[Expanded(child:TextField(controller:contact,decoration:const InputDecoration(labelText:'Contact person'))),const SizedBox(width:FactorySpacing.sm),Expanded(child:TextField(controller:phone,decoration:const InputDecoration(labelText:'Phone')))]),const SizedBox(height:FactorySpacing.sm),TextField(controller:email,decoration:const InputDecoration(labelText:'Email')),const SizedBox(height:FactorySpacing.sm),Row(children:[Expanded(child:TextField(controller:city,decoration:const InputDecoration(labelText:'City'))),const SizedBox(width:FactorySpacing.sm),Expanded(child:TextField(controller:state,decoration:const InputDecoration(labelText:'State'))),const SizedBox(width:FactorySpacing.sm),SizedBox(width:120,child:TextField(controller:credit,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Credit days')))]),SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Active'),value:active,onChanged:(v)=>setState(()=>active=v))]))),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancel')),FilledButton(onPressed:(){final days=int.tryParse(credit.text.trim());if(code.text.trim().length<2||name.text.trim().length<2||days==null)return;Navigator.pop(context,{'partner_code':code.text.trim().toUpperCase(),'name':name.text.trim(),'partner_type':type,'contact_person':_nullIfBlank(contact.text),'phone':_nullIfBlank(phone.text),'email':_nullIfBlank(email.text),'city':_nullIfBlank(city.text),'state':_nullIfBlank(state.text),'country_code':'IN','credit_days':days,'is_active':active});},child:const Text('Save'))]);
}

class RequisitionEditor extends StatefulWidget {
  const RequisitionEditor({required this.factories,required this.items,super.key}); final List<Map<String,dynamic>> factories,items;
  @override State<RequisitionEditor> createState()=>_RequisitionEditorState();
}
class _RequisitionEditorState extends State<RequisitionEditor>{String? factoryId;DateTime? requiredDate;final purpose=TextEditingController();final lines=<Map<String,dynamic>>[];@override void initState(){super.initState();factoryId=widget.factories.isEmpty?null:widget.factories.first['id'] as String;}@override void dispose(){purpose.dispose();super.dispose();}Future<void> addLine()async{final d=await showDialog<Map<String,dynamic>>(context:context,builder:(_)=>CommercialLineEditor(items:widget.items,mode:'requisition'));if(d!=null)setState(()=>lines.add(d));}@override Widget build(BuildContext context)=>AlertDialog(title:const Text('New purchase requisition'),content:SizedBox(width:580,child:Column(mainAxisSize:MainAxisSize.min,children:[DropdownButtonFormField<String>(initialValue:factoryId,decoration:const InputDecoration(labelText:'Factory'),items:[for(final f in widget.factories)DropdownMenuItem(value:f['id'] as String,child:Text('${f['code']} · ${f['name']}'))],onChanged:(v)=>setState(()=>factoryId=v)),const SizedBox(height:FactorySpacing.sm),TextField(controller:purpose,decoration:const InputDecoration(labelText:'Purpose')),const SizedBox(height:FactorySpacing.sm),ListTile(contentPadding:EdgeInsets.zero,title:Text(requiredDate==null?'Required date':'Required ${_date(requiredDate!)}'),trailing:IconButton(onPressed:()async{final d=await showDatePicker(context:context,firstDate:DateTime.now(),lastDate:DateTime.now().add(const Duration(days:365)),initialDate:DateTime.now().add(const Duration(days:7)));if(d!=null)setState(()=>requiredDate=d);},icon:const Icon(Icons.calendar_month))),for(final line in lines)ListTile(dense:true,title:Text(_itemName(widget.items,line['item_id'])),subtitle:Text('Qty ${_number(line['quantity'])} · Est ${_money(line['estimated_unit_cost'])}'),trailing:IconButton(onPressed:()=>setState(()=>lines.remove(line)),icon:const Icon(Icons.close))),OutlinedButton.icon(onPressed:addLine,icon:const Icon(Icons.add),label:const Text('Add item'))])),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancel')),FilledButton(onPressed:factoryId==null||lines.isEmpty?null:()=>Navigator.pop(context,{'factory_id':factoryId,'required_date':requiredDate==null?null:_date(requiredDate!),'purpose':purpose.text.trim(),'lines':lines}),child:const Text('Submit'))]);}

class PurchaseOrderEditor extends StatefulWidget{const PurchaseOrderEditor({required this.factories,required this.suppliers,required this.requisitions,required this.items,super.key});final List<Map<String,dynamic>> factories,suppliers,requisitions,items;@override State<PurchaseOrderEditor> createState()=>_PurchaseOrderEditorState();}
class _PurchaseOrderEditorState extends State<PurchaseOrderEditor>{String? factoryId,supplierId,requisitionId;DateTime? expected;final notes=TextEditingController();final lines=<Map<String,dynamic>>[];@override void initState(){super.initState();factoryId=widget.factories.isEmpty?null:widget.factories.first['id'] as String;supplierId=widget.suppliers.isEmpty?null:widget.suppliers.first['id'] as String;}@override void dispose(){notes.dispose();super.dispose();}Future<void> addLine()async{final d=await showDialog<Map<String,dynamic>>(context:context,builder:(_)=>CommercialLineEditor(items:widget.items,mode:'purchase'));if(d!=null)setState(()=>lines.add(d));}@override Widget build(BuildContext context)=>AlertDialog(title:const Text('New purchase order'),content:SizedBox(width:600,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[DropdownButtonFormField<String>(initialValue:factoryId,decoration:const InputDecoration(labelText:'Factory'),items:[for(final f in widget.factories)DropdownMenuItem(value:f['id'] as String,child:Text('${f['code']} · ${f['name']}'))],onChanged:(v)=>setState(()=>factoryId=v)),const SizedBox(height:FactorySpacing.sm),DropdownButtonFormField<String>(initialValue:supplierId,decoration:const InputDecoration(labelText:'Supplier'),items:[for(final p in widget.suppliers)DropdownMenuItem(value:p['id'] as String,child:Text('${p['partner_code']} · ${p['name']}'))],onChanged:(v)=>setState(()=>supplierId=v)),const SizedBox(height:FactorySpacing.sm),DropdownButtonFormField<String>(initialValue:requisitionId,decoration:const InputDecoration(labelText:'Approved requisition (optional)'),items:[for(final r in widget.requisitions.where((r)=>r['factory_id']==factoryId))DropdownMenuItem(value:r['id'] as String,child:Text(r['requisition_no'] as String))],onChanged:(v)=>setState(()=>requisitionId=v)),ListTile(contentPadding:EdgeInsets.zero,title:Text(expected==null?'Expected date':'Expected ${_date(expected!)}'),trailing:IconButton(onPressed:()async{final d=await showDatePicker(context:context,firstDate:DateTime.now(),lastDate:DateTime.now().add(const Duration(days:365)),initialDate:DateTime.now().add(const Duration(days:7)));if(d!=null)setState(()=>expected=d);},icon:const Icon(Icons.calendar_month))),TextField(controller:notes,decoration:const InputDecoration(labelText:'Notes')),const SizedBox(height:FactorySpacing.sm),for(final line in lines)ListTile(dense:true,title:Text(_itemName(widget.items,line['item_id'])),subtitle:Text('Qty ${_number(line['quantity'])} · ${_money(line['unit_price'])} · tax ${_number(line['tax_rate'])}%'),trailing:IconButton(onPressed:()=>setState(()=>lines.remove(line)),icon:const Icon(Icons.close))),OutlinedButton.icon(onPressed:addLine,icon:const Icon(Icons.add),label:const Text('Add PO item'))]))),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancel')),FilledButton(onPressed:factoryId==null||supplierId==null||lines.isEmpty?null:()=>Navigator.pop(context,{'factory_id':factoryId,'supplier_id':supplierId,'requisition_id':requisitionId,'expected_date':expected==null?null:_date(expected!),'notes':notes.text.trim(),'lines':lines}),child:const Text('Create'))]);}

class GoodsReceiptEditor extends StatefulWidget{const GoodsReceiptEditor({required this.po,required this.lines,required this.locations,super.key});final Map<String,dynamic> po;final List<Map<String,dynamic>> lines,locations;@override State<GoodsReceiptEditor> createState()=>_GoodsReceiptEditorState();}
class _GoodsReceiptEditorState extends State<GoodsReceiptEditor>{String? lineId,locationId;final qty=TextEditingController();final lot=TextEditingController();final notes=TextEditingController();bool quality=true;@override void initState(){super.initState();lineId=widget.lines.first['id'] as String;final preferred=widget.locations.where((l)=>l['location_type']=='quality').toList();if(preferred.isNotEmpty){locationId=preferred.first['id'] as String;}else if(widget.locations.isNotEmpty){locationId=widget.locations.first['id'] as String;}}@override void dispose(){qty.dispose();lot.dispose();notes.dispose();super.dispose();}@override Widget build(BuildContext context){final line=widget.lines.firstWhere((l)=>l['id']==lineId);final remaining=(line['ordered_quantity'] as num)-(line['received_quantity'] as num);return AlertDialog(title:Text('Receive ${widget.po['purchase_order_no']}'),content:SizedBox(width:540,child:Column(mainAxisSize:MainAxisSize.min,children:[DropdownButtonFormField<String>(initialValue:lineId,decoration:const InputDecoration(labelText:'PO line'),items:[for(final l in widget.lines)DropdownMenuItem(value:l['id'] as String,child:Text('${_rel(l,'inventory_items','name')} · remaining ${_number((l['ordered_quantity'] as num)-(l['received_quantity'] as num))}'))],onChanged:(v)=>setState(()=>lineId=v)),const SizedBox(height:FactorySpacing.sm),DropdownButtonFormField<String>(initialValue:locationId,decoration:const InputDecoration(labelText:'Receiving / Incoming QC location'),items:[for(final l in widget.locations)DropdownMenuItem(value:l['id'] as String,child:Text('${l['code']} · ${l['name']}'))],onChanged:(v)=>setState(()=>locationId=v)),const SizedBox(height:FactorySpacing.sm),Row(children:[Expanded(child:TextField(controller:qty,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:'Quantity',helperText:'Remaining ${_number(remaining)}'))),const SizedBox(width:FactorySpacing.sm),Expanded(child:TextField(controller:lot,decoration:const InputDecoration(labelText:'Lot / batch')))]),SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Incoming quality inspection required'),value:quality,onChanged:(v)=>setState(()=>quality=v)),TextField(controller:notes,decoration:const InputDecoration(labelText:'Notes'))])),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancel')),FilledButton(onPressed:locationId==null?null:(){final q=double.tryParse(qty.text.trim());if(q==null||q<=0||q>remaining)return;Navigator.pop(context,{'location_id':locationId,'notes':notes.text.trim(),'lines':[{'purchase_order_line_id':lineId,'quantity':q,'lot_batch_no':_nullIfBlank(lot.text),'quality_required':quality}]});},child:const Text('Post GRN'))]);}}

class QuotationEditor extends StatefulWidget{const QuotationEditor({required this.factories,required this.customers,required this.items,super.key});final List<Map<String,dynamic>> factories,customers,items;@override State<QuotationEditor> createState()=>_QuotationEditorState();}
class _QuotationEditorState extends State<QuotationEditor>{String? factoryId,customerId;DateTime? valid;final notes=TextEditingController();final lines=<Map<String,dynamic>>[];@override void initState(){super.initState();factoryId=widget.factories.isEmpty?null:widget.factories.first['id'] as String;customerId=widget.customers.isEmpty?null:widget.customers.first['id'] as String;valid=DateTime.now().add(const Duration(days:7));}@override void dispose(){notes.dispose();super.dispose();}Future<void> addLine()async{final d=await showDialog<Map<String,dynamic>>(context:context,builder:(_)=>CommercialLineEditor(items:widget.items,mode:'sales'));if(d!=null)setState(()=>lines.add(d));}@override Widget build(BuildContext context)=>AlertDialog(title:const Text('New quotation'),content:SizedBox(width:600,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[DropdownButtonFormField<String>(initialValue:factoryId,decoration:const InputDecoration(labelText:'Factory'),items:[for(final f in widget.factories)DropdownMenuItem(value:f['id'] as String,child:Text('${f['code']} · ${f['name']}'))],onChanged:(v)=>setState(()=>factoryId=v)),const SizedBox(height:FactorySpacing.sm),DropdownButtonFormField<String>(initialValue:customerId,decoration:const InputDecoration(labelText:'Customer'),items:[for(final p in widget.customers)DropdownMenuItem(value:p['id'] as String,child:Text('${p['partner_code']} · ${p['name']}'))],onChanged:(v)=>setState(()=>customerId=v)),ListTile(contentPadding:EdgeInsets.zero,title:Text('Valid until ${_date(valid!)}'),trailing:IconButton(onPressed:()async{final d=await showDatePicker(context:context,firstDate:DateTime.now(),lastDate:DateTime.now().add(const Duration(days:365)),initialDate:valid!);if(d!=null)setState(()=>valid=d);},icon:const Icon(Icons.calendar_month))),TextField(controller:notes,decoration:const InputDecoration(labelText:'Notes')),const SizedBox(height:FactorySpacing.sm),for(final line in lines)ListTile(dense:true,title:Text(_itemName(widget.items,line['item_id'])),subtitle:Text('Qty ${_number(line['quantity'])} · ${_money(line['unit_price'])} · tax ${_number(line['tax_rate'])}%'),trailing:IconButton(onPressed:()=>setState(()=>lines.remove(line)),icon:const Icon(Icons.close))),OutlinedButton.icon(onPressed:addLine,icon:const Icon(Icons.add),label:const Text('Add quotation item'))]))),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancel')),FilledButton(onPressed:factoryId==null||customerId==null||lines.isEmpty?null:()=>Navigator.pop(context,{'factory_id':factoryId,'customer_id':customerId,'valid_until':_date(valid!),'notes':notes.text.trim(),'lines':lines}),child:const Text('Create'))]);}

class CommercialLineEditor extends StatefulWidget{const CommercialLineEditor({required this.items,required this.mode,super.key});final List<Map<String,dynamic>> items;final String mode;@override State<CommercialLineEditor> createState()=>_CommercialLineEditorState();}
class _CommercialLineEditorState extends State<CommercialLineEditor>{String? itemId;final qty=TextEditingController(text:'1');final price=TextEditingController();final tax=TextEditingController(text:'0');@override void initState(){super.initState();itemId=widget.items.isEmpty?null:widget.items.first['id'] as String;}@override void dispose(){qty.dispose();price.dispose();tax.dispose();super.dispose();}@override Widget build(BuildContext context){final requisition=widget.mode=='requisition';return AlertDialog(title:Text(requisition?'Add requisition item':'Add line item'),content:SizedBox(width:460,child:Column(mainAxisSize:MainAxisSize.min,children:[DropdownButtonFormField<String>(initialValue:itemId,decoration:const InputDecoration(labelText:'Item'),items:[for(final i in widget.items)DropdownMenuItem(value:i['id'] as String,child:Text('${i['sku']} · ${i['name']}'))],onChanged:(v)=>setState(()=>itemId=v)),const SizedBox(height:FactorySpacing.sm),TextField(controller:qty,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Quantity')),const SizedBox(height:FactorySpacing.sm),TextField(controller:price,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:requisition?'Estimated unit cost':'Unit price')),if(!requisition)...[const SizedBox(height:FactorySpacing.sm),TextField(controller:tax,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Tax %'))]])),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancel')),FilledButton(onPressed:itemId==null?null:(){final q=double.tryParse(qty.text.trim());final p=double.tryParse(price.text.trim());final t=double.tryParse(tax.text.trim())??0;if(q==null||q<=0||p==null||p<0||t<0||t>100)return;Navigator.pop(context,requisition?{'item_id':itemId,'quantity':q,'estimated_unit_cost':p}:{'item_id':itemId,'quantity':q,'unit_price':p,'tax_rate':t});},child:const Text('Add'))]);}}

class InvoiceEditor extends StatefulWidget{const InvoiceEditor({required this.title,required this.numberLabel,this.autoNumber=false,super.key});final String title,numberLabel;final bool autoNumber;@override State<InvoiceEditor> createState()=>_InvoiceEditorState();}
class _InvoiceEditorState extends State<InvoiceEditor>{final number=TextEditingController();DateTime invoice=DateTime.now(),due=DateTime.now().add(const Duration(days:15));@override void dispose(){number.dispose();super.dispose();}@override Widget build(BuildContext context)=>AlertDialog(title:Text(widget.title),content:SizedBox(width:460,child:Column(mainAxisSize:MainAxisSize.min,children:[if(!widget.autoNumber)TextField(controller:number,decoration:InputDecoration(labelText:widget.numberLabel)),ListTile(contentPadding:EdgeInsets.zero,title:Text('Invoice date ${_date(invoice)}'),trailing:IconButton(onPressed:()async{final d=await showDatePicker(context:context,firstDate:DateTime.now().subtract(const Duration(days:60)),lastDate:DateTime.now().add(const Duration(days:60)),initialDate:invoice);if(d!=null)setState(()=>invoice=d);},icon:const Icon(Icons.calendar_month))),ListTile(contentPadding:EdgeInsets.zero,title:Text('Due date ${_date(due)}'),trailing:IconButton(onPressed:()async{final d=await showDatePicker(context:context,firstDate:invoice,lastDate:invoice.add(const Duration(days:365)),initialDate:due);if(d!=null)setState(()=>due=d);},icon:const Icon(Icons.event_available)))])),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancel')),FilledButton(onPressed:!widget.autoNumber&&number.text.trim().length<2?null:()=>Navigator.pop(context,{'invoice_no':number.text.trim(),'invoice_date':_date(invoice),'due_date':_date(due)}),child:const Text('Post'))]);}

class PaymentEditor extends StatefulWidget{const PaymentEditor({required this.maxAmount,super.key});final num maxAmount;@override State<PaymentEditor> createState()=>_PaymentEditorState();}
class _PaymentEditorState extends State<PaymentEditor>{late final amount=TextEditingController(text:_number(widget.maxAmount));final reference=TextEditingController();String method='bank_transfer';@override void dispose(){amount.dispose();reference.dispose();super.dispose();}@override Widget build(BuildContext context)=>AlertDialog(title:const Text('Record payment'),content:SizedBox(width:440,child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:amount,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:'Amount',helperText:'Outstanding ${_money(widget.maxAmount)}')),const SizedBox(height:FactorySpacing.sm),DropdownButtonFormField<String>(initialValue:method,decoration:const InputDecoration(labelText:'Method'),items:const [DropdownMenuItem(value:'bank_transfer',child:Text('Bank transfer')),DropdownMenuItem(value:'upi',child:Text('UPI')),DropdownMenuItem(value:'cash',child:Text('Cash')),DropdownMenuItem(value:'cheque',child:Text('Cheque')),DropdownMenuItem(value:'card',child:Text('Card')),DropdownMenuItem(value:'other',child:Text('Other'))],onChanged:(v)=>setState(()=>method=v??method)),const SizedBox(height:FactorySpacing.sm),TextField(controller:reference,decoration:const InputDecoration(labelText:'Reference'))])),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancel')),FilledButton(onPressed:(){final value=double.tryParse(amount.text.trim());if(value==null||value<=0||value>widget.maxAmount)return;Navigator.pop(context,{'amount':value,'method':method,'reference':reference.text.trim()});},child:const Text('Record'))]);}

class LocationPickerDialog extends StatelessWidget{const LocationPickerDialog({required this.title,required this.locations,super.key});final String title;final List<Map<String,dynamic>> locations;@override Widget build(BuildContext context)=>SimpleDialog(title:Text(title),children:[for(final l in locations)SimpleDialogOption(onPressed:()=>Navigator.pop(context,l['id'] as String),child:ListTile(leading:const Icon(Icons.location_on_outlined),title:Text('${l['code']} · ${l['name']}'),subtitle:Text(_title(l['location_type'] as String))))]);}

class _Metric extends StatelessWidget{const _Metric(this.label,this.value,this.icon);final String label,value;final IconData icon;@override Widget build(BuildContext context)=>SizedBox(width:210,child:Card(child:Padding(padding:const EdgeInsets.all(FactorySpacing.lg),child:Row(children:[CircleAvatar(child:Icon(icon)),const SizedBox(width:FactorySpacing.md),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(value,style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w900)),Text(label)]))]))));}
class _ErrorPanel extends StatelessWidget{const _ErrorPanel({required this.message,required this.onRetry});final String message;final VoidCallback onRetry;@override Widget build(BuildContext context)=>Center(child:Padding(padding:const EdgeInsets.all(FactorySpacing.lg),child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.error_outline,size:48),const SizedBox(height:FactorySpacing.md),Text(message,textAlign:TextAlign.center),const SizedBox(height:FactorySpacing.md),OutlinedButton(onPressed:onRetry,child:const Text('Retry'))])));}
class _CommercialSection{const _CommercialSection(this.label,this.icon,this.page);final String label;final IconData icon;final Widget page;}

List<Map<String,dynamic>> _rows(dynamic value)=>(value as List<dynamic>).map((e)=>Map<String,dynamic>.from(e as Map)).toList();
List<Map<String,dynamic>> _nestedRows(Map<String,dynamic> row,String key){final v=row[key];if(v is! List)return const [];return v.map((e)=>Map<String,dynamic>.from(e as Map)).toList();}
Map<String,dynamic> _map(dynamic v)=>v is Map?Map<String,dynamic>.from(v):<String,dynamic>{};
String _rel(Map<String,dynamic> row,String key,String field){final value=row[key];return value is Map&&value[field]!=null?'${value[field]}':'—';}
String _title(String value)=>value.replaceAll('_',' ').split(' ').where((p)=>p.isNotEmpty).map((p)=>'${p[0].toUpperCase()}${p.substring(1)}').join(' ');
String _number(dynamic value){final n=value is num?value:num.tryParse('$value')??0;return n%1==0?n.toInt().toString():n.toStringAsFixed(2);}
String _money(dynamic value)=>'₹${_number(value)}';
String _date(DateTime value)=>'${value.year.toString().padLeft(4,'0')}-${value.month.toString().padLeft(2,'0')}-${value.day.toString().padLeft(2,'0')}';
String? _nullIfBlank(String value)=>value.trim().isEmpty?null:value.trim();
String _itemName(List<Map<String,dynamic>> items,dynamic id){for(final i in items){if(i['id']==id)return i['name'] as String;}return 'Item';}
num _due(Map<String,dynamic> invoice,String paymentsKey){final total=(invoice['total_amount'] as num?)??0;final payments=_nestedRows(invoice,paymentsKey).fold<num>(0,(sum,row)=>sum+((row['amount'] as num?)??0));return total-payments;}
String _errorText(Object error)=>error.toString().replaceFirst('PostgrestException(message: ','').replaceFirst('AuthException(message: ','');
