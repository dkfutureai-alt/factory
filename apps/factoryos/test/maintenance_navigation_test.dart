import 'package:factoryos/factoryos_routes.dart';
import 'package:factoryos/features/maintenance/data/maintenance_repository.dart';
import 'package:factoryos/features/maintenance/presentation/maintenance_dashboard_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('maintenance dashboard, work order and planner navigate', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: MaintenanceDashboardPage(repository: PreviewMaintenanceRepository())));
    await tester.pumpAndSettle();
    expect(find.text('Maintenance Management'), findsOneWidget);
    expect(find.text('Work order queue'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.textContaining('WO-2026-00241').first);
    await tester.pumpAndSettle();
    expect(find.text('Maintenance Work Order'), findsOneWidget);
    expect(find.text('Spare parts / Inventory handoff'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Preventive planner'));
    await tester.pumpAndSettle();
    expect(find.text('Preventive Maintenance Planner'), findsOneWidget);
    expect(find.text('Service schedule'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('admin sidebar reaches maintenance route', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(initialRoute: '/admin', routes: FactoryOsRoutes.routes));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Maintenance').first);
    await tester.pumpAndSettle();
    expect(find.text('Maintenance Management'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
