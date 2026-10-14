import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/maintenance/data/maintenance_repository.dart';
import 'features/maintenance/presentation/maintenance_dashboard_page.dart';

void main() => runApp(MaterialApp(
  title: 'FactoryOS Maintenance Preview',
  debugShowCheckedModeBanner: false,
  theme: AppTheme.light(),
  home: const MaintenanceDashboardPage(repository: PreviewMaintenanceRepository()),
));
