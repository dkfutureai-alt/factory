import 'package:factoryos/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('admin reaches fleet vehicle driver trip and fuel workflows', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const FactoryOsApp());

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'manager@example.test');
    await tester.enterText(fields.at(1), 'preview123');
    final signIn = find.widgetWithText(FilledButton, 'Sign in');
    await tester.ensureVisible(signIn);
    await tester.tap(signIn);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Transport').first);
    await tester.pumpAndSettle();
    expect(find.text('Fleet & Transport'), findsOneWidget);
    expect(find.text('Vehicle availability'), findsOneWidget);
    expect(find.text('MH 13 DK 4521'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'Fleet dashboard must render without overflow.');

    await tester.tap(find.text('MH 13 DK 4521').first);
    await tester.pumpAndSettle();
    expect(find.text('Vehicle Detail'), findsOneWidget);
    expect(find.text('Documents & compliance'), findsOneWidget);
    expect(find.text('Cost & utilization'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'Vehicle detail must render without overflow.');

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Driver management'));
    await tester.pumpAndSettle();
    expect(find.text('Driver Detail'), findsOneWidget);
    expect(find.text('License & compliance'), findsOneWidget);
    expect(find.text('Performance snapshot'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'Driver detail must render without overflow.');

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trip management'));
    await tester.pumpAndSettle();
    expect(find.text('Trip Management'), findsOneWidget);
    expect(find.text('Today’s trip queue'), findsOneWidget);
    expect(find.text('TRIP-2026-00814'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'Trip management must render without overflow.');

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fuel management'));
    await tester.pumpAndSettle();
    expect(find.text('Fuel Management'), findsOneWidget);
    expect(find.text('Recent fuel entries'), findsOneWidget);
    expect(find.text('FUEL-01472'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'Fuel management must render without overflow.');
  });
}
