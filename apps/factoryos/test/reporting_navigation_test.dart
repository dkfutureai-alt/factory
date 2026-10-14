import 'package:factoryos/factoryos_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('admin reaches reports and all reporting surfaces render', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(MaterialApp(initialRoute: '/admin', routes: FactoryOsRoutes.routes));
    await tester.pumpAndSettle();

    final reportsNav = find.text('Reports').first;
    await tester.ensureVisible(reportsNav);
    await tester.tap(reportsNav);
    await tester.pumpAndSettle();
    expect(find.text('Reports Center'), findsOneWidget);
    expect(find.text('Report library'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Executive Analytics').first);
    await tester.pumpAndSettle();
    expect(find.text('Cross-module performance'), findsOneWidget);
    expect(find.text('Module scorecard'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Operations').first);
    await tester.pumpAndSettle();
    expect(find.text('Production, quality, inventory & maintenance'), findsOneWidget);
    expect(find.text('Operational exceptions'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Commercial').first);
    await tester.pumpAndSettle();
    expect(find.text('Sales, collections & purchase'), findsOneWidget);
    expect(find.text('Top customer performance'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Workforce & Fleet').first);
    await tester.pumpAndSettle();
    expect(find.text('People and transport performance'), findsOneWidget);
    expect(find.text('People & transport exceptions'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Report Builder').first);
    await tester.pumpAndSettle();
    expect(find.text('Build an export-ready report'), findsOneWidget);
    expect(find.text('Report configuration'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(FilledButton, 'Generate preview'));
    await tester.pumpAndSettle();
    expect(find.text('Export preview'), findsOneWidget);
    expect(find.text('₹72.3L / ₹54.8L'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
