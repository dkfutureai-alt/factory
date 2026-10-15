import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/warehouse_models.dart';
import 'warehouse_repository.dart';

final class SupabaseWarehouseRepository implements WarehouseRepository {
  const SupabaseWarehouseRepository(this.client);

  final SupabaseClient client;

  @override
  bool get supportsMutations => true;

  @override
  Future<WarehouseOverview> loadOverview() async {
    final now = DateTime.now().toUtc();
    final dayStart = DateTime.utc(now.year, now.month, now.day).toIso8601String();

    final transferRows = await client
        .from('warehouse_transfers')
        .select('transfer_number,status,reason,assigned_employee_id,created_at')
        .order('created_at', ascending: false)
        .limit(20);
    final stockRows = await client
        .from('stock_transactions')
        .select('transaction_type')
        .eq('status', 'posted')
        .gte('occurred_at', dayStart);

    final transfers = transferRows.cast<Map<String, dynamic>>();
    final stock = stockRows.cast<Map<String, dynamic>>();
    final transfersToday = transfers.where((row) {
      final created = DateTime.tryParse(row['created_at']?.toString() ?? '');
      return created != null && !created.toUtc().isBefore(DateTime.parse(dayStart));
    }).length;

    return WarehouseOverview(
      receiptsToday: stock.where((row) => row['transaction_type'] == 'purchase_receipt').length,
      issuesToday: stock.where((row) {
        final type = row['transaction_type'];
        return type == 'production_issue' || type == 'sales_dispatch' || type == 'maintenance_issue';
      }).length,
      transfersToday: transfersToday,
      pendingPutaway: 0,
      tasks: transfers.take(8).map((row) {
        final reason = (row['reason']?.toString().trim().isNotEmpty ?? false)
            ? row['reason'].toString().trim()
            : 'Warehouse transfer';
        return WarehouseTask(
          type: 'Transfer',
          reference: row['transfer_number']?.toString() ?? 'Transfer',
          detail: reason,
          assignee: row['assigned_employee_id'] == null ? 'Unassigned' : 'Assigned employee',
          status: _titleCase(row['status']?.toString() ?? 'draft'),
        );
      }).toList(growable: false),
      utilization: const [],
    );
  }

