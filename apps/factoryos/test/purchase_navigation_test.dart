import 'package:factoryos/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('admin opens purchase dashboard and purchase order detail', (tester) async {
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

    await tester.tap(find.text('Purchase').first);
    await tester.pumpAndSettle();
    expect(find.text('Purchase order queue'), findsOneWidget);
    expect(find.text('Supplier performance'), findsOneWidget);
    expect(find.text('Recent goods receipts'), findsOneWidget);

    await tester.tap(find.textContaining('PO-2026-00481').first);
    await tester.pumpAndSettle();
    expect(find.text('Order lines'), findsOneWidget);
    expect(find.text('Supplier & commercial terms'), findsOneWidget);
    expect(find.text('Approval & receiving checks'), findsOneWidget);
    expect(find.textContaining('350 kg pending'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
