class WarehouseTransferLine {
  const WarehouseTransferLine({
    required this.sku,
    required this.name,
    required this.fromLocation,
    required this.toLocation,
    required this.quantity,
    required this.unit,
    this.batchNumber,
  });

  final String sku;
  final String name;
  final String fromLocation;
  final String toLocation;
  final double quantity;
  final String unit;
  final String? batchNumber;

  double get safeQuantity => quantity < 0 ? 0 : quantity;
}

class WarehouseTransferDetail {
  const WarehouseTransferDetail({
    required this.transferNumber,
    required this.status,
    required this.sourceWarehouse,
    required this.destinationWarehouse,
    required this.reason,
    required this.assignee,
    required this.outLedgerPosted,
    required this.inLedgerPosted,
    required this.lines,
  });

  final String transferNumber;
  final String status;
  final String sourceWarehouse;
  final String destinationWarehouse;
  final String reason;
  final String assignee;
  final bool outLedgerPosted;
  final bool inLedgerPosted;
  final List<WarehouseTransferLine> lines;

  double get totalQuantity => lines.fold(0, (sum, line) => sum + line.safeQuantity);
  bool get ledgerReconciled => outLedgerPosted && inLedgerPosted;
  bool get canComplete =>
      (status == 'Ready' || status == 'In progress') && lines.isNotEmpty && !ledgerReconciled;
}
