class ProductionOverview {
  const ProductionOverview({
    required this.plannedQuantity,
    required this.completedQuantity,
    required this.activeOrderCount,
    required this.rejectedOrHoldQuantity,
    required this.orders,
    required this.alerts,
  });

  final int plannedQuantity;
  final int completedQuantity;
  final int activeOrderCount;
  final int rejectedOrHoldQuantity;
  final List<ProductionOrderSummary> orders;
  final List<ProductionAlert> alerts;

  double get achievement => plannedQuantity == 0 ? 0 : completedQuantity / plannedQuantity;
}

class ProductionOrderSummary {
  const ProductionOrderSummary({
    required this.number,
    required this.product,
    required this.line,
    required this.planned,
    required this.completed,
    required this.status,
  });

  final String number;
  final String product;
  final String line;
  final int planned;
  final int completed;
  final String status;
}

class ProductionAlert {
  const ProductionAlert({required this.title, required this.detail, required this.severity});

  final String title;
  final String detail;
  final ProductionAlertSeverity severity;
}

enum ProductionAlertSeverity { info, warning, critical }
