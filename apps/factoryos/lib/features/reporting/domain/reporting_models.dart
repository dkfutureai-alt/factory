class ReportFilter {
  const ReportFilter({required this.start, required this.end, required this.factoryName});
  final DateTime start;
  final DateTime end;
  final String factoryName;

  int get inclusiveDays => end.isBefore(start) ? 0 : end.difference(start).inDays + 1;
}

class ReportMetric {
  const ReportMetric({required this.label, required this.value, this.supporting = '', this.trendPercent});
  final String label;
  final String value;
  final String supporting;
  final double? trendPercent;
}

class ReportTrendPoint {
  const ReportTrendPoint(this.label, this.value);
  final String label;
  final double value;
}

class ReportScorecardRow {
  const ReportScorecardRow({required this.area, required this.kpi, required this.current, required this.target, required this.status});
  final String area;
  final String kpi;
  final String current;
  final String target;
  final String status;
}

class ReportsOverview {
  const ReportsOverview({
    required this.filter,
    required this.productionAchievement,
    required this.inventoryValue,
    required this.salesThisMonth,
    required this.attendanceRate,
    required this.trend,
  });
  final ReportFilter filter;
  final double productionAchievement;
  final double inventoryValue;
  final double salesThisMonth;
  final double attendanceRate;
  final List<ReportTrendPoint> trend;

  double get boundedProductionAchievement => productionAchievement.clamp(0, 1).toDouble();
  double get boundedAttendanceRate => attendanceRate.clamp(0, 1).toDouble();
}

class ExecutiveAnalyticsReport {
  const ExecutiveAnalyticsReport({
    required this.filter,
    required this.revenue,
    required this.productionAchievement,
    required this.onTimeDeliveryRate,
    required this.attendanceRate,
    required this.assetAvailability,
    required this.trend,
    required this.attentionItems,
    required this.scorecard,
  });
  final ReportFilter filter;
  final double revenue;
  final double productionAchievement;
  final double onTimeDeliveryRate;
  final double attendanceRate;
  final double assetAvailability;
  final List<ReportTrendPoint> trend;
  final List<String> attentionItems;
  final List<ReportScorecardRow> scorecard;

  double boundedRate(double value) => value.clamp(0, 1).toDouble();
}

class OperationsReport {
  const OperationsReport({
    required this.filter,
    required this.productionOutput,
    required this.firstPassQuality,
    required this.lowStockItems,
    required this.downtimeHours,
    required this.linePerformance,
    required this.rawMaterialValue,
    required this.finishedGoodsValue,
    required this.sparesValue,
    required this.exceptions,
  });
  final ReportFilter filter;
  final int productionOutput;
  final double firstPassQuality;
  final int lowStockItems;
  final double downtimeHours;
  final Map<String, double> linePerformance;
  final double rawMaterialValue;
  final double finishedGoodsValue;
  final double sparesValue;
  final List<String> exceptions;

  double get inventoryValue => rawMaterialValue + finishedGoodsValue + sparesValue;
  double lineRate(String line) => (linePerformance[line] ?? 0).clamp(0, 1).toDouble();
}

class CustomerCommercialRow {
  const CustomerCommercialRow({required this.customer, required this.sales, required this.collected});
  final String customer;
  final double sales;
  final double collected;
  double get outstanding => (sales - collected).clamp(0, double.infinity).toDouble();
}

class CommercialReport {
  const CommercialReport({
    required this.filter,
    required this.salesBooked,
    required this.collected,
    required this.purchaseOpen,
    required this.overdueReceivables,
    required this.openSalesOrders,
    required this.readyForDispatch,
    required this.purchaseOrdersDue,
    required this.customers,
  });
  final ReportFilter filter;
  final double salesBooked;
  final double collected;
  final double purchaseOpen;
  final double overdueReceivables;
  final int openSalesOrders;
  final int readyForDispatch;
  final int purchaseOrdersDue;
  final List<CustomerCommercialRow> customers;

  double get receivable => (salesBooked - collected).clamp(0, double.infinity).toDouble();
  double get collectionRate => salesBooked <= 0 ? 0 : (collected / salesBooked).clamp(0, 1).toDouble();
}

class DepartmentAttendanceRow {
  const DepartmentAttendanceRow(this.department, this.rate);
  final String department;
  final double rate;
  double get boundedRate => rate.clamp(0, 1).toDouble();
}

class WorkforceFleetReport {
  const WorkforceFleetReport({
    required this.filter,
    required this.attendanceRate,
    required this.onLeaveToday,
    required this.totalVehicles,
    required this.availableVehicles,
    required this.averageMileage,
    required this.tripsCompleted,
    required this.fuelConsumedLitres,
    required this.serviceAlerts,
    required this.departmentAttendance,
    required this.exceptions,
  });
  final ReportFilter filter;
  final double attendanceRate;
  final int onLeaveToday;
  final int totalVehicles;
  final int availableVehicles;
  final double averageMileage;
  final int tripsCompleted;
  final double fuelConsumedLitres;
  final int serviceAlerts;
  final List<DepartmentAttendanceRow> departmentAttendance;
  final List<String> exceptions;

  double get fleetAvailability => totalVehicles <= 0 ? 0 : (availableVehicles / totalVehicles).clamp(0, 1).toDouble();
}

enum ReportExportFormat { pdf, csv, excel }

class ReportBuildRequest {
  const ReportBuildRequest({
    required this.reportType,
    required this.filter,
    required this.metrics,
    required this.format,
  });
  final String reportType;
  final ReportFilter filter;
  final List<String> metrics;
  final ReportExportFormat format;
}

class ReportPreview {
  const ReportPreview({required this.title, required this.filter, required this.metrics, required this.format});
  final String title;
  final ReportFilter filter;
  final List<ReportMetric> metrics;
  final ReportExportFormat format;

  bool get hasValidRange => filter.inclusiveDays > 0;
}
