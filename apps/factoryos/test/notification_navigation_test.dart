import 'package:factoryos/factoryos_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('admin reaches notification center and alert rules', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(MaterialApp(initialRoute: '/admin', routes: FactoryOsRoutes.routes));
    await tester.pumpAndSettle();

    final notificationsNav = find.text('Notifications').first;
    await tester.ensureVisible(notificationsNav);
    await tester.tap(notificationsNav);
    await tester.pumpAndSettle();

    expect(find.text('Operational alerts & approvals'), findsOneWidget);
    expect(find.text('Live inbox'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(TextButton, 'Alert rules'));
    await tester.pumpAndSettle();
    expect(find.text('Role-scoped operational triggers'), findsOneWidget);
    expect(find.text('maintenance.breakdown'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('employee notification bell reaches inbox and preferences', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(MaterialApp(initialRoute: '/employee', routes: FactoryOsRoutes.routes));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    expect(find.text('Your factory alerts'), findsOneWidget);
    expect(find.text('Mark all as read'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.tune_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Choose your alerts'), findsOneWidget);
    expect(find.text('Critical safety & breakdown'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('driver notification bell reaches assigned driver alerts', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(MaterialApp(initialRoute: '/driver', routes: FactoryOsRoutes.routes));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    expect(find.text('Assigned driver alerts'), findsOneWidget);
    expect(find.text('Delivery DEL-2026-00681 assigned'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
