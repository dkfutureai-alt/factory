import 'package:flutter/material.dart';

import 'core/data/dashboard_repository.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_page.dart';
import 'features/dashboard/admin_dashboard_page.dart';
import 'features/dispatch/data/dispatch_repository.dart';
import 'features/dispatch/presentation/dispatch_dashboard_page.dart';
import 'features/fleet/data/fleet_repository.dart';
import 'features/fleet/presentation/driver_detail_page.dart';
import 'features/fleet/presentation/fleet_dashboard_page.dart';
import 'features/fleet/presentation/fuel_management_page.dart';
import 'features/fleet/presentation/trip_management_page.dart';
import 'features/fleet/presentation/vehicle_detail_page.dart';
import 'features/home/driver_home_page.dart';
import 'features/home/employee_home_page.dart';
import 'features/hr/data/hr_repository.dart';
import 'features/hr/presentation/attendance_leave_page.dart';
import 'features/hr/presentation/employee_detail_page.dart';
import 'features/hr/presentation/holiday_calendar_page.dart';
import 'features/hr/presentation/hr_dashboard_page.dart';
import 'features/inventory/data/inventory_item_detail_repository.dart';
import 'features/inventory/data/inventory_repository.dart';
import 'features/inventory/presentation/inventory_dashboard_page.dart';
import 'features/inventory/presentation/inventory_item_detail_page.dart';
import 'features/production/data/production_order_detail_repository.dart';
import 'features/production/data/production_repository.dart';
import 'features/production/presentation/production_dashboard_page.dart';
import 'features/production/presentation/production_order_detail_page.dart';
import 'features/purchase/data/purchase_repository.dart';
import 'features/purchase/presentation/purchase_dashboard_page.dart';
import 'features/purchase/presentation/purchase_order_detail_page.dart';
import 'features/sales/data/sales_repository.dart';
import 'features/sales/presentation/customer_detail_page.dart';
import 'features/sales/presentation/payment_delivery_tracking_page.dart';
import 'features/sales/presentation/sales_dashboard_page.dart';
import 'features/sales/presentation/sales_order_detail_page.dart';
import 'features/scanner/domain/scanner_port.dart';
import 'features/scanner/presentation/scanner_page.dart';
import 'features/warehouse/data/warehouse_repository.dart';
import 'features/warehouse/presentation/warehouse_dashboard_page.dart';

void main() => runApp(const FactoryOsApp());

class FactoryOsApp extends StatelessWidget {
  const FactoryOsApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'FactoryOS',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        initialRoute: '/',
        routes: {
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
          '/hr': (_) => const HrDashboardPage(repository: PreviewHrRepository()),
          '/hr/employee': (_) => const EmployeeDetailPage(repository: PreviewHrRepository(), employeeCode: 'EMP-0018'),
          '/hr/attendance-leave': (_) => const AttendanceLeavePage(repository: PreviewHrRepository()),
          '/hr/holidays': (_) => const HolidayCalendarPage(repository: PreviewHrRepository()),
          '/sales': (_) => const SalesDashboardPage(repository: PreviewSalesRepository()),
          '/sales/customer': (_) => const CustomerDetailPage(repository: PreviewSalesRepository(), customerCode: 'CUST-0042'),
          '/sales/order': (_) => const SalesOrderDetailPage(repository: PreviewSalesRepository(), orderNumber: 'SO-2026-01842'),
          '/sales/tracking': (_) => const PaymentDeliveryTrackingPage(repository: PreviewSalesRepository(), orderNumber: 'SO-2026-01842'),
          '/fleet': (_) => const FleetDashboardPage(repository: PreviewFleetRepository()),
          '/fleet/vehicle': (_) => const VehicleDetailPage(repository: PreviewFleetRepository(), registration: 'MH 13 DK 4521'),
          '/fleet/driver': (_) => const DriverDetailPage(repository: PreviewFleetRepository(), employeeCode: 'DRV-0001'),
          '/fleet/trips': (_) => const TripManagementPage(repository: PreviewFleetRepository()),
          '/fleet/fuel': (_) => const FuelManagementPage(repository: PreviewFleetRepository()),
          '/scanner': (_) => const ScannerPage(scanner: PreviewScannerPort()),
          '/employee': (_) => const EmployeeHomePage(),
          '/driver': (_) => const DriverHomePage(),
        },
      );
}
