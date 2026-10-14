import '../domain/reporting_models.dart';

abstract class ReportingRepository {
  Future<ReportsOverview> loadOverview();
  Future<ExecutiveAnalyticsReport> loadExecutive();
  Future<OperationsReport> loadOperations();
  Future<CommercialReport> loadCommercial();
  Future<WorkforceFleetReport> loadWorkforceFleet();
  Future<ReportPreview> buildPreview(ReportBuildRequest request);
}

class PreviewReportingRepository implements ReportingRepository {
  const PreviewReportingRepository();

  static final ReportFilter demoFilter = ReportFilter(
    start: DateTime(2026, 10, 1),
    end: DateTime(2026, 10, 14),
    factoryName: 'Main Manufacturing Plant',
  );

  @override
  Future<ReportsOverview> loadOverview() async => ReportsOverview(
        filter: demoFilter,
        productionAchievement: 0.924,
        inventoryValue: 4860000,
        salesThisMonth: 7230000,
        attendanceRate: 0.941,
        trend: const [
          ReportTrendPoint('08 Oct', 78),
          ReportTrendPoint('09 Oct', 82),
          ReportTrendPoint('10 Oct', 80),
          ReportTrendPoint('11 Oct', 87),
          ReportTrendPoint('12 Oct', 85),
          ReportTrendPoint('13 Oct', 91),
          ReportTrendPoint('14 Oct', 92.4),
        ],
      );

  @override
  Future<ExecutiveAnalyticsReport> loadExecutive() async => ExecutiveAnalyticsReport(
        filter: demoFilter,
        revenue: 7230000,
        productionAchievement: 0.924,
        onTimeDeliveryRate: 0.958,
        attendanceRate: 0.941,
        assetAvailability: 18 / 21,
        trend: const [
          ReportTrendPoint('W1', 84),
          ReportTrendPoint('W2', 88),
          ReportTrendPoint('W3', 87),
          ReportTrendPoint('W4', 92.4),
        ],
        attentionItems: const [
          '12 low-stock items • 4 production orders affected',
          '₹8.4L purchase outstanding • 3 approvals pending',
          '2 open breakdowns • Maintenance review required',
        ],
        scorecard: const [
          ReportScorecardRow(area: 'Production', kpi: 'Achievement', current: '92.4%', target: '90%', status: 'On track'),
          ReportScorecardRow(area: 'Delivery', kpi: 'On-time', current: '95.8%', target: '97%', status: 'Watch'),
          ReportScorecardRow(area: 'HR', kpi: 'Attendance', current: '94.1%', target: '93%', status: 'On track'),
          ReportScorecardRow(area: 'Maintenance', kpi: 'Availability', current: '85.7%', target: '90%', status: 'Watch'),
        ],
      );

  @override
  Future<OperationsReport> loadOperations() async => OperationsReport(
        filter: demoFilter,
        productionOutput: 18480,
        firstPassQuality: 0.972,
        lowStockItems: 12,
        downtimeHours: 7.4,
        linePerformance: const {'LINE-01': 0.91, 'LINE-02': 0.95, 'LINE-03': 0.85},
        rawMaterialValue: 2840000,
        finishedGoodsValue: 1570000,
        sparesValue: 450000,
        exceptions: const [
          'RM-STL-304-02 below reorder • PRD-2026-01040 material risk',
          'AC-02 breakdown • Line 02 downtime',
          'QC-2026-00418 • 8 units on hold',
        ],
      );

  @override
  Future<CommercialReport> loadCommercial() async => CommercialReport(
        filter: demoFilter,
        salesBooked: 7230000,
        collected: 5480000,
        purchaseOpen: 840000,
        overdueReceivables: 420000,
        openSalesOrders: 18,
        readyForDispatch: 7,
        purchaseOrdersDue: 7,
        customers: const [
          CustomerCommercialRow(customer: 'Aarav Engineering Works', sales: 1860000, collected: 1520000),
          CustomerCommercialRow(customer: 'Nova Process Systems', sales: 1480000, collected: 1190000),
          CustomerCommercialRow(customer: 'Sahyadri Industrial Systems', sales: 1120000, collected: 860000),
        ],
      );

  @override
  Future<WorkforceFleetReport> loadWorkforceFleet() async => WorkforceFleetReport(
        filter: demoFilter,
        attendanceRate: 0.941,
        onLeaveToday: 3,
        totalVehicles: 10,
        availableVehicles: 8,
        averageMileage: 8.7,
        tripsCompleted: 34,
        fuelConsumedLitres: 1248,
        serviceAlerts: 2,
        departmentAttendance: const [
          DepartmentAttendanceRow('Production', 0.96),
          DepartmentAttendanceRow('Warehouse', 0.92),
          DepartmentAttendanceRow('Logistics', 0.89),
          DepartmentAttendanceRow('Maintenance', 0.94),
        ],
        exceptions: const [
          'Attendance • 4 late check-ins • Supervisor review',
          'Fleet • MH12-DK-3201 service due • Schedule service',
          'Leave • 2 requests pending approval',
        ],
      );

  @override
  Future<ReportPreview> buildPreview(ReportBuildRequest request) async {
    final metrics = <ReportMetric>[];
    for (final metric in request.metrics) {
      switch (metric) {
        case 'Production':
          metrics.add(const ReportMetric(label: 'Production achievement', value: '92.4%', supporting: '18,480 pcs output'));
          break;
        case 'Inventory':
          metrics.add(const ReportMetric(label: 'Inventory value', value: '₹48.6L', supporting: '12 low-stock items'));
          break;
        case 'Sales & collections':
          metrics.add(const ReportMetric(label: 'Sales / collected', value: '₹72.3L / ₹54.8L', supporting: '₹17.5L receivable'));
          break;
        case 'Attendance':
          metrics.add(const ReportMetric(label: 'Attendance rate', value: '94.1%', supporting: '3 employees on leave'));
          break;
        case 'Fleet & maintenance':
          metrics.add(const ReportMetric(label: 'Fleet / asset availability', value: '80.0% / 85.7%', supporting: '2 fleet + 2 maintenance alerts'));
          break;
      }
    }
    return ReportPreview(title: request.reportType, filter: request.filter, metrics: metrics, format: request.format);
  }
}
