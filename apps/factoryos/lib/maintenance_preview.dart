import 'package:flutter/material.dart';
import 'features/maintenance/data/maintenance_repository.dart';
import 'features/maintenance/presentation/maintenance_dashboard_page.dart';

void main() => runApp(const MaterialApp(
  title: 'FactoryOS Maintenance Preview',
  debugShowCheckedModeBanner: false,
  home: MaintenanceDashboardPage(repository: PreviewMaintenanceRepository()),
));
