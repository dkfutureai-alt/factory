import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/dispatch_models.dart';
import 'dispatch_repository.dart';

final class SupabaseDispatchRepository implements DispatchRepository {
  const SupabaseDispatchRepository(this.client);

  final SupabaseClient client;

  @override
  bool get supportsMutations => true;

  @override
  Future<DispatchOverview> loadOverview() async {
    final rawOrders = await client
        .from('dispatch_orders')
        .select(
          'id,dispatch_number,sales_order_id,trip_id,loading_bay,package_count,weight_kg,status,dispatched_at,created_at',
        )
        .order('created_at', ascending: false)
        .limit(30);
    final dispatchRows = rawOrders.cast<Map<String, dynamic>>();

    final salesOrderIds = _nonNullIds(dispatchRows.map((row) => row['sales_order_id']));
    final salesRows = salesOrderIds.isEmpty
        ? <Map<String, dynamic>>[]
        : (await client.from('sales_orders').select('id,customer_id').inFilter('id', salesOrderIds))
            .cast<Map<String, dynamic>>();
    final salesById = {for (final row in salesRows) row['id'].toString(): row};

    final customerIds = _nonNullIds(salesRows.map((row) => row['customer_id']));
    final customerRows = customerIds.isEmpty
        ? <Map<String, dynamic>>[]
        : (await client.from('customers').select('id,name,city').inFilter('id', customerIds))
            .cast<Map<String, dynamic>>();
    final customerById = {for (final row in customerRows) row['id'].toString(): row};

    final tripIds = _nonNullIds(dispatchRows.map((row) => row['trip_id']));
    final tripRows = tripIds.isEmpty
        ? <Map<String, dynamic>>[]
        : (await client.from('trips').select('id,vehicle_id').inFilter('id', tripIds))
            .cast<Map<String, dynamic>>();
    final tripById = {for (final row in tripRows) row['id'].toString(): row};

    final vehicleIds = _nonNullIds(tripRows.map((row) => row['vehicle_id']));
    final vehicleRows = vehicleIds.isEmpty
        ? <Map<String, dynamic>>[]
        : (await client.from('vehicles').select('id,registration_number').inFilter('id', vehicleIds))
            .cast<Map<String, dynamic>>();
    final vehicleById = {
      for (final row in vehicleRows) row['id'].toString(): row['registration_number']?.toString() ?? 'Assigned vehicle',
    };

    final now = DateTime.now().toUtc();
    final dayStart = DateTime.utc(now.year, now.month, now.day);
    final recent = dispatchRows.take(8).map((row) {
      final sales = salesById[row['sales_order_id']?.toString()] ?? const <String, dynamic>{};
      final customer = customerById[sales['customer_id']?.toString()] ?? const <String, dynamic>{};
      return DispatchOrderSummary(
        orderNumber: row['dispatch_number']?.toString() ?? 'Dispatch',
        customer: customer['name']?.toString() ?? 'Customer',
        city: customer['city']?.toString() ?? '',
        packages: _asInt(row['package_count']),
        weightKg: _asDouble(row['weight_kg']),
        status: _titleCase(row['status']?.toString() ?? 'planned'),
      );
    }).toList(growable: false);

    final activeBays = dispatchRows
        .where((row) => row['loading_bay'] != null && row['status'] != 'dispatched' && row['status'] != 'cancelled')
        .take(5)
        .map((row) {
      final trip = tripById[row['trip_id']?.toString()] ?? const <String, dynamic>{};
      final vehicle = vehicleById[trip['vehicle_id']?.toString()] ?? 'Assigned vehicle';
      final status = row['status']?.toString();
      final progress = status == 'loaded' ? 1.0 : status == 'loading' ? .5 : .1;
      return LoadingBay(name: row['loading_bay'].toString(), vehicle: vehicle, progress: progress);
    }).toList(growable: false);

    var checks = const <DispatchCheck>[];
    if (dispatchRows.isNotEmpty) {
      final checkRows = await client
          .from('dispatch_checks')
          .select('label,is_complete')
          .eq('dispatch_order_id', dispatchRows.first['id']);
      checks = checkRows
          .cast<Map<String, dynamic>>()
          .map((row) => DispatchCheck(label: row['label']?.toString() ?? 'Dispatch check', complete: row['is_complete'] == true))
          .toList(growable: false);
    }

    return DispatchOverview(
      readyOrders: dispatchRows.where((row) => row['status'] == 'ready').length,
      loadingOrders: dispatchRows.where((row) => row['status'] == 'loading' || row['status'] == 'loaded').length,
      dispatchedToday: dispatchRows.where((row) {
        final dispatchedAt = DateTime.tryParse(row['dispatched_at']?.toString() ?? '');
        return dispatchedAt != null && !dispatchedAt.toUtc().isBefore(dayStart);
      }).length,
      blockedOrders: dispatchRows.where((row) => row['status'] == 'blocked').length,
      orders: recent,
      bays: activeBays,
      checks: checks,
    );
  }

