import 'package:flutter/material.dart';
import 'factoryos_exports.dart';

class FactoryOsOperationsRoutes {
  static final Map<String, WidgetBuilder> routes = {
    '/': (_) => const LoginPage(),
    '/admin': (_) => const AdminDashboardPage(repository: PreviewDashboardRepository()),
    '/inventory': (_) => const InventoryDashboardPage(repository: PreviewInventoryRepository()),
    '/inventory/item': (_) => const InventoryItemDetailPage(repository: PreviewInventoryItemDetailRepository(), sku: 'RM-STL-304-02'),
    '/production': (_) => const ProductionDashboardPage(repository: PreviewProductionRepository()),
    '/production/order': (_) => const ProductionOrderDetailPage(repository: PreviewProductionOrderDetailRepository(), orderNumber: 'PRD-2026-01038'),
    '/purchase': (_) => const PurchaseDashboardPage(repository: PreviewPurchaseRepository()),
    '/purchase/order': (_) => const PurchaseOrderDetailPage(repository: PreviewPurchaseRepository(), orderNumber: 'PO-2026-00481'),
    '/warehouse': (_) => const WarehouseDashboardPage(repository: PreviewWarehouseRepository()),
    '/dispatch': (_) => const DispatchDashboardPage(repository: PreviewDispatchRepository()),
    '/delivery': (_) => const DeliveryDashboardPage(repository: PreviewDeliveryRepository()),
    '/delivery/detail': (_) => const DeliveryDetailPage(repository: PreviewDeliveryRepository(), deliveryNumber: 'DEL-2026-00681'),
    '/delivery/exception': (_) => const DeliveryExceptionPage(repository: PreviewDeliveryRepository(), deliveryNumber: 'DEL-2026-00678'),
    '/maintenance': (_) => const MaintenanceDashboardPage(repository: PreviewMaintenanceRepository()),
    '/maintenance/asset': (_) => const MaintenanceAssetPage(repository: PreviewMaintenanceRepository(), code: 'AC-02'),
    '/maintenance/work-order': (_) => const MaintenanceWorkOrderPage(repository: PreviewMaintenanceRepository(), number: 'WO-2026-00241'),
    '/maintenance/plan': (_) => const MaintenancePlanPage(repository: PreviewMaintenanceRepository()),
    '/maintenance/breakdowns': (_) => const MaintenanceBreakdownSparesPage(repository: PreviewMaintenanceRepository()),
    '/maintenance/reports': (_) => const MaintenanceReportsPage(repository: PreviewMaintenanceRepository()),
    '/reports': (_) => const ReportsDashboardPage(repository: PreviewReportingRepository()),
    '/reports/executive': (_) => const ExecutiveAnalyticsPage(repository: PreviewReportingRepository()),
    '/reports/operations': (_) => const OperationsReportPage(repository: PreviewReportingRepository()),
    '/reports/commercial': (_) => const CommercialReportPage(repository: PreviewReportingRepository()),
    '/reports/workforce-fleet': (_) => const WorkforceFleetReportPage(repository: PreviewReportingRepository()),
    '/reports/builder': (_) => const ReportBuilderPage(repository: PreviewReportingRepository()),
    '/notifications': (_) => const NotificationCenterPage(repository: PreviewNotificationRepository()),
    '/notifications/rules': (_) => const NotificationRulesPage(repository: PreviewNotificationRepository()),
  };
}
