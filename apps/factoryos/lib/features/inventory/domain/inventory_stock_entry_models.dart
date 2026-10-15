enum InventoryStockEntryDirection { stockIn, stockOut }

extension InventoryStockEntryDirectionX on InventoryStockEntryDirection {
  String get label => this == InventoryStockEntryDirection.stockIn ? 'Stock In' : 'Stock Out';
  double signedQuantity(double quantity) => this == InventoryStockEntryDirection.stockIn ? quantity : -quantity;
}

class InventoryStockEntryItemOption {
  const InventoryStockEntryItemOption({
    required this.id,
    required this.sku,
    required this.name,
    required this.unit,
    required this.defaultUnitCost,
    required this.batchTracking,
    required this.serialTracking,
    required this.totalOnHand,
  });

  final String id;
  final String sku;
  final String name;
  final String unit;
  final double defaultUnitCost;
  final bool batchTracking;
  final bool serialTracking;
  final double totalOnHand;

  bool get requiresTracking => batchTracking || serialTracking;
}

class InventoryStockEntryWarehouseOption {
  const InventoryStockEntryWarehouseOption({
    required this.id,
    required this.code,
    required this.name,
  });

  final String id;
  final String code;
  final String name;
}

class InventoryStockEntryLocationOption {
  const InventoryStockEntryLocationOption({
    required this.id,
    required this.warehouseId,
    required this.code,
    required this.name,
  });

  final String id;
  final String warehouseId;
  final String code;
  final String name;
}

class InventoryStockEntryBatchOption {
  const InventoryStockEntryBatchOption({
    required this.id,
    required this.itemId,
    required this.batchNumber,
  });

  final String id;
  final String itemId;
  final String batchNumber;
}

class InventoryStockEntrySerialOption {
  const InventoryStockEntrySerialOption({
    required this.id,
    required this.itemId,
    required this.serialNumber,
    required this.status,
    this.currentWarehouseId,
    this.currentLocationId,
  });

  final String id;
  final String itemId;
  final String serialNumber;
  final String status;
  final String? currentWarehouseId;
  final String? currentLocationId;
}

class InventoryStockEntryBalance {
  const InventoryStockEntryBalance({
    required this.itemId,
    required this.warehouseId,
    required this.quantity,
    this.locationId,
    this.batchId,
    this.serialNumberId,
  });

  final String itemId;
  final String warehouseId;
  final String? locationId;
  final String? batchId;
  final String? serialNumberId;
  final double quantity;
}

class InventoryStockEntryOptions {
  const InventoryStockEntryOptions({
    required this.items,
    required this.warehouses,
    required this.locations,
    required this.batches,
    required this.serials,
    required this.balances,
  });

  final List<InventoryStockEntryItemOption> items;
  final List<InventoryStockEntryWarehouseOption> warehouses;
  final List<InventoryStockEntryLocationOption> locations;
  final List<InventoryStockEntryBatchOption> batches;
  final List<InventoryStockEntrySerialOption> serials;
  final List<InventoryStockEntryBalance> balances;

  InventoryStockEntryItemOption? itemById(String? id) {
    if (id == null) return null;
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  List<InventoryStockEntryLocationOption> locationsForWarehouse(String? warehouseId) =>
      locations.where((location) => location.warehouseId == warehouseId).toList(growable: false);

  List<InventoryStockEntryBatchOption> batchesForItem(String? itemId) =>
      batches.where((batch) => batch.itemId == itemId).toList(growable: false);

  List<InventoryStockEntrySerialOption> serialsForItem(String? itemId) =>
      serials.where((serial) => serial.itemId == itemId).toList(growable: false);

  double quantityAt({
    required String? itemId,
    required String? warehouseId,
    String? locationId,
    String? batchId,
    String? serialNumberId,
  }) {
    if (itemId == null || warehouseId == null) return 0;
    return balances
        .where(
          (balance) =>
              balance.itemId == itemId &&
              balance.warehouseId == warehouseId &&
              balance.locationId == locationId &&
              balance.batchId == batchId &&
              balance.serialNumberId == serialNumberId,
        )
        .fold<double>(0, (total, balance) => total + balance.quantity);
  }
}

class InventoryStockEntryRequest {
  const InventoryStockEntryRequest({
    required this.direction,
    required this.warehouseId,
    required this.itemId,
    required this.quantity,
    required this.unitCost,
    required this.reason,
    required this.idempotencyKey,
    this.locationId,
    this.batchId,
    this.serialNumberId,
  });

  final InventoryStockEntryDirection direction;
  final String warehouseId;
  final String? locationId;
  final String itemId;
  final String? batchId;
  final String? serialNumberId;
  final double quantity;
  final double? unitCost;
  final String reason;
  final String idempotencyKey;

  double get quantityDelta => direction.signedQuantity(quantity);

  String? validate(InventoryStockEntryOptions options) {
    final item = options.itemById(itemId);
    if (item == null) return 'Select an inventory item.';
    if (warehouseId.isEmpty) return 'Select a warehouse.';
    if (quantity <= 0) return 'Quantity must be greater than zero.';
    if (unitCost != null && unitCost! < 0) return 'Unit cost cannot be negative.';
    if (reason.trim().length < 5) return 'Enter a clear reason for this adjustment.';
    if (idempotencyKey.trim().length < 8) return 'Stock entry request is missing its idempotency key.';
    if (item.batchTracking && batchId == null) return 'Select a batch for this batch-tracked item.';
    if (!item.batchTracking && batchId != null) return 'This item does not use batch tracking.';
    if (item.serialTracking && serialNumberId == null) return 'Select a serial number for this serial-tracked item.';
    if (!item.serialTracking && serialNumberId != null) return 'This item does not use serial tracking.';
    if (item.serialTracking && quantity != 1) return 'Serial-tracked adjustments must be exactly 1 unit.';
    return null;
  }
}

class InventoryStockEntryResult {
  const InventoryStockEntryResult({
    required this.transactionId,
    required this.transactionNumber,
    required this.status,
  });

  final String transactionId;
  final String transactionNumber;
  final String status;

  bool get isPosted => status == 'posted';
}
