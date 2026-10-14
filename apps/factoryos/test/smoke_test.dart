import 'package:factoryos/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('login validates and opens admin preview', (tester) async {
    await tester.pumpWidget(const FactoryOsApp());

    expect(find.text('Welcome to FactoryOS'), findsOneWidget);

    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(2));

    await tester.enterText(fields.at(0), 'manager@example.test');
    await tester.enterText(fields.at(1), 'preview123');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Operations overview'), findsOneWidget);
    expect(find.textContaining('3420 / 4800'), findsOneWidget);
  });
}
