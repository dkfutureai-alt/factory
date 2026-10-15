import '../domain/inventory_models.dart';

abstract interface class InventoryRepository {
  Future<InventoryOverview> loadOverview();
}

/// Preview-only repository. Replace with a Supabase-backed implementation once
/// the dedicated FactoryOS project exists.
final class PreviewInventoryRepository implements InventoryRepository {
  const PreviewInventoryRepository();

  @override
  Future<InventoryOverview> loadOverview() async {
    return const InventoryOverview(
      stockValue: 4280000,
      activeSkuCount: 108,
      lowStockCount: 12,
      todayMovements: 47,
      blockedOrDamagedCount: 6,
      items: [
        InventoryItemSummary(sku: 'RM-STL-304-02', name: 'Stainless Steel Rod 304 • 40mm', category: 'Raw Material', location: 'RM-WH / Rack A-03', onHand: 420, unit: 'kg', reorderLevel: 500),
        InventoryItemSummary(sku: 'RM-STEEL-001', name: 'MS Steel Sheet 2mm', category: 'Raw Material', location: 'RM-A / R03-B02', onHand: 1240, unit: 'kg', reorderLevel: 600),
        InventoryItemSummary(sku: 'RM-PIPE-001', name: 'Industrial Pipe 25mm', category: 'Raw Material', location: 'RM-B / R01-B04', onHand: 182, unit: 'pcs', reorderLevel: 200),
        InventoryItemSummary(sku: 'PK-CARTON-014', name: 'Heavy Duty Carton 14in', category: 'Packaging', location: 'PK-A / R02-B01', onHand: 860, unit: 'pcs', reorderLevel: 300),
        InventoryItemSummary(sku: 'SP-BRG-6204', name: 'Bearing 6204 ZZ', category: 'Spare Part', location: 'SP-A / R04-B03', onHand: 9, unit: 'pcs', reorderLevel: 12),
        InventoryItemSummary(sku: 'FG-VALVE-25', name: 'Valve Assembly 25mm', category: 'Finished Goods', location: 'FG-A / R01-B08', onHand: 420, unit: 'pcs', reorderLevel: 150),
      ],
    );
  }
}
