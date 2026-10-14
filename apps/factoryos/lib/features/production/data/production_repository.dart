import '../domain/production_models.dart';

abstract interface class ProductionRepository {
  Future<ProductionOverview> loadOverview();
}

/// Preview-only adapter matching the connected demo dataset. The production
/// implementation will query aggregate views/RPCs in the dedicated FactoryOS
/// Supabase project rather than calculating operational truth in the widget.
final class PreviewProductionRepository implements ProductionRepository {
  const PreviewProductionRepository();

  @override
  Future<ProductionOverview> loadOverview() async {
    return const ProductionOverview(
      plannedQuantity: 4800,
      completedQuantity: 3420,
      activeOrderCount: 6,
      rejectedOrHoldQuantity: 32,
      orders: [
        ProductionOrderSummary(number: 'PRD-2026-01038', product: 'Industrial Component X', line: 'LINE-02', planned: 500, completed: 420, status: 'In Production'),
        ProductionOrderSummary(number: 'PRD-2026-01039', product: 'Valve Assembly 25mm', line: 'LINE-01', planned: 300, completed: 300, status: 'QC Pending'),
        ProductionOrderSummary(number: 'PRD-2026-01040', product: 'Bracket Set A', line: 'LINE-03', planned: 700, completed: 0, status: 'Material Pending'),
      ],
      alerts: [
        ProductionAlert(title: 'PRD-2026-01038', detail: 'Material short • 72 units pending', severity: ProductionAlertSeverity.warning),
        ProductionAlert(title: 'PB-141026-A06', detail: 'QC hold • 8 rejected', severity: ProductionAlertSeverity.critical),
        ProductionAlert(title: 'LINE-02', detail: 'Changeover due in 35 min', severity: ProductionAlertSeverity.info),
      ],
    );
  }
}
