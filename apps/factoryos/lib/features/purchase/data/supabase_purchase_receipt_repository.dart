import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/purchase_receipt_models.dart';
import 'purchase_receipt_repository.dart';

final class SupabasePurchaseReceiptRepository implements PurchaseReceiptRepository {
  const SupabasePurchaseReceiptRepository(this.client);

  final SupabaseClient client;

  @override
  bool get supportsPosting => true;

  @override
  Future<PurchaseReceiptOptions> loadOptions(String orderNumber) async {
    final poRows = (await client
            .from('purchase_orders')
            .select('id,order_number,supplier_id,factory_id,status')
            .eq('order_number', orderNumber)
            .limit(1))
        .cast<Map<String, dynamic>>();
    if (poRows.isEmpty) throw StateError('Purchase order not found.');
    final po = poRows.single;

    final supplierRows = (await client
            .from('suppliers')
            .select('id,name')
            .eq('id', po['supplier_id'].toString())
            .limit(1))
        .cast<Map<String, dynamic>>();
    final supplier = supplierRows.isEmpty ? 'Supplier' : supplierRows.single['name']?.toString() ?? 'Supplier';

    final progressRows = (await client
            .from('purchase_order_line_progress')
            .select('id,item_id,unit_price,pending_quantity')
            .eq('purchase_order_id', po['id'].toString()))
        .cast<Map<String, dynamic>>();
    final openProgress = progressRows.where((row) => _asDouble(row['pending_quantity']) > 0).toList(growable: false);

    final itemIds = openProgress.map((row) => row['item_id'].toString()).toSet().toList(growable: false);
    final itemRows = itemIds.isEmpty
        ? <Map<String, dynamic>>[]
        : (await client
                .from('items')
                .select('id,sku,name,unit_id,batch_tracking,serial_tracking,status')
                .inFilter('id', itemIds))
            .cast<Map<String, dynamic>>();
    final itemById = {for (final row in itemRows) row['id'].toString(): row};

    final unitIds = itemRows.map((row) => row['unit_id']?.toString()).whereType<String>().toSet().toList(growable: false);
    final unitRows = unitIds.isEmpty
        ? <Map<String, dynamic>>[]
        : (await client.from('item_units').select('id,code').inFilter('id', unitIds)).cast<Map<String, dynamic>>();
    final unitById = {for (final row in unitRows) row['id'].toString(): row['code']?.toString() ?? ''};

    final warehouseRows = (await client
            .from('warehouses')
            .select('id,code,name,factory_id')
            .eq('factory_id', po['factory_id'].toString())
            .eq('status', 'active')
            .order('code'))
        .cast<Map<String, dynamic>>();
    final warehouseIds = warehouseRows.map((row) => row['id'].toString()).toList(growable: false);
    final locationRows = warehouseIds.isEmpty
        ? <Map<String, dynamic>>[]
        : (await client
                .from('warehouse_locations')
                .select('id,warehouse_id,code,name')
                .inFilter('warehouse_id', warehouseIds)
                .eq('status', 'active')
                .order('code'))
            .cast<Map<String, dynamic>>();

    return PurchaseReceiptOptions(
      purchaseOrderId: po['id'].toString(),
      orderNumber: po['order_number']?.toString() ?? orderNumber,
      supplier: supplier,
      status: po['status']?.toString() ?? 'unknown',
      warehouses: warehouseRows
          .map((row) => PurchaseReceiptWarehouseOption(
                id: row['id'].toString(),
                code: row['code']?.toString() ?? 'WH',
                name: row['name']?.toString() ?? 'Warehouse',
              ))
          .toList(growable: false),
      locations: locationRows
          .map((row) => PurchaseReceiptLocationOption(
                id: row['id'].toString(),
                warehouseId: row['warehouse_id'].toString(),
                code: row['code']?.toString() ?? 'LOC',
                name: row['name']?.toString() ?? row['code']?.toString() ?? 'Location',
              ))
          .toList(growable: false),
      lines: openProgress.map((row) {
        final item = itemById[row['item_id'].toString()];
        if (item == null) throw StateError('Purchase order item is not visible.');
        return PurchaseReceiptLineOption(
          purchaseOrderLineId: row['id'].toString(),
          itemId: row['item_id'].toString(),
          sku: item['sku']?.toString() ?? 'SKU',
          itemName: item['name']?.toString() ?? 'Item',
          unit: unitById[item['unit_id']?.toString()] ?? '',
          pendingQuantity: _asDouble(row['pending_quantity']),
          unitPrice: _asDouble(row['unit_price']),
          batchTracking: item['batch_tracking'] == true,
          serialTracking: item['serial_tracking'] == true,
        );
      }).toList(growable: false),
    );
  }

  @override
  Future<PurchaseReceiptResult> postReceipt(PurchaseReceiptRequest request) async {
    final raw = await client.rpc(
      'post_purchase_goods_receipt',
      params: {
        'target_purchase_order_id': request.purchaseOrderId,
        'target_warehouse_id': request.warehouseId,
        'target_supplier_invoice_number': request.supplierInvoiceNumber.trim(),
        'target_supplier_delivery_note': request.supplierDeliveryNote.trim(),
        'target_note': request.note.trim(),
        'target_lines': request.toRpcLines(),
        'target_idempotency_key': request.idempotencyKey.trim(),
      },
    );
    final row = Map<String, dynamic>.from(raw as Map);
    return PurchaseReceiptResult(
      goodsReceiptId: row['id']?.toString() ?? '',
      grnNumber: row['grn_number']?.toString() ?? 'GRN',
      status: row['status']?.toString() ?? 'unknown',
      stockTransactionId: row['stock_transaction_id']?.toString(),
    );
  }
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
