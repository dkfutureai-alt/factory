class DispatchLoadLine {
  const DispatchLoadLine({
    required this.sku,
    required this.name,
    required this.plannedQuantity,
    required this.loadedQuantity,
    required this.unit,
    required this.ledgerPosted,
    this.batchNumber,
  });

  final String sku;
  final String name;
  final double plannedQuantity;
  final double loadedQuantity;
  final String unit;
  final bool ledgerPosted;
  final String? batchNumber;

  double get safePlannedQuantity => plannedQuantity < 0 ? 0 : plannedQuantity;
  double get safeLoadedQuantity => loadedQuantity.clamp(0, safePlannedQuantity).toDouble();
  double get pendingQuantity => (safePlannedQuantity - safeLoadedQuantity).clamp(0, double.infinity).toDouble();
  bool get fullyLoaded => pendingQuantity == 0;
}

class DispatchRequiredCheck {
  const DispatchRequiredCheck({
    required this.label,
    required this.required,
    required this.complete,
  });

  final String label;
  final bool required;
  final bool complete;
}

class DispatchLoadDetail {
  const DispatchLoadDetail({
    required this.dispatchNumber,
    required this.salesOrderNumber,
    required this.customer,
    required this.status,
    required this.loadingBay,
    required this.vehicleRegistration,
    required this.driverName,
    required this.tripNumber,
    required this.packageCount,
    required this.weightKg,
    required this.lines,
    required this.checks,
  });

  final String dispatchNumber;
  final String salesOrderNumber;
  final String customer;
  final String status;
  final String loadingBay;
  final String vehicleRegistration;
  final String driverName;
  final String tripNumber;
  final int packageCount;
  final double weightKg;
  final List<DispatchLoadLine> lines;
  final List<DispatchRequiredCheck> checks;

  double get plannedQuantity => lines.fold(0, (sum, line) => sum + line.safePlannedQuantity);
  double get loadedQuantity => lines.fold(0, (sum, line) => sum + line.safeLoadedQuantity);
  double get loadedRate => plannedQuantity == 0 ? 0 : (loadedQuantity / plannedQuantity).clamp(0, 1).toDouble();
  bool get linesFullyLoaded => lines.isNotEmpty && lines.every((line) => line.fullyLoaded);
  bool get ledgerReconciled => lines.isNotEmpty && lines.every((line) => line.ledgerPosted);
  bool get requiredChecksComplete => checks.where((check) => check.required).every((check) => check.complete);
  bool get tripAssigned => tripNumber.trim().isNotEmpty;
  bool get canFinalize =>
      status == 'Loaded' && linesFullyLoaded && ledgerReconciled && requiredChecksComplete && tripAssigned;
}
