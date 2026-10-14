import 'package:flutter/material.dart';

import 'core/data/dashboard_repository.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_page.dart';
import 'features/dashboard/admin_dashboard_page.dart';
import 'features/home/driver_home_page.dart';
import 'features/home/employee_home_page.dart';
import 'features/inventory/data/inventory_repository.dart';
import 'features/inventory/presentation/inventory_dashboard_page.dart';
import 'features/production/data/production_repository.dart';
import 'features/production/presentation/production_dashboard_page.dart';
import 'features/scanner/domain/scanner_port.dart';
import 'features/scanner/presentation/scanner_page.dart';

void main() {
  runApp(const FactoryOsApp());
}

class FactoryOsApp extends StatelessWidget {
  const FactoryOsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FactoryOS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      initialRoute: '/',
      routes: {
        '/': (_) => const LoginPage(),
        '/admin': (_) => const AdminDashboardPage(
              repository: PreviewDashboardRepository(),
            ),
        '/inventory': (_) => const InventoryDashboardPage(
              repository: PreviewInventoryRepository(),
            ),
        '/production': (_) => const ProductionDashboardPage(
              repository: PreviewProductionRepository(),
            ),
        '/scanner': (_) => const ScannerPage(
              scanner: PreviewScannerPort(),
            ),
        '/employee': (_) => const EmployeeHomePage(),
        '/driver': (_) => const DriverHomePage(),
      },
    );
  }
}
