class InventoryOverview {
  const InventoryOverview({
    required this.stockValue,
    required this.activeSkuCount,
    required this.lowStockCount,
    required this.todayMovements,
    required this.blockedOrDamagedCount,
    required this.items,
  });

  final double stockValue;
  final int activeSkuCount;
  final int lowStockCount;
  final int todayMovements;
  final int blockedOrDamagedCount;
  final List<InventoryItemSummary> items;
}

class InventoryItemSummary {
  const InventoryItemSummary({
    required this.sku,
    required this.name,
    required this.category,
    required this.location,
    required this.onHand,
    required this.unit,
    required this.reorderLevel,
  });

  final String sku;
  final String name;
  final String category;
  final String location;
  final double onHand;
  final String unit;
  final double reorderLevel;

  bool get isLowStock => onHand <= reorderLevel;
}
