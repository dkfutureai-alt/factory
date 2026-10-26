import 'package:factoryos_core/factoryos_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('honors accessibility Reduce Motion', (tester) async {
    Duration? observed;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) {
              observed = FactoryMotion.duration(
                context,
                FactoryMotion.navigation,
              );
              return const Scaffold(body: Text('Ready'));
            },
          ),
        ),
      ),
    );
    expect(observed, Duration.zero);
    expect(find.text('Ready'), findsOneWidget);
  });

  testWidgets('uses short transition when animation is allowed', (tester) async {
    Duration? observed;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: false),
          child: Builder(
            builder: (context) {
              observed = FactoryMotion.duration(
                context,
                FactoryMotion.standard,
              );
              return const Scaffold(body: Text('Ready'));
            },
          ),
        ),
      ),
    );
    expect(observed, FactoryMotion.standard);
  });

  testWidgets('pressable module card activates once', (tester) async {
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FactoryPressCard(
            semanticLabel: 'Open inventory',
            onTap: () => opened++,
            child: const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Inventory'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Inventory'));
    await tester.pumpAndSettle();
    expect(opened, 1);
  });

  testWidgets('reveal is visible with reduced motion', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: FactoryReveal(child: Text('Factory ready')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Factory ready'), findsOneWidget);
    final fade = tester.widget<Opacity>(find.byType(Opacity).last);
    expect(fade.opacity, 1);
  });
}
