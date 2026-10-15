import 'package:supabase_flutter/supabase_flutter.dart';

import 'inventory_item_detail_repository.dart';

final class SupabaseInventoryItemDetailRepository implements InventoryItemDetailRepository {
  const SupabaseInventoryItemDetailRepository(this.client);

  final SupabaseClient client;

  @override
  Future<InventoryItemDetail> loadItem(String sku) async {
    final item = await client
        .from('items')
        .select(
          'id,sku,name,category_id,unit_id,barcode,cost,reorder_level,batch_tracking,serial_tracking',
        )
        .eq('sku', sku)
        .single();
    final itemId = item['id'].toString();

    final category = await client
        .from('item_categories')
        .select('name')
        .eq('id', item['category_id'])
        .maybeSingle();
    final unit = await client
        .from('item_units')
        .select('code')
        .eq('id', item['unit_id'])
        .maybeSingle();

    final balances = (await client
            .from('inventory_balances')
            .select('warehouse_id,location_id,quantity_on_hand,last_movement_at')
            .eq('item_id', itemId))
        .cast<Map<String, dynamic>>();
    final onHand = balances.fold<double>(0, (sum, row) => sum + _asDouble(row['quantity_on_hand']));

    Map<String, dynamic>? primaryBalance;
    for (final row in balances) {
      if (_asDouble(row['quantity_on_hand']) <= 0) continue;
      if (primaryBalance == null ||
          _asDouble(row['quantity_on_hand']) > _asDouble(primaryBalance['quantity_on_hand'])) {
        primaryBalance = row;
      }
    }

    var locationLabel = 'No stock location';
    if (primaryBalance != null) {
      final warehouse = await client
          .from('warehouses')
          .select('code')
          .eq('id', primaryBalance['warehouse_id'])
          .maybeSingle();
      final locationId = primaryBalance['location_id'];
      final location = locationId == null
          ? null
          : await client
              .from('warehouse_locations')
              .select('code')
              .eq('id', locationId)
              .maybeSingle();
      final warehouseCode = warehouse?['code']?.toString() ?? 'WH';
      final locationCode = location?['code']?.toString();
      locationLabel = locationCode == null ? warehouseCode : '$warehouseCode • $locationCode';
    }

    final rawLines = (await client
            .from('stock_transaction_lines')
            .select('stock_transaction_id,quantity_delta,created_at')
            .eq('item_id', itemId)
            .order('created_at', ascending: false)
            .limit(30))
        .cast<Map<String, dynamic>>();
    final transactionIds = rawLines
        .map((row) => row['stock_transaction_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final transactions = transactionIds.isEmpty
        ? <Map<String, dynamic>>[]
        : (await client
                .from('stock_transactions')
                .select('id,transaction_number,transaction_type,occurred_at,status')
                .inFilter('id', transactionIds)
                .eq('status', 'posted'))
            .cast<Map<String, dynamic>>();
    final transactionById = {
      for (final row in transactions) row['id'].toString(): row,
    };

    final movements = <InventoryMovement>[];
    for (final line in rawLines) {
      final transaction = transactionById[line['stock_transaction_id']?.toString()];
      if (transaction == null) continue;
      movements.add(
        InventoryMovement(
          time: _formatDateTime(transaction['occurred_at']),
          type: _titleCase(transaction['transaction_type']?.toString() ?? 'movement'),
          reference: transaction['transaction_number']?.toString() ?? 'Stock movement',
          quantityDelta: _asDouble(line['quantity_delta']),
        ),
      );
    }

    var inboundPending = 0.0;
    try {
      final purchaseProgress = (await client
              .from('purchase_order_line_progress')
              .select('pending_quantity')
              .eq('item_id', itemId))
          .cast<Map<String, dynamic>>();
      inboundPending = purchaseProgress.fold<double>(
        0,
        (sum, row) => sum + _asDouble(row['pending_quantity']),
      );
    } catch (_) {
      // Purchase visibility is optional for an inventory-only role. Item truth still loads.
    }

    final batchTracking = item['batch_tracking'] == true;
    final serialTracking = item['serial_tracking'] == true;
    final tracking = serialTracking
        ? 'Serial controlled'
        : batchTracking
            ? 'Batch controlled'
            : 'Standard stock';

    return InventoryItemDetail(
      sku: item['sku']?.toString() ?? sku,
      name: item['name']?.toString() ?? 'Unnamed item',
      category: category?['name']?.toString() ?? 'Other',
      unit: unit?['code']?.toString() ?? '',
      barcode: item['barcode']?.toString() ?? 'Not assigned',
      onHand: onHand,
      reorderLevel: _asDouble(item['reorder_level']),
      reserved: 0,
      standardCost: _asDouble(item['cost']),
      tracking: tracking,
      location: locationLabel,
      inboundPending: inboundPending,
      movements: movements,
    );
  }
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

String _titleCase(String value) => value
    .split('_')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

String _formatDateTime(dynamic value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  if (parsed == null) return 'Unknown time';
  final local = parsed.toLocal();
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.day} ${months[local.month - 1]} $hour:$minute';
}
