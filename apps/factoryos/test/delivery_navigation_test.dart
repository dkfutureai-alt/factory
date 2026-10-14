import 'package:factoryos/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('dispatch reaches delivery detail and exception workflows', (tester) async {
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

    await tester.tap(find.text('Dispatch').first);
    await tester.pumpAndSettle();
    expect(find.text('Dispatch'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Delivery queue'));
    await tester.pumpAndSettle();

    expect(find.text('Delivery Management'), findsOneWidget);
    expect(find.text('Delivery queue'), findsOneWidget);
    expect(find.textContaining('DEL-2026-00681'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'Delivery dashboard must render without overflow.');

    await tester.tap(find.textContaining('DEL-2026-00681').first);
    await tester.pumpAndSettle();
    expect(find.text('Delivery Detail'), findsOneWidget);
    expect(find.text('Proof of delivery'), findsOneWidget);
    expect(find.text('Delivery items'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'Delivery detail must render without overflow.');

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('DEL-2026-00678').first);
    await tester.pumpAndSettle();
    expect(find.text('Delivery Exception / Return'), findsOneWidget);
    expect(find.text('Rejected items'), findsOneWidget);
    expect(find.text('Inventory handoff rule'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'Delivery exception must render without overflow.');
  });
}
