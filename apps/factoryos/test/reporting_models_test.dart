import 'package:factoryos/features/reporting/domain/reporting_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('report filter uses inclusive days and rejects reversed range', () {
    final normal = ReportFilter(start: DateTime(2026, 10, 1), end: DateTime(2026, 10, 14), factoryName: 'Plant');
    final reversed = ReportFilter(start: DateTime(2026, 10, 14), end: DateTime(2026, 10, 1), factoryName: 'Plant');
    expect(normal.inclusiveDays, 14);
    expect(reversed.inclusiveDays, 0);
  });

  test('commercial receivable and collection rate are safe and bounded', () {
    final report = CommercialReport(
      filter: ReportFilter(start: DateTime(2026, 10, 1), end: DateTime(2026, 10, 14), factoryName: 'Plant'),
      salesBooked: 100,
      collected: 120,
      purchaseOpen: 0,
      overdueReceivables: 0,
      openSalesOrders: 0,
      readyForDispatch: 0,
      purchaseOrdersDue: 0,
      customers: const [],
    );
    expect(report.receivable, 0);
    expect(report.collectionRate, 1);
    const customer = CustomerCommercialRow(customer: 'Demo', sales: 100, collected: 120);
    expect(customer.outstanding, 0);
  });

  test('operations inventory and line performance are derived safely', () {
    final report = OperationsReport(
      filter: ReportFilter(start: DateTime(2026, 10, 1), end: DateTime(2026, 10, 14), factoryName: 'Plant'),
      productionOutput: 1,
      firstPassQuality: 1,
      lowStockItems: 0,
      downtimeHours: 0,
      linePerformance: const {'A': 1.4},
      rawMaterialValue: 10,
      finishedGoodsValue: 20,
      sparesValue: 5,
      exceptions: const [],
    );
    expect(report.inventoryValue, 35);
    expect(report.lineRate('A'), 1);
    expect(report.lineRate('missing'), 0);
  });

  test('fleet availability is zero-safe and bounded', () {
    final empty = WorkforceFleetReport(
      filter: ReportFilter(start: DateTime(2026, 10, 1), end: DateTime(2026, 10, 1), factoryName: 'Plant'),
      attendanceRate: 1,
      onLeaveToday: 0,
      totalVehicles: 0,
      availableVehicles: 0,
      averageMileage: 0,
      tripsCompleted: 0,
      fuelConsumedLitres: 0,
      serviceAlerts: 0,
      departmentAttendance: const [],
      exceptions: const [],
    );
    final overloaded = WorkforceFleetReport(
      filter: empty.filter,
      attendanceRate: 1,
      onLeaveToday: 0,
      totalVehicles: 2,
      availableVehicles: 3,
      averageMileage: 0,
      tripsCompleted: 0,
      fuelConsumedLitres: 0,
      serviceAlerts: 0,
      departmentAttendance: const [],
      exceptions: const [],
    );
    expect(empty.fleetAvailability, 0);
    expect(overloaded.fleetAvailability, 1);
  });

  test('report preview validity follows selected date range', () {
    final good = ReportPreview(
      title: 'Executive',
      filter: ReportFilter(start: DateTime(2026, 10, 1), end: DateTime(2026, 10, 2), factoryName: 'Plant'),
      metrics: const [],
      format: ReportExportFormat.pdf,
    );
    final bad = ReportPreview(
      title: 'Executive',
      filter: ReportFilter(start: DateTime(2026, 10, 2), end: DateTime(2026, 10, 1), factoryName: 'Plant'),
      metrics: const [],
      format: ReportExportFormat.csv,
    );
    expect(good.hasValidRange, isTrue);
    expect(bad.hasValidRange, isFalse);
  });
}
