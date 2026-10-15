import 'package:flutter/material.dart';
import 'factoryos_exports.dart';

class FactoryOsPeopleRoutes {
  static final Map<String, WidgetBuilder> routes = {
    '/hr': (_) => const HrDashboardPage(repository: PreviewHrRepository()),
    '/hr/employee': (_) => const EmployeeDetailPage(repository: PreviewHrRepository(), employeeCode: 'EMP-0018'),
    '/hr/attendance-leave': (_) => const AttendanceLeavePage(repository: PreviewHrRepository()),
    '/hr/holidays': (_) => const HolidayCalendarPage(repository: PreviewHrRepository()),
    '/sales': (_) => const SalesDashboardPage(repository: PreviewSalesRepository()),
    '/sales/customer': (_) => const CustomerDetailPage(repository: PreviewSalesRepository(), customerCode: 'CUST-0042'),
    '/sales/order': (_) => const SalesOrderDetailPage(repository: PreviewSalesRepository(), orderNumber: 'SO-2026-01842'),
    '/sales/tracking': (_) => const PaymentDeliveryTrackingPage(repository: PreviewSalesRepository(), orderNumber: 'SO-2026-01842'),
    '/scanner': (_) => const ScannerPage(scanner: PreviewScannerPort()),
    '/employee': (_) => const EmployeeHomePage(),
    '/driver': (_) => const DriverHomePage(),
    '/notifications/employee': (_) => const NotificationInboxPage(repository: PreviewNotificationRepository(), audience: 'employee'),
    '/notifications/driver': (_) => const NotificationInboxPage(repository: PreviewNotificationRepository(), audience: 'driver'),
    '/notifications/preferences': (_) => const NotificationPreferencesPage(repository: PreviewNotificationRepository()),
  };
}
