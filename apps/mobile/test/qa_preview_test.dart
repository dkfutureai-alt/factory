import 'package:factoryos_mobile/qa_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('offline QA preview is explicitly labeled and uses fixture data',
      (tester) async {
    await tester.pumpWidget(const FactoryOsQaPreviewApp());
    await tester.pumpAndSettle();
    expect(find.text('OFFLINE UI PREVIEW · NO LIVE DATA'), findsOneWidget);
    expect(find.text('DEMO FACTORY · NOT CONNECTED'), findsOneWidget);
    expect(find.text('Example Plant'), findsOneWidget);
  });

  testWidgets('device reviewer can inspect work and profile without a backend',
      (tester) async {
    await tester.pumpWidget(const FactoryOsQaPreviewApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Work').last);
    await tester.pumpAndSettle();
    expect(find.text('Workspaces'), findsOneWidget);
    expect(find.text('Production'), findsOneWidget);
    await tester.tap(find.text('Production'));
    await tester.pump();
    expect(
      find.text(
        'Production: visual preview only. No data was read or changed.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    expect(find.text('Visual QA fixture'), findsOneWidget);
    expect(find.text('OFFLINE UI PREVIEW · NO LIVE DATA'), findsOneWidget);
  });

  testWidgets('role switch changes fixture permissions without authentication',
      (tester) async {
    await tester.pumpWidget(const FactoryOsQaPreviewApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Driver').last);
    await tester.pumpAndSettle();
    expect(find.text('Driver'), findsWidgets);

    await tester.tap(find.text('Work').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Fleet');
    await tester.pumpAndSettle();
    expect(find.text('Fleet'), findsOneWidget);
  });

  testWidgets('offline QA banner is responsive at 320px and large text',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(2)),
      child: FactoryOsQaPreviewApp(),
    ));
    await tester.pumpAndSettle();
    expect(find.text('OFFLINE UI PREVIEW · NO LIVE DATA'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