  @override
  Future<DispatchLoadDetail> loadDispatch(String dispatchNumber) async {
    final dispatch = await client
        .from('dispatch_orders')
        .select(
          'id,dispatch_number,sales_order_id,trip_id,loading_bay,package_count,weight_kg,status',
        )
        .eq('dispatch_number', dispatchNumber)
        .single();

    final dispatchId = dispatch['id'].toString();
    final salesOrder = await client
        .from('sales_orders')
        .select('order_number,customer_id')
        .eq('id', dispatch['sales_order_id'])
        .single();
    final customer = await client
        .from('customers')
        .select('name')
        .eq('id', salesOrder['customer_id'])
        .single();

    var tripNumber = '';
    var vehicleRegistration = 'Not assigned';
    var driverName = 'Not assigned';
    final tripId = dispatch['trip_id']?.toString();
    if (tripId != null && tripId.isNotEmpty) {
      final trip = await client
          .from('trips')
          .select('trip_number,vehicle_id,driver_employee_id')
          .eq('id', tripId)
          .single();
      tripNumber = trip['trip_number']?.toString() ?? '';

      final vehicle = await client
          .from('vehicles')
          .select('registration_number')
          .eq('id', trip['vehicle_id'])
          .maybeSingle();
      if (vehicle != null) {
        vehicleRegistration = vehicle['registration_number']?.toString() ?? vehicleRegistration;
      }

      final driver = await client
          .from('employees')
          .select('first_name,last_name')
          .eq('id', trip['driver_employee_id'])
          .maybeSingle();
      if (driver != null) {
        driverName = '${driver['first_name']} ${driver['last_name']}'.trim();
      }
    }

    final rawLines = await client
        .from('dispatch_lines')
        .select('item_id,batch_id,planned_quantity,loaded_quantity,stock_transaction_line_id')
        .eq('dispatch_order_id', dispatchId);
    final lineRows = rawLines.cast<Map<String, dynamic>>();

    final itemIds = _nonNullIds(lineRows.map((row) => row['item_id']));
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

    final batchIds = _nonNullIds(lineRows.map((row) => row['batch_id']));
    final batchRows = batchIds.isEmpty
        ? <Map<String, dynamic>>[]
        : (await client.from('batches').select('id,batch_number').inFilter('id', batchIds))
            .cast<Map<String, dynamic>>();
    final batchById = {for (final row in batchRows) row['id'].toString(): row['batch_number']?.toString()};

    final lines = lineRows.map((row) {
      final item = itemById[row['item_id']?.toString()] ?? const <String, dynamic>{};
      final unitId = item['unit_id']?.toString();
      final batchId = row['batch_id']?.toString();
      return DispatchLoadLine(
        sku: item['sku']?.toString() ?? 'Unknown SKU',
        name: item['name']?.toString() ?? 'Unknown item',
        batchNumber: batchId == null ? null : batchById[batchId],
        plannedQuantity: _asDouble(row['planned_quantity']),
        loadedQuantity: _asDouble(row['loaded_quantity']),
        unit: unitId == null ? '' : unitById[unitId] ?? '',
        ledgerPosted: row['stock_transaction_line_id'] != null,
      );
    }).toList(growable: false);

    final rawChecks = await client
        .from('dispatch_checks')
        .select('label,is_required,is_complete')
        .eq('dispatch_order_id', dispatchId);
    final checks = rawChecks.cast<Map<String, dynamic>>().map((row) {
      return DispatchRequiredCheck(
        label: row['label']?.toString() ?? 'Dispatch check',
        required: row['is_required'] == true,
        complete: row['is_complete'] == true,
      );
    }).toList(growable: false);

    return DispatchLoadDetail(
      dispatchNumber: dispatch['dispatch_number']?.toString() ?? dispatchNumber,
      salesOrderNumber: salesOrder['order_number']?.toString() ?? 'Sales order',
      customer: customer['name']?.toString() ?? 'Customer',
      status: _titleCase(dispatch['status']?.toString() ?? 'planned'),
      loadingBay: dispatch['loading_bay']?.toString() ?? 'No loading bay',
      vehicleRegistration: vehicleRegistration,
      driverName: driverName,
      tripNumber: tripNumber,
      packageCount: _asInt(dispatch['package_count']),
      weightKg: _asDouble(dispatch['weight_kg']),
      lines: lines,
      checks: checks,
    );
  }

  @override
  Future<DispatchLoadDetail> postStock(String dispatchNumber) async {
    final row = await client.from('dispatch_orders').select('id').eq('dispatch_number', dispatchNumber).single();
    await client.rpc('post_dispatch_stock', params: {'target_dispatch_id': row['id']});
    return loadDispatch(dispatchNumber);
  }

  @override
  Future<DispatchLoadDetail> finalizeDispatch(String dispatchNumber) async {
    final row = await client.from('dispatch_orders').select('id').eq('dispatch_number', dispatchNumber).single();
    await client.rpc('finalize_dispatch', params: {'target_dispatch_id': row['id']});
    return loadDispatch(dispatchNumber);
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

int _asInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _titleCase(String value) => value
    .split('_')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');
