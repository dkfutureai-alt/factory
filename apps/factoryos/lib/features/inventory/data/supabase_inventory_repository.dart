import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/inventory_models.dart';
import 'inventory_repository.dart';

final class SupabaseInventoryRepository implements InventoryRepository {
  const SupabaseInventoryRepository(this.client);

  final SupabaseClient client;

  @override
  Future<InventoryOverview> loadOverview() async {
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();

    final itemRows = (await client
            .from('items')
            .select('id,sku,name,category_id,unit_id,cost,reorder_level')
            .eq('status', 'active')
            .order('name')
            .limit(200))
        .cast<Map<String, dynamic>>();

    final categoryIds = _ids(itemRows.map((row) => row['category_id']));
    final unitIds = _ids(itemRows.map((row) => row['unit_id']));
    final categoryRows = categoryIds.isEmpty
        ? <Map<String, dynamic>>[]
        : (await client.from('item_categories').select('id,name').inFilter('id', categoryIds))
            .cast<Map<String, dynamic>>();
    final unitRows = unitIds.isEmpty
        ? <Map<String, dynamic>>[]
        : (await client.from('item_units').select('id,code').inFilter('id', unitIds))
            .cast<Map<String, dynamic>>();

    final balanceRows = (await client
            .from('inventory_balances')
            .select('item_id,warehouse_id,location_id,quantity_on_hand,last_movement_at'))
        .cast<Map<String, dynamic>>();
    final warehouseIds = _ids(balanceRows.map((row) => row['warehouse_id']));
    final locationIds = _ids(balanceRows.map((row) => row['location_id']));
    final warehouseRows = warehouseIds.isEmpty
        ? <Map<String, dynamic>>[]
        : (await client.from('warehouses').select('id,code').inFilter('id', warehouseIds))
            .cast<Map<String, dynamic>>();
    final locationRows = locationIds.isEmpty
        ? <Map<String, dynamic>>[]
        : (await client.from('warehouse_locations').select('id,code').inFilter('id', locationIds))
            .cast<Map<String, dynamic>>();

    final todayTransactions = (await client
            .from('stock_transactions')
            .select('id')
            .eq('status', 'posted')
            .gte('occurred_at', dayStart))
        .cast<Map<String, dynamic>>();
    final damagedSerials = (await client
            .from('serial_numbers')
            .select('id')
            .inFilter('status', const ['damaged', 'scrapped']))
        .cast<Map<String, dynamic>>();

    final categoryById = {
      for (final row in categoryRows) row['id'].toString(): row['name']?.toString() ?? 'Other',
    };
    final unitById = {
      for (final row in unitRows) row['id'].toString(): row['code']?.toString() ?? '',
    };
    final warehouseById = {
      for (final row in warehouseRows) row['id'].toString(): row['code']?.toString() ?? 'WH',
    };
    final locationById = {
      for (final row in locationRows) row['id'].toString(): row['code']?.toString() ?? 'Location',
    };

    final balancesByItem = <String, List<Map<String, dynamic>>>{};
    for (final row in balanceRows) {
      balancesByItem.putIfAbsent(row['item_id'].toString(), () => []).add(row);
    }

    var stockValue = 0.0;
    var lowStockCount = 0;
    final summaries = <InventoryItemSummary>[];
    for (final item in itemRows) {
      final itemId = item['id'].toString();
      final balances = balancesByItem[itemId] ?? const <Map<String, dynamic>>[];
      final onHand = balances.fold<double>(0, (sum, row) => sum + _asDouble(row['quantity_on_hand']));
      final reorderLevel = _asDouble(item['reorder_level']);
      final cost = _asDouble(item['cost']);
      stockValue += onHand * cost;
      if (onHand <= reorderLevel) lowStockCount++;

      Map<String, dynamic>? primaryBalance;
      for (final row in balances) {
        if (_asDouble(row['quantity_on_hand']) <= 0) continue;
        if (primaryBalance == null ||
            _asDouble(row['quantity_on_hand']) > _asDouble(primaryBalance['quantity_on_hand'])) {
          primaryBalance = row;
        }
      }
      final warehouse = primaryBalance == null
          ? null
          : warehouseById[primaryBalance['warehouse_id']?.toString()];
      final location = primaryBalance == null
          ? null
          : locationById[primaryBalance['location_id']?.toString()];
      final locationLabel = warehouse == null
          ? 'No stock location'
          : location == null
              ? warehouse
              : '$warehouse / $location';

      summaries.add(
        InventoryItemSummary(
          sku: item['sku']?.toString() ?? 'Unknown SKU',
          name: item['name']?.toString() ?? 'Unnamed item',
          category: categoryById[item['category_id']?.toString()] ?? 'Other',
          location: locationLabel,
          onHand: onHand,
          unit: unitById[item['unit_id']?.toString()] ?? '',
          reorderLevel: reorderLevel,
        ),
      );
    }

    return InventoryOverview(
      stockValue: stockValue,
      activeSkuCount: itemRows.length,
      lowStockCount: lowStockCount,
      todayMovements: todayTransactions.length,
      blockedOrDamagedCount: damagedSerials.length,
      items: summaries,
    );
  }
}

List<String> _ids(Iterable<dynamic> values) => values
    .where((value) => value != null)
    .map((value) => value.toString())
    .where((value) => value.isNotEmpty)
    .toSet()
    .toList(growable: false);

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
