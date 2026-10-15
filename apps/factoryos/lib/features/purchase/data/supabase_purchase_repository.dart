import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/purchase_models.dart';
import 'purchase_repository.dart';

final class SupabasePurchaseRepository implements PurchaseRepository {
  const SupabasePurchaseRepository(this.client);

  final SupabaseClient client;

  @override
  Future<PurchaseOverview> loadOverview() async {
    final orderRows = (await client
            .from('purchase_orders')
            .select('id,order_number,supplier_id,expected_delivery_date,status')
            .order('expected_delivery_date'))
        .cast<Map<String, dynamic>>();
    final supplierRows = (await client.from('suppliers').select('id,name')).cast<Map<String, dynamic>>();
    final supplierById = {for (final row in supplierRows) row['id'].toString(): row['name']?.toString() ?? 'Supplier'};
    final progressRows = (await client
            .from('purchase_order_line_progress')
            .select('purchase_order_id,ordered_quantity,unit_price,accepted_received_quantity,pending_quantity'))
        .cast<Map<String, dynamic>>();

    final valueByOrder = <String, double>{};
    final pendingValueByOrder = <String, double>{};
    for (final row in progressRows) {
      final orderId = row['purchase_order_id'].toString();
      final price = _asDouble(row['unit_price']);
      valueByOrder[orderId] = (valueByOrder[orderId] ?? 0) + (_asDouble(row['ordered_quantity']) * price);
      pendingValueByOrder[orderId] = (pendingValueByOrder[orderId] ?? 0) + (_asDouble(row['pending_quantity']) * price);
    }

    final openRows = orderRows.where((row) => !_closedStatuses.contains(row['status']?.toString())).toList(growable: false);
    final now = DateTime.now();
    final dueCutoff = now.add(const Duration(days: 7));

    final receiptRows = (await client
            .from('goods_receipts')
            .select('id,grn_number,purchase_order_id,supplier_id,received_at,status')
            .eq('status', 'posted')
            .order('received_at', ascending: false)
            .limit(8))
        .cast<Map<String, dynamic>>();
    final receiptLineRows = receiptRows.isEmpty
        ? <Map<String, dynamic>>[]
        : (await client
                .from('goods_receipt_lines')
                .select('goods_receipt_id')
                .inFilter('goods_receipt_id', receiptRows.map((row) => row['id'].toString()).toList(growable: false)))
            .cast<Map<String, dynamic>>();
    final receiptLineCounts = <String, int>{};
    for (final row in receiptLineRows) {
      final id = row['goods_receipt_id'].toString();
      receiptLineCounts[id] = (receiptLineCounts[id] ?? 0) + 1;
    }
    final orderNumberById = {for (final row in orderRows) row['id'].toString(): row['order_number']?.toString() ?? 'PO'};

    final supplierStats = <String, List<bool>>{};
    final orderById = {for (final row in orderRows) row['id'].toString(): row};
    for (final receipt in receiptRows) {
      final order = orderById[receipt['purchase_order_id']?.toString()];
      final supplierId = receipt['supplier_id']?.toString();
      final received = _asDate(receipt['received_at']);
      final expected = _asDate(order?['expected_delivery_date']);
      if (supplierId != null && received != null && expected != null) {
        supplierStats.putIfAbsent(supplierId, () => <bool>[]).add(!received.isAfter(expected.add(const Duration(days: 1))));
      }
    }

    return PurchaseOverview(
      openOrders: openRows.length,
      pendingApproval: orderRows.where((row) => row['status']?.toString() == 'pending_approval').length,
      dueThisWeek: openRows.where((row) {
        final date = _asDate(row['expected_delivery_date']);
        return date != null && !date.isBefore(DateTime(now.year, now.month, now.day)) && !date.isAfter(dueCutoff);
      }).length,
      outstandingValue: openRows.fold<double>(0, (sum, row) => sum + (pendingValueByOrder[row['id'].toString()] ?? 0)),
      orders: openRows
          .map((row) => PurchaseOrderSummary(
                orderNumber: row['order_number']?.toString() ?? 'PO',
                supplier: supplierById[row['supplier_id']?.toString()] ?? 'Supplier',
                expectedDate: _asDate(row['expected_delivery_date']) ?? now,
                totalValue: valueByOrder[row['id'].toString()] ?? 0,
                status: _statusLabel(row['status']?.toString(), _asDate(row['expected_delivery_date']), now),
              ))
          .toList(growable: false),
      suppliers: supplierStats.entries.map((entry) {
        final values = entry.value;
        final onTime = values.where((value) => value).length;
        return SupplierPerformance(
          name: supplierById[entry.key] ?? 'Supplier',
          onTimeRate: values.isEmpty ? 0 : onTime / values.length,
        );
      }).toList(growable: false),
      receipts: receiptRows
          .map((row) => GoodsReceiptSummary(
                grnNumber: row['grn_number']?.toString() ?? 'GRN',
                orderNumber: orderNumberById[row['purchase_order_id']?.toString()] ?? 'PO',
                lineCount: receiptLineCounts[row['id'].toString()] ?? 0,
                receivedLabel: _shortDate(_asDate(row['received_at'])),
              ))
          .toList(growable: false),
    );
  }

