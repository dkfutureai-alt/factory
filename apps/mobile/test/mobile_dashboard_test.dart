import 'package:factoryos_core/factoryos_core.dart';
import 'package:factoryos_mobile/main_phase11.dart' show MobileData;
import 'package:factoryos_mobile/mobile_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const modules = <AppModule>[
    AppModule(key: 'inventory', name: 'Inventory', sortOrder: 1),
    AppModule(key: 'hr', name: 'HR', sortOrder: 2),
  ];

  testWidgets('dashboard displays real bootstrap counts and opens a module',
      (tester) async {
    AppModule? opened;
    const data = MobileData(
      organizationName: 'Example Works',
      role: AppRole.employee,
      factories: [
        {'name': 'North Plant', 'code': 'NP-1', 'city': 'Pune'},
      ],
      modules: modules,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: FactoryTheme.light(),
        home: Scaffold(
          body: FactoryHomeDashboard(
            data: data,
            onOpenModule: (_, module) => opened = module,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Example Works'), findsOneWidget);
    expect(find.text('North Plant'), findsOneWidget);
    expect(find.text('2 workspaces'), findsOneWidget);
    expect(find.text('2 available'), findsOneWidget);
    await tester.tap(find.text('Inventory'));
    expect(opened?.key, 'inventory');
  });

  testWidgets('narrow workspace does not overflow and shows empty state',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const data = MobileData(
      organizationName: 'Example',
      role: AppRole.employee,
      factories: [],
      modules: [],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: FactoryTheme.light(),
        home: Scaffold(
          body: FactoryHomeDashboard(
            data: data,
            onOpenModule: (_, _) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No factory assigned'), findsOneWidget);
    expect(find.text('No modules are enabled for this role.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
