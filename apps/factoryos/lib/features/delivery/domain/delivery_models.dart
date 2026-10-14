enum DeliveryAlertSeverity { info, warning, danger }

class DeliveryOverview {
  const DeliveryOverview({
    required this.outForDelivery,
    required this.deliveredToday,
    required this.podPending,
    required this.exceptions,
    required this.deliveries,
    required this.alerts,
  });

  final int outForDelivery;
  final int deliveredToday;
  final int podPending;
  final int exceptions;
  final List<DeliverySummary> deliveries;
  final List<DeliveryAlert> alerts;

  double get completionRate {
    final total = outForDelivery + deliveredToday;
    return total == 0 ? 0 : deliveredToday / total;
  }
}

class DeliverySummary {
  const DeliverySummary({
    required this.deliveryNumber,
    required this.customer,
    required this.salesOrderNumber,
    required this.tripNumber,
    required this.etaLabel,
    required this.status,
    required this.podStatus,
  });

  final String deliveryNumber;
  final String customer;
  final String salesOrderNumber;
  final String tripNumber;
  final String etaLabel;
  final String status;
  final String podStatus;

  bool get hasException => status == 'Rejected qty' || status == 'Failed';
}

class DeliveryAlert {
  const DeliveryAlert({required this.title, required this.detail, required this.severity});
  final String title;
  final String detail;
  final DeliveryAlertSeverity severity;
}

class DeliveryLine {
  const DeliveryLine({
    required this.itemCode,
    required this.itemName,
    required this.plannedQuantity,
    required this.acceptedQuantity,
    required this.rejectedQuantity,
    this.rejectionReason,
  });

  final String itemCode;
  final String itemName;
  final double plannedQuantity;
  final double acceptedQuantity;
  final double rejectedQuantity;
  final String? rejectionReason;

  double get reconciledQuantity => acceptedQuantity + rejectedQuantity;
  double get pendingQuantity => (plannedQuantity - reconciledQuantity).clamp(0, double.infinity).toDouble();
  bool get reconciled => pendingQuantity == 0;
}

class DeliveryDetail {
  const DeliveryDetail({
    required this.deliveryNumber,
    required this.customer,
    required this.salesOrderNumber,
    required this.tripNumber,
    required this.shipTo,
    required this.driverName,
    required this.driverCode,
    required this.vehicleRegistration,
    required this.etaLabel,
    required this.status,
    required this.podStatus,
    required this.receiverName,
    required this.deliveredAtLabel,
    required this.hasPodEvidence,
    required this.lines,
  });

  final String deliveryNumber;
  final String customer;
  final String salesOrderNumber;
  final String tripNumber;
  final String shipTo;
  final String driverName;
  final String driverCode;
  final String vehicleRegistration;
  final String etaLabel;
  final String status;
  final String podStatus;
  final String receiverName;
  final String deliveredAtLabel;
  final bool hasPodEvidence;
  final List<DeliveryLine> lines;

  double get plannedQuantity => lines.fold(0, (sum, line) => sum + line.plannedQuantity);
  double get acceptedQuantity => lines.fold(0, (sum, line) => sum + line.acceptedQuantity);
  double get rejectedQuantity => lines.fold(0, (sum, line) => sum + line.rejectedQuantity);
  double get pendingQuantity => lines.fold(0, (sum, line) => sum + line.pendingQuantity);
  bool get quantitiesReconciled => lines.every((line) => line.reconciled);
  bool get canComplete => quantitiesReconciled && receiverName.isNotEmpty && hasPodEvidence;
}

class DeliveryExceptionDetail {
  const DeliveryExceptionDetail({
    required this.deliveryNumber,
    required this.customer,
    required this.exceptionType,
    required this.customerNote,
    required this.evidenceCount,
    required this.returnTripNumber,
    required this.resolutionStatus,
    required this.lines,
  });

  final String deliveryNumber;
  final String customer;
  final String exceptionType;
  final String customerNote;
  final int evidenceCount;
  final String returnTripNumber;
  final String resolutionStatus;
  final List<DeliveryLine> lines;

  double get rejectedQuantity => lines.fold(0, (sum, line) => sum + line.rejectedQuantity);
  bool get requiresReturn => rejectedQuantity > 0;
}
