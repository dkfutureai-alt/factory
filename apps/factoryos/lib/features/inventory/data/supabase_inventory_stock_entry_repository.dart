import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/inventory_stock_entry_models.dart';
import 'inventory_stock_entry_repository.dart';

final class SupabaseInventoryStockEntryRepository implements InventoryStockEntryRepository {
  const SupabaseInventoryStockEntryRepository(this.client);

  final SupabaseClient client;

  @override
  bool get supportsPosting => true;

  @override
  Future<InventoryStockEntryOptions> loadOptions() async {
    final itemRows = (await client
            .from('items')
            .select('id,sku,name,unit_id,cost,batch_tracking,serial_tracking')
            .eq('status', 'active')
            .order('name'))
        .cast<Map<String, dynamic>>();
    final warehouseRows = (await client
            .from('warehouses')
            .select('id,code,name')
            .eq('status', 'active')
            .order('code'))
        .cast<Map<String, dynamic>>();
    final locationRows = (await client
            .from('warehouse_locations')
            .select('id,warehouse_id,code,name')
            .eq('status', 'active')
            .order('code'))
        .cast<Map<String, dynamic>>();
    final batchRows = (await client
            .from('batches')
            .select('id,item_id,batch_number')
            .eq('status', 'active')
            .order('batch_number'))
        .cast<Map<String, dynamic>>();
    final serialRows = (await client
            .from('serial_numbers')
            .select('id,item_id,serial_number,status,current_warehouse_id,current_location_id')
            .order('serial_number'))
        .cast<Map<String, dynamic>>();
    final balanceRows = (await client
            .from('inventory_balances')
            .select('item_id,warehouse_id,location_id,batch_id,serial_number_id,quantity_on_hand'))
        .cast<Map<String, dynamic>>();

    final unitIds = itemRows
        .map((row) => row['unit_id'])
        .where((value) => value != null)
        .map((value) => value.toString())
        .toSet()
        .toList(growable: false);
    final unitRows = unitIds.isEmpty
        ? <Map<String, dynamic>>[]
        : (await client.from('item_units').select('id,code').inFilter('id', unitIds))
            .cast<Map<String, dynamic>>();
    final unitById = {
      for (final row in unitRows) row['id'].toString(): row['code']?.toString() ?? '',
    };

    final totalByItem = <String, double>{};
    for (final row in balanceRows) {
      final itemId = row['item_id']?.toString();
      if (itemId == null) continue;
      totalByItem[itemId] = (totalByItem[itemId] ?? 0) + _asDouble(row['quantity_on_hand']);
    }

    return InventoryStockEntryOptions(
      items: itemRows
          .map(
            (row) => InventoryStockEntryItemOption(
              id: row['id'].toString(),
              sku: row['sku']?.toString() ?? 'Unknown SKU',
              name: row['name']?.toString() ?? 'Unnamed item',
              unit: unitById[row['unit_id']?.toString()] ?? '',
              defaultUnitCost: _asDouble(row['cost']),
              batchTracking: row['batch_tracking'] == true,
              serialTracking: row['serial_tracking'] == true,
              totalOnHand: totalByItem[row['id'].toString()] ?? 0,
            ),
          )
          .toList(growable: false),
      warehouses: warehouseRows
          .map(
            (row) => InventoryStockEntryWarehouseOption(
              id: row['id'].toString(),
              code: row['code']?.toString() ?? 'WH',
              name: row['name']?.toString() ?? 'Warehouse',
            ),
          )
          .toList(growable: false),
      locations: locationRows
          .map(
            (row) => InventoryStockEntryLocationOption(
              id: row['id'].toString(),
              warehouseId: row['warehouse_id'].toString(),
              code: row['code']?.toString() ?? 'Location',
              name: row['name']?.toString() ?? row['code']?.toString() ?? 'Location',
            ),
          )
          .toList(growable: false),
      batches: batchRows
          .map(
            (row) => InventoryStockEntryBatchOption(
              id: row['id'].toString(),
              itemId: row['item_id'].toString(),
              batchNumber: row['batch_number']?.toString() ?? 'Batch',
            ),
          )
          .toList(growable: false),
      serials: serialRows
          .map(
            (row) => InventoryStockEntrySerialOption(
              id: row['id'].toString(),
              itemId: row['item_id'].toString(),
              serialNumber: row['serial_number']?.toString() ?? 'Serial',
              status: row['status']?.toString() ?? 'available',
              currentWarehouseId: row['current_warehouse_id']?.toString(),
              currentLocationId: row['current_location_id']?.toString(),
            ),
          )
          .toList(growable: false),
      balances: balanceRows
          .map(
            (row) => InventoryStockEntryBalance(
              itemId: row['item_id'].toString(),
              warehouseId: row['warehouse_id'].toString(),
              locationId: row['location_id']?.toString(),
              batchId: row['batch_id']?.toString(),
              serialNumberId: row['serial_number_id']?.toString(),
              quantity: _asDouble(row['quantity_on_hand']),
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<InventoryStockEntryResult> postAdjustment(InventoryStockEntryRequest request) async {
    final raw = await client.rpc(
      'post_manual_stock_adjustment',
      params: {
        'target_warehouse_id': request.warehouseId,
        'target_location_id': request.locationId,
        'target_item_id': request.itemId,
        'target_batch_id': request.batchId,
        'target_serial_number_id': request.serialNumberId,
        'target_quantity_delta': request.quantityDelta,
        'target_unit_cost': request.unitCost,
        'target_reason': request.reason.trim(),
        'target_idempotency_key': request.idempotencyKey.trim(),
      },
    );

    final row = Map<String, dynamic>.from(raw as Map);
    return InventoryStockEntryResult(
      transactionId: row['id']?.toString() ?? '',
      transactionNumber: row['transaction_number']?.toString() ?? 'Adjustment',
      status: row['status']?.toString() ?? 'unknown',
    );
  }
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
