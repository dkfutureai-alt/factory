import 'package:factoryos/factoryos_exports.dart';
import 'package:factoryos/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PO draft request derives totals and rejects duplicate items', () async {
    final options = await const PreviewPurchaseOrderWorkflowRepository().loadEditor();
    final first = options.items.first;
    final line = PurchaseOrderDraftLine(
      itemId: first.id,
      orderedQuantity: 10,
      unitPrice: 100,
      taxRate: 18,
    );
    final request = PurchaseOrderDraftRequest(
      factoryId: options.factories.first.id,
      supplierId: options.suppliers.first.id,
      expectedDeliveryDate: DateTime.now().add(const Duration(days: 5)),
      paymentTerms: '30 days',
      notes: 'Test',
      lines: [line],
      idempotencyKey: 'po-model-test-001',
    );
    expect(request.validate(options), isNull);
    expect(request.lineValue, 1000);
    expect(request.taxValue, 180);
    expect(request.totalValue, 1180);

    final duplicate = PurchaseOrderDraftRequest(
      factoryId: request.factoryId,
      supplierId: request.supplierId,
      expectedDeliveryDate: request.expectedDeliveryDate,
      paymentTerms: request.paymentTerms,
      notes: request.notes,
      lines: [line, line],
      idempotencyKey: 'po-model-test-002',
    );
    expect(duplicate.validate(options), contains('same item'));
  });

  test('Preview PO workflow never performs a fake mutation', () async {
    const repository = PreviewPurchaseOrderWorkflowRepository();
    final options = await repository.loadEditor();
    expect(repository.supportsMutations, isFalse);
    final request = PurchaseOrderDraftRequest(
      factoryId: options.factories.first.id,
      supplierId: options.suppliers.first.id,
      expectedDeliveryDate: DateTime.now().add(const Duration(days: 5)),
      paymentTerms: '30 days',
      notes: 'Preview only',
      lines: const [],
      idempotencyKey: 'preview-po-create-001',
    );
    expect(() => repository.saveDraft(request), throwsA(isA<UnsupportedError>()));
  });

  testWidgets('Purchase dashboard opens Create Purchase Order preview', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const FactoryOsApp(initialRoute: '/purchase'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('create-purchase-order')));
    await tester.pumpAndSettle();

    expect(find.text('Create Purchase Order'), findsOneWidget);
    expect(find.text('Save draft'), findsOneWidget);
    expect(find.text('Submit approval'), findsOneWidget);
    expect(find.textContaining('Preview mode'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Pending PO reaches approval review from purchase queue', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const FactoryOsApp(initialRoute: '/purchase'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('PO-2026-00482').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('review-purchase-order')), findsOneWidget);

    await tester.tap(find.byKey(const Key('review-purchase-order')));
    await tester.pumpAndSettle();
    expect(find.text('Purchase Order Approval'), findsOneWidget);
    expect(find.text('Approve PO'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Live-capable PO editor saves then submits through repository boundary', (tester) async {
    final repository = _FakePurchaseOrderWorkflowRepository();
    await tester.binding.setSurfaceSize(const Size(1440, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: PurchaseOrderEditorPage(repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add item'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit approval'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(repository.saveCount, 1);
    expect(repository.submitCount, 1);
    expect(repository.lastDraft?.lines.length, 1);
    expect(repository.lastSubmitRevision, 1);
    expect(find.textContaining('Pending Approval'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Live-capable approval surface sends approve decision through repository boundary', (tester) async {
    final repository = _FakePurchaseOrderWorkflowRepository(pendingApproval: true);
    await tester.binding.setSurfaceSize(const Size(1440, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: PurchaseOrderApprovalPage(repository: repository, orderNumber: 'PO-TEST-001'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Approve PO'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(repository.decisionCount, 1);
    expect(repository.lastDecision?.decision, PurchaseOrderDecision.approve);
    expect(find.textContaining('Current state: approved'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

final class _FakePurchaseOrderWorkflowRepository implements PurchaseOrderWorkflowRepository {
  _FakePurchaseOrderWorkflowRepository({this.pendingApproval = false});

  final bool pendingApproval;
  bool decided = false;
  int saveCount = 0;
  int submitCount = 0;
  int decisionCount = 0;
  int? lastSubmitRevision;
  PurchaseOrderDraftRequest? lastDraft;
  PurchaseOrderDecisionRequest? lastDecision;

  static const _factory = PurchaseOrderFactoryOption(id: 'factory-1', code: 'PLANT-01', name: 'Test Plant');
  static const _supplier = PurchaseOrderSupplierOption(id: 'supplier-1', code: 'SUP-01', name: 'Test Supplier', paymentTermsDays: 30);
  static const _item = PurchaseOrderItemOption(id: 'item-1', sku: 'RM-001', name: 'Test Material', unit: 'KG', defaultUnitPrice: 100);

  @override
  bool get supportsMutations => true;

  @override
  Future<PurchaseOrderEditorOptions> loadEditor({String? orderNumber}) async {
    PurchaseOrderDraftSnapshot? draft;
    if (pendingApproval) {
      draft = PurchaseOrderDraftSnapshot(
        purchaseOrderId: 'po-1',
        orderNumber: orderNumber ?? 'PO-TEST-001',
        revision: decided ? 3 : 2,
        status: decided ? 'approved' : 'pending_approval',
        factoryId: _factory.id,
        supplierId: _supplier.id,
        expectedDeliveryDate: DateTime.now().add(const Duration(days: 5)),
        paymentTerms: '30 days',
        notes: 'Approval test',
        lines: const [PurchaseOrderDraftLine(itemId: 'item-1', orderedQuantity: 5, unitPrice: 100, taxRate: 18)],
      );
    }
    return PurchaseOrderEditorOptions(
      factories: const [_factory],
      suppliers: const [_supplier],
      items: const [_item],
      draft: draft,
    );
  }

  @override
  Future<PurchaseOrderWorkflowResult> saveDraft(PurchaseOrderDraftRequest request) async {
    saveCount++;
    lastDraft = request;
    return const PurchaseOrderWorkflowResult(
      purchaseOrderId: 'po-1',
      orderNumber: 'PO-TEST-001',
      revision: 1,
      status: 'draft',
    );
  }

  @override
  Future<PurchaseOrderWorkflowResult> submit({required String purchaseOrderId, required int expectedRevision, required String idempotencyKey}) async {
    submitCount++;
    lastSubmitRevision = expectedRevision;
    return const PurchaseOrderWorkflowResult(
      purchaseOrderId: 'po-1',
      orderNumber: 'PO-TEST-001',
      revision: 2,
      status: 'pending_approval',
    );
  }

  @override
  Future<PurchaseOrderWorkflowResult> decide(PurchaseOrderDecisionRequest request) async {
    decisionCount++;
    lastDecision = request;
    decided = true;
    return const PurchaseOrderWorkflowResult(
      purchaseOrderId: 'po-1',
      orderNumber: 'PO-TEST-001',
      revision: 3,
      status: 'approved',
    );
  }
}