  @override
  Future<WarehouseTransferDetail> loadTransfer(String transferNumber) async {
    final transfer = await client
        .from('warehouse_transfers')
        .select(
          'id,transfer_number,status,reason,assigned_employee_id,out_stock_transaction_id,in_stock_transaction_id,source_warehouse_id,destination_warehouse_id',
        )
        .eq('transfer_number', transferNumber)
        .single();

    final transferId = transfer['id'].toString();
    final sourceWarehouseId = transfer['source_warehouse_id'].toString();
    final destinationWarehouseId = transfer['destination_warehouse_id'].toString();
    final warehouseRows = await client
        .from('warehouses')
        .select('id,code,name')
        .inFilter('id', [sourceWarehouseId, destinationWarehouseId]);
    final warehouseLabels = <String, String>{
      for (final row in warehouseRows.cast<Map<String, dynamic>>())
        row['id'].toString(): '${row['code']} • ${row['name']}',
    };

    var assignee = 'Unassigned';
    final assignedEmployeeId = transfer['assigned_employee_id']?.toString();
    if (assignedEmployeeId != null && assignedEmployeeId.isNotEmpty) {
      final employee = await client
          .from('employees')
          .select('first_name,last_name')
          .eq('id', assignedEmployeeId)
          .maybeSingle();
      if (employee != null) {
        assignee = '${employee['first_name']} ${employee['last_name']}'.trim();
      }
    }

    final rawLines = await client
        .from('warehouse_transfer_lines')
        .select('item_id,batch_id,source_location_id,destination_location_id,quantity')
        .eq('warehouse_transfer_id', transferId);
    final lines = rawLines.cast<Map<String, dynamic>>();

    final itemIds = _nonNullIds(lines.map((row) => row['item_id']));
    final itemRows = itemIds.isEmpty
        ? <Map<String, dynamic>>[]
        : (await client.from('items').select('id,sku,name,unit_id').inFilter('id', itemIds))
            .cast<Map<String, dynamic>>();
    final itemById = {for (final row in itemRows) row['id'].toString(): row};

    final unitIds = _nonNullIds(itemRows.map((row) => row['unit_id']));
    final unitRows = unitIds.isEmpty
        ? <Map<String, dynamic>>[]
        : (await client.from('item_units').select('id,code').inFilter('id', unitIds))
            .cast<Map<String, dynamic>>();
    final unitById = {for (final row in unitRows) row['id'].toString(): row['code']?.toString() ?? ''};

    final batchIds = _nonNullIds(lines.map((row) => row['batch_id']));
    final batchRows = batchIds.isEmpty
        ? <Map<String, dynamic>>[]
        : (await client.from('batches').select('id,batch_number').inFilter('id', batchIds))
            .cast<Map<String, dynamic>>();
    final batchById = {for (final row in batchRows) row['id'].toString(): row['batch_number']?.toString()};

    final locationIds = _nonNullIds([
      ...lines.map((row) => row['source_location_id']),
      ...lines.map((row) => row['destination_location_id']),
    ]);
    final locationRows = locationIds.isEmpty
        ? <Map<String, dynamic>>[]
        : (await client.from('warehouse_locations').select('id,code').inFilter('id', locationIds))
            .cast<Map<String, dynamic>>();
    final locationById = {for (final row in locationRows) row['id'].toString(): row['code']?.toString() ?? 'Location'};

    final mappedLines = lines.map((row) {
      final item = itemById[row['item_id']?.toString()] ?? const <String, dynamic>{};
      final unitId = item['unit_id']?.toString();
      final batchId = row['batch_id']?.toString();
      final sourceLocationId = row['source_location_id']?.toString();
      final destinationLocationId = row['destination_location_id']?.toString();
      return WarehouseTransferLine(
        sku: item['sku']?.toString() ?? 'Unknown SKU',
        name: item['name']?.toString() ?? 'Unknown item',
        batchNumber: batchId == null ? null : batchById[batchId],
        fromLocation: sourceLocationId == null ? 'Warehouse' : locationById[sourceLocationId] ?? 'Warehouse',
        toLocation: destinationLocationId == null ? 'Warehouse' : locationById[destinationLocationId] ?? 'Warehouse',
        quantity: _asDouble(row['quantity']),
        unit: unitId == null ? '' : unitById[unitId] ?? '',
      );
    }).toList(growable: false);

    return WarehouseTransferDetail(
      transferNumber: transfer['transfer_number']?.toString() ?? transferNumber,
      status: _titleCase(transfer['status']?.toString() ?? 'draft'),
      sourceWarehouse: warehouseLabels[sourceWarehouseId] ?? 'Source warehouse',
      destinationWarehouse: warehouseLabels[destinationWarehouseId] ?? 'Destination warehouse',
      reason: transfer['reason']?.toString() ?? 'Warehouse transfer',
      assignee: assignee,
      outLedgerPosted: transfer['out_stock_transaction_id'] != null,
      inLedgerPosted: transfer['in_stock_transaction_id'] != null,
      lines: mappedLines,
    );
  }

  @override
  Future<WarehouseTransferDetail> completeTransfer(String transferNumber) async {
    final row = await client
        .from('warehouse_transfers')
        .select('id')
        .eq('transfer_number', transferNumber)
        .single();
    await client.rpc(
      'complete_warehouse_transfer',
      params: {'target_transfer_id': row['id']},
    );
    return loadTransfer(transferNumber);
  }
}

List<String> _nonNullIds(Iterable<dynamic> values) => values
    .where((value) => value != null)
    .map((value) => value.toString())
    .where((value) => value.isNotEmpty)
    .toSet()
    .toList(growable: false);

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

String _titleCase(String value) => value
    .split('_')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');
