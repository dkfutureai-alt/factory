import '../domain/maintenance_models.dart';
abstract class MaintenanceRepository {
  Future<MaintenanceOverview> loadOverview();
  Future<MaintenanceAssetDetail> loadAsset(String code);
  Future<MaintenanceWorkOrderDetail> loadWorkOrder(String number);
  Future<MaintenancePlan> loadPlan();
}
class PreviewMaintenanceRepository implements MaintenanceRepository {
  const PreviewMaintenanceRepository();
  @override
  Future<MaintenanceOverview> loadOverview() async => const MaintenanceOverview(
    totalAssets: 21, operationalAssets: 18, pmDue: 4, breakdowns: 2,
    assets: [
      MaintenanceAssetSummary(code: 'AC-02', name: 'Air Compressor', location: 'Line 02', status: 'Maintenance', nextService: '18 Oct'),
      MaintenanceAssetSummary(code: 'CL-01', name: 'CNC Lathe', location: 'Line 01', status: 'Service due', nextService: '15 Oct'),
    ],
    orders: [
      MaintenanceWorkOrderSummary(number: 'WO-2026-00241', assetCode: 'AC-02', assetName: 'Air Compressor', type: 'Breakdown', priority: 'Critical', status: 'In progress', assignee: 'S. Patil'),
      MaintenanceWorkOrderSummary(number: 'WO-2026-00242', assetCode: 'CL-01', assetName: 'CNC Lathe', type: 'Corrective', priority: 'High', status: 'Awaiting spares', assignee: 'A. Jadhav'),
    ],
  );
  @override
  Future<MaintenanceAssetDetail> loadAsset(String code) async => const MaintenanceAssetDetail(
    code: 'AC-02', name: 'Air Compressor', location: 'Main Plant / Line 02',
    serialNumber: 'DEMO-AC-002', status: 'Maintenance', operatingHours: 8420,
    lastService: '18 Sep 2026', nextService: '18 Oct 2026',
    history: [
      MaintenanceHistoryEntry('WO-2026-00241', 'Bearing temperature alert', 'In progress'),
      MaintenanceHistoryEntry('WO-2026-00212', 'Lubrication and inspection', 'Completed'),
    ],
  );
  @override
  Future<MaintenanceWorkOrderDetail> loadWorkOrder(String number) async =>
    MaintenanceWorkOrderDetail(
      number: number, assetCode: 'AC-02', assetName: 'Air Compressor',
      type: 'Breakdown', priority: 'Critical', status: 'In progress', assignee: 'S. Patil',
      reportedAt: DateTime(2026, 10, 14, 9, 50),
      startedAt: DateTime(2026, 10, 14, 10, 30),
      resolvedAt: null, rootCause: '', resolution: '', safetyCleared: false,
      checklist: const ['Inspect equipment', 'Replace parts', 'Verify service'],
      spares: const [
        MaintenanceSparePart(sku: 'SP-BRG-6205', name: 'Bearing 6205', requestedQuantity: 2, postedIssueQuantity: 0),
      ],
    );
  @override
  Future<MaintenancePlan> loadPlan() async => MaintenancePlan([
    MaintenancePlanEntry(code: 'PM-CL-01', assetCode: 'CL-01', assetName: 'CNC Lathe', task: 'Belt inspection', dueAt: DateTime(2026, 10, 15), status: 'Due'),
    MaintenancePlanEntry(code: 'PM-AC-02', assetCode: 'AC-02', assetName: 'Air Compressor', task: 'Oil check', dueAt: DateTime(2026, 10, 18), status: 'Due'),
  ], 12);
}
