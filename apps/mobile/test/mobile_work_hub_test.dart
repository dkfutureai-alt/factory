import 'package:factoryos_core/factoryos_core.dart';
import 'package:factoryos_mobile/main_phase11.dart' show MobileData;
import 'package:factoryos_mobile/mobile_work_hub.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const modules = <AppModule>[
    AppModule(key: 'production', name: 'Production', sortOrder: 1),
    AppModule(key: 'hr', name: 'Human Resources', sortOrder: 3),
    AppModule(key: 'reports', name: 'Reports', sortOrder: 5),
    AppModule(key: 'delivery', name: 'Delivery', sortOrder: 6),
    AppModule(key: 'vehicles', name: 'Fleet', sortOrder: 7),
    AppModule(key: 'unimplemented', name: 'Coming Soon', sortOrder: 9),
  ];

  test('only launchable modules are offered, including role restrictions', () {
    const employee = MobileData(
      organizationName: 'Example Works',
      role: AppRole.employee,
      factories: [],
      modules: modules,
    );
    final available = FactoryWorkHubPolicy.available(employee);
    expect(available.map((item) => item.key), [
      'production', 'hr', 'delivery',
    ]);
    expect(available.any((item) => item.key == 'reports'), isFalse);
    expect(available.any((item) => item.key == 'vehicles'), isFalse);
    expect(available.any((item) => item.key == 'unimplemented'), isFalse);

    const driver = MobileData(
      organizationName: 'Example Works',
      role: AppRole.driver,
      factories: [],
      modules: modules,
    );
    expect(FactoryWorkHubPolicy.available(driver).map((e) => e.key),
        containsAll(['production', 'hr', 'delivery', 'vehicles']));
  });

  testWidgets('search filters enabled workspaces and taps open correct one',
      (tester) async {
    const employee = MobileData(
      organizationName: 'Example Works',
      role: AppRole.employee,
      factories: [],
      modules: modules,
    );
    AppModule? selected;
    await tester.pumpWidget(MaterialApp(
      theme: FactoryTheme.light(),
      home: Scaffold(
        body: FactoryWorkHub(
          data: employee,
          onOpenModule: (_, module) => selected = module,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Human Resources'), findsOneWidget);
    expect(find.text('Coming Soon'), findsNothing);

    await tester.enterText(find.byType(TextField), 'human');
    await tester.pumpAndSettle();
    expect(find.text('Human Resources'), findsOneWidget);
    expect(find.text('Production'), findsNothing);
    await tester.tap(find.text('Human Resources'));
    expect(selected?.key, 'hr');
  });

  testWidgets('empty role stays truthful instead of showing fake tasks',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const empty = MobileData(
      organizationName: 'Example Works',
      role: AppRole.viewer,
      factories: [],
      modules: [],
    );
    await tester.pumpWidget(MaterialApp(
      theme: FactoryTheme.light(),
      home: Scaffold(
        body: FactoryWorkHub(
          data: empty,
          onOpenModule: (_, _) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('No operational workspaces are available'), findsOneWidget);
    expect(find.textContaining('task assigned'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
