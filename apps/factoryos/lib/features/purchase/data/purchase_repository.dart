import '../domain/purchase_models.dart';

abstract interface class PurchaseRepository {
  Future<PurchaseOverview> loadOverview();
  Future<PurchaseOrderDetail> loadOrder(String orderNumber);
}

final class PreviewPurchaseRepository implements PurchaseRepository {
  const PreviewPurchaseRepository();

  @override
  Future<PurchaseOverview> loadOverview() async => PurchaseOverview(
        openOrders: 12,
        pendingApproval: 3,
        dueThisWeek: 7,
        outstandingValue: 840000,
        orders: [
          PurchaseOrderSummary(orderNumber: 'PO-2026-00481', supplier: 'Maharashtra Metals Pvt Ltd', expectedDate: DateTime(2026, 10, 17), totalValue: 246000, status: 'Part received'),
          PurchaseOrderSummary(orderNumber: 'PO-2026-00482', supplier: 'Precision Bearings Co', expectedDate: DateTime(2026, 10, 18), totalValue: 118000, status: 'Pending approval'),
          PurchaseOrderSummary(orderNumber: 'PO-2026-00483', supplier: 'Om Packaging Industries', expectedDate: DateTime(2026, 10, 16), totalValue: 86000, status: 'Approved'),
          PurchaseOrderSummary(orderNumber: 'PO-2026-00479', supplier: 'Western Industrial Chemicals', expectedDate: DateTime(2026, 10, 13), totalValue: 302000, status: 'Overdue'),
        ],
        suppliers: const [
          SupplierPerformance(name: 'Maharashtra Metals Pvt Ltd', onTimeRate: .94),
          SupplierPerformance(name: 'Precision Bearings Co', onTimeRate: .91),
          SupplierPerformance(name: 'Om Packaging Industries', onTimeRate: .86),
        ],
        receipts: const [
          GoodsReceiptSummary(grnNumber: 'GRN-2026-00731', orderNumber: 'PO-2026-00481', lineCount: 2, receivedLabel: 'Today'),
          GoodsReceiptSummary(grnNumber: 'GRN-2026-00730', orderNumber: 'PO-2026-00477', lineCount: 4, receivedLabel: '13 Oct'),
          GoodsReceiptSummary(grnNumber: 'GRN-2026-00729', orderNumber: 'PO-2026-00475', lineCount: 1, receivedLabel: '12 Oct'),
        ],
      );

  @override
  Future<PurchaseOrderDetail> loadOrder(String orderNumber) async {
    if (orderNumber == 'PO-2026-00482') {
      return const PurchaseOrderDetail(
        orderNumber: 'PO-2026-00482',
        supplier: 'Om Packaging Industries',
        expectedDateLabel: '18 Oct 2026',
        status: 'Pending approval',
        paymentTerms: '21 days from accepted GRN',
        deliveryLocation: 'Raw Material Warehouse • Pune Plant',
        latestGrn: 'No receipt until approval',
        lines: [
          PurchaseOrderLine(sku: 'PK-CARTON-014', itemName: 'Packaging Carton', unit: 'pcs', orderedQuantity: 600, receivedQuantity: 0, unitPrice: 22),
        ],
        checks: [
          PurchaseCheck(label: 'Purchase order submitted', complete: true),
          PurchaseCheck(label: 'Factory Manager approval pending', complete: false),
          PurchaseCheck(label: 'Receiving locked until approval', complete: false),
        ],
      );
    }
    if (orderNumber == 'PO-2026-00483') {
      return const PurchaseOrderDetail(
        orderNumber: 'PO-2026-00483',
        supplier: 'Om Packaging Industries',
        expectedDateLabel: '16 Oct 2026',
        status: 'Approved',
        paymentTerms: '21 days from accepted GRN',
        deliveryLocation: 'Raw Material Warehouse • Pune Plant',
        latestGrn: 'Ready for first receipt',
        lines: [
          PurchaseOrderLine(sku: 'PK-CARTON-014', itemName: 'Packaging Carton', unit: 'pcs', orderedQuantity: 600, receivedQuantity: 0, unitPrice: 22),
        ],
        checks: [
          PurchaseCheck(label: 'Purchase order submitted', complete: true),
          PurchaseCheck(label: 'PO approved by Factory Manager', complete: true),
          PurchaseCheck(label: 'Goods receipt available', complete: true),
        ],
      );
    }
    return const PurchaseOrderDetail(
      orderNumber: 'PO-2026-00481',
      supplier: 'Maharashtra Metals Pvt Ltd',
      expectedDateLabel: '17 Oct 2026',
      status: 'Part received',
      paymentTerms: '30 days from accepted GRN',
      deliveryLocation: 'Raw Material Warehouse • Pune Plant',
      latestGrn: 'GRN-2026-00731 • Received today at 10:42',
      lines: [
        PurchaseOrderLine(sku: 'RM-STL-304-02', itemName: 'SS Sheet 304 2mm', unit: 'kg', orderedQuantity: 1000, receivedQuantity: 650, unitPrice: 198),
        PurchaseOrderLine(sku: 'RM-PIPE-001', itemName: 'Industrial Pipe 25mm', unit: 'pcs', orderedQuantity: 400, receivedQuantity: 400, unitPrice: 120),
      ],
      checks: [
        PurchaseCheck(label: 'Purchase request approved', complete: true),
        PurchaseCheck(label: 'PO approved by Factory Manager', complete: true),
        PurchaseCheck(label: 'Supplier acknowledged', complete: true),
        PurchaseCheck(label: 'First GRN quality check passed', complete: true),
        PurchaseCheck(label: 'Balance 350 kg still pending', complete: false),
      ],
    );
  }
}