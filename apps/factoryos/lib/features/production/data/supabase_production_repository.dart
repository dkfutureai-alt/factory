import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/production_models.dart';
import 'production_repository.dart';

final class SupabaseProductionRepository implements ProductionRepository {
  const SupabaseProductionRepository(this.client);

  final SupabaseClient client;

  @override
  Future<ProductionOverview> loadOverview() async {
    final orderRows = (await client
            .from('production_orders')
            .select(
              'id,order_number,item_id,production_line_id,planned_quantity,completed_quantity,rejected_quantity,status,notes,planned_start_at',
            )
            .order('planned_start_at', ascending: false)
            .limit(100))
        .cast<Map<String, dynamic>>();

    final itemIds = _ids(orderRows.map((row) => row['item_id']));
    final lineIds = _ids(orderRows.map((row) => row['production_line_id']));
    final itemRows = itemIds.isEmpty
        ? <Map<String, dynamic>>[]
        : (await client.from('items').select('id,name').inFilter('id', itemIds))
            .cast<Map<String, dynamic>>();
    final lineRows = lineIds.isEmpty
        ? <Map<String, dynamic>>[]
        : (await client.from('production_lines').select('id,code').inFilter('id', lineIds))
            .cast<Map<String, dynamic>>();
    final itemById = {
      for (final row in itemRows) row['id'].toString(): row['name']?.toString() ?? 'Product',
    };
    final lineById = {
      for (final row in lineRows) row['id'].toString(): row['code']?.toString() ?? 'Line',
    };

    final activeStatuses = const {
      'planned',
      'material_pending',
      'ready',
      'in_production',
      'qc_pending',
    };
    final activeRows = orderRows.where((row) => activeStatuses.contains(row['status']?.toString())).toList();
    final plannedQuantity = activeRows.fold<int>(0, (sum, row) => sum + _asInt(row['planned_quantity']));
    final completedQuantity = activeRows.fold<int>(0, (sum, row) => sum + _asInt(row['completed_quantity']));
    final rejectedOrHoldQuantity = activeRows.fold<int>(0, (sum, row) => sum + _asInt(row['rejected_quantity']));

    final summaries = activeRows.take(12).map((row) {
      return ProductionOrderSummary(
        number: row['order_number']?.toString() ?? 'Production order',
        product: itemById[row['item_id']?.toString()] ?? 'Product',
        line: lineById[row['production_line_id']?.toString()] ?? 'Unassigned line',
        planned: _asInt(row['planned_quantity']),
        completed: _asInt(row['completed_quantity']),
        status: _statusLabel(row['status']?.toString() ?? 'planned'),
      );
    }).toList(growable: false);

    final alerts = <ProductionAlert>[];
    for (final row in activeRows) {
      final status = row['status']?.toString() ?? '';
      final rejected = _asInt(row['rejected_quantity']);
      if (status == 'material_pending') {
        alerts.add(
          ProductionAlert(
            title: row['order_number']?.toString() ?? 'Production order',
            detail: row['notes']?.toString().trim().isNotEmpty == true
                ? row['notes'].toString().trim()
                : 'Material pending',
            severity: ProductionAlertSeverity.warning,
          ),
        );
      } else if (status == 'qc_pending') {
        alerts.add(
          ProductionAlert(
            title: row['order_number']?.toString() ?? 'Production order',
            detail: rejected > 0 ? 'QC pending • $rejected rejected' : 'Quality review pending',
            severity: rejected > 0 ? ProductionAlertSeverity.critical : ProductionAlertSeverity.info,
          ),
        );
      } else if (rejected > 0) {
        alerts.add(
          ProductionAlert(
            title: row['order_number']?.toString() ?? 'Production order',
            detail: '$rejected rejected units require attention',
            severity: ProductionAlertSeverity.critical,
          ),
        );
      }
      if (alerts.length >= 6) break;
    }

    return ProductionOverview(
      plannedQuantity: plannedQuantity,
      completedQuantity: completedQuantity,
      activeOrderCount: activeRows.length,
      rejectedOrHoldQuantity: rejectedOrHoldQuantity,
      orders: summaries,
      alerts: alerts,
    );
  }
}

List<String> _ids(Iterable<dynamic> values) => values
    .where((value) => value != null)
    .map((value) => value.toString())
    .where((value) => value.isNotEmpty)
    .toSet()
    .toList(growable: false);

int _asInt(dynamic value) {
  if (value is num) return value.round();
  return double.tryParse(value?.toString() ?? '')?.round() ?? 0;
}

String _statusLabel(String value) => value
    .split('_')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');
