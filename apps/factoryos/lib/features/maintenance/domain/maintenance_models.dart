enum MaintenanceSeverity { info, warning, critical }

class MaintenanceAssetSummary {
  const MaintenanceAssetSummary({required this.code, required this.name, required this.location, required this.status, required this.nextService});
  final String code;
  final String name;
  final String location;
  final String status;
  final String nextService;
}

class MaintenanceWorkOrderSummary {
  const MaintenanceWorkOrderSummary({required this.number, required this.assetCode, required this.assetName, required this.type, required this.priority, required this.status, required this.assignee});
  final String number;
  final String assetCode;
  final String assetName;
  final String type;
  final String priority;
  final String status;
  final String assignee;
}

class MaintenanceOverview {
  const MaintenanceOverview({required this.totalAssets, required this.operationalAssets, required this.pmDue, required this.breakdowns, required this.orders, required this.assets});
  final int totalAssets;
  final int operationalAssets;
  final int pmDue;
  final int breakdowns;
  final List<MaintenanceWorkOrderSummary> orders;
  final List<MaintenanceAssetSummary> assets;
  double get availability => totalAssets <= 0 ? 0 : (operationalAssets / totalAssets).clamp(0, 1).toDouble();
}

class MaintenanceHistoryEntry {
  const MaintenanceHistoryEntry(this.number, this.description, this.status);
  final String number;
  final String description;
  final String status;
}

class MaintenanceAssetDetail {
  const MaintenanceAssetDetail({required this.code, required this.name, required this.location, required this.serialNumber, required this.status, required this.operatingHours, required this.lastService, required this.nextService, required this.history});
  final String code;
  final String name;
  final String location;
  final String serialNumber;
  final String status;
  final int operatingHours;
  final String lastService;
  final String nextService;
  final List<MaintenanceHistoryEntry> history;
}

class MaintenanceSparePart {
  const MaintenanceSparePart({required this.sku, required this.name, required this.requestedQuantity, required this.postedIssueQuantity});
  final String sku;
  final String name;
  final double requestedQuantity;
  final double postedIssueQuantity;
  double get pendingQuantity => (requestedQuantity - postedIssueQuantity).clamp(0, double.infinity).toDouble();
  bool get fullyIssued => postedIssueQuantity >= requestedQuantity;
}

class MaintenanceWorkOrderDetail {
  const MaintenanceWorkOrderDetail({required this.number, required this.assetCode, required this.assetName, required this.type, required this.priority, required this.status, required this.assignee, required this.reportedAt, required this.startedAt, required this.resolvedAt, required this.rootCause, required this.resolution, required this.safetyCleared, required this.checklist, required this.spares});
  final String number;
  final String assetCode;
  final String assetName;
  final String type;
  final String priority;
  final String status;
  final String assignee;
  final DateTime reportedAt;
  final DateTime? startedAt;
  final DateTime? resolvedAt;
  final String rootCause;
  final String resolution;
  final bool safetyCleared;
  final List<String> checklist;
  final List<MaintenanceSparePart> spares;
  Duration get downtime => startedAt == null || resolvedAt == null || resolvedAt!.isBefore(startedAt!) ? Duration.zero : resolvedAt!.difference(startedAt!);
  bool get sparesReconciled => spares.every((part) => part.fullyIssued);
  bool get canClose => startedAt != null && resolvedAt != null && !resolvedAt!.isBefore(startedAt!) && rootCause.trim().isNotEmpty && resolution.trim().isNotEmpty && safetyCleared && sparesReconciled;
}

class MaintenancePlanEntry {
  const MaintenancePlanEntry({required this.code, required this.assetCode, required this.assetName, required this.task, required this.dueAt, required this.status});
  final String code;
  final String assetCode;
  final String assetName;
  final String task;
  final DateTime dueAt;
  final String status;
  bool overdueAt(DateTime now) => status != 'Completed' && dueAt.isBefore(now);
}

class MaintenancePlan {
  const MaintenancePlan(this.entries, this.completedThisMonth);
  final List<MaintenancePlanEntry> entries;
  final int completedThisMonth;
  int dueBy(DateTime date) => entries.where((e) => e.status != 'Completed' && !e.dueAt.isAfter(date)).length;
}
