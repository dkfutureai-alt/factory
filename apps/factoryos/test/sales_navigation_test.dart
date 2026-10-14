import 'package:factoryos/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('admin reaches sales customer order and tracking workflows', (tester) async {
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

    await tester.tap(find.text('Sales').first);
    await tester.pumpAndSettle();
    expect(find.text('Sales & Customers'), findsOneWidget);
    expect(find.text('Sales order queue'), findsOneWidget);
    expect(find.text('Top customers'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'Sales dashboard must render without overflow.');

    await tester.tap(find.text('CUST-0042').first);
    await tester.pumpAndSettle();
    expect(find.text('Customer Detail'), findsOneWidget);
    expect(find.text('Customer profile'), findsOneWidget);
    expect(find.textContaining('98•••'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'Customer detail must render without overflow.');

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('SO-2026-01842').first);
    await tester.pumpAndSettle();
    expect(find.text('Sales Order Detail'), findsOneWidget);
    expect(find.text('Order lines'), findsOneWidget);
    expect(find.text('Order lifecycle'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'Sales order detail must render without overflow.');

    await tester.tap(find.widgetWithText(FilledButton, 'Open tracking'));
    await tester.pumpAndSettle();
    expect(find.text('Payment & Delivery Tracking'), findsOneWidget);
    expect(find.text('Payment history'), findsOneWidget);
    expect(find.text('Delivery timeline'), findsOneWidget);
    expect(find.text('DSP-2026-00912'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'Payment and delivery tracking must render without overflow.');
  });
}
