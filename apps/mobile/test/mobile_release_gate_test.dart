import 'package:factoryos_core/factoryos_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:factoryos_mobile/mobile_release_gate.dart';

void main() {
  testWidgets('mandatory version blocks existing workspace until rechecked', (
    tester,
  ) async {
    var checks = 0;
    await tester.pumpWidget(MaterialApp(
      home: MobileReleaseGate(
        checkPolicy: () async {
          checks++;
          return const MobileReleaseState(
            action: FactoryReleaseAction.forceUpdate,
            notes: 'Safety-critical scanner upgrade',
          );
        },
        child: const Text('Sensitive warehouse workspace'),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Update required'), findsOneWidget);
    expect(find.text('Sensitive warehouse workspace'), findsNothing);
    expect(find.text('Not now'), findsNothing);
    expect(find.text('Safety-critical scanner upgrade'), findsOneWidget);
    await tester.tap(find.text('Check again'));
    await tester.pumpAndSettle();
    expect(checks, 2);
    expect(find.text('Sensitive warehouse workspace'), findsNothing);
  });

  testWidgets('optional version can be deferred', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MobileReleaseGate(
        checkPolicy: () async => const MobileReleaseState(
          action: FactoryReleaseAction.optionalUpdate,
        ),
        child: const Text('Driver workspace'),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Update available'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.text('Driver workspace'), findsOneWidget);
  });

  testWidgets('maintenance has no bypass to stock operations', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MobileReleaseGate(
        checkPolicy: () async => const MobileReleaseState(
          action: FactoryReleaseAction.maintenance,
        ),
        child: const Text('Inventory transfer'),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Scheduled maintenance'), findsOneWidget);
    expect(find.text('Inventory transfer'), findsNothing);
    expect(find.text('Continue for now'), findsNothing);
  });

  testWidgets('connection error is visibly different from no policy', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(
      home: MobileReleaseGate(
        checkPolicy: () async => throw StateError('network offline'),
        child: const Text('Employee attendance'),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Update check unavailable'), findsOneWidget);
    expect(find.text('Employee attendance'), findsNothing);
    await tester.tap(find.text('Continue for now'));
    await tester.pumpAndSettle();
    expect(find.text('Employee attendance'), findsOneWidget);
  });

  testWidgets('trusted update URL is launched explicitly', (tester) async {
    Uri? opened;
    final url = Uri.parse('https://example.org/app/download');
    await tester.pumpWidget(MaterialApp(
      home: MobileReleaseGate(
        checkPolicy: () async => MobileReleaseState(
          action: FactoryReleaseAction.forceUpdate,
          downloadUrl: url,
        ),
        openUpdateLink: (uri) async => opened = uri,
        child: const Text('Factory data'),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open update page'));
    await tester.pumpAndSettle();
    expect(opened, url);
    expect(find.text('Factory data'), findsNothing);
  });
}
