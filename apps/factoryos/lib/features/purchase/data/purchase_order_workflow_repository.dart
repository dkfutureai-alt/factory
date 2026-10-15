import '../domain/purchase_order_workflow_models.dart';

abstract interface class PurchaseOrderWorkflowRepository {
  bool get supportsMutations;

  Future<PurchaseOrderEditorOptions> loadEditor({String? orderNumber});
  Future<PurchaseOrderWorkflowResult> saveDraft(PurchaseOrderDraftRequest request);
  Future<PurchaseOrderWorkflowResult> submit({
    required String purchaseOrderId,
    required int expectedRevision,
    required String idempotencyKey,
  });
  Future<PurchaseOrderWorkflowResult> decide(PurchaseOrderDecisionRequest request);
}

final class PreviewPurchaseOrderWorkflowRepository implements PurchaseOrderWorkflowRepository {
  const PreviewPurchaseOrderWorkflowRepository();

  @override
  bool get supportsMutations => false;

  @override
  Future<PurchaseOrderEditorOptions> loadEditor({String? orderNumber}) async {
    const factories = [
      PurchaseOrderFactoryOption(id: 'preview-plant-01', code: 'PLANT-01', name: 'Main Manufacturing Plant'),
    ];
    const suppliers = [
      PurchaseOrderSupplierOption(id: 'preview-sup-metals', code: 'SUP-METALS', name: 'Maharashtra Metals Pvt Ltd', paymentTermsDays: 30),
      PurchaseOrderSupplierOption(id: 'preview-sup-pack', code: 'SUP-PACK', name: 'Om Packaging Industries', paymentTermsDays: 21),
    ];
    const items = [
      PurchaseOrderItemOption(id: 'preview-rm-steel', sku: 'RM-STL-304-02', name: 'SS Sheet 304 2mm', unit: 'KG', defaultUnitPrice: 198),
      PurchaseOrderItemOption(id: 'preview-carton', sku: 'PK-CARTON-014', name: 'Packaging Carton', unit: 'PCS', defaultUnitPrice: 22),
    ];
    PurchaseOrderDraftSnapshot? draft;
    if (orderNumber != null) {
      final pending = orderNumber == 'PO-2026-00482';
      draft = PurchaseOrderDraftSnapshot(
        purchaseOrderId: pending ? 'preview-po-482' : 'preview-po-481',
        orderNumber: orderNumber,
        revision: pending ? 3 : 2,
        status: pending ? 'pending_approval' : 'draft',
        factoryId: 'preview-plant-01',
        supplierId: pending ? 'preview-sup-pack' : 'preview-sup-metals',
        expectedDeliveryDate: DateTime(2026, 10, pending ? 18 : 20),
        paymentTerms: pending ? '21 days from accepted GRN' : '30 days from accepted GRN',
        notes: pending ? 'Packaging replenishment for October production.' : 'Material as per approved specification.',
        lines: pending
            ? const [PurchaseOrderDraftLine(itemId: 'preview-carton', orderedQuantity: 600, unitPrice: 22, taxRate: 18)]
            : const [
                PurchaseOrderDraftLine(itemId: 'preview-rm-steel', orderedQuantity: 350, unitPrice: 198, taxRate: 18),
                PurchaseOrderDraftLine(itemId: 'preview-carton', orderedQuantity: 600, unitPrice: 22, taxRate: 18),
              ],
        submittedBy: pending ? 'Factory Purchase User' : null,
        submittedAt: pending ? DateTime(2026, 10, 15, 10, 30) : null,
      );
    }
    return PurchaseOrderEditorOptions(factories: factories, suppliers: suppliers, items: items, draft: draft);
  }

  @override
  Future<PurchaseOrderWorkflowResult> saveDraft(PurchaseOrderDraftRequest request) =>
      throw UnsupportedError('Preview mode does not create or update purchase orders.');

  @override
  Future<PurchaseOrderWorkflowResult> submit({required String purchaseOrderId, required int expectedRevision, required String idempotencyKey}) =>
      throw UnsupportedError('Preview mode does not submit purchase orders.');

  @override
  Future<PurchaseOrderWorkflowResult> decide(PurchaseOrderDecisionRequest request) =>
      throw UnsupportedError('Preview mode does not approve or reject purchase orders.');
}