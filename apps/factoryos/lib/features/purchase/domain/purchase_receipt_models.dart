class PurchaseReceiptWarehouseOption {
  const PurchaseReceiptWarehouseOption({required this.id, required this.code, required this.name});
  final String id;
  final String code;
  final String name;
}

class PurchaseReceiptLocationOption {
  const PurchaseReceiptLocationOption({
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

class PurchaseReceiptLineOption {
  const PurchaseReceiptLineOption({
    required this.purchaseOrderLineId,
    required this.itemId,
    required this.sku,
    required this.itemName,
    required this.unit,
    required this.pendingQuantity,
    required this.unitPrice,
    required this.batchTracking,
    required this.serialTracking,
  });

  final String purchaseOrderLineId;
  final String itemId;
  final String sku;
  final String itemName;
  final String unit;
  final double pendingQuantity;
  final double unitPrice;
  final bool batchTracking;
  final bool serialTracking;

  bool get requiresTracking => batchTracking || serialTracking;
}

class PurchaseReceiptOptions {
  const PurchaseReceiptOptions({
    required this.purchaseOrderId,
    required this.orderNumber,
    required this.supplier,
    required this.status,
    required this.warehouses,
    required this.locations,
    required this.lines,
  });

  final String purchaseOrderId;
  final String orderNumber;
  final String supplier;
  final String status;
  final List<PurchaseReceiptWarehouseOption> warehouses;
  final List<PurchaseReceiptLocationOption> locations;
  final List<PurchaseReceiptLineOption> lines;

  bool get canReceive => status == 'approved' || status == 'part_received';
}

class PurchaseReceiptAllocationRequest {
  const PurchaseReceiptAllocationRequest({
    required this.locationId,
    required this.quantity,
    this.batchId,
    this.batchNumber,
    this.serialNumberId,
    this.serialNumber,
  });

  final String locationId;
  final double quantity;
  final String? batchId;
  final String? batchNumber;
  final String? serialNumberId;
  final String? serialNumber;

  Map<String, dynamic> toJson() => {
        'location_id': locationId,
        'quantity': quantity,
        if (batchId != null && batchId!.isNotEmpty) 'batch_id': batchId,
        if (batchNumber != null && batchNumber!.trim().isNotEmpty) 'batch_number': batchNumber!.trim(),
        if (serialNumberId != null && serialNumberId!.isNotEmpty) 'serial_number_id': serialNumberId,
        if (serialNumber != null && serialNumber!.trim().isNotEmpty) 'serial_number': serialNumber!.trim(),
      };
}

class PurchaseReceiptLineRequest {
  const PurchaseReceiptLineRequest({
    required this.purchaseOrderLineId,
    required this.receivedQuantity,
    required this.acceptedQuantity,
    required this.rejectedQuantity,
    required this.allocations,
    this.supplierBatchNumber,
    this.note,
  });

  final String purchaseOrderLineId;
  final double receivedQuantity;
  final double acceptedQuantity;
  final double rejectedQuantity;
  final String? supplierBatchNumber;
  final String? note;
  final List<PurchaseReceiptAllocationRequest> allocations;

  double get allocationTotal => allocations.fold<double>(0, (sum, item) => sum + item.quantity);

  String? validate(PurchaseReceiptLineOption option) {
    if (purchaseOrderLineId != option.purchaseOrderLineId) return 'Purchase order line does not match selected item.';
    if (receivedQuantity <= 0) return 'Received quantity must be greater than zero.';
    if (acceptedQuantity < 0 || rejectedQuantity < 0) return 'Accepted and rejected quantities cannot be negative.';
    if ((acceptedQuantity + rejectedQuantity - receivedQuantity).abs() > 0.0001) {
      return 'Accepted + rejected must equal received quantity.';
    }
    if (acceptedQuantity - option.pendingQuantity > 0.0001) return 'Accepted quantity exceeds PO pending quantity.';
    if (acceptedQuantity > 0 && allocations.isEmpty) return 'Accepted quantity requires inventory allocation.';
    if ((allocationTotal - acceptedQuantity).abs() > 0.0001) return 'Allocation total must equal accepted quantity.';
    if (option.batchTracking && allocations.any((a) => (a.batchId == null || a.batchId!.isEmpty) && (a.batchNumber == null || a.batchNumber!.trim().isEmpty))) {
      return 'Batch number is required for this item.';
    }
    if (option.serialTracking && allocations.any((a) => a.quantity != 1 || ((a.serialNumberId == null || a.serialNumberId!.isEmpty) && (a.serialNumber == null || a.serialNumber!.trim().isEmpty)))) {
      return 'Each serial allocation must be one unit with a serial number.';
    }
    if (!option.batchTracking && !option.serialTracking && allocations.any((a) => a.batchId != null || a.batchNumber != null || a.serialNumberId != null || a.serialNumber != null)) {
      return 'Non-tracked item cannot use batch or serial allocation.';
    }
    if (allocations.any((a) => a.locationId.isEmpty || a.quantity <= 0)) return 'Each allocation requires a location and positive quantity.';
    return null;
  }

  Map<String, dynamic> toJson() => {
        'purchase_order_line_id': purchaseOrderLineId,
        'received_quantity': receivedQuantity,
        'accepted_quantity': acceptedQuantity,
        'rejected_quantity': rejectedQuantity,
        if (supplierBatchNumber != null && supplierBatchNumber!.trim().isNotEmpty) 'supplier_batch_number': supplierBatchNumber!.trim(),
        if (note != null && note!.trim().isNotEmpty) 'note': note!.trim(),
        'allocations': allocations.map((item) => item.toJson()).toList(growable: false),
      };
}

class PurchaseReceiptRequest {
  const PurchaseReceiptRequest({
    required this.purchaseOrderId,
    required this.warehouseId,
    required this.supplierInvoiceNumber,
    required this.supplierDeliveryNote,
    required this.note,
    required this.lines,
    required this.idempotencyKey,
  });

  final String purchaseOrderId;
  final String warehouseId;
  final String supplierInvoiceNumber;
  final String supplierDeliveryNote;
  final String note;
  final List<PurchaseReceiptLineRequest> lines;
  final String idempotencyKey;

  double get acceptedQuantity => lines.fold<double>(0, (sum, line) => sum + line.acceptedQuantity);
  double get rejectedQuantity => lines.fold<double>(0, (sum, line) => sum + line.rejectedQuantity);

  String? validate(PurchaseReceiptOptions options) {
    if (purchaseOrderId != options.purchaseOrderId) return 'Purchase order does not match receipt options.';
    if (!options.canReceive) return 'Purchase order is not open for receiving.';
    if (!options.warehouses.any((warehouse) => warehouse.id == warehouseId)) return 'Select an allowed warehouse.';
    if (idempotencyKey.trim().length < 8) return 'Receipt request key is invalid.';
    if (lines.isEmpty) return 'Add at least one receipt line.';
    if (acceptedQuantity <= 0) return 'At least one accepted quantity is required to post inventory.';
    for (final line in lines) {
      final matches = options.lines.where((item) => item.purchaseOrderLineId == line.purchaseOrderLineId);
      if (matches.length != 1) return 'Receipt contains an unknown purchase order line.';
      final error = line.validate(matches.single);
      if (error != null) return error;
      if (line.allocations.any((allocation) => !options.locations.any((location) => location.id == allocation.locationId && location.warehouseId == warehouseId))) {
        return 'Allocation location must belong to selected warehouse.';
      }
    }
    return null;
  }

  List<Map<String, dynamic>> toRpcLines() => lines.map((line) => line.toJson()).toList(growable: false);
}

class PurchaseReceiptResult {
  const PurchaseReceiptResult({
    required this.goodsReceiptId,
    required this.grnNumber,
    required this.status,
    this.stockTransactionId,
  });
  final String goodsReceiptId;
  final String grnNumber;
  final String status;
  final String? stockTransactionId;
}
