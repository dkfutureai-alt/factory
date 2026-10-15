import 'package:factoryos/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('admin reaches HR employee attendance leave and holiday workflows', (tester) async {
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

    await tester.tap(find.text('HR').first);
    await tester.pumpAndSettle();
    expect(find.text('HR & Workforce'), findsOneWidget);
    expect(find.text('Today attendance'), findsOneWidget);
    expect(find.text('Pending approvals'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'HR dashboard must render without overflow.');

    await tester.tap(find.text('Ravi Patil').first);
    await tester.pumpAndSettle();
    expect(find.text('Employee Detail'), findsOneWidget);
    expect(find.text('Employment & compliance'), findsOneWidget);
    expect(find.textContaining('98•••'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'Employee detail must render without overflow.');

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Attendance & leave'));
    await tester.pumpAndSettle();
    expect(find.text('Attendance & Leave'), findsOneWidget);
    expect(find.text('Daily attendance register'), findsOneWidget);
    expect(find.text('Leave requests'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'Attendance and leave page must render without overflow.');

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Holidays'));
    await tester.pumpAndSettle();
    expect(find.text('Holiday Calendar'), findsOneWidget);
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text('Upcoming holidays'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'Holiday calendar must render without overflow.');
  });
}
