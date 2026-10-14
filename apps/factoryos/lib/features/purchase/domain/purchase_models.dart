class PurchaseOrderSummary {
  const PurchaseOrderSummary({
    required this.orderNumber,
    required this.supplier,
    required this.expectedDate,
    required this.totalValue,
    required this.status,
  });

  final String orderNumber;
  final String supplier;
  final DateTime expectedDate;
  final double totalValue;
  final String status;

  bool get isOverdue => status == 'Overdue';
}

class SupplierPerformance {
  const SupplierPerformance({required this.name, required this.onTimeRate});
  final String name;
  final double onTimeRate;
}

class GoodsReceiptSummary {
  const GoodsReceiptSummary({
    required this.grnNumber,
    required this.orderNumber,
    required this.lineCount,
    required this.receivedLabel,
  });
  final String grnNumber;
  final String orderNumber;
  final int lineCount;
  final String receivedLabel;
}

class PurchaseOverview {
  const PurchaseOverview({
    required this.openOrders,
    required this.pendingApproval,
    required this.dueThisWeek,
    required this.outstandingValue,
    required this.orders,
    required this.suppliers,
    required this.receipts,
  });

  final int openOrders;
  final int pendingApproval;
  final int dueThisWeek;
  final double outstandingValue;
  final List<PurchaseOrderSummary> orders;
  final List<SupplierPerformance> suppliers;
  final List<GoodsReceiptSummary> receipts;
}

class PurchaseOrderLine {
  const PurchaseOrderLine({
    required this.sku,
    required this.itemName,
    required this.unit,
    required this.orderedQuantity,
    required this.receivedQuantity,
    required this.unitPrice,
  });

  final String sku;
  final String itemName;
  final String unit;
  final double orderedQuantity;
  final double receivedQuantity;
  final double unitPrice;

  double get pendingQuantity => (orderedQuantity - receivedQuantity).clamp(0, double.infinity).toDouble();
  double get lineValue => orderedQuantity * unitPrice;
  double get receivedValue => receivedQuantity * unitPrice;
  bool get fullyReceived => pendingQuantity == 0;
}

class PurchaseCheck {
  const PurchaseCheck({required this.label, required this.complete});
  final String label;
  final bool complete;
}

class PurchaseOrderDetail {
  const PurchaseOrderDetail({
    required this.orderNumber,
    required this.supplier,
    required this.expectedDateLabel,
    required this.status,
    required this.paymentTerms,
    required this.deliveryLocation,
    required this.latestGrn,
    required this.lines,
    required this.checks,
  });

  final String orderNumber;
  final String supplier;
  final String expectedDateLabel;
  final String status;
  final String paymentTerms;
  final String deliveryLocation;
  final String latestGrn;
  final List<PurchaseOrderLine> lines;
  final List<PurchaseCheck> checks;

  double get orderValue => lines.fold(0, (sum, line) => sum + line.lineValue);
  double get receivedValue => lines.fold(0, (sum, line) => sum + line.receivedValue);
  double get pendingValue => (orderValue - receivedValue).clamp(0, double.infinity).toDouble();
  bool get fullyReceived => lines.isNotEmpty && lines.every((line) => line.fullyReceived);
}
