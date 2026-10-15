import '../domain/purchase_receipt_models.dart';

abstract interface class PurchaseReceiptRepository {
  Future<PurchaseReceiptOptions> loadOptions(String orderNumber);
  bool get supportsPosting;
  Future<PurchaseReceiptResult> postReceipt(PurchaseReceiptRequest request);
}

final class PreviewPurchaseReceiptRepository implements PurchaseReceiptRepository {
  const PreviewPurchaseReceiptRepository();

  @override
  bool get supportsPosting => false;

  @override
  Future<PurchaseReceiptOptions> loadOptions(String orderNumber) async {
    return const PurchaseReceiptOptions(
      purchaseOrderId: 'preview-po-00481',
      orderNumber: 'PO-2026-00481',
      supplier: 'Maharashtra Metals Pvt Ltd',
      status: 'part_received',
      warehouses: [
        PurchaseReceiptWarehouseOption(id: 'preview-rm-wh', code: 'RM-WH', name: 'Raw Material Warehouse'),
      ],
      locations: [
        PurchaseReceiptLocationOption(id: 'preview-rm-a', warehouseId: 'preview-rm-wh', code: 'RM-A-R03-B02', name: 'Steel Storage'),
        PurchaseReceiptLocationOption(id: 'preview-rm-b', warehouseId: 'preview-rm-wh', code: 'RM-B-R01-B04', name: 'Pipe Storage'),
      ],
      lines: [
        PurchaseReceiptLineOption(
          purchaseOrderLineId: 'preview-pol-steel',
          itemId: 'preview-rm-steel',
          sku: 'RM-STL-304-02',
          itemName: 'SS Sheet 304 2mm',
          unit: 'KG',
          pendingQuantity: 350,
          unitPrice: 198,
          batchTracking: true,
          serialTracking: false,
        ),
      ],
    );
  }

  @override
  Future<PurchaseReceiptResult> postReceipt(PurchaseReceiptRequest request) {
    throw UnsupportedError('Purchase GRN posting is disabled in preview mode.');
  }
}
