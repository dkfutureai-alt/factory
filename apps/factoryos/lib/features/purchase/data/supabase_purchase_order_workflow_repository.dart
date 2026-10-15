import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/purchase_order_workflow_models.dart';
import 'purchase_order_workflow_repository.dart';

final class SupabasePurchaseOrderWorkflowRepository implements PurchaseOrderWorkflowRepository {
  const SupabasePurchaseOrderWorkflowRepository(this.client);

  final SupabaseClient client;

  @override
  bool get supportsMutations => true;

  @override
  Future<PurchaseOrderEditorOptions> loadEditor({String? orderNumber}) async {
    final factoryRows = (await client
            .from('factories')
            .select('id,code,name,status')
            .eq('status', 'active')
            .order('code'))
        .cast<Map<String, dynamic>>();
    final supplierRows = (await client
            .from('suppliers')
            .select('id,code,name,payment_terms_days,status')
            .eq('status', 'active')
            .order('name'))
        .cast<Map<String, dynamic>>();
    final itemRows = (await client
            .from('items')
            .select('id,sku,name,unit_id,cost,status')
            .eq('status', 'active')
            .order('sku'))
        .cast<Map<String, dynamic>>();
    final unitIds = itemRows.map((row) => row['unit_id']?.toString()).whereType<String>().toSet().toList(growable: false);
    final unitRows = unitIds.isEmpty
        ? <Map<String, dynamic>>[]
        : (await client.from('item_units').select('id,code').inFilter('id', unitIds)).cast<Map<String, dynamic>>();
    final unitById = {for (final row in unitRows) row['id'].toString(): row['code']?.toString() ?? ''};

    PurchaseOrderDraftSnapshot? draft;
    if (orderNumber != null && orderNumber.trim().isNotEmpty) {
      final poRows = (await client
              .from('purchase_orders')
              .select('id,order_number,revision,status,factory_id,supplier_id,expected_delivery_date,payment_terms,notes,rejection_reason,submitted_by,submitted_at')
              .eq('order_number', orderNumber)
              .limit(1))
          .cast<Map<String, dynamic>>();
      if (poRows.isEmpty) throw StateError('Purchase order not found.');
      final po = poRows.single;
      final lineRows = (await client
              .from('purchase_order_lines')
              .select('item_id,ordered_quantity,unit_price,tax_rate,note')
              .eq('purchase_order_id', po['id'].toString())
              .order('created_at'))
          .cast<Map<String, dynamic>>();
      draft = PurchaseOrderDraftSnapshot(
        purchaseOrderId: po['id'].toString(),
        orderNumber: po['order_number']?.toString() ?? orderNumber,
        revision: _asInt(po['revision'], 1),
        status: po['status']?.toString() ?? 'draft',
        factoryId: po['factory_id'].toString(),
        supplierId: po['supplier_id'].toString(),
        expectedDeliveryDate: _asDate(po['expected_delivery_date']),
        paymentTerms: po['payment_terms']?.toString() ?? '',
        notes: po['notes']?.toString() ?? '',
        rejectionReason: po['rejection_reason']?.toString(),
        submittedBy: po['submitted_by']?.toString(),
        submittedAt: _asDate(po['submitted_at']),
        lines: lineRows
            .map((row) => PurchaseOrderDraftLine(
                  itemId: row['item_id'].toString(),
                  orderedQuantity: _asDouble(row['ordered_quantity']),
                  unitPrice: _asDouble(row['unit_price']),
                  taxRate: _asDouble(row['tax_rate']),
                  note: row['note']?.toString(),
                ))
            .toList(growable: false),
      );
    }

    return PurchaseOrderEditorOptions(
      factories: factoryRows
          .map((row) => PurchaseOrderFactoryOption(
                id: row['id'].toString(),
                code: row['code']?.toString() ?? 'FACTORY',
                name: row['name']?.toString() ?? 'Factory',
              ))
          .toList(growable: false),
      suppliers: supplierRows
          .map((row) => PurchaseOrderSupplierOption(
                id: row['id'].toString(),
                code: row['code']?.toString() ?? 'SUP',
                name: row['name']?.toString() ?? 'Supplier',
                paymentTermsDays: _asInt(row['payment_terms_days'], 30),
              ))
          .toList(growable: false),
      items: itemRows
          .map((row) => PurchaseOrderItemOption(
                id: row['id'].toString(),
                sku: row['sku']?.toString() ?? 'SKU',
                name: row['name']?.toString() ?? 'Item',
                unit: unitById[row['unit_id']?.toString()] ?? '',
                defaultUnitPrice: _asDouble(row['cost']),
              ))
          .toList(growable: false),
      draft: draft,
    );
  }

  @override
  Future<PurchaseOrderWorkflowResult> saveDraft(PurchaseOrderDraftRequest request) async {
    final raw = request.purchaseOrderId == null
        ? await client.rpc(
            'create_purchase_order_draft',
            params: {
              'target_factory_id': request.factoryId,
              'target_supplier_id': request.supplierId,
              'target_expected_delivery_date': _dateOnly(request.expectedDeliveryDate),
              'target_payment_terms': request.paymentTerms.trim(),
              'target_notes': request.notes.trim(),
              'target_lines': request.toRpcLines(),
              'target_idempotency_key': request.idempotencyKey.trim(),
            },
          )
        : await client.rpc(
            'update_purchase_order_draft',
            params: {
              'target_purchase_order_id': request.purchaseOrderId,
              'target_expected_revision': request.expectedRevision,
              'target_supplier_id': request.supplierId,
              'target_expected_delivery_date': _dateOnly(request.expectedDeliveryDate),
              'target_payment_terms': request.paymentTerms.trim(),
              'target_notes': request.notes.trim(),
              'target_lines': request.toRpcLines(),
              'target_idempotency_key': request.idempotencyKey.trim(),
            },
          );
    return _result(Map<String, dynamic>.from(raw as Map));
  }

  @override
  Future<PurchaseOrderWorkflowResult> submit({
    required String purchaseOrderId,
    required int expectedRevision,
    required String idempotencyKey,
  }) async {
    final raw = await client.rpc(
      'submit_purchase_order',
      params: {
        'target_purchase_order_id': purchaseOrderId,
        'target_expected_revision': expectedRevision,
        'target_idempotency_key': idempotencyKey.trim(),
      },
    );
    return _result(Map<String, dynamic>.from(raw as Map));
  }

  @override
  Future<PurchaseOrderWorkflowResult> decide(PurchaseOrderDecisionRequest request) async {
    final raw = await client.rpc(
      'decide_purchase_order',
      params: {
        'target_purchase_order_id': request.purchaseOrderId,
        'target_decision': request.rpcDecision,
        'target_comment': request.comment.trim(),
        'target_idempotency_key': request.idempotencyKey.trim(),
      },
    );
    return _result(Map<String, dynamic>.from(raw as Map));
  }
}

PurchaseOrderWorkflowResult _result(Map<String, dynamic> row) => PurchaseOrderWorkflowResult(
      purchaseOrderId: row['id']?.toString() ?? '',
      orderNumber: row['order_number']?.toString() ?? 'PO',
      revision: _asInt(row['revision'], 1),
      status: row['status']?.toString() ?? 'unknown',
      rejectionReason: row['rejection_reason']?.toString(),
    );

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int _asInt(dynamic value, int fallback) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

DateTime? _asDate(dynamic value) => value == null ? null : DateTime.tryParse(value.toString());
String? _dateOnly(DateTime? value) => value == null ? null : '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';