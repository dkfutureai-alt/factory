import 'package:factoryos/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('admin can open inventory and scanner workflows', (tester) async {
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

    await tester.tap(find.text('Inventory').first);
    await tester.pumpAndSettle();
    expect(find.text('Live stock position • 14 Oct 2026'), findsOneWidget);
    expect(find.text('₹42.8L'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Scan item'));
    await tester.pumpAndSettle();
    expect(find.text('Camera scanner integration pending'), findsOneWidget);

    final manualEntry = find.byType(TextField);
    await tester.enterText(manualEntry.last, 'RM-STEEL-001');
    await tester.tap(find.widgetWithText(FilledButton, 'Use manual entry'));
    await tester.pumpAndSettle();

    expect(find.text('MS Steel Sheet 2mm'), findsOneWidget);
    expect(find.text('1240 kg available'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
