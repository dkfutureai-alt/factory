class PurchaseOrderFactoryOption {
  const PurchaseOrderFactoryOption({required this.id, required this.code, required this.name});
  final String id;
  final String code;
  final String name;
}

class PurchaseOrderSupplierOption {
  const PurchaseOrderSupplierOption({
    required this.id,
    required this.code,
    required this.name,
    required this.paymentTermsDays,
  });
  final String id;
  final String code;
  final String name;
  final int paymentTermsDays;
}

class PurchaseOrderItemOption {
  const PurchaseOrderItemOption({
    required this.id,
    required this.sku,
    required this.name,
    required this.unit,
    required this.defaultUnitPrice,
  });
  final String id;
  final String sku;
  final String name;
  final String unit;
  final double defaultUnitPrice;
}

class PurchaseOrderDraftLine {
  const PurchaseOrderDraftLine({
    required this.itemId,
    required this.orderedQuantity,
    required this.unitPrice,
    required this.taxRate,
    this.note,
  });

  final String itemId;
  final double orderedQuantity;
  final double unitPrice;
  final double taxRate;
  final String? note;

  double get lineValue => orderedQuantity * unitPrice;
  double get taxValue => lineValue * taxRate / 100;
  double get totalValue => lineValue + taxValue;

  String? validate(PurchaseOrderEditorOptions options) {
    if (!options.items.any((item) => item.id == itemId)) return 'Select an active purchase item.';
    if (orderedQuantity <= 0) return 'Quantity must be greater than zero.';
    if (unitPrice < 0) return 'Unit price cannot be negative.';
    if (taxRate < 0 || taxRate > 100) return 'Tax rate must be between 0 and 100.';
    return null;
  }

  Map<String, dynamic> toJson() => {
        'item_id': itemId,
        'ordered_quantity': orderedQuantity,
        'unit_price': unitPrice,
        'tax_rate': taxRate,
        if (note != null && note!.trim().isNotEmpty) 'note': note!.trim(),
      };
}

class PurchaseOrderDraftSnapshot {
  const PurchaseOrderDraftSnapshot({
    required this.purchaseOrderId,
    required this.orderNumber,
    required this.revision,
    required this.status,
    required this.factoryId,
    required this.supplierId,
    required this.expectedDeliveryDate,
    required this.paymentTerms,
    required this.notes,
    required this.lines,
    this.rejectionReason,
    this.submittedBy,
    this.submittedAt,
  });

  final String purchaseOrderId;
  final String orderNumber;
  final int revision;
  final String status;
  final String factoryId;
  final String supplierId;
  final DateTime? expectedDeliveryDate;
  final String paymentTerms;
  final String notes;
  final List<PurchaseOrderDraftLine> lines;
  final String? rejectionReason;
  final String? submittedBy;
  final DateTime? submittedAt;

  bool get isDraft => status == 'draft';
  bool get isPendingApproval => status == 'pending_approval';
  bool get isApproved => status == 'approved' || status == 'part_received' || status == 'received';
  double get lineValue => lines.fold<double>(0, (sum, line) => sum + line.lineValue);
  double get taxValue => lines.fold<double>(0, (sum, line) => sum + line.taxValue);
  double get totalValue => lineValue + taxValue;
}

class PurchaseOrderEditorOptions {
  const PurchaseOrderEditorOptions({
    required this.factories,
    required this.suppliers,
    required this.items,
    this.draft,
  });

  final List<PurchaseOrderFactoryOption> factories;
  final List<PurchaseOrderSupplierOption> suppliers;
  final List<PurchaseOrderItemOption> items;
  final PurchaseOrderDraftSnapshot? draft;

  PurchaseOrderSupplierOption? supplierById(String? id) {
    if (id == null) return null;
    for (final item in suppliers) {
      if (item.id == id) return item;
    }
    return null;
  }

  PurchaseOrderItemOption? itemById(String? id) {
    if (id == null) return null;
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }
}

class PurchaseOrderDraftRequest {
  const PurchaseOrderDraftRequest({
    this.purchaseOrderId,
    this.expectedRevision,
    required this.factoryId,
    required this.supplierId,
    required this.expectedDeliveryDate,
    required this.paymentTerms,
    required this.notes,
    required this.lines,
    required this.idempotencyKey,
  });

  final String? purchaseOrderId;
  final int? expectedRevision;
  final String factoryId;
  final String supplierId;
  final DateTime? expectedDeliveryDate;
  final String paymentTerms;
  final String notes;
  final List<PurchaseOrderDraftLine> lines;
  final String idempotencyKey;

  double get lineValue => lines.fold<double>(0, (sum, line) => sum + line.lineValue);
  double get taxValue => lines.fold<double>(0, (sum, line) => sum + line.taxValue);
  double get totalValue => lineValue + taxValue;

  String? validate(PurchaseOrderEditorOptions options) {
    if (!options.factories.any((factory) => factory.id == factoryId)) return 'Select an allowed factory.';
    if (!options.suppliers.any((supplier) => supplier.id == supplierId)) return 'Select an active supplier.';
    if (idempotencyKey.trim().length < 8) return 'Purchase order request key is invalid.';
    if (expectedDeliveryDate != null) {
      final today = DateTime.now();
      final day = DateTime(today.year, today.month, today.day);
      final delivery = DateTime(expectedDeliveryDate!.year, expectedDeliveryDate!.month, expectedDeliveryDate!.day);
      if (purchaseOrderId == null && delivery.isBefore(day)) return 'Expected delivery date cannot be in the past.';
    }
    final itemIds = <String>{};
    for (final line in lines) {
      final error = line.validate(options);
      if (error != null) return error;
      if (!itemIds.add(line.itemId)) return 'The same item cannot appear twice.';
    }
    if (purchaseOrderId != null && (expectedRevision == null || expectedRevision! <= 0)) {
      return 'Existing draft revision is required.';
    }
    return null;
  }

  List<Map<String, dynamic>> toRpcLines() => lines.map((line) => line.toJson()).toList(growable: false);
}

class PurchaseOrderWorkflowResult {
  const PurchaseOrderWorkflowResult({
    required this.purchaseOrderId,
    required this.orderNumber,
    required this.revision,
    required this.status,
    this.rejectionReason,
  });
  final String purchaseOrderId;
  final String orderNumber;
  final int revision;
  final String status;
  final String? rejectionReason;
}

enum PurchaseOrderDecision { approve, reject }

class PurchaseOrderDecisionRequest {
  const PurchaseOrderDecisionRequest({
    required this.purchaseOrderId,
    required this.decision,
    required this.comment,
    required this.idempotencyKey,
  });
  final String purchaseOrderId;
  final PurchaseOrderDecision decision;
  final String comment;
  final String idempotencyKey;

  String get rpcDecision => decision.name;

  String? validate() {
    if (purchaseOrderId.isEmpty) return 'Purchase order is required.';
    if (idempotencyKey.trim().length < 8) return 'Approval request key is invalid.';
    if (decision == PurchaseOrderDecision.reject && comment.trim().length < 3) return 'Rejection reason is required.';
    return null;
  }
}