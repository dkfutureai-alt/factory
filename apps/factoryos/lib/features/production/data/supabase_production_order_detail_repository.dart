import 'package:supabase_flutter/supabase_flutter.dart';

import 'production_order_detail_repository.dart';

final class SupabaseProductionOrderDetailRepository implements ProductionOrderDetailRepository {
  const SupabaseProductionOrderDetailRepository(this.client);

  final SupabaseClient client;

  @override
  bool get supportsCompletion => true;

  @override
  Future<ProductionOrderDetail> loadOrder(String number) async {
    final order = await client
        .from('production_orders')
        .select(
          'id,order_number,item_id,production_line_id,status,planned_quantity,completed_quantity,rejected_quantity,actual_start_at,planned_start_at,planned_end_at,actual_end_at,notes',
        )
        .eq('order_number', number)
        .single();
    final orderId = order['id'].toString();

    final item = await client
        .from('items')
        .select('name')
        .eq('id', order['item_id'])
        .maybeSingle();
    final lineId = order['production_line_id'];
    final line = lineId == null
        ? null
        : await client.from('production_lines').select('code').eq('id', lineId).maybeSingle();

    final batchRows = (await client
            .from('production_batches')
            .select('id,batch_number,status,good_quantity,rejected_quantity,started_at,completed_at,created_at')
            .eq('production_order_id', orderId)
            .order('created_at', ascending: false)
            .limit(1))
        .cast<Map<String, dynamic>>();
    final batch = batchRows.isEmpty ? null : batchRows.first;

    Map<String, dynamic>? quality;
    if (batch != null) {
      final qualityRows = (await client
              .from('quality_checks')
              .select('check_number,result,rejected_quantity,inspected_at,rejection_reason')
              .eq('production_batch_id', batch['id'])
              .order('created_at', ascending: false)
              .limit(1))
          .cast<Map<String, dynamic>>();
      quality = qualityRows.isEmpty ? null : qualityRows.first;
    }

    final requirementRows = (await client
            .from('production_material_requirements')
            .select('item_id,planned_quantity,issued_quantity,returned_quantity')
            .eq('production_order_id', orderId))
        .cast<Map<String, dynamic>>();
    final requirementItemIds = requirementRows
        .map((row) => row['item_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final requirementItems = requirementItemIds.isEmpty
        ? <Map<String, dynamic>>[]
        : (await client
                .from('items')
                .select('id,sku,name,unit_id')
                .inFilter('id', requirementItemIds))
            .cast<Map<String, dynamic>>();
    final requirementItemById = {
      for (final row in requirementItems) row['id'].toString(): row,
    };
    final unitIds = requirementItems
        .map((row) => row['unit_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final unitRows = unitIds.isEmpty
        ? <Map<String, dynamic>>[]
        : (await client.from('item_units').select('id,code').inFilter('id', unitIds))
            .cast<Map<String, dynamic>>();
    final unitById = {
      for (final row in unitRows) row['id'].toString(): row['code']?.toString() ?? '',
    };

    final availabilityByItem = <String, double>{};
    if (requirementItemIds.isNotEmpty) {
      final balances = (await client
              .from('inventory_balances')
              .select('item_id,quantity_on_hand')
              .inFilter('item_id', requirementItemIds))
          .cast<Map<String, dynamic>>();
      for (final row in balances) {
        final id = row['item_id'].toString();
        availabilityByItem[id] = (availabilityByItem[id] ?? 0) + _asDouble(row['quantity_on_hand']);
      }
    }

    final materials = requirementRows.map((row) {
      final itemId = row['item_id'].toString();
      final material = requirementItemById[itemId] ?? const <String, dynamic>{};
      final unitId = material['unit_id']?.toString();
      return ProductionMaterialRequirement(
        sku: material['sku']?.toString() ?? 'Unknown SKU',
        name: material['name']?.toString() ?? 'Unknown material',
        required: _asDouble(row['planned_quantity']),
        available: availabilityByItem[itemId] ?? 0,
        unit: unitId == null ? '' : unitById[unitId] ?? '',
      );
    }).toList(growable: false);

    final timeline = <ProductionTimelineEvent>[];
    final actualStart = order['actual_start_at'] ?? batch?['started_at'];
    if (actualStart != null) {
      timeline.add(
        ProductionTimelineEvent(
          title: 'Order started',
          detail: line?['code']?.toString() ?? 'Production line',
          time: _formatTime(actualStart),
          isWarning: false,
        ),
      );
    }
    if (quality != null) {
      final result = quality['result']?.toString() ?? 'pending';
      timeline.add(
        ProductionTimelineEvent(
          title: 'Quality ${_statusLabel(result).toLowerCase()}',
          detail: quality['check_number']?.toString() ?? 'Quality check',
          time: _formatTime(quality['inspected_at']),
          isWarning: result == 'hold' || result == 'fail',
        ),
      );
    }
    final actualEnd = order['actual_end_at'] ?? batch?['completed_at'];
    if (actualEnd != null) {
      timeline.add(
        ProductionTimelineEvent(
          title: 'Production completed',
          detail: batch?['batch_number']?.toString() ?? number,
          time: _formatTime(actualEnd),
          isWarning: false,
        ),
      );
    }

    final qualityResult = quality?['result']?.toString();
    return ProductionOrderDetail(
      number: order['order_number']?.toString() ?? number,
      product: item?['name']?.toString() ?? 'Product',
      line: line?['code']?.toString() ?? 'Unassigned line',
      status: _statusLabel(order['status']?.toString() ?? 'planned'),
      planned: _asInt(order['planned_quantity']),
      completed: _asInt(order['completed_quantity']),
      startedAt: _formatDateTime(order['actual_start_at'] ?? order['planned_start_at']),
      dueAt: _formatDateTime(order['planned_end_at']),
      batchNumber: batch?['batch_number']?.toString() ?? 'No active batch',
      qcStatus: qualityResult == null ? 'Pending' : _statusLabel(qualityResult),
      rejected: _asInt(quality?['rejected_quantity'] ?? batch?['rejected_quantity'] ?? order['rejected_quantity']),
      materials: materials,
      timeline: timeline,
    );
  }

  @override
  Future<ProductionOrderDetail> completeActiveBatch(String number) async {
    final order = await client
        .from('production_orders')
        .select('id')
        .eq('order_number', number)
        .single();
    final batches = (await client
            .from('production_batches')
            .select('id,status,created_at')
            .eq('production_order_id', order['id'])
            .inFilter('status', const ['in_production', 'qc_pending'])
            .order('created_at', ascending: false)
            .limit(1))
        .cast<Map<String, dynamic>>();
    if (batches.isEmpty) {
      throw StateError('No production batch is ready for completion.');
    }
    await client.rpc(
      'complete_production_batch',
      params: {'target_batch_id': batches.first['id']},
    );
    return loadOrder(number);
  }
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int _asInt(dynamic value) => _asDouble(value).round();

String _statusLabel(String value) => value
    .split('_')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

String _formatTime(dynamic value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  if (parsed == null) return '—';
  final local = parsed.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String _formatDateTime(dynamic value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  if (parsed == null) return 'Not scheduled';
  final local = parsed.toLocal();
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${local.day} ${months[local.month - 1]} • ${_formatTime(local.toIso8601String())}';
}
