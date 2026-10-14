import 'package:factoryos/factoryos_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('maintenance dashboard reaches work order planner breakdowns and reports', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(initialRoute: '/maintenance', routes: FactoryOsRoutes.routes));
    await tester.pumpAndSettle();

    expect(find.text('Maintenance Management'), findsOneWidget);
    expect(find.text('Work order queue'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'Maintenance dashboard must render without overflow.');

    await tester.tap(find.textContaining('WO-2026-00241').first);
    await tester.pumpAndSettle();
    expect(find.text('Maintenance Work Order'), findsOneWidget);
    expect(find.text('Spare parts / Inventory handoff'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'Maintenance work order must render without overflow.');

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Preventive planner'));
    await tester.pumpAndSettle();
    expect(find.text('Preventive Maintenance Planner'), findsOneWidget);
    expect(find.text('Service schedule'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'Preventive planner must render without overflow.');

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Breakdowns & spares'));
    await tester.pumpAndSettle();
    expect(find.text('Breakdowns & Spare Parts'), findsOneWidget);
    expect(find.text('Spare requirements'), findsOneWidget);
    expect(find.text('Inventory handoff'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'Breakdown and spares page must render without overflow.');

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Maintenance reports'));
    await tester.pumpAndSettle();
    expect(find.text('Maintenance Reports'), findsOneWidget);
    expect(find.text('Reliability trend'), findsOneWidget);
    expect(find.text('Top downtime assets'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'Maintenance reports must render without overflow.');
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
