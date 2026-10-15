import 'package:factoryos/features/purchase/domain/purchase_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('purchase order line pending quantity never goes negative', () {
    const line = PurchaseOrderLine(
      sku: 'RM-1',
      itemName: 'Material',
      unit: 'kg',
      orderedQuantity: 100,
      receivedQuantity: 120,
      unitPrice: 10,
    );
    expect(line.pendingQuantity, 0);
    expect(line.fullyReceived, isTrue);
  });

  test('purchase order detail derives order received and pending values', () {
    const detail = PurchaseOrderDetail(
      orderNumber: 'PO-1',
      supplier: 'Supplier',
      expectedDateLabel: '17 Oct 2026',
      status: 'Part received',
      paymentTerms: '30 days',
      deliveryLocation: 'RM Warehouse',
      latestGrn: 'GRN-1',
      lines: [
        PurchaseOrderLine(sku: 'A', itemName: 'A', unit: 'kg', orderedQuantity: 10, receivedQuantity: 6, unitPrice: 100),
        PurchaseOrderLine(sku: 'B', itemName: 'B', unit: 'pcs', orderedQuantity: 5, receivedQuantity: 5, unitPrice: 200),
      ],
      checks: [],
    );
    expect(detail.orderValue, 2000);
    expect(detail.receivedValue, 1600);
    expect(detail.pendingValue, 400);
    expect(detail.fullyReceived, isFalse);
  });
}
