import 'package:factoryos/features/maintenance/domain/maintenance_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('asset availability is bounded and zero-safe', () {
    const empty = MaintenanceOverview(totalAssets: 0, operationalAssets: 0, pmDue: 0, breakdowns: 0, orders: [], assets: []);
    const overloaded = MaintenanceOverview(totalAssets: 3, operationalAssets: 4, pmDue: 0, breakdowns: 0, orders: [], assets: []);
    expect(empty.availability, 0);
    expect(overloaded.availability, 1);
  });

  test('spare requirement cannot count unposted issues as consumed', () {
    const part = MaintenanceSparePart(sku: 'SP-BRG-6204', name: 'Bearing', requestedQuantity: 2, postedIssueQuantity: 0);
    expect(part.pendingQuantity, 2);
    expect(part.fullyIssued, isFalse);
    const issued = MaintenanceSparePart(sku: 'SP-BRG-6204', name: 'Bearing', requestedQuantity: 2, postedIssueQuantity: 2);
    expect(issued.pendingQuantity, 0);
    expect(issued.fullyIssued, isTrue);
  });

  test('closure requires root cause, resolution, safety and issued spares', () {
    final started = DateTime(2026, 10, 14, 10);
    final closed = DateTime(2026, 10, 14, 12);
    MaintenanceWorkOrderDetail build({bool safety = true, String cause = 'Bearing wear', double posted = 2}) =>
      MaintenanceWorkOrderDetail(
        number: 'WO-1', assetCode: 'AC-02', assetName: 'Compressor', type: 'Breakdown',
        priority: 'Critical', status: 'In progress', assignee: 'Tech',
        reportedAt: started, startedAt: started, resolvedAt: closed,
        rootCause: cause, resolution: 'Replaced bearing', safetyCleared: safety,
        checklist: const [], spares: [MaintenanceSparePart(sku: 'SP-BRG-6204', name: 'Bearing', requestedQuantity: 2, postedIssueQuantity: posted)],
      );
    expect(build().canClose, isTrue);
    expect(build(safety: false).canClose, isFalse);
    expect(build(cause: '').canClose, isFalse);
    expect(build(posted: 0).canClose, isFalse);
    expect(build().downtime, const Duration(hours: 2));
  });

  test('planner counts only non-completed entries through date', () {
    final plan = MaintenancePlan([
      MaintenancePlanEntry(code: 'A', assetCode: 'AC-02', assetName: 'AC', task: 'Oil', dueAt: DateTime(2026, 10, 15), status: 'Due'),
      MaintenancePlanEntry(code: 'B', assetCode: 'CL-01', assetName: 'Lathe', task: 'Belt', dueAt: DateTime(2026, 10, 15), status: 'Completed'),
      MaintenancePlanEntry(code: 'C', assetCode: 'DG-01', assetName: 'Generator', task: 'Filter', dueAt: DateTime(2026, 10, 19), status: 'Scheduled'),
    ], 1);
    expect(plan.dueBy(DateTime(2026, 10, 15)), 1);
    expect(plan.dueBy(DateTime(2026, 10, 20)), 2);
  });
}
