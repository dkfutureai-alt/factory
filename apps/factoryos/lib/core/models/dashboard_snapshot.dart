class DashboardSnapshot {
  const DashboardSnapshot({
    required this.productionPlanned,
    required this.productionCompleted,
    required this.lowStockCount,
    required this.employeesPresent,
    required this.activeVehicles,
    required this.pendingApprovals,
  });

  final int productionPlanned;
  final int productionCompleted;
  final int lowStockCount;
  final int employeesPresent;
  final int activeVehicles;
  final int pendingApprovals;

  double get productionAchievement =>
      productionPlanned == 0 ? 0 : productionCompleted / productionPlanned;
}
