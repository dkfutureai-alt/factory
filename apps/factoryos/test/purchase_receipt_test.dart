import 'package:factoryos/factoryos_exports.dart';
import 'package:factoryos/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Purchase GRN request validates accepted rejected tracking and location totals', () async {
    final options = await const PreviewPurchaseReceiptRepository().loadOptions('PO-2026-00481');
    final line = options.lines.single;
    final valid = PurchaseReceiptLineRequest(
      purchaseOrderLineId: line.purchaseOrderLineId,
      receivedQuantity: 350,
      acceptedQuantity: 340,
      rejectedQuantity: 10,
      supplierBatchNumber: 'SUP-B-001',
      allocations: const [
        PurchaseReceiptAllocationRequest(
          locationId: 'preview-rm-a',
          quantity: 340,
          batchNumber: 'SUP-B-001',
        ),
      ],
    );
    final request = PurchaseReceiptRequest(
      purchaseOrderId: options.purchaseOrderId,
      warehouseId: 'preview-rm-wh',
      supplierInvoiceNumber: 'INV-001',
      supplierDeliveryNote: 'DN-001',
      note: 'Checked',
      lines: [valid],
      idempotencyKey: 'purchase-grn-test-001',
    );
    expect(valid.validate(line), isNull);
    expect(request.validate(options), isNull);
    expect(request.acceptedQuantity, 340);
    expect(request.rejectedQuantity, 10);

    final invalid = PurchaseReceiptLineRequest(
      purchaseOrderLineId: line.purchaseOrderLineId,
      receivedQuantity: 350,
      acceptedQuantity: 350,
      rejectedQuantity: 5,
      allocations: const [
        PurchaseReceiptAllocationRequest(locationId: 'preview-rm-a', quantity: 350),
      ],
    );
    expect(invalid.validate(line), contains('Accepted + rejected'));
  });

  test('Preview Purchase GRN never performs a fake mutation', () async {
    const repository = PreviewPurchaseReceiptRepository();
    final options = await repository.loadOptions('PO-2026-00481');
    expect(repository.supportsPosting, isFalse);
    expect(
      () => repository.postReceipt(
        PurchaseReceiptRequest(
          purchaseOrderId: options.purchaseOrderId,
          warehouseId: 'preview-rm-wh',
          supplierInvoiceNumber: '',
          supplierDeliveryNote: '',
          note: '',
          lines: const [],
          idempotencyKey: 'purchase-grn-preview-test',
        ),
      ),
      throwsA(isA<UnsupportedError>()),
    );
  });

  testWidgets('Purchase order opens the GRN preview workflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const FactoryOsApp(initialRoute: '/purchase/order'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('record-purchase-receipt')));
    await tester.pumpAndSettle();

    expect(find.text('Purchase GRN / Goods Receipt'), findsOneWidget);
    expect(find.textContaining('Preview mode is read-only'), findsOneWidget);
    expect(find.text('Post goods receipt'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('live-capable Purchase GRN posts through repository boundary', (tester) async {
    final repository = _FakePurchaseReceiptRepository();
    await tester.binding.setSurfaceSize(const Size(1440, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: PurchaseGoodsReceiptPage(repository: repository, orderNumber: 'PO-2026-00481'),
      ),
    );
    await tester.pumpAndSettle();

    final batchField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == 'Batch number',
    );
    expect(batchField, findsOneWidget);
    await tester.enterText(batchField, 'GRN-BATCH-TEST-001');
    await tester.tap(find.byKey(const Key('post-purchase-grn')));
    await tester.pumpAndSettle();

    expect(repository.postCount, 1);
    expect(repository.lastRequest?.acceptedQuantity, 350);
    expect(repository.lastRequest?.lines.single.allocations.single.batchNumber, 'GRN-BATCH-TEST-001');
    expect(find.textContaining('GRN-TEST-001'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

final class _FakePurchaseReceiptRepository implements PurchaseReceiptRepository {
  int postCount = 0;
  PurchaseReceiptRequest? lastRequest;

  @override
  bool get supportsPosting => true;

  @override
  Future<PurchaseReceiptOptions> loadOptions(String orderNumber) =>
      const PreviewPurchaseReceiptRepository().loadOptions(orderNumber);

  @override
  Future<PurchaseReceiptResult> postReceipt(PurchaseReceiptRequest request) async {
    postCount++;
    lastRequest = request;
    return const PurchaseReceiptResult(
      goodsReceiptId: 'grn-test-id',
      grnNumber: 'GRN-TEST-001',
      status: 'posted',
      stockTransactionId: 'stock-test-id',
    );
  }
}
