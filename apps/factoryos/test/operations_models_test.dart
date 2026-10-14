import 'package:factoryos/features/inventory/domain/inventory_models.dart';
import 'package:factoryos/features/production/domain/production_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('inventory item marks quantity at reorder level as low stock', () {
    const low = InventoryItemSummary(
      sku: 'SP-BRG-6204',
      name: 'Bearing 6204 ZZ',
      category: 'Spare Part',
      location: 'SP-A / R04-B03',
      onHand: 12,
      unit: 'pcs',
      reorderLevel: 12,
    );
    const healthy = InventoryItemSummary(
      sku: 'RM-STEEL-001',
      name: 'MS Steel Sheet 2mm',
      category: 'Raw Material',
      location: 'RM-A / R03-B02',
      onHand: 1240,
      unit: 'kg',
      reorderLevel: 600,
    );

    expect(low.isLowStock, isTrue);
    expect(healthy.isLowStock, isFalse);
  });

  test('production achievement handles normal and zero planned output', () {
    const overview = ProductionOverview(
      plannedQuantity: 4800,
      completedQuantity: 3420,
      activeOrderCount: 6,
      rejectedOrHoldQuantity: 32,
      orders: [],
      alerts: [],
    );
    const empty = ProductionOverview(
      plannedQuantity: 0,
      completedQuantity: 0,
      activeOrderCount: 0,
      rejectedOrHoldQuantity: 0,
      orders: [],
      alerts: [],
    );

    expect(overview.achievement, closeTo(0.7125, 0.0001));
    expect(empty.achievement, 0);
  });
}
