import '../domain/inventory_stock_entry_models.dart';

abstract interface class InventoryStockEntryRepository {
  Future<InventoryStockEntryOptions> loadOptions();
  bool get supportsPosting;
  Future<InventoryStockEntryResult> postAdjustment(InventoryStockEntryRequest request);
}

final class PreviewInventoryStockEntryRepository implements InventoryStockEntryRepository {
  const PreviewInventoryStockEntryRepository();

  @override
  bool get supportsPosting => false;

  @override
  Future<InventoryStockEntryOptions> loadOptions() async {
    return const InventoryStockEntryOptions(
      items: [
        InventoryStockEntryItemOption(
          id: 'preview-pk-carton',
          sku: 'PK-CARTON-014',
          name: 'Heavy Duty Carton 14in',
          unit: 'PCS',
          defaultUnitCost: 22,
          batchTracking: false,
          serialTracking: false,
          totalOnHand: 860,
        ),
        InventoryStockEntryItemOption(
          id: 'preview-rm-steel',
          sku: 'RM-STEEL-001',
          name: 'MS Steel Sheet 2mm',
          unit: 'KG',
          defaultUnitCost: 72.5,
          batchTracking: true,
          serialTracking: false,
          totalOnHand: 1240,
        ),
        InventoryStockEntryItemOption(
          id: 'preview-sp-bearing',
          sku: 'SP-BRG-6204',
          name: 'Bearing 6204 ZZ',
          unit: 'PCS',
          defaultUnitCost: 265,
          batchTracking: false,
          serialTracking: false,
          totalOnHand: 9,
        ),
      ],
      warehouses: [
        InventoryStockEntryWarehouseOption(id: 'preview-rm-wh', code: 'RM-WH', name: 'Raw Material Warehouse'),
        InventoryStockEntryWarehouseOption(id: 'preview-fg-wh', code: 'FG-WH', name: 'Finished Goods Warehouse'),
        InventoryStockEntryWarehouseOption(id: 'preview-sp-wh', code: 'SP-WH', name: 'Spares & Consumables Store'),
      ],
      locations: [
        InventoryStockEntryLocationOption(id: 'preview-rm-a', warehouseId: 'preview-rm-wh', code: 'RM-A-R03-B02', name: 'Steel Storage'),
        InventoryStockEntryLocationOption(id: 'preview-rm-b', warehouseId: 'preview-rm-wh', code: 'RM-B-R01-B04', name: 'Pipe Storage'),
        InventoryStockEntryLocationOption(id: 'preview-fg-a', warehouseId: 'preview-fg-wh', code: 'FG-A-R01-B08', name: 'Valve Finished Goods'),
        InventoryStockEntryLocationOption(id: 'preview-sp-a', warehouseId: 'preview-sp-wh', code: 'SP-A-R04-B03', name: 'Bearing & Belts'),
      ],
      batches: [
        InventoryStockEntryBatchOption(id: 'preview-steel-batch', itemId: 'preview-rm-steel', batchNumber: 'RM-141026-03'),
      ],
      serials: [],
      balances: [
        InventoryStockEntryBalance(itemId: 'preview-pk-carton', warehouseId: 'preview-rm-wh', locationId: 'preview-rm-a', quantity: 860),
        InventoryStockEntryBalance(itemId: 'preview-rm-steel', warehouseId: 'preview-rm-wh', locationId: 'preview-rm-a', batchId: 'preview-steel-batch', quantity: 1240),
        InventoryStockEntryBalance(itemId: 'preview-sp-bearing', warehouseId: 'preview-sp-wh', locationId: 'preview-sp-a', quantity: 9),
      ],
    );
  }

  @override
  Future<InventoryStockEntryResult> postAdjustment(InventoryStockEntryRequest request) {
    throw UnsupportedError('Inventory Stock Entry posting is disabled in preview mode.');
  }
}
