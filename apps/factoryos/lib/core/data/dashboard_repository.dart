import '../models/dashboard_snapshot.dart';

abstract interface class DashboardRepository {
  Future<DashboardSnapshot> loadOverview();
}

/// Temporary preview adapter used only until the dedicated FactoryOS Supabase
/// project is connected. Widgets depend on [DashboardRepository], not these
/// values, so production data can replace this adapter without UI rewrites.
final class PreviewDashboardRepository implements DashboardRepository {
  const PreviewDashboardRepository();

  @override
  Future<DashboardSnapshot> loadOverview() async {
    return const DashboardSnapshot(
      productionPlanned: 4800,
      productionCompleted: 3420,
      lowStockCount: 12,
      employeesPresent: 37,
      activeVehicles: 7,
      pendingApprovals: 5,
    );
  }
}
