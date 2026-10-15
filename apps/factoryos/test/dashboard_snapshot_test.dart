import 'package:flutter_test/flutter_test.dart';
import 'package:factoryos/core/models/dashboard_snapshot.dart';

void main() {
  test('production achievement handles normal and zero planned values', () {
    const snapshot = DashboardSnapshot(
      productionPlanned: 4800,
      productionCompleted: 3420,
      lowStockCount: 12,
      employeesPresent: 37,
      activeVehicles: 7,
      pendingApprovals: 5,
    );

    expect(snapshot.productionAchievement, closeTo(0.7125, 0.0001));

    const zeroPlan = DashboardSnapshot(
      productionPlanned: 0,
      productionCompleted: 0,
      lowStockCount: 0,
      employeesPresent: 0,
      activeVehicles: 0,
      pendingApprovals: 0,
    );
    expect(zeroPlan.productionAchievement, 0);
  });
}