  @override
  Future<PurchaseOrderDetail> loadOrder(String orderNumber) async {
    final orderRows = (await client
            .from('purchase_orders')
            .select('id,order_number,supplier_id,expected_delivery_date,status,payment_terms')
            .eq('order_number', orderNumber)
            .limit(1))
        .cast<Map<String, dynamic>>();
    if (orderRows.isEmpty) throw StateError('Purchase order not found.');
    final order = orderRows.single;

    final supplierRows = (await client.from('suppliers').select('name').eq('id', order['supplier_id'].toString()).limit(1))
        .cast<Map<String, dynamic>>();
    final supplier = supplierRows.isEmpty ? 'Supplier' : supplierRows.single['name']?.toString() ?? 'Supplier';

    final progressRows = (await client
            .from('purchase_order_line_progress')
            .select('item_id,ordered_quantity,unit_price,accepted_received_quantity,pending_quantity')
            .eq('purchase_order_id', order['id'].toString()))
        .cast<Map<String, dynamic>>();
    final itemIds = progressRows.map((row) => row['item_id'].toString()).toSet().toList(growable: false);
    final itemRows = itemIds.isEmpty
        ? <Map<String, dynamic>>[]
        : (await client.from('items').select('id,sku,name,unit_id').inFilter('id', itemIds)).cast<Map<String, dynamic>>();
    final itemById = {for (final row in itemRows) row['id'].toString(): row};
    final unitIds = itemRows.map((row) => row['unit_id']?.toString()).whereType<String>().toSet().toList(growable: false);
    final unitRows = unitIds.isEmpty
        ? <Map<String, dynamic>>[]
        : (await client.from('item_units').select('id,code').inFilter('id', unitIds)).cast<Map<String, dynamic>>();
    final unitById = {for (final row in unitRows) row['id'].toString(): row['code']?.toString() ?? ''};

    final receiptRows = (await client
            .from('goods_receipts')
            .select('grn_number,warehouse_id,received_at,status')
            .eq('purchase_order_id', order['id'].toString())
            .eq('status', 'posted')
            .order('received_at', ascending: false)
            .limit(1))
        .cast<Map<String, dynamic>>();
    String deliveryLocation = 'Receiving warehouse';
    String latestGrn = 'No posted GRN yet';
    if (receiptRows.isNotEmpty) {
      final receipt = receiptRows.single;
      final warehouseRows = (await client.from('warehouses').select('code,name').eq('id', receipt['warehouse_id'].toString()).limit(1))
          .cast<Map<String, dynamic>>();
      if (warehouseRows.isNotEmpty) {
        final warehouse = warehouseRows.single;
        deliveryLocation = '${warehouse['code']} • ${warehouse['name']}';
      }
      latestGrn = '${receipt['grn_number']} • ${_shortDate(_asDate(receipt['received_at']))}';
    }

    final lines = progressRows.map((row) {
      final item = itemById[row['item_id'].toString()];
      return PurchaseOrderLine(
        sku: item?['sku']?.toString() ?? 'SKU',
        itemName: item?['name']?.toString() ?? 'Item',
        unit: unitById[item?['unit_id']?.toString()] ?? '',
        orderedQuantity: _asDouble(row['ordered_quantity']),
        receivedQuantity: _asDouble(row['accepted_received_quantity']),
        unitPrice: _asDouble(row['unit_price']),
      );
    }).toList(growable: false);
    final pending = lines.fold<double>(0, (sum, line) => sum + line.pendingQuantity);
    final status = order['status']?.toString() ?? 'unknown';

    return PurchaseOrderDetail(
      orderNumber: order['order_number']?.toString() ?? orderNumber,
      supplier: supplier,
      expectedDateLabel: _longDate(_asDate(order['expected_delivery_date'])),
      status: _statusLabel(status, _asDate(order['expected_delivery_date']), DateTime.now()),
      paymentTerms: order['payment_terms']?.toString() ?? 'Not specified',
      deliveryLocation: deliveryLocation,
      latestGrn: latestGrn,
      lines: lines,
      checks: [
        PurchaseCheck(label: 'Purchase order approved', complete: ['approved', 'part_received', 'received'].contains(status)),
        PurchaseCheck(label: 'At least one posted GRN', complete: receiptRows.isNotEmpty),
        PurchaseCheck(label: pending <= 0 ? 'All ordered quantity received' : '${pending.toStringAsFixed(0)} units still pending', complete: pending <= 0),
      ],
    );
  }
}

const _closedStatuses = {'received', 'cancelled', 'closed'};

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _asDate(dynamic value) => value == null ? null : DateTime.tryParse(value.toString());

String _statusLabel(String? status, DateTime? expected, DateTime now) {
  if (expected != null && expected.isBefore(DateTime(now.year, now.month, now.day)) && !{'received', 'cancelled', 'closed'}.contains(status)) {
    return 'Overdue';
  }
  return switch (status) {
    'pending_approval' => 'Pending approval',
    'part_received' => 'Part received',
    'approved' => 'Approved',
    'received' => 'Received',
    'cancelled' => 'Cancelled',
    'closed' => 'Closed',
    'draft' => 'Draft',
    _ => status ?? 'Unknown',
  };
}

String _shortDate(DateTime? value) => value == null ? '—' : '${value.day} ${_month(value.month)}';
String _longDate(DateTime? value) => value == null ? '—' : '${value.day} ${_month(value.month)} ${value.year}';
String _month(int month) => const ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][month.clamp(1, 12) - 1];
