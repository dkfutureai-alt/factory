import 'package:factoryos/factoryos_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('warehouse transfer and dispatch handoff render without exceptions', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(MaterialApp(initialRoute: '/warehouse', routes: FactoryOsRoutes.routes));
    await tester.pumpAndSettle();
    expect(find.text('Operational tasks'), findsOneWidget);
    expect(find.textContaining('TRF-2026-00218'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'Warehouse dashboard must render without overflow.');

    await tester.tap(find.textContaining('TRF-2026-00218').first);
    await tester.pumpAndSettle();
    expect(find.text('Transfer lines'), findsOneWidget);
    expect(find.text('Completion gate'), findsOneWidget);
    expect(find.textContaining('transfer_out ledger posted'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'Warehouse transfer detail must render without overflow.');

    await tester.pumpWidget(MaterialApp(initialRoute: '/dispatch', routes: FactoryOsRoutes.routes));
    await tester.pumpAndSettle();
    expect(find.text('Dispatch queue'), findsOneWidget);
    expect(find.textContaining('DSP-2026-00417'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'Dispatch dashboard must render without overflow.');

    await tester.tap(find.textContaining('DSP-2026-00417').first);
    await tester.pumpAndSettle();
    expect(find.text('Finalization gate'), findsOneWidget);
    expect(find.textContaining('Posted sales_dispatch ledger'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Open Delivery handoff'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'Dispatch load detail must render without overflow.');

    await tester.tap(find.widgetWithText(FilledButton, 'Open Delivery handoff'));
    await tester.pumpAndSettle();
    expect(find.text('Delivery Detail'), findsOneWidget);
    expect(find.text('DEL-2026-00681'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'Dispatch to Delivery handoff must render without overflow.');
  });
}